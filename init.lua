-- savepos/init.lua

local worldname
local selected = 1
local selected_map = {}
local rename_index
local storage = minetest.get_mod_storage()

local player
minetest.register_on_connect(function()
	player = minetest.localplayer
end)

---
--- HELPERS
---

local function renumber_table(t)
    local result = {}
    for _, value in pairs(t) do
        result[#result+1] = value
    end
    return result
end

local function get_listnames()
	local l = storage:to_table()
	local lists = {}
	for _, i in pairs(l.fields) do
		lists[#lists + 1] = _
	end
	return lists
end

local function list_exists(name)
	local l = storage:to_table()
	for _, i in pairs(l.fields) do
		if _ == name then
			return true
		end
	end
end

local function get_list(name)
	return minetest.deserialize(storage:get_string(name)) or {}
end

local function set_list(name, value)
	storage:set_string(name, minetest.serialize(value))
end

local function get_list_item(name, index)
	local list = get_list(name)
	if list[index] then
		return list[index]
	end
end

local function add_list_item(name, toadd) -- TEST ONWARDS
	local list = get_list(name)
	list[#list + 1] = toadd
	set_list(name, list)
end

local function remove_list_item(name, index)
	local list = get_list(name)
	if list[index] then
		list[index] = nil
		list = renumber_table(list)
		set_list(name, list)
		return true
	end
end

local function change_list_item(name, index, new)
	local list = get_list(name)
	if list[index] then
		list[index] = new
		set_list(name, list)
	end
end

local function change_list_item_field(name, index, field, new)
	local list = get_list(name)
	if list[index] and list[index][field] then
		list[index][field] = new
		set_list(name, list)
		return true
	end
end

---
--- FUNCTIONS
---

local function send(msg)
	minetest.display_chat_message(minetest.colorize("red", "[SavePos]").." "..msg)
end

local function teleport(index)
	local list = get_list(worldname)
	local i
	if selected_map[index] and list[selected_map[index]] then
		i = list[selected_map[index]]
	else
		i = list[index]
	end

	if i then
		local pos  = i.pos
		local tpos = pos.x.." "..pos.y.." "..pos.z
		minetest.run_server_chatcommand("teleport", tpos)
	else
		send("Could not teleport! Index "..dump(index).." doesn't exist!")
	end
end

local function check_error(message, error_message)
	if error_message then
		return minetest.colorize("red", error_message..":")
	else
		assert(message, "savepos: check_error: message is nil")
		return message..":"
	end
end

---
--- Formspec
---

local function show_set(error)
	local default = ""
	local info = minetest.get_server_info()
	if info and info.address ~= "" then
		default = info.address..":"..info.port
	end

	local message = check_error("World Name", error)
	minetest.show_formspec("savepos_set", [[
		size[6,1]
		bgcolor[#080808BB;true]
		background[5,5;1,1;gui_formbg.png;true]
		field[0.15,0.2;6.4,1;name;]]..message..[[;]]..default..[[]
		button[-0.1,0.65;2,1;done;Done]
		button_exit[4.2,0.65;2,1;quit;Cancel]
		field_close_on_enter[name;false]
	]])
end

local function show_add(error)
	local message = check_error("Position Name", error)
	minetest.show_formspec("savepos_add", [[
		size[6,1]
		bgcolor[#080808BB;true]
		background[5,5;1,1;gui_formbg.png;true]
		field[0.15,0.2;6.4,1;name;]]..message..[[;]
		button[-0.1,0.65;2,1;done;Done]
		button[4.2,0.65;2,1;quit;Cancel]
		field_close_on_enter[name;false]
	]])
end

local function show_rename(index, error)
	local i = get_list_item(worldname, index)
	if i then
		local message = check_error("Rename Position", error)
		local name = i.name or ""
		rename_index = index
		minetest.show_formspec("savepos_rename", [[
			size[6,1]
			bgcolor[#080808BB;true]
			background[5,5;1,1;gui_formbg.png;true]
			field[0.15,0.2;6.4,1;name;]]..message..[[;]]..name..[[]
			button[-0.1,0.65;2,1;done;Done]
			button[4.2,0.65;2,1;quit;Cancel]
			field_close_on_enter[name;false]
		]])
	end
end

local function show_confirm(name, text)
	minetest.show_formspec("savepos_"..name, [[
		size[6,1]
		bgcolor[#080808BB;true]
		background[5,5;1,1;gui_formbg.png;true]
		label[0,0;]]..text..[[]
		button[-0.1,0.65;2,1;yes;Yes]
		button[4.2,0.65;2,1;no;No]
	]])
end

local function show_main(search)
	selected_map = {}
	local list = get_list(worldname)
	local text = ""
	local count = #list or 0
	local added_index = 0
	for _, i in ipairs(list) do
		if not search or (search and i.name:lower():find(search:lower())) then
			added_index = added_index + 1
			selected_map[added_index] = _
			local c = ""
			if text ~= "" then c = "," end
			text = text..c..i.name.." "..minetest.pos_to_string(i.pos):gsub(",", " ")
		end
	end

	local action_buttons = [[
		button_exit[4.2,0.75;2,1;go;Go]
		tooltip[go;Teleport to selected position]
		button[4.2,1.5;2,1;add;Add]
		tooltip[add;Save current position]
		button[4.2,2.25;2,1;rename;Rename]
		tooltip[rename;Rename selected position]
		button[4.2,3;2,1;remove;Remove]
		tooltip[remove;Remove selected position]
	]]

	if text == "" and search then
		action_buttons = ""
	elseif text == "" or next(list) == nil then
		action_buttons = [[
			button[4.2,0.75;2,1;add;Add]
			tooltip[add;Save current position]
		]]
	end

	local count_text = tostring(count)
	if count < 10 then
		count_text = " " .. count_text
	elseif count >= 100 then
		count_text = count_text .. " "
	end

	search = search or ""

	minetest.show_formspec("savepos_main", [[
		size[6,8]
		bgcolor[#080808BB;true]
		background[5,5;1,1;gui_formbg.png;true]

		label[-0.1,-0.33;Search ]]..worldname..[[:]
		field[0.18,0.3;4.39,1;search;;]]..search..[[]
		button[4.2,0;2,1;search_button;Search]
		tooltip[search_button;Search saved positions]
		table[-0.11,0.88;4.2,7.375;list;]]..text..[[;]]..selected..[[]
		field_close_on_enter[search;false]

		]]..action_buttons..[[

		label[4.45,5.6;]]..count..[[ Positions]
		button[4.2,6;2,1;rst;Reset]
		tooltip[rst;Reset saves for ]]..worldname..[[]
		button[4.2,6.75;2,1;rst_all;Reset All]
		tooltip[rst_all;Reset saves for all worlds]
		button_exit[4.2,7.5;2,1;exit;Exit]
	]])
end

---
--- Registrations
---

minetest.register_on_formspec_input(function(name, fields)
	if name == "savepos_set" then
		if (fields.done or fields.key_enter_field == "name") and
				fields.name and fields.name ~= "" then
			worldname = minetest.formspec_escape(fields.name)
			send("World name set to \""..fields.name.."\"")

			if not list_exists(worldname) then
				set_list(worldname, {})
			end

			-- Worldname saved, show main formspec
			show_main()
		elseif (fields.done or fields.key_enter_field == "name")
				and fields.name == "" then
			show_set("Worldname cannot be blank")
		end
	elseif name == "savepos_main" then
		if fields.search and (fields.key_enter_field == "search" or
				fields.search_button) then
			if not fields.search or fields.search == "" then
				show_main()
			else
				show_main(fields.search)
			end
		elseif fields.list then
			local e = fields.list:split(":")
			selected = tonumber(e[2])
			if e[1] == "DCL" and e[3] == "1" then
				teleport(selected)
			end
		elseif fields.go then
			if selected then
				teleport(selected)
			end
		elseif fields.add then
			show_add()
		elseif fields.rename then
			show_rename(selected)
		elseif fields.remove then
			local i = get_list_item(worldname, selected)
			if i then
				show_confirm("remove", "Are you sure you want to remove "
					..i.name.."?")
			end
		elseif fields.rst then
			show_confirm("rst", "Are you sure you want to reset saves for "
					..worldname.."?")
		elseif fields.rst_all then
			show_confirm("rst_all", "Are you sure you want to reset all saves?")
		end
	elseif name == "savepos_add" then
		if (fields.done or fields.key_enter_field == "name") and
				fields.name and fields.name ~= "" then
			local pos = vector.round(player:get_pos())
			local name = minetest.formspec_escape(fields.name)
			add_list_item(worldname, { pos = pos, name = name })
		elseif (fields.done or fields.key_enter_field == "name")
				and fields.name == "" then
			show_add("Position name cannot be blank")
		end

		if ((fields.done or fields.key_enter_field == "name") and fields.name and
				fields.name ~= "") or fields.quit then
			show_main()
		end
	elseif name == "savepos_rename" then
		if (fields.done or fields.key_enter_field == "name") and
				fields.name and fields.name ~= "" and rename_index then
			local name = minetest.formspec_escape(fields.name)
			change_list_item_field(worldname, rename_index, "name", name)
		elseif (fields.done or fields.key_enter_field == "name")
				and fields.name == "" then
			show_rename(rename_index, "New position name cannot be blank")
		end

		if ((fields.done or fields.key_enter_field == "name") and fields.name and
				fields.name ~= "") or fields.quit then
			show_main()
		end
	elseif name == "savepos_rst" then
		if fields.yes then
			set_list(worldname, {})
		end

		if fields.yes or fields.no then
			show_main()
		end
	elseif name == "savepos_rst_all" then
		if fields.yes then
			local new_table = { fields = {} }
			new_table.fields[worldname] = minetest.serialize({})
			storage:from_table(new_table)
		end

		if fields.yes or fields.no then
			show_main()
		end
	elseif name == "savepos_remove" then
		if fields.yes then
			remove_list_item(worldname, selected)
			selected = 1
			show_main()
		end

		if fields.yes or fields.no then
			show_main()
		end
	end
end)

minetest.register_chatcommand("pos", {
	description = "Set or teleport between positions",
	func = function(param)
		-- If unset show set formspec, else show main.
		if not worldname or worldname == "" then
			show_set()
		else
			show_main()
		end
	end,
})
