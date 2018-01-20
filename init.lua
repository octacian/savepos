-- savepos/init.lua

local worldname
local selected = 1
local edit_index
local storage  = minetest.get_mod_storage()

local player
minetest.register_on_connect(function()
	player = minetest.localplayer
end)

---
--- FUNCTIONS
---

local function renumber_table(t)
    local result = {}
    for _, value in pairs(t) do
        result[#result+1] = value
    end
    return result
end

local function send(msg)
	minetest.display_chat_message(minetest.colorize("red", "[SavePos]").." "..msg)
end

local function teleport(index)
	local list = minetest.deserialize(storage:get_string(worldname))
	if list[index] then
		local pos  = list[index].pos
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

local function show_edit(index, error)
	local list = minetest.deserialize(storage:get_string(worldname))

	if list[index] then
		local message = check_error("Edit Position Name", error)
		local name = list[index].name or ""
		edit_index = index
		minetest.show_formspec("savepos_edit", [[
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

local function show_main()
	local list = minetest.deserialize(storage:get_string(worldname))
	local text = ""
	local count = #list or 0
	for _, i in ipairs(list) do
		local c
		if _ ~= 1 then c = "," else c = "" end
		text = text..c..i.name.." "..minetest.pos_to_string(i.pos):gsub(",", " ")
	end

	local action_buttons = [[
		button_exit[4.2,0;2,1;go;Go]
		tooltip[go;Teleport to selected position]
		button[4.2,0.75;2,1;add;Add]
		tooltip[add;Save current position]
		button[4.2,1.5;2,1;edit;Edit]
		tooltip[edit;Edit selected position]
		button[4.2,2.25;2,1;remove;Remove]
		tooltip[remove;Remove selected position]
	]]

	if next(list) == nil then
		action_buttons = [[
			button[4.2,0;2,1;add;Add]
			tooltip[add;Save current position]
		]]
	end

	local count_text = tostring(count)
	if count < 10 then
		count_text = " " .. count_text
	elseif count >= 100 then
		count_text = count_text .. " "
	end

	minetest.show_formspec("savepos_main", [[
		size[6,8]
		bgcolor[#080808BB;true]
		background[5,5;1,1;gui_formbg.png;true]

		label[-0.1,-0.25;Saved Positions for ]]..worldname..[[:]
		table[-0.11,0.12;4.2,8.13;list;]]..text..[[;]]..selected..[[]

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
			worldname = fields.name
			send("World name set to \""..worldname.."\"")

			local res = storage:get_string(worldname)
			if not res or res == "" then
				storage:set_string(worldname, minetest.serialize({}))
			end

			-- Worldname saved, show main formspec
			show_main()
		elseif (fields.done or fields.key_enter_field == "name")
				and fields.name == "" then
			show_set("Worldname cannot be blank")
		end
	elseif name == "savepos_main" then
		if fields.list then
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
		elseif fields.edit then
			show_edit(selected)
		elseif fields.remove then
			local list = minetest.deserialize(storage:get_string(worldname))
			if list[selected] then
				show_confirm("remove", "Are you sure you want to remove "
					..list[selected].name.."?")
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

			local list = minetest.deserialize(storage:get_string(worldname))
			list[#list + 1] = { pos = pos, name = fields.name }
			storage:set_string(worldname, minetest.serialize(list))
		elseif (fields.done or fields.key_enter_field == "name")
				and fields.name == "" then
			show_add("Position name cannot be blank")
		end

		if ((fields.done or fields.key_enter_field == "name") and fields.name and
				fields.name ~= "") or fields.quit then
			show_main()
		end
	elseif name == "savepos_edit" then
		if (fields.done or fields.key_enter_field == "name") and
				fields.name and fields.name ~= "" and edit_index then
			local list = minetest.deserialize(storage:get_string(worldname))
			list[edit_index].name = fields.name
			storage:set_string(worldname, minetest.serialize(list))
		elseif (fields.done or fields.key_enter_field == "name")
				and fields.name == "" then
			show_edit(edit_index, "Position name cannot be blank")
		end

		if ((fields.done or fields.key_enter_field == "name") and fields.name and
				fields.name ~= "") or fields.quit then
			show_main()
		end
	elseif name == "savepos_rst" then
		if fields.yes then
			storage:set_string(worldname, minetest.serialize({}))
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
			local list = minetest.deserialize(storage:get_string(worldname))
			list[selected] = nil
			list = renumber_table(list)
			storage:set_string(worldname, minetest.serialize(list))
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
