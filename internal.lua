function areas:player_exists(name)
	return minetest.auth_table[name] ~= nil
end

-- Save the areas to a file
function areas:save()
	local datastr = minetest.serialize({self.owned,self.areas,self.regions})
	if not datastr then
		minetest.log("error", "[areas] Failed to serialize area data!")
		return
	end
	local file, err = io.open(self.filename, "w")
	if err then
		return err
	end
	file:write(datastr)
	file:close()
end

-- Load the areas table from the save file
function areas:load()
	local file, err = io.open(self.filename, "r")
	if err then
		self.areas = self.areas or {}
		return err
	end
	self.owned,self.areas,self.regions = minetest.deserialize(file:read("*a"))
	if type(self.owned) ~= "table" then
        self.owned = {}
		self.areas = {}
        self.regions = {}
	end
	file:close()
end

function areas:forRegions(area,operation)
    local keysSeen = {}
    local x1 = area.pos1.x
    local y1 = area.pos1.y
    local z1 = area.pos1.z
    local x2 = area.pos2.x
    local y2 = area.pos2.y
    local z2 = area.pos2.z

    for _,pos in ipairs({
        {x=x1,y=y1,z=z1},
        {x=x1,y=y1,z=z2},
        {x=x1,y=y2,z=z1},
        {x=x1,y=y2,z=z2},
        {x=x2,y=y1,z=z1},
        {x=x2,y=y1,z=z2},
        {x=x2,y=y2,z=z1},
        {x=x2,y=y2,z=z2}}) do
        local key = self.key(pos1)
        if not keysSeen[key] then
            keysSeen[key] = true
            local region = self.regions[key]
            operation(key,region)
        end
    end
end

function areas:addToRegions(area) 
    self:forRegions(area,function(key,region)
        if region == nil then
            region = {}
            self.regions[key] = region
        end
        region[#region+1] = area
    end)
end

function areas:removeFromRegions(area)
    self:forRegions(area,function(key, region)
        if region ~= nil then                
            local newregion = {}
            for _,oldarea in region do
                if area ~= oldarea then
                    newregion[#newregion+1] = oldarea
                end
            end
            self.regions[key] = newregion
        end
    end)
end

function areas:potentiallyIntersecting(area)
    local result = {}
    self:forRegions(area,function(key,region)
        if region ~= nil then
            for _,area in ipairs(region) do
                result[#result+1] = area
            end
        end
    end)
    return result
end

-- Add an area
function areas:add(owner, name, pos1, pos2, parent)
    local id = owner .. ':' .. name
	local area = {name=name, id=id, pos1=pos1, pos2=pos2, owner=owner,
			parent=parent}
    self.owners[#self.owners+1] = owner
    self.areas[id] = area
    areas:addtoRegions(pos1,pos2,area)
	return id
end

function areas:removeChildren()
    -- Recursively find child entries and remove them
    for _, child in self.children do
        child:removeChildren()
    end
end

-- Remove an area, and optionally it's children recursively.
-- If a area is deleted non-recursively the children will
-- have the removed area's parent as their new parent.
function areas:remove(id, area, recurse)
	if recurse then
        self:removeChildren(area)
	else
		-- Update parents
		local parent = area.parent -- nil for top level areas is O.K.
		for _, child in pairs(area.children) do
			-- The subarea parent will be niled out if the
			-- removed area does not have a parent
			child.parent = parent
		end
	end
    self:removeFromRegions(area)
    local owned = self.owned[area.owner]
    for i,testarea in ipairs(owned) do
        if area == testarea then
            table.remove(owned,i)
        end
    end
	-- Remove main entry
	self.areas[name] = nil
end

-- Checks if a area between two points is entirely contained by another area
function areas:canBeSubarea(pos1, pos2, parent)
	if not parent then
		return false
	end
	p1, p2 = parent.pos1, parent.pos2
	if (pos1.x >= p1.x and pos1.x <= p2.x) and
	   (pos2.x >= p1.x and pos2.x <= p2.x) and
	   (pos1.y >= p1.y and pos1.y <= p2.y) and
	   (pos2.y >= p1.y and pos2.y <= p2.y) and
	   (pos1.z >= p1.z and pos1.z <= p2.z) and
	   (pos2.z >= p1.z and pos2.z <= p2.z) then
		return true
	end
end

-- Checks if the user has sufficient privileges.
-- If the player is not a administrator it also checks
-- if the area intersects other areas that they do not own.
-- Also checks the size of the area and if the user already
-- has more than max_areas.
function areas:canPlayerAddArea(pos1, pos2, name)
	if minetest.check_player_privs(name, {areas=true}) then
		return true
	end

	-- Check self protection privilege, if it is enabled,
	-- and if the area is too big.
	if (not self.self_protection) or 
	   (not minetest.check_player_privs(name,
	   		{[areas.self_protection_privilege]=true})) then
		return false, "Self protection is disabled or you do not have"
				.." the necessary privilege."
	end

	if (pos2.x - pos1.x) > self.self_protection_max_size.x or
	   (pos2.y - pos1.y) > self.self_protection_max_size.y or
	   (pos2.z - pos1.z) > self.self_protection_max_size.z then
		return false, "Area is too big."
	end

	-- Check number of areas the user has and make sure it not above the max
	local count = 0
    local owned = self.owned[name]
    if owned and #owned > self.self_protection_max_areas then
		return false, "You have reached the maximum amount of"
				.." areas that you are allowed to  protect."
	end

	-- Check intersecting areas
	for _, area in ipairs(areas:potentiallyIntersecting({pos1=pos1,pos2=pos2})) do
		if (area.pos1.x <= pos2.x and area.pos2.x >= pos1.x) and
		   (area.pos1.y <= pos2.y and area.pos2.y >= pos1.y) and
		   (area.pos1.z <= pos2.z and area.pos2.z >= pos1.z) then
			-- Found an area intersecting with the suplied area
			if not areas:isAreaOwner(id, name) then
				return false, ("The area intersects with"
					.." %s [%u] owned by %s.")
					:format(area.name, id, area.owner)
			end
		end
	end

	return true
end

-- Given a id returns a string in the format:
-- "name [id]: owner (x1, y1, z1) (x2, y2, z2) -> children"
function areas:toString(area)
	local message = ("%s [%s]: %s %s %s"):format(
		area.name, area.id, area.owner,
		minetest.pos_to_string(area.pos1),
		minetest.pos_to_string(area.pos2))

	local children = area.children
	if #children > 0 then
        local childstr = {}
        for _,child in ipairs(children) do
            childstr[#childstr+1] = '('..areas:toString(child)..')'
        end
		message = message.." -> "..table.concat(childstr, ", ")
	end
	return message
end

-- Checks if a player owns an area or a parent of it
function areas:isAreaOwner(area, name)
	if minetest.check_player_privs(name, {areas=true}) then
		return true
	end
	while true do
		if cur.owner == name then
			return true
		elseif cur.parent then
			cur = cur.parent
		else
            return false
		end
	end
end

