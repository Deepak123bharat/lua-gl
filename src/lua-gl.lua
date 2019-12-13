local table = table
local pairs = pairs
local print = print
local iup = iup
local error = error
local pcall = pcall
local type = type

local math = math
local setmetatable = setmetatable
local getmetatable = getmetatable
local tonumber = tonumber
local tostring = tostring

local objects = require("lua-gl.objects")
local ports = require("lua-gl.ports")
local conn = require("lua-gl.connector")
local hooks = require("lua-gl.hooks")
local tu = require("tableUtils")
local CC = require("lua-gl.canvas")
local router = require("lua-gl.router")

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

_VERSION = "B19.12.4"

--- TASKS
--[[
* Update generateSegments to work with routing matrix object
* Remove cnvobj dependency from generateSegments just pass it grdx and grdy or better yet - stepx and stepy 
* Create routing Matrix object - Update code to update routing matrix in functions
* Update the canvas module with the new data structure methodology
* Finish loading of saved structure.
* Finish moveSegment
* Finish moveConn
* Finish removeConn
* Finish removeObj
* Add Text functionality
* Add arc functionality
* Canvas scroll, zoom, pan and coordinate translation
* Have to make undo/redo lists - improve API by spawning from the UI interaction functions their immediate action counterparts
* Connector labeling
* Have to add export/print
]]




-- This is the metatable that contains the API of the library that can be used by the host program

local objFuncs
objFuncs = {
	
	-- Function to move the list of items (given as a list of their IDs) by moving the all items offx and offy offsets
	-- if offxx is not a number then the movement is done interactively with a mouse
	move = function(cnvobj,items,offx,offy)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
			return nil,"Not a valid lua-gl object"
		end
		-- Check whether this is an interactive move or not
		local interactive
		if offx and type(offx) ~= "number" then
			interactive = true
		elseif not offx or not offy or type(offx) ~= "number" or type(offy) ~= "number" then
			return nil, "Coordinates not given"
		end
		if not interactive then
			-- Just do a single move
			-- Compile the list of objects from their item IDs
			local itemList = {}
			for i = 1,#items do
				local it = items[i]:match("^(.)%d*")
				if it == "O" then
					itemList[i] = cnvobj:getObjFromID(items[i])
				else
					itemList[i] = cnvobj:getConnFromID(items[i])
				end
			end
			-- sort items according to their order
			table.sort(itemList,function(one,two)
					return one.order < two.order
			end)
			for i = 1,#itemList do
				local it = itemList[i].id:match("^(.)%d*")
				if it == "O" then
					
				else
				end
			end
			
			return true
		end
		-- Setup the interactive move call backs
		
	end,

	save = function(cnvobj)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
			return nil,"Not a valid lua-gl object"
		end
		-- First check if any operation is happenning then end it
		if cnvobj.op.end and type(cnvobj.op.end) == "function" then
			cnvobj.op.finish()
		end
		return tu.t2sr(cnvobj.drawn)
	end,
	-- function to load the drawn structures in str and put them in the canvas 
	-- x and y are the coordinates where the structures will be loaded. If not given x,y will default to the center of the canvas
	-- if interactive==true then the placed elements will be moving with the mouse pointer and left click will place them
	load = function(cnvobj,str,x,y,interactive)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
			return nil,"Not a valid lua-gl object"
		end
		local tab = tu.s2tr(str)
		if not tab then return nil,"No data found" end
		x = x or math.floor(tonumber(cnvobj.cnv.rastersize:match("(%d+)x%d+"))/2)
		y = y or math.floor(tonumber(cnvobj.cnv.rastersize:match("%d+x(%d+)"))/2)
		local grdx,grdy = cnvobj.grid_x,cnvobj.grid_y
		if not cnvobj.snapGrid then
			grdx,grdy = 1,1
		end
		-- Now append the data in tab into the cnvobj.drawn structure
		-- obj array copy
		local objS = tab.obj
		local objD = cnvobj.drawn.obj
		local offx,offy = x-objS[1].start_x,y-objS[1].start_y
		for i = 1,#objS do
			objD[#objD + 1] = objS[i]
			objS[i].id = "O"..tostring(objD.ids + 1)
			objS[i].start_x = objS[i].start_x + offx
			objS[i].start_y = objS[i].start_y + offy
			objS[i].end_x = objS[i].end_x + offx
			objS[i].end_y = objS[i].end_y + offx
			objD.ids = objD.ids + 1
		end
		
		-- port array copy
		local portS = tab.port
		local portD = cnvobj.drawn.port
		for i = 1,#portS do
			portD[#portD + 1] = portS[i]
			portS[i].id = "P"..tostring(portD.ids + 1)
			portD.ids = portD.ids + 1
			portS[i].x = portS[i].x + offx
			portS[i].y = portS[i].y + offy
		end
		
		-- group array copy
		local grpS = tab.group
		local grpD = cnvobj.drawn.group
		for i = 1,#grpS do
			grpD[#grpD + 1] = grpS[i]
		end
		
		-- conn array copy
		local connS = tab.conn
		local connD = cnvobj.drawn.conn
		for i = 1,#connS do
			connD[#connD + 1] = connS[i]
			connS[i].id = "C"..tostring(connD.ids + 1)
			connD.ids = connD.ids + 1
			-- update all segments
			local segs = connS[i].segments
			for j = 1,#segs do
				segs[j].start_x = segs[j].start_x + offx
				segs[j].start_y = segs[j].start_y + offy
				segs[j].end_x = segs[j].end_x + offx
				segs[j].end_y = segs[j].end_y + offy
			end
			-- Update all junctions
			local junc = connS[i].junction
			for j = 1,#junc do
				junc[j].x = junc[j].x + offx
				junc[j].y = junc[j].y + offy
			end
		end
		
		-- Now do the order array copy
		local orderS = tab.order
		local orderD = cnvobj.drawn.order
		local curTop = #orderD
		for i = 1,#orderS do
			orderD[#orderD+1] = orderS[i]
			-- Fix the order number on the item
			orderS[i].item.order = #orderD
		end
		
		-- Everything is loaded now
		if not interactive then
			return true
		end
		-- Setup the interactive movement here
	end,

	erase = function(cnvobj)
		if not cnvobj or type(cnvobj) ~= "table" or getmetatable(cnvobj) ~= objFuncs then
			return nil,"Not a valid lua-gl object"
		end
		cnvobj.drawn = {
			obj = {ids=0},		-- array of object structures. See structure in objects.lua
			group = {},			-- array of arrays containing objects intended to be grouped together
			port = {ids=0},		-- array of port structures. See structure of port in ports.lua
			conn = {ids=0},		-- array of connector structures. See structure of connector in connector.lua
			order = {},			-- array of structures containing the things to draw in order
			--[[ Order stucture looks like this:
			{
				[i] = {
					type = <string>,	-- string describing what type of item this is. Values are like "object", "connector"
					item = <table>		-- table structure of the item that is at this order position. For object it will be the object structure. For connector it will be the connector structure.
				},
			}
			]]
		}
		cnvobj.hook = {ids=0}	-- Array of hook structure. See structure of hook in hooks.lua
		-- .op is a member table used for holding temporary data and setting up modes of operation of the canvas
		cnvobj.op = {
			mode="DISP",	-- To indicate the operation mode of the canvas. The following modes are known:
							-- * DISP = This is the normal mode where the mouse pointer is not associated with anything and it is not in the middle of any operation
							-- * DRAWCONN = A connector is being drawn in interactive mode
							-- * DRAGSEG = A segment is being dragged in interative mode
							-- * MOVEOBJ = An object is being moved in interactive mode
							-- * DRAGOBJ = An object is being dragged in interactive mode
							-- * DRAWOBJ = An object is being drawn in interactive mode
			finish = nil,	-- When set by a function calling that function will end the mode and reset the operation and the operation table back
			-- DRAWCONN
			connID = nil,	-- String containing the connector ID during interactive draw connector
			cIndex = nil,	-- index of the connector in cnvobj.drawn.conn which is being drawn
			startseg = nil,	-- index of the segment in the connector from which the segments need to be auto routed
			start = nil,	-- Table containing the X and Y coordinates marking the reference start coordinates
			-- DRAGSEG
			segList = nil,	-- list of segments in a structure described in the dragSegment functon documentation
			coor1 = nil,	-- Initial starting coordinate of the 1st segement in the segList array to serve as reference of the total movement
			offx = nil,		-- To store the last x offset applied to the segments being moved
			offy = nil,		-- To store the last y offset applied to the segments being moved
			oldSegs = nil,	-- To store the old segments table for the all the connectors whose segments are being dragged i.e. in the segList
			-- MOVEOBJ
			coor1 = nil,	-- Initial starting coordinate of the 1st object in the objList to serve as reference of the total movement
			-- DRAGOBJ
			-- DRAWOBJ
			obj = nil		-- shape string of the object being drawn. The shape strings are listed at the top of the objects file when initialized in the environment
			
		}
		cnvobj.rM = router.newRoutingMatrix(cnvobj)
		cnvobj.size = nil	-- when set should be in the form {width=<integer>,height=<integer>} and that will fix the size of the drawing area to that
		--[[
		cnvobj.size = {}	
		cnvobj.size.width = cnvobj.cnv.rastersize:match("(%d%d*)x%d*")
		cnvobj.size.height = cnvobj.cnv.rastersize:match("%d%d*x(%d%d*)")
		]]
		
		if cnvobj.cnv then
			function cnvobj.cnv:button_cb(button,pressed,x,y, status)
				CC.buttonCB(cnvobj,button,pressed,x,y, status)
			end
			
			function cnvobj.cnv:motion_cb(x, y, status)
				CC.motionCB(cnvobj,x,y, status)		
			end
		end
	end,


	---- CONNECTORS---------
	drawConnector = conn.drawConnector,		-- draw connector
	dragSegment = conn.dragSegment,
	moveSegment = conn.moveSegment,
	moveConn = conn.moveConn,
	getConnFromID = conn.getConnFromID,
	getConnFromXY = conn.getConnFromXY,
	---- HOOKS--------------
	addHook = hooks.addHook,
	removeHook = hooks.removeHook,
	processHooks = hooks.processHooks,
	---- PORTS--------------
	addPort = ports.addPort, 				-- Add a port to a shape
	removePort = ports.removePort,			-- Remove a port given the portID
	getPortFromID = ports.getPortFromID,	-- Get the port structure from the port ID
	getPortFromXY = ports.getPortFromXY,	-- get the port structure close to x,y
	---- OBJECTS------------
	drawObj = objects.drawObj,				-- Draw object
	dragObj = objects.dragObj,				-- drag object(s)/group(s)
	moveObj = objects.moveObj,				-- move object(s)
	groupObjects = objects.groupObjects,	
	getObjFromID = objects.getObjFromID,
	getObjFromXY = objects.getObjFromXY,
}

local function checkPara(para)

	if not para.width or type(para.width) ~= "number" then
		return nil,"Width not given or not a number"
	end
	if not para.height or type(para.height) ~= "number" then
		return nil,"height not given or not a number"
	end
	if not para.grid_x or type(para.grid_x) ~= "number" then
		return nil,"grid_x not given or not a number"
	end
	if not para.grid_y or type(para.grid_y) ~= "number" then
		return nil,"grid_y not given or not a number"
	end
	return true
end


-- The parameter table contains the initialization parameters
--[[
{
	width = <integer>, 	--Width of the canvas
	height = <integer>,	--Height of the canvas
	grid_x = <integer>, --x direction grid distance
	grid_y = <integer>, --y direction grid distance
	gridVisibility = <boolean>,	-- (OPTIONAL) if true then grid is visible
	snapGrid = <boolean>,		-- (OPTIONAL) if true then everything works on the grid, otherwise it behaves as if grid is 1px x 1px
	showBlockingRect = <boolean>,-- (OPTIONAL) if true then blocking rectangles are drawn on screen
}

]]
new = function(para)
	local cnvobj = {}	-- The canvas object for lua-gl
	
	local resp,msg = checkPara(para)
   
	if not resp then
		return nil,msg
	end
	
	-- Put all parameters into the cnvobj object
	for k,v in pairs(para) do
		cnvobj[k] = v
	end
	  
	cnvobj.cnv = iup.canvas{}		-- iup canvas where all drawing will happen
	cnvobj.cnv.rastersize=""..cnvobj.width.."x"..cnvobj.height..""
	
	objFuncs.erase(cnvobj)
	-- Create the canvas element
	
	-- Setup the callback functions
	function cnvobj.cnv.map_cb()
		CC.mapCB(cnvobj)	
	end
	
	function cnvobj.cnv.unmap_cb()
		CC.unmapCB(cnvobj)
	end
	
	function cnvobj.cnv.action()
		CC.render(cnvobj)
	end
	
	function cnvobj.cnv:button_cb(button,pressed,x,y, status)
		CC.buttonCB(cnvobj,button,pressed,x,y, status)
	end
	
	function cnvobj.cnv:motion_cb(x, y, status)
		CC.motionCB(cnvobj,x,y, status)		
	end
	
	setmetatable(cnvobj,{__index = objFuncs})
	
	return cnvobj
end
