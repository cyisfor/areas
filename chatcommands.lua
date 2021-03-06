
minetest.register_chatcommand("protect", {
	params = "<AreaName>",
	description = "Protect your own area",
	privs = {[areas.self_protection_privilege]=true},
	func = function(name, param)
		if param == "" then
			return false, "Invalid usage, see /help protect."
		end
		local pos1, pos2 = areas:getPos(name)
		if not (pos1 and pos2) then
			return false, "You need to select an area first."
		end

		minetest.log("action", "/protect invoked, owner="..name..
				" AreaName="..param..
				" StartPos="..minetest.pos_to_string(pos1)..
				" EndPos="  ..minetest.pos_to_string(pos2))

		local canAdd, errMsg = areas:canPlayerAddArea(pos1, pos2, name)
		if not canAdd then
			return false, "You can't protect that area: "..errMsg
		end

		local id = areas:add(name, param, pos1, pos2, nil)
		areas:save()

		return true, "Area protected. ID: "..id
	end
})


minetest.register_chatcommand("set_owner", {
	params = "<PlayerName> <AreaName>",
	description = "Protect an area beetween two positions and give"
		.." a player access to it without setting the parent of the"
		.." area to any existing area",
	privs = {areas=true},
	func = function(name, param)
		local ownerName, areaName = param:match('^(%S+)%s(.+)$')

		if not ownerName then
			return false, "Incorrect usage, see /help set_owner."
		end

		local pos1, pos2 = areas:getPos(name)
		if not (pos1 and pos2) then
			return false, "You need to select an area first."
		end

		if not areas:player_exists(ownerName) then
			return false, "The player \""
					..ownerName.."\" does not exist."
		end

		minetest.log("action", name.." runs /set_owner. Owner = "..ownerName..
				" AreaName = "..areaName..
				" StartPos = "..minetest.pos_to_string(pos1)..
				" EndPos = "  ..minetest.pos_to_string(pos2))

		local id = areas:add(ownerName, areaName, pos1, pos2, nil)
		areas:save()
	
		minetest.chat_send_player(ownerName,
				"You have been granted control over area #"..
				id..". Type /list_areas to show your areas.")
		return true, "Area protected. ID: "..id
	end
})


minetest.register_chatcommand("add_owner", {
	params = "<ParentID> <Player> <AreaName>",
	description = "Give a player access to a sub-area beetween two"
		.." positions that have already been protected,"
		.." Use set_owner if you don't want the parent to be set.",
	func = function(name, param)
		local pid, ownerName, areaName
				= param:match('^(%d+) ([^ ]+) (.+)$')

		if not found then
			minetest.chat_send_player(name, "Incorrect usage, see /help add_owner")
			return
		end

		local pos1, pos2 = areas:getPos(name)
		if not (pos1 and pos2) then
			return false, "You need to select an area first."
		end

		if not areas:player_exists(ownerName) then
			return false, "The player \""..ownerName.."\" does not exist."
		end

		minetest.log("action", name.." runs /add_owner. Owner = "..ownerName..
				" AreaName = "..areaName.." ParentID = "..pid..
				" StartPos = "..pos1.x..","..pos1.y..","..pos1.z..
				" EndPos = "  ..pos2.x..","..pos2.y..","..pos2.z)

		-- Check if this new area is inside an area owned by the player
        local area = areas.areas[pid]
		if not area or
            (not areas:isAreaOwner(area, name)) or
		    (not areas:canBeSubarea(pos1, pos2, area)) then
			  return false, "You can't protect that area."
		end

		local id = areas:add(ownerName, areaName, pos1, pos2, pid)
		areas:save()

		minetest.chat_send_player(ownerName,
				"You have been granted control over area "..
				id..". Type /list_areas to show your areas.")
		return true, "Area protected. ID: "..id
	end
})

minetest.register_chatcommand("rename_area", {
	params = "<ID> <newName>",
	description = "Rename a area that you own",
	func = function(name, param)
		local id, newName = param:match("^(%d+)%s(.+)$")
		if not found then
			return false, "Invalid usage, see /help rename_area."
		end

		local area = areas.areas[id]
		if not area then
			return false, "That area doesn't exist."
		end

		if not areas:isAreaOwner(area, name) then
			return true, "You don't own that area."
		end

		area.name = newName
		areas:save()
		return true, "Area renamed."
	end
})


minetest.register_chatcommand("find_areas", {
	params = "<regexp>",
	description = "Find areas using a Lua regular expression",
	func = function(name, param)
		if param == "" then
			return false, "A regular expression is required."
		end

		-- Check expression for validity
		local function testRegExp()
			("Test [player:name]: Player (0,0,0) (0,0,0)"):find(param)
		end
		if not pcall(testRegExp) then
			return false, "Invalid regular expression."
		end

		local matches = {}
		for id, area in pairs(areas.areas) do
			if areas:isAreaOwner(area, name) then
                local s = areas:toString(area)
                if s:find(param) then
    				table.insert(matches, s)
                end
			end
		end
		if #matches > 1 then
			return true, table.concat(matches, "\n")
		else
			return true, "No matches found."
		end
	end
})


minetest.register_chatcommand("list_areas", {
	description = "List your areas, or all areas if you are an admin.",
	func = function(name, param)
		local admin = minetest.check_player_privs(name, {areas=true})
		local areaStrings = {}
        if admin then
    		for id, area in pairs(areas.areas) do
			    table.insert(areaStrings, areas:toString(area))
			end
        else
            local owned = areas.owned[name]
            if owned then
                for _, area in ipairs(owned) do
                    table.insert(areaStrings, areas:toString(area))
                end
            end
		end
		if #areaStrings == 0 then
			return true, "No visible areas."
		end
		return true, table.concat(areaStrings, "\n")
	end
})

minetest.register_chatcommand("recursive_remove_areas", {
	params = "<id>",
	description = "Recursively remove areas using an id",
	func = function(name, id)
		local area = areas.areas[id]
		if not area then
			return false, "Invalid usage, see"
					.." /help recursive_remove_areas"
		end

		if not areas:isAreaOwner(area, name) then
			return false, "Area "..id.." does not exist or is"
					.." not owned by you."
		end

		areas:remove(id, area, true)
		areas:save()
		return true, "Removed area "..id.." and it's sub areas."
	end
})


minetest.register_chatcommand("remove_area", {
	params = "<id>",
	description = "Remove an area using an id (nonrecursively)",
	func = function(name, id)
		local area = areas.areas[id]
		if not area then
			return false, "Invalid usage, see /help remove_area"
		end

		if not areas:isAreaOwner(area, name) then
			return false, "Area "..id.." does not exist or"
					.." is not owned by you."
		end

		areas:remove(id,area,false)
		areas:save()
		return true, "Removed area "..id
	end
})


minetest.register_chatcommand("change_owner", {
	params = "<ID> <NewOwner>",
	description = "Change the owner of an area using its ID",
	func = function(name, param)
		local id, newOwner = param:match("^(%S+)%s(%S+)$")

        local area = areas.areas[id]
		if not area then
			return false, "Invalid usage, see"
					.." /help change_owner."
		end
		
		if not areas:player_exists(newOwner) then
			return false, "The player \""..newOwner
					.."\" does not exist."
		end

		if not areas:isAreaOwner(area, name) then
			return false, "Area "..id.." does not exist"
					.." or is not owned by you."
		end
		area.owner = newOwner
		areas:save()
		minetest.chat_send_player(newOwner,
			("%s has given you control over the area %q (ID %d).")
				:format(name, area.name, id))
		return true, "Owner changed."
	end
})


minetest.register_chatcommand("area_open", {
	params = "<ID>",
	description = "Toggle an area open (anyone can interact) or closed",
	func = function(name, id)
        local area = areas.areas[id]
		if not area then
			return false, "Invalid usage, see /help area_open."
		end

		if not areas:isAreaOwner(area, name) then
			return false, "Area "..id.." does not exist"
					.." or is not owned by you."
		end
		local open = not area.open
		-- Save false as nil to avoid inflating the DB.
		area.open = open or nil
		areas:save()
		return true, ("Area %s."):format(open and "opened" or "closed")
	end
})

