local regionBase = 0x100 -- regionBase^3 possible regions in the entire map
-- only regions with areas will actually be created ofc
-- areas that overlap regions are in both regions.
-- max 8 regions per area (8 points on cube)

local regionSize = 31000 * 2 / regionBase

function areas.key(pos) 
    return pos.x / regionSize + pos.y / regionSize * regionBase + pos.z / regionSize * regionBase * regionBase
end

function areas:getAreasAtRegion(pos)
    return self.regions[self.key(pos)]
end

-- Returns a list of areas that include the provided position
function areas:getAreasAtPos(pos)
	local a = {}
	local px, py, pz = pos.x, pos.y, pos.z
	for _, area in pairs(self:getAreasAtRegion(pos)) do
		local ap1, ap2 = area.pos1, area.pos2
		if px >= ap1.x and px <= ap2.x and
		   py >= ap1.y and py <= ap2.y and
		   pz >= ap1.z and pz <= ap2.z then
			table.insert(a,area)
		end
	end
	return a
end

-- Checks if the area is unprotected or owned by you
function areas:canInteract(pos, name)
	if minetest.check_player_privs(name, {areas=true}) then
		return true
	end
	local owned = false
	for _, area in pairs(self:getAreasAtPos(pos)) do
		if area.owner == name or area.open then
			return true
		else
			owned = true
		end
	end
	return not owned
end

-- Returns a table (list) of all players that own a position (possibly overlapping areas)
function areas:getNodeOwners(pos)
	local owners = {}
	for _, area in pairs(self:getAreasAtPos(pos)) do
		table.insert(owners, area.owner)
	end
	return owners
end

