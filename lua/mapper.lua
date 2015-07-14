<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE muclient>
<muclient>
<plugin
   name="Lotj_Mapper"
   author="Xavious"
   id="63e6909083318cf63707c044"
   language="Lua"
   purpose="Automap areas using MSDP"
   save_state="y"
   date_written="2014-10-22"
   requires="4.61"
   version="1.0"
   >

<description trim="y">
<![CDATA[
AUTOMATIC MAPPER ...  by Nick Gammon

Ported to Lotj by Xavious

The window can be dragged to a new location by dragging the room name.

Your current room is always in the center with a bolder border.

LH-click on a room to speed-walk to it. RH-click on a room for options.

LH-click on the "*" button on the bottom-left corner to configure it.

** WHY DOES THE MAP CHANGE? **

The mapper draws from your room outwards - that is, it draws your room's exits
first, then the rooms leading from those rooms, and so on.

Eventually it finds an overlap, and draws a short "stub" line to indicate there
is a room there which there isn't space to draw. If you get closer to that
room the stub will disappear and the room(s) in question will be drawn.

COMMANDS

mapper help         --> this help  (or click the "?" button on the bottom right)
mapper zoom out     --> zoom out
mapper zoom in      --> zoom in
mapper hide         --> hide map
mapper show         --> show map
mapper toggle       --> turns room creation on/off (Best to have off once mapped.)
                    --> moving too quickly can cause room exits to build wrong

RIGHT-CLICK ROOM OPTIONS

Delete Room         --> deletes the targeted room
Reset Exits         --> removes all exits from target room

]]>
</description>

</plugin>

<aliases>
  <alias
   script="OnHelp"
   match="mapper help"
   enabled="y"
  >
  </alias>
  <alias
   script="mapper.hide"
   match="mapper hide"
   enabled="y"
  >
  </alias>
  <alias
   script="mapper.show"
   match="mapper show"
   enabled="y"
  >
  </alias>
   <alias
   match="mapper zoom out"
   enabled="y"
   sequence="100"
   script="mapper.zoom_out"
  >
  </alias>

<alias
   match="mapper zoom in"
   enabled="y"
   sequence="100"
   script="mapper.zoom_in"
  >
  </alias>
  <alias
   script="OnToggleMapping"
   match="mapper toggle"
   enabled="y"
  >
  </alias>
</aliases>


<!--  Script  -->

<script>
<![CDATA[

-- mapper module
require "mapper"
require "serialize"  -- needed to serialize table to string
require "checkplugin"
require "tprint"

rooms = { }
automap = "true"
-- -----------------------------------------------------------------
-- these commands will be considered "room changing" commands
-- -----------------------------------------------------------------
local valid_direction = {
  n = "n",
  s = "s",
  e = "e",
  w = "w",
  u = "u",
  d = "d",
  ne = "ne",
  sw = "sw",
  nw = "nw",
  se = "se",
  north = "n",
  south = "s",
  east = "e",
  west = "w",
  up = "u",
  down = "d",
  northeast = "ne",
  northwest = "nw",
  southeast = "se",
  southwest = "sw",
  ['in'] = "in",
  out = "out",
  }  -- end of valid_direction
  
-- for calculating the way back
local inverse_direction = {
  n = "s",
  s = "n",
  e = "w",
  w = "e",
  u = "d",
  d = "u",
  ne = "sw",
  sw = "ne",
  nw = "se",
  se = "nw",
  ['in'] = "out",
  out = "in",
  }  -- end of inverse_direction  

  default_config = {
  -- assorted colours
  BACKGROUND_COLOUR       = { name = "Background",        colour =  ColourNameToRGB "lightseagreen", },
  ROOM_COLOUR             = { name = "Room",              colour =  ColourNameToRGB "cyan", },
  EXIT_COLOUR             = { name = "Exit",              colour =  ColourNameToRGB "darkgreen", },
  EXIT_COLOUR_UP_DOWN     = { name = "Exit up/down",      colour =  ColourNameToRGB "darkmagenta", },
  OUR_ROOM_COLOUR         = { name = "Our room",          colour =  ColourNameToRGB "black", },
  UNKNOWN_ROOM_COLOUR     = { name = "Unknown room",      colour =  ColourNameToRGB "#00CACA", },
  SHOP_FILL_COLOUR        = { name = "Shop",              colour =  ColourNameToRGB "darkolivegreen", },
  LIBRARY_FILL_COLOUR     = { name = "Library",           colour =  ColourNameToRGB "purple", },
  BANK_FILL_COLOUR        = { name = "Bank",              colour =  ColourNameToRGB "yellow", },
  WORKSHOP_FILL_COLOUR    = { name = "Workshop",          colour =  ColourNameToRGB "green", },
  HOTEL_FILL_COLOUR       = { name = "Hotel",             colour =  ColourNameToRGB "red", },
  TRAINER_FILL_COLOUR     = { name = "Trainer",           colour =  ColourNameToRGB "lightgreen" },
  PAD_FILL_COLOUR         = { name = "Landing Pad",       colour =  ColourNameToRGB "orange" },

  ROOM_NAME_TEXT          = { name = "Room name text",    colour = ColourNameToRGB "#BEF3F1", },
  ROOM_NAME_FILL          = { name = "Room name fill",    colour = ColourNameToRGB "#105653", },
  ROOM_NAME_BORDER        = { name = "Room name box",     colour = ColourNameToRGB "black", },

  AREA_NAME_TEXT          = { name = "Area name text",    colour = ColourNameToRGB "#BEF3F1",},
  AREA_NAME_FILL          = { name = "Area name fill",    colour = ColourNameToRGB "#105653", },
  AREA_NAME_BORDER        = { name = "Area name box",     colour = ColourNameToRGB "black", },

  FONT = { name =  get_preferred_font {"Dina",  "Lucida Console",  "Fixedsys", "Courier", "Sylfaen",} ,
           size = 8
         } ,

  -- size of map window
  WINDOW = { width = 400, height = 400 },

  -- how far from where we are standing to draw (rooms)
  SCAN = { depth = 30 },

  -- speedwalk delay
  DELAY = { time = 0.0 },

  -- how many seconds to show "recent visit" lines (default 3 minutes)
  LAST_VISIT_TIME = { time = 60 * 3 },

  } -- end of default_config
  
function room_toggle_thing (room, uid, fieldname, description)
	Note("Enter Toggle.....")
	rooms [uid] [fieldname] = not rooms [uid] [fieldname]

  if rooms [uid] [fieldname] then
	Note("marked")
    mapper.mapprint ("Room", uid, "marked as " .. description)
  else
	Note("unmarked")
    mapper.mapprint ("Room", uid, "not " .. description .. " any more")
  end

  mapper.draw (current_room)

end -- room_toggle_thing

function room_toggle_shop (room, uid)
  room_toggle_thing (room, uid, "shop", "a shop")
end -- room_toggle_shop

function room_toggle_hotel (room, uid)
  room_toggle_thing (room, uid, "hotel", "a hotel")
end -- room_toggle_inn

function room_toggle_trainer (room, uid)
  room_toggle_thing (room, uid, "trainer", "a training room")
end -- room_toggle_train

function room_toggle_library (room, uid)
  room_toggle_thing (room, uid, "library", "a library")
end -- room_toggle_guild

function room_toggle_workshop (room, uid)
  room_toggle_thing (room, uid, "workshop", "a workshop")
end -- room_toggle_guild

function room_toggle_bank (room, uid)
  room_toggle_thing (room, uid, "bank", "a bank")
end -- room_toggle_guild

function room_toggle_pad (room, uid)
  room_toggle_thing (room, uid, "pad", "a landing pad")
end -- room_toggle_guild
-- -----------------------------------------------------------------
-- mapper 'get_room' callback - it wants to know about room uid
-- -----------------------------------------------------------------
function get_room (uid)

	room = rooms[uid]
	if not room then
		return nil
	end
	
	room.bordercolour = config.ROOM_COLOUR.colour
	room.borderpen = miniwin.pen_solid 
	room.borderpenwidth = 1
	room.fillbrush = miniwin.brush_null  -- no fill
	--pattern  = miniwin.brush_fine_pattern
	--pattern = miniwin.brush_solid
	--pattern = miniwin.brush_medium_pattern
	--pattern = miniwin.brush_coarse_pattern
	
	--pattern = miniwin.brush_hatch_horizontal
	--pattern = miniwin.brush_hatch_vertical
	--pattern = miniwin.brush_hatch_forwards_diagonal
	--pattern = miniwin.brush_hatch_backwards_diagonal
	--pattern = miniwin.brush_hatch_cross
	--pattern = miniwin.brush_hatch_cross_diagonal
	pattern = miniwin.brush_fine_pattern
	--pattern = miniwin.brush_medium_pattern
	--pattern = miniwin.brush_coarse_pattern
	--pattern = miniwin.brush_waves_horizontal
	--pattern = miniwin.brush_waves_vertical	
	
	if uid == current_room then
		room.bordercolour = config.OUR_ROOM_COLOUR.colour
		room.borderpenwidth = 2
	end
	
	if rooms[uid]["pad"] then
		room.fillcolour = config.PAD_FILL_COLOUR.colour
		room.fillbrush = pattern
	elseif rooms[uid]["bank"] then
		room.fillcolour = config.BANK_FILL_COLOUR.colour
		room.fillbrush = pattern
	elseif rooms[uid]["workshop"] then
		room.fillcolour = config.WORKSHOP_FILL_COLOUR.colour
		room.fillbrush = pattern
	elseif rooms[uid]["library"] then
		room.fillcolour = config.LIBRARY_FILL_COLOUR.colour
		room.fillbrush = pattern
	elseif rooms[uid]["hotel"] then
		room.fillcolour = config.HOTEL_FILL_COLOUR.colour
		room.fillbrush = pattern
	elseif rooms[uid]["trainer"] then
		room.fillcolour = config.TRAINER_FILL_COLOUR.colour
		room.fillbrush = pattern
	elseif rooms[uid]["shop"] then
		room.fillcolour = config.SHOP_FILL_COLOUR.colour
		room.fillbrush = pattern
	else
		room.fillcolour = config.ROOM_COLOUR.colour
	end
	--system = utils.base64decode(GetPluginVariable("b3aae34498d5bf19b5b2e2af", "SHIPSYSNAME"))
	--if system ~= nil then
		--room.area = system
	--else
		room.area = "Unknown"
	--end
	room.hovermessage = room.name
	return room
end -- get_room

-- -----------------------------------------------------------------
-- Delete a room
-- -----------------------------------------------------------------
function delete_room(room, uid)
	if(uid == current_room) then
		ColourNote ("black", "yellow", "Not the room you are in!")
	else
		rooms[uid] = nil
		table.remove(rooms, uid)
		current_room = utils.base64decode(GetPluginVariable("b3aae34498d5bf19b5b2e2af", "ROOMVNUM"))
		mapper.draw(current_room)
		ColourNote ("black", "yellow", "     ----- Room Deleted -----     ")
	end --if
end --delete_room

-- -----------------------------------------------------------------
-- Reset a room's exits
-- -----------------------------------------------------------------
function reset_exits(room, uid)

	rooms[uid].exits = nil
	--table.remove(rooms[uid].exits, uid)
	current_room = utils.base64decode(GetPluginVariable("b3aae34498d5bf19b5b2e2af", "ROOMVNUM"))
	mapper.draw(current_room)
	ColourNote ("black", "yellow", "     ----- Exits Reset -----     ")
end --delete_room

-- -----------------------------------------------------------------
-- Right-Click Room
-- -----------------------------------------------------------------
function room_click (uid, flags)

  -- check we got room at all
  if not uid then
    return nil
  end -- if

  -- look it up
  local room = rooms [uid]

  if not room then
    return
  end -- if still not there

  local function checkmark (which)
    if rooms [uid] [which] then
      return "+"
    else
      return ""
    end -- if
  end -- checkmark

  local handlers = {
		{ name = "Delete Room", func = delete_room} ,
		{ name = "Reset Exits", func = reset_exits} ,
		{ name = "-", } ,
        { name = checkmark ("shop")  .. "Shop",         func = room_toggle_shop } ,
        { name = checkmark ("trainer") .. "Trainer",      func = room_toggle_trainer } ,
        { name = checkmark ("hotel")   .. "Hotel",          func = room_toggle_hotel } ,
        { name = checkmark ("bank") .. "Bank",  func = room_toggle_bank } ,
		{ name = checkmark ("library") .. "Library",  func = room_toggle_library } ,
		{ name = checkmark ("workshop") .. "Workshop",  func = room_toggle_workshop } ,
		{ name = checkmark ("pad") .. "Landing Pad",  func = room_toggle_pad } ,
      --{ name = "Edit bookmark", func = room_edit_bookmark} ,
      --{ name = "-", } ,
      --{ name = "Add Exit",    func = room_add_exit} ,
      --{ name = "Change Exit", func = room_change_exit} ,
      --{ name = "Delete Exit", func = room_delete_exit} ,
      --{ name = "-", } ,
      --{ name = checkmark ("shop")  .. "Shop",         func = room_toggle_shop } ,
      --{ name = checkmark ("train") .. "Trainer",      func = room_toggle_train } ,
      --{ name = checkmark ("inn")   .. "Inn",          func = room_toggle_inn } ,
      --{ name = checkmark ("guild") .. "Guildmaster",  func = room_toggle_guild } ,
     } -- handlers

  local t, tf = {}, {}
  for _, v in pairs (handlers) do
    table.insert (t, v.name)
    tf [v.name] = v.func
  end -- for

  local choice = WindowMenu (mapper.win,
                            WindowInfo (mapper.win, 14),
                            WindowInfo (mapper.win, 15),
                            table.concat (t, "|"))

  local f = tf [choice]

  if f then
    f (room, uid)
  end -- if handler found

end -- room_click

-- -----------------------------------------------------------------
-- Plugin Install
-- -----------------------------------------------------------------
function OnPluginInstall ()
  config = {}  -- in case not found

  -- get saved configuration
  assert (loadstring (GetVariable ("config") or "")) ()

  -- allow for additions to config
  for k, v in pairs (default_config) do
    config [k] = config [k] or v
  end -- for
  -- initialize mapper
  mapper.init { 
            config = config,      -- ie. colours, sizes
			room_click = room_click,    -- called on RH click on room square
            get_room = get_room,  -- info about room (uid)
			show_help  = OnHelp,   -- to show help
			toggle_mapping = OnToggleMapping -- Turn auto mapping on or off.
              }
               
  mapper.mapprint (string.format ("MUSHclient mapper installed, version %0.1f", mapper.VERSION))
  
  rooms = {}  -- ensure table exists, if not loaded from variable
  automap = GetVariable("automap")

  -- seed random number generator
  math.randomseed (os.time ())

  assert (loadstring (GetVariable ("rooms") or "")) ()
end -- OnPluginInstall

-- -----------------------------------------------------------------
-- Plugin Help
-- -----------------------------------------------------------------
function OnHelp ()
  mapper.mapprint (string.format ("[MUSHclient mapper, version %0.1f]", mapper.VERSION))
  mapper.mapprint (world.GetPluginInfo (world.GetPluginID (), 3))
end

function OnToggleMapping()
	if GetVariable("automap") == "true" then
		SetVariable("automap", "false")
		ColourNote ("black", "yellow", "AutoMapping: Off")
	else
		SetVariable("automap", "true")
		ColourNote ("black", "yellow", "AutoMapping: On")
	end
end


function OnPluginListChanged()
	do_plugin_check_now ("b3aae34498d5bf19b5b2e2af", "LotJMSDPHandler") -- check we have MSDP handler plugin
end

dofile(GetPluginInfo(GetPluginID(), 20) .. "lotj_colors.lua")
function OnPluginBroadcast (msg, id, name, text)
	-- Look for MSDP Handler.
	if (id == 'b3aae34498d5bf19b5b2e2af' and msg == 91) then
		if (text == "ROOMVNUM") then
			uid = utils.base64decode(GetPluginVariable("b3aae34498d5bf19b5b2e2af", "ROOMVNUM"))
			--Note(uid)
			if uid == nil then
				Note("Uid not defined")
			elseif GetVariable("automap") == "false" then
				current_room = uid
				mapper.draw(current_room)
			else
				--Note(uid)
				if not rooms[uid] then
					--Note("Set New Room")
					room_name = strip_colours(utils.base64decode(GetPluginVariable("b3aae34498d5bf19b5b2e2af", "ROOMNAME")))
					--Note(room_name)
					rooms[uid] = {name = room_name, exits = {} }
					--Note("Setting exits:")
					room_exits = utils.base64decode(GetPluginVariable("b3aae34498d5bf19b5b2e2af", "ROOMEXITS"))
					--Note(room_exits)
					--Mud separates MSDP ROOMEXITS with hex 01(start of text) and hex 02 (end of text) to separate exits in a string.
					if room_exits ~= nil and room_exits ~= '' then
						room_exits = utils.tohex(room_exits)
						--Note("Room exits:'"..room_exits.."'")
						room_exits = string.gsub(room_exits, "024F01", "20")
						room_exits = string.gsub(room_exits, "024301", "20")
						room_exits = string.gsub(room_exits, "024F", "")
						room_exits = string.gsub(room_exits, "0243", "")
						room_exits = utils.fromhex(room_exits)
						--Note(room_exits)
						room_exits = utils.split(room_exits, " ")
						--tprint(room_exits)
						for key, value in pairs(room_exits) do
							--Note(valid_direction[value])
							if valid_direction[value] ~= nil then
								if rooms[uid].exits [valid_direction[value]] == nil then
									rooms[uid].exits [valid_direction[value]] = 0
								end
							end
						end
					end --if room_exits not nil
				end --if not rooms
				-- if we changed rooms assume that our last movement sent us here
			    if uid ~= current_room and current_room	and last_direction_moved then
					-- previous room led here
					rooms [current_room].exits [last_direction_moved] = uid 
					-- assume inverse direction leads back
					rooms [uid].exits [inverse_direction [last_direction_moved]] = current_room
			    end -- if  uid
			    -- this is now our current room
			    current_room = uid
			    -- draw this room
			    mapper.draw (current_room)
			end	-- if uid	
		end --if ROOMVNUM
    end -- if id
end -- OnPluginBroadcast

-- -----------------------------------------------------------------
-- Save the map
-- -----------------------------------------------------------------
function OnPluginSaveState ()
  SetVariable ("config", serialize.save("config"))
  SetVariable ("rooms", serialize.save ("rooms"))
  mapper.save_state (win)
end -- function OnPluginSaveState

-- -----------------------------------------------------------------
-- try to detect when we send a movement command
-- -----------------------------------------------------------------
function OnPluginSent (sText)
  last_direction_moved = valid_direction [sText]
end -- OnPluginSent

-- -----------------------------------------------------------------
-- Hide the window
-- -----------------------------------------------------------------
function OnPluginDisable()
	mapper.hide()
end

-- hide window on removal
function OnPluginClose ()
	mapper.hide()
end -- OnPluginClose

]]>
</script>
</muclient>