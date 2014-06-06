-- This is inspired by the landrush mod by Bremaweb

areas.hud = {}

minetest.register_globalstep(function(dtime)
	for _, player in pairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		local pos = vector.round(player:getpos())
		local areaString = ""
		local first = true
		for _, area in ipairs(areas:getAreasAtPos(pos)) do
			if not first then
				areaString = areaString..", "
			else
				first = false
			end
			areaString = areaString .. ("%s (%s%s)")
					:format(area.name, area.owner,
					area.open and ":open" or "")
		end
		if not areas.hud[name] then
			areas.hud[name] = {}
			areas.hud[name].areasId = player:hud_add({
				hud_elem_type = "text",
				name = "Areas",
				number = 0xFFFFFF,
				position = {x=0, y=1},
				offset = {x=5, y=-60},
				direction = 0,
				text = "Areas: "..areaString,
				scale = {x=200, y=60},
				alignment = {x=1, y=1},
			})
			areas.hud[name].oldAreas = areaString
			return
		elseif areas.hud[name].oldAreas ~= areaString then
			player:hud_change(areas.hud[name].areasId, "text",
					"Areas: "..areaString)
			areas.hud[name].oldAreas = areaString
		end
	end
end)

minetest.register_on_leaveplayer(function(player)
	areas.hud[player:get_player_name()] = nil
end)

