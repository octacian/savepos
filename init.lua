-- savepos/init.lua

local listname
local selected = 1
local sort_order = "A-Z"
local sort_map = {["A-Z"] = "1", ["Z-A"] = "2", ["Distance"] = "3", ["Date Added"] = "4", ["Date Modified"] = "5"}
local selected_map = {} -- Used to understand the selected item when the list is reorganized
local huds = {}
local storage = minetest.get_mod_storage()

local player
if minetest.register_on_connect then
	minetest.register_on_connect(function()
		player = minetest.localplayer
	end)
else
	minetest.after(0, function()
		player = minetest.localplayer
	end)
end

---
--- HELPERS
---

--[local function] Clean/renumber table indices
local function renumber_table(t)
    local result = {}
    for _, value in pairs(t) do
        result[#result+1] = value
    end
    return result
end

--[local function] Get names of all lists
local function get_listnames()
	local l = storage:to_table()
	local lists = {}
	for _, i in pairs(l.fields) do
		lists[#lists + 1] = _
	end
	return lists
end

--[local function] Check if a list exists
--[[local function list_exists(name)
	local l = storage:to_table()
	for _, i in pairs(l.fields) do
		if _ == name then
			return true
		end
	end
end]]--

--[local function] Get the contents of a list
local function get_list(name)
	return minetest.deserialize(storage:get_string(name)) or {}
end

--[local function] Set the contents of a list
local function set_list(name, value)
	if value then value = minetest.serialize(value) end
	storage:set_string(name, value)
end

--[local function] Get the contents of a list with keys embedded
local function get_list_with_keys(name)
	local list = minetest.deserialize(storage:get_string(name)) or {}
	for _, i in pairs(list) do
		list[_].key = _
	end

	return list
end

--[local function] Get the item at a particular indice of a list
local function get_list_item(name, index)
	local list = get_list(name)
	if list[index] then
		return list[index]
	end
end

--[local function] Add an item to a list
local function add_list_item(name, toadd)
	local list = get_list(name)
	local index = #list + 1
	list[index] = toadd
	set_list(name, list)
	return index
end

--[local function] Remove an item from a list
local function remove_list_item(name, index)
	local list = get_list(name)
	if list[index] then
		list[index] = nil
		list = renumber_table(list)
		set_list(name, list)
		return true
	end
end

--[local function] Change an item in a list
--[[local function change_list_item(name, index, new)
	local list = get_list(name)
	if list[index] then
		list[index] = new
		set_list(name, list)
	end
end]]--

--[local function] Change a particular field of an item in a list
local function change_list_item_field(name, index, field, new)
	local list = get_list(name)
	if list[index] then
		list[index][field] = new
		set_list(name, list)
		return true
	end
end

--[local function] Get the string to be prepended to the beginning of each formspec
-- Defines formspec size, background colour, and background image (from Minetest Game).
local function get_prepend_string(x, y)
	x, y = tonumber(x) or "8", tonumber(y) or "10"
	local background = [[
		background[5,5;1,1;gui_formbg.png;true]
		bgcolor[#080808BB;true]
	]]

	if storage:get_string("__background") == "false" then
		background = ""
	end

	return "size["..x..","..y.."]" .. background
end

---
--- FUNCTIONS
---

--[local function] Check if a hexidecimal color string is valid
local function check_color(str)
	if type(str) ~= "string" or (#str ~= 7 and #str ~= 4) or str:sub(1, 1) ~= "#" then
		return
	end

	local valid_characters = {
		"0", "1", "2", "3", "4", "5", "6", "7",
		"8", "9", "a", "b", "c", "d", "e", "f"
	}

	str = str:lower()
	for i = 2, #str do
		local valid
		for k = 1, #valid_characters do
			if valid_characters[k] == str:sub(i, i) then
				valid = true
				break
			end
		end

		if not valid then
			return
		end
	end

	return true
end

--[local function] Convert hexadecimal color string to a ColorSpec
local function hex_to_rgb(str)
	if check_color(str) then
		str = str:gsub("#", "")

		-- if only 3 characters, expand by doubling digits
		if #str == 3 then
			local new_str = ""
			for i = 1, #str do
				new_str = new_str..str:sub(i, i):rep(2)
			end
			str = new_str
		end

		return tonumber("0x00"..str:sub(1, 2)..str:sub(3, 4)..str:sub(5, 6))
	end
end

--[local function] Send a message to the player, colorized to be red
local function send(msg)
	minetest.display_chat_message(minetest.colorize("red", "[SavePos]").." "..msg)
end

--[local function] Process any particular indice against the selection map
local function get_mapped_indice(list, index)
	local i
	if selected_map[index] and list[selected_map[index]] then
		i = selected_map[index]
	else
		i = index
	end

	return i
end

--[local function] Get the item at a particular indice in a list based off of the selected map
-- Shorthand for: i = list[get_mapped_indice(list, selected)]
local function get_mapped(list, index)
	return list[get_mapped_indice(list, index)]
end

--[local function] Add waypoint to HUD by list index
local function hud_add(index)
	if player.hud_add and not huds[index] then
		local point = get_list_item(listname, index)
		-- if HUD is not disabled for this waypoint, add
		if point.hud ~= false then
			-- Add internal HUD ID to table
			huds[index] = player:hud_add({
				hud_elem_type = "waypoint",
				name = point.name,
				text = "m",
				world_pos = point.pos,
				number = hex_to_rgb(point.color) or 0x00FFFFFF,
			})

			return true
		end
	end
end

--[local function] Reload an HUD after its waypoint data has changed
local function hud_reload(index, name_changed, color_changed, world_pos_changed)
	if player.hud_add and huds[index] then
		local point = get_list_item(listname, index)
		if name_changed then player:hud_change(huds[index], "name", point.name) end
		if world_pos_changed then player:hud_change(huds[index], "world_pos", point.pos) end
		if color_changed then player:hud_change(huds[index], "number", hex_to_rgb(point.color) or 0x00FFFFFF) end
	end
end

--[local function] Remove waypoint from HUD by the index of its location in the list
local function hud_remove(index)
	if player.hud_add and huds[index] then
		player:hud_remove(huds[index])
		huds[index] = nil
		return true
	end
end

--[local function] Remove all HUDs
local function hud_remove_all()
	if player.hud_add then
		for _, i in pairs(huds) do
			player:hud_remove(i)
			huds[_] = nil
		end
	end
end

--[local function] Teleport to the position at a particular indice of the current list
-- Utilizes get_mapped to process the selected indice.
local function teleport(index)
	local i = get_mapped(get_list(listname), index)

	if i then
		local pos  = i.pos
		send("Attempting to teleport to "..minetest.colorize(i.color or "white", i.name)
			.." "..minetest.pos_to_string(pos).."...")
		local tpos = pos.x.." "..pos.y.." "..pos.z
		minetest.run_server_chatcommand("teleport", tpos)
	else
		send("Could not teleport! Index "..dump(index).." doesn't exist!")
	end
end

--[local function] Set the current list and attempt to display HUDs
local function set_listname(index)
	listname = get_mapped(get_listnames(), index) -- Update listname

	-- Attempt to display HUDs
	if player.hud_add then
		local list = get_list(listname)
		for _, i in pairs(list) do
			hud_add(_)
		end
	end
end

--[local function] Check if there is an error
local function check_error(message, error_message)
	-- if there is an error, display it
	if error_message then
		return minetest.colorize("red", error_message..":")
	else -- else, display the default message
		assert(message, "savepos: check_error: message is nil")
		return message..":"
	end
end

--[local function] Sort the current waypoint list using global sort_order
local function sort_list()
	-- Order map
	local map = {["0"] = 1, ["1"] = 2, ["2"] = 3, ["3"] = 4, ["4"] = 5, ["5"] = 6, ["6"] = 7,
		["7"] = 8, ["8"] = 9, ["9"] = 10, a = 11, b = 12, c = 13, d = 14, e = 15, f = 16, g = 17,
		h = 18, i = 19, j = 20, k = 21, l = 22, m = 23, n = 24, o = 25, p = 26, q = 27, r = 28,
		s = 29, t = 30, u = 31, v = 32, w = 33, x = 34, y = 35, z = 36}

	-- Get list as "t"
	local t = get_list_with_keys(listname)

	-- Detect sort order and sort using custom comparison functions
	local order = sort_map[sort_order]
	if order == "1" then
		table.sort(t, function(a, b) return map[a.name:sub(1, 1):lower()] < map[b.name:sub(1, 1):lower()] end)
	elseif order == "2" then
		table.sort(t, function(a, b) return map[a.name:sub(1, 1):lower()] > map[b.name:sub(1, 1):lower()] end)
	elseif order == "3" then
		local pos = player:get_pos()
		table.sort(t, function(a, b) return vector.distance(pos, a.pos) < vector.distance(pos, b.pos) end)
	elseif order == "4" then
		table.sort(t, function(a, b) return a.added < b.added end)
	elseif order == "5" then
		table.sort(t, function(a, b) return a.modified > b.modified end)
	end

	-- Return iterator function
	local i = 0
	return function()
		i = i + 1
		if t[i] then
			return i, t[i]
		end
	end
end

---
--- Reusable Formspec Pages
---

--[local function] Confirmation formspec
local function show_confirm(name, text)
	text = table.concat(minetest.wrap_text(minetest.formspec_escape(text), 40, true), ",")
	minetest.show_formspec("savepos_confirm_"..name, get_prepend_string(6, 1) .. [[
		tableoptions[background=#00000000;highlight=#00000000;border=false]
		table[-0.13,-0.3;6.1,1;title;]]..text..[[;1]
		button[-0.1,0.65;2,1;yes;Yes]
		button[4.2,0.65;2,1;no;No]
	]])
end

--[local function] Add formspec (basic single field)
local function show_add(name, title, default, error)
	default = minetest.formspec_escape(default) or ""
	local message = check_error(title, error)
	minetest.show_formspec("savepos_add_"..name, get_prepend_string(6, 1) .. [[
		field[0.15,0.2;6.4,1;name;]]..message..[[;]]..default..[[]
		button[-0.1,0.65;2,1;done;Done]
		button[4.2,0.65;2,1;quit;Cancel]
		field_close_on_enter[name;false]
	]])
end

--[local function] Rename formspec
local function show_rename(name, title, default, error)
	default = minetest.formspec_escape(default) or ""
	local message = check_error(title, error)
	minetest.show_formspec("savepos_rename_"..name, get_prepend_string(6, 1) .. [[
		field[0.15,0.2;6.4,1;name;]]..message..[[;]]..default..[[]
		button[-0.1,0.65;2,1;done;Done]
		button[4.2,0.65;2,1;quit;Cancel]
		field_close_on_enter[name;false]
	]])
end

--[local function] Check the validity of a particular text-input field
local function handle_field(fieldname, fields, valid, invalid, cancel, after)
	local v
	-- if submitted and not blank, call valid
	if (fields.done or fields.key_enter_field == fieldname) and
			fields[fieldname] and fields[fieldname] ~= "" then
		if type(valid) == "function" then valid() end
		v = true
	-- elseif submitted and blank, call invalid
	elseif (fields.done or fields.key_enter_field == "name")
			and fields[fieldname] == "" then
		if type(invalid) == "function" then invalid() end
	-- elseif cancel is pressed, call cancel
	elseif fields.quit then
		if type(cancel) == "function" then cancel() end
	end

	-- Call after once everything else is done
	if type(after) == "function" then after(v) end
end

--[local function] Process results from the basic confirmation formspec
local function handle_confirm(fields, yes, no, after)
	if fields.yes then
		if type(yes) == "function" then yes(fields) end
	end

	if fields.no then
		if type(no) == "function" then no(fields) end
	end

	if fields.yes or fields.no then
		if type(after) == "function" then after(fields) end
	end
end

---
--- Formspec Pages
---

--[local function] Show formspec allowing the management of lists
local function show_lists(search)
	selected_map = {} -- Reset selection map
	local lists = get_listnames() -- Get lists
	local text = ""
	local count = #lists or 0
	local waypoint_count = 0
	local added_index = 0
	-- Build selection map and format text for use in a table
	for _, i in ipairs(lists) do
		if not search or (search and i:lower():find(search:lower())) then
			if i:sub(1, 2) ~= "__" then
				added_index = added_index + 1
				selected_map[added_index] = _
				local c = ""
				if text ~= "" then c = "," end

				local wcount = #get_list(i) -- Get waypoint count
				local waypoint_count_text = "Waypoints"
				-- Use singular form of count text if only 1 waypoint
				if wcount == 1 then
					waypoint_count_text = "Waypoint"
				end

				waypoint_count = waypoint_count + wcount
				text = text..c..wcount.." "..waypoint_count_text..","..minetest.formspec_escape(i)
			end
		end
	end

	-- if selected is greater than the total number of lists, set selected to 1
	if selected > count then
		selected = 1
	end

	local count_text = "Lists"
	-- Use singular form of count text if only 1 item
	if count == 1 then
		count_text = "List"
	end

	local waypoint_count_text = "Waypoints"
	-- Use singular form of count text if only 1 waypoint
	if waypoint_count == 1 then
		waypoint_count_text = "Waypoint"
	end

	local action_buttons = [[
		button[6.2,0.75;2,1;use;Use]
		tooltip[use;Use selected list]
		button[6.2,1.5;2,1;add;Add]
		tooltip[add;Create a new list]
		button[6.2,2.25;2,1;rename;Rename]
		tooltip[rename;Rename selected list]
		button[6.2,3;2,1;remove;Remove]
		tooltip[remove;Remove selected list]
	]]

	-- if nothing to display and there is text in the search bar, hide action buttons
	if text == "" and search then
		action_buttons = ""
	-- elseif there is nothing to display, limit action buttons
	elseif text == "" or next(lists) == nil then
		action_buttons = [[
			button[6.2,0.75;2,1;add;Add]
			tooltip[add;Save current position as a waypoint]
		]]
	end

	search = search or ""
	-- Show formspec
	minetest.show_formspec("savepos_lists", get_prepend_string(8, 10) .. [[
		label[-0.1,-0.33;Search Lists:]
		field[0.18,0.3;6.39,1;search;;]]..search..[[]
		button[6.2,0;2,1;search_button;Search]
		tooltip[search_button;Search waypoints]
		tablecolumns[text,width=5;text,width=20]
		table[-0.11,0.88;6.2,9.375;list;]]..text..[[;]]..selected..[[]
		field_close_on_enter[search;false]

		]]..action_buttons..[[

		label[6.7,7.2;]]..count.." "..count_text..[[]
		label[6.45,7.6;]]..waypoint_count.." "..waypoint_count_text..[[]
		button[6.2,8;2,1;rst;Reset]
		tooltip[rst;Reset selected waypoint list]
		button[6.2,8.75;2,1;rst_all;Reset All]
		tooltip[rst_all;Reset all waypoint lists]
		button_exit[6.2,9.5;2,1;exit;Exit]
	]])
end

--[local function] Show main waypoint list management formspec
local function show_main(search)
	minetest.log("Showing main...")
	selected_map = {} -- Reset selection map
	local pos = player:get_pos()
	local list = get_list(listname) -- Get current list items
	local text = ""
	local count = #list or 0
	local added_index = 0
	-- Build selection map and format text for use in a table
	for _, i in sort_list(list) do
		if not search or (search and i.name:lower():find(search:lower())) then
			added_index = added_index + 1
			selected_map[added_index] = i.key
			local c = ""
			if text ~= "" then c = "," end
			local dist = tostring(math.floor(vector.distance(pos, i.pos)))
			local color = i.color or "#ffffff"
			text = text..c..color..","..dist.."m,"..i.pos.x..","..i.pos.y..","..
				i.pos.z..","..minetest.formspec_escape(i.name)
		end
	end

	-- if selected is greater than the total number of items in the list, set selected to 1
	if selected > count then
		selected = 1
	end

	local count_text = "Waypoints"
	-- Use singular form of count text if only 1 waypoint
	if count == 1 then
		count_text = "Waypoint"
	end

	-- Starting height for action buttons
	local btn_height = 0.75
	--[local function] Get button height
	local function btnh()
		btn_height = btn_height + 0.75
		return btn_height
	end

	-- Formstring for go/teleport button
	local go_button = "button_exit[6.2,"..btnh()..";2,1;go;Go]" ..
		"tooltip[go;Teleport to selected waypoint]"
	-- if privileges API is available and player does not have teleport
	-- privileges, hide go button and shift others up
	if minetest.get_privilege_list().teleport ~= true then
		go_button = ""
		btn_height = 0
	end

	local action_buttons = go_button ..
		"button[6.2,"..btnh()..";2,1;add;Add]" ..
		"tooltip[add;Save current position as a waypoint]" ..
		"button[6.2,"..btnh()..";2,1;rename;Rename]" ..
		"tooltip[rename;Rename selected waypoint]" ..
		"button[6.2,"..btnh()..";2,1;remove;Remove]" ..
		"tooltip[remove;Remove selected waypoint]" ..
		"button[6.2,"..btnh()..";2,1;color;Color]" ..
		"tooltip[color;Set color of selected waypoint]"

	-- if nothing to display and there is text in the search bar, hide action buttons
	if text == "" and search then
		action_buttons = ""
	-- elseif there is nothing to display, limit action buttons
	elseif text == "" or next(list) == nil then
		action_buttons = "button[6.2,1.5;2,1;add;Add]" ..
			"tooltip[add;Save current position as a waypoint]"
	else -- else, add HUD toggler
		local item = get_mapped(get_list(listname), selected)
		if item then
			local status = "Disable HUD"
			if item.hud == false then
				status = "Enable HUD"
			end

			action_buttons = action_buttons ..
				"button[6.2,"..btnh()..";2,1;toggle_hud;" .. status .. "]" ..
				"tooltip[toggle_hud;"..status.." for selected waypoint]"
		end
	end

	search = search or ""
	local ln = minetest.formspec_escape(listname)
	-- Show formspec
	minetest.show_formspec("savepos_main", get_prepend_string(8, 10) .. [[
		label[-0.1,-0.33;Search ]]..ln..[[:]
		field[0.18,0.3;6.39,1;search;;]]..search..[[]
		button[6.2,0;2,1;search_button;Search]
		tooltip[search_button;Search waypoints]
		tablecolumns[color;text,width=2;text,width=2;text,width=2;text,width=2;text,width=20]
		table[-0.11,0.88;6.2,9.375;list;]]..text..[[;]]..selected..[[]
		field_close_on_enter[search;false]
		dropdown[6.2,0.85;1.95;sort;A-Z,Z-A,Distance,Date Added,Date Modified;]]..sort_map[sort_order]..[[]

		]]..action_buttons..[[

		label[6.5,7.6;]]..count.." "..count_text..[[]
		button[6.2,8;2,1;rst;Reset]
		tooltip[rst;Reset ]]..ln..[[ waypoint list]
		button[6.2,8.75;2,1;change;Change]
		tooltip[change;Change current list]
		button_exit[6.2,9.5;2,1;exit;Exit]
	]])
end

---
--- Registrations
---

minetest.register_on_formspec_input(function(name, fields)
	--[[ Handle lists view formspec ]]--
	if name == "savepos_lists" then
		-- Handle search bar
		if fields.search and (fields.key_enter_field == "search" or
				fields.search_button) then
			if not fields.search or fields.search == "" then
				show_lists()
			else
				show_lists(fields.search)
			end
		-- Update selected indice
		elseif fields.list then
			local e = fields.list:split(":")
			selected = tonumber(e[2])
			if e[1] == "DCL" and e[3] == "1" then -- Set current list
				set_listname(selected)
				show_main()
			end
		-- Set current list
		elseif fields.use then
			set_listname(selected)
			show_main()
		-- Trigger formspec to add a new list
		elseif fields.add then
			show_add("list", "List Name")
		-- Trigger formspec to rename selected list
		elseif fields.rename then
			show_rename("list", "List Name", get_mapped(get_listnames(), selected))
		-- Trigger confirmation to remove selected list
		elseif fields.remove then
			show_confirm("remove_list", "Are you sure you want to remove the selected list?")
		-- Trigger confirmation to reset selected list
		elseif fields.rst then
			show_confirm("rst_list", "Are you sure you want to reset the "
					.."selected waypoint list?")
		-- Trigger confirmation to reset all lists
		elseif fields.rst_all then
			show_confirm("rst_all_lists", "Are you sure you want to reset all waypoint lists?")
		end
	-- Handle add list formspec submission
	elseif name == "savepos_add_list" then
		handle_field("name", fields, function() -- Valid (not blank)
			if fields.name:sub(1, 2) ~= "__" then
				set_list(fields.name, {})
				show_lists()
			else
				show_add("list", "List Name", fields.name, "List name cannot begin with __")
			end
		end, function() -- Invalid (blank)
			show_add("list", "List Name", nil, "List name cannot be blank")
		end, function() -- Quit (Cancel pressed)
			show_lists()
		end)
	-- Handle rename list formspec submission
	elseif name == "savepos_rename_list" then
		handle_field("name", fields, function() -- Valid (not blank)
			if fields.name:sub(1, 2) ~= "__" then
				local original = get_mapped(get_listnames(), selected)
				local list = get_list(original)
				set_list(fields.name, list)
				set_list(original, nil)
				show_lists()
			else
				show_rename("list", "List Name", fields.name, "List name cannot begin with __")
			end
		end, function() -- Invalid (blank)
			show_rename("list", "List Name", get_mapped(get_listnames(), selected), "List name cannot be blank")
		end, function() -- Quit (Cancel pressed)
			show_lists()
		end)
	-- Handle remove list confirmation
	elseif name == "savepos_confirm_remove_list" then
		handle_confirm(fields, function() -- Remove
			set_list(get_mapped(get_listnames(), selected), nil)
		end, nil, function() -- Cancel
			show_lists()
		end)
	-- Handle reset list confirmation
	elseif name == "savepos_confirm_rst_list" then
		handle_confirm(fields, function() -- Reset
			set_list(get_mapped(get_listnames(), selected), {})
		end, nil, function() -- Cancel
			show_lists()
		end)
	-- Handle reset all lists confirmation
	elseif name == "savepos_confirm_rst_all_lists" then
		handle_confirm(fields, function() -- Reset all
			local new_table = { fields = {} }
			storage:from_table(new_table)
		end, nil, function() -- Cancel
			show_lists()
		end)

	--[[ Handle main waypoint list formspec ]]--
	elseif name == "savepos_main" then
		-- Handle search bar
		if fields.search and (fields.key_enter_field == "search" or
				fields.search_button) then
			if not fields.search or fields.search == "" then
				show_main()
			else
				show_main(fields.search)
			end
		-- Update selected indice
		elseif fields.list then
			local e = fields.list:split(":")
			selected = tonumber(e[2])
			if e[1] == "DCL" and e[3] == "1" then
				teleport(selected)
			end
			show_main() -- Reload main to update HUD toggler
		-- Teleport to selected position
		elseif fields.go then
			if selected then
				teleport(selected)
			end
		-- Trigger formspec to add a new waypoint
		elseif fields.add then
			show_add("waypoint", "Waypoint Name")
		-- Trigger formspec to rename a waypoint
		elseif fields.rename then
			show_rename("waypoint", "Waypoint Name", get_mapped(get_list(listname), selected).name)
		-- Trigger confirmation to remove a waypoint
		elseif fields.remove then
			local i = get_mapped(get_list(listname), selected)
			if i then
				show_confirm("remove", "Are you sure you want to remove "
					..i.name.."?")
			end
		-- Trigger formspec to set the color of a waypoint
		elseif fields.color then
			local color = get_mapped(get_list(listname), selected).color
			show_add("color", "Hex Color Value", color)
		-- Handle per-waypoint HUD toggler
		elseif fields.toggle_hud then
			local index = get_mapped_indice(get_list(listname), selected)
			local current = get_list_item(listname, index).hud
			change_list_item_field(listname, index, "hud", not current)

			-- if current is false, enable HUD
			if current == false then
				hud_add(index)
			else -- else, disable HUD
				hud_remove(index)
			end

			show_main() -- Refresh HUD toggler status
		-- Trigger confirmation to reset the current list
		elseif fields.rst then
			show_confirm("rst", "Are you sure you want to reset the "
					..listname.." waypoint list?")
		-- Trigger list management formspec
		elseif fields.change then
			hud_remove_all() -- Attempt to remove all HUDs
			listname = nil
			show_lists()
		-- Handle sort dropdown
		elseif fields.sort then
			minetest.log(dump(fields.sort))
			sort_order = fields.sort -- Update sort order
			show_main() -- Update formspec
		end
	-- Handle add waypoint formspec submission
	elseif name == "savepos_add_waypoint" then
		handle_field("name", fields, function()
			local pos = vector.round(player:get_pos())
			local time = os.time()
			local index = add_list_item(listname, { pos = pos, name = fields.name, hud = true,
				added = time, modified = time })
			hud_add(index) -- Add HUD
		end, function()
			show_add("waypoint", "Waypoint Name", nil, "Waypoint name cannot be blank")
		end, function() show_main() end, function(valid)
			if valid then show_main() end
		end)
	-- Handle rename waypoint formspec submission
	elseif name == "savepos_rename_waypoint" then
		handle_field("name", fields, function()
			local index = get_mapped_indice(get_list(listname), selected)
			change_list_item_field(listname, index, "name", fields.name)
			change_list_item_field(listname, index, "modified", os.time())
			hud_reload(index, true) -- Reload HUD
		end, function()
			show_rename("waypoint", "Waypoint Name", get_mapped(get_list(listname), selected).name,
				"New waypoint name cannot be blank")
		end, function() show_main() end, function(valid)
			if valid then show_main() end
		end)
	-- Handle remove waypoint confirmation
	elseif name == "savepos_confirm_remove" then
		handle_confirm(fields, function()
			local index = get_mapped_indice(get_list(listname), selected)
			remove_list_item(listname, index)
			hud_remove(index) -- Remove HUD
			selected = 1
			show_main()
		end, nil, function()
			show_main()
		end)
	-- Handle set color formspec submission
	elseif name == "savepos_add_color" then
		handle_field("name", fields, function() -- Valid
			if fields.name:sub(1, 1) ~= "#" then
				fields.name = "#"..fields.name
			end

			if check_color(fields.name) then
				local index = get_mapped_indice(get_list(listname), selected)
				change_list_item_field(listname, index, "color", fields.name)
				change_list_item_field(listname, index, "modified", os.time())
				hud_reload(index, nil, true)
				show_main()
			else
				show_add("color", "Hex Color Value", fields.name, "Invalid hex color value")
			end
		end, function() -- Invalid
			show_add("color", "Hex Color Value", fields.name, "Color value cannot be blank")
		end, function() show_main() end)
	-- Handle reset list confirmation
	elseif name == "savepos_confirm_rst" then
		handle_confirm(fields, function()
			set_list(listname, {})
		end, nil, function()
			show_main()
		end)
	end
end)

---
--- Chatcommand
---

minetest.register_chatcommand("pos", {
	description = "Set or teleport between waypoints",
	params = "help | background <true/false>",
	func = function(param)
		if param == "" or not param then
			-- If unset show set formspec, else show main.
			if not listname or listname == "" then
				show_lists()
			else
				show_main()
			end
		elseif param == "help" then
			local function c(str)
				return minetest.colorize("cyan", str)
			end

			return true, c(".pos").." | Open GUI\n" ..
				c(".pos help").." | Display help\n" ..
				c(".pos background <true/false>").." | Enable or disable image background for formspecs"
		else
			param = param:split(" ")
			if param[1] == "background" and param[2] and
					param[2] == "true" or param[2] == "false" then
				storage:set_string("__background", param[2])
				return true, "Set background to "..param[2].."."
			elseif param[1] == "background" and not param[2] then
				if storage:get_string("__background") == "false" then
					return true, "Formspec background image disabled."
				else
					return true, "Formspec background image enabled."
				end
			else
				return false, "Invalid parameters, try .pos help"
			end
		end
	end,
})
