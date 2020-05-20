
require("submodsearcher")
local LGL = require("lua-gl")
local tu = require("tableUtils")
local sel = require("selection")

local GUI = require("GUIStructures")

iup.ImageLibOpen()
iup.SetGlobal("IMAGESTOCKSIZE","32")

-------------<<<<<<<<<<< ##### LuaTerminal ##### >>>>>>>>>>>>>-------------
require("iuplua_scintilla")
local LT = require("LuaTerminal")
LT.USESCINTILLA = true

-- Create terminal
local LTdlg = iup.dialog{
	iup.vbox{
		LT.newTerm(_ENV,true)--,"testlog.txt")
	}; 
	title="LuaTerminal", 
	size="QUARTERxQUARTER",
	icon = GUI.images.appIcon
}
LTdlg:showxy(iup.RIGHT, iup.LEFT)
-------------<<<<<<<<<<< ##### LuaTerminal End ##### >>>>>>>>>>>>>-------------

--*************** Main (Part 1/2) ******************************

cnvobj = LGL.new{ 
	grid_x = 5, 
	grid_y = 5, 
	width = 900, 
	height = 600, 
	gridVisibility = true,
	snapGrid = true,
	showBlockingRect = true,
	--usecrouter = true,
}
GUI.mainArea:append(cnvobj.cnv)

local MODE

local undo,redo = {},{}		-- The UNDO and REDO stacks
local toRedo, doingRedo, group
local function addUndoStack(diff)
	local tab = undo
	if toRedo then 
		tab = redo 
	elseif not doingRedo then
		redo = {}	-- Redo is emptied if any action is done
	end
	if group then
		-- To group multiple luagl actions into 1 undo action of the host application
		if #tab == 0 or tab[#tab].type ~= "LUAGLGROUP" then
			tab[#tab + 1] = {
				type = "LUAGLGROUP",
				obj = {diff}
			}
		else
			tab[#tab].obj[#tab[#tab].obj + 1] = diff
		end
	else
		tab[#tab + 1] = {
			type = "LUAGL",
			obj = diff
		}
	end
end
cnvobj:addHook("UNDOADDED",addUndoStack)

local pushHelpText,popHelpText,clearHelpTextStack

do
	local order = {}
	local ID = 0
	local helpTextStack = {}
	function pushHelpText(text)
		if text then
			ID = ID + 1
			helpTextStack[ID] = text
			order[#order + 1] = ID
			GUI.statBarL.title = text
			return ID
		end
	end

	function popHelpText(ID)
		if not ID then
			return	-- Probably log here that popHelpText called without ID
		end
		helpTextStack[ID] = nil
		local ind = tu.inArray(order,ID)
		if ind then
			table.remove(order,ind)
			if #order == 0 then
				GUI.statBarL.title = "Ready"
			else
				GUI.statBarL.title = helpTextStack[order[#order]]
			end
			return true
		end
	end

	function clearHelpTextStack()
		helpTextStack = {}
		order = {}
		ID = 0
		GUI.statBarL.title = "Ready"
	end
end

sel.init(cnvobj,GUI)
sel.resumeSelection()


--********************* Callbacks *************

-- Undo button action
function GUI.toolbar.buttons.undoButton:action()
	for i = #undo,1,-1 do
		if undo[i].type == "LUAGL" then
			toRedo = true
			cnvobj:undo(undo[i].obj)
			table.remove(undo,i)
			toRedo = false
			break
		elseif undo[i].type == "LUAGLGROUP" then
			toRedo = true
			group = true
			for j = #undo[i].obj,1,-1 do
				cnvobj:undo(undo[i].obj[j])
			end
			table.remove(undo,i)
			toRedo = false
			group = false
			break
		end
	end
end

-- Redo button action
function GUI.toolbar.buttons.redoButton:action()
	for i = #redo,1,-1 do
		if redo[i].type == "LUAGL" then
			doingRedo = true
			cnvobj:undo(redo[i].obj)
			table.remove(redo,i)
			doingRedo = false
			break
		elseif redo[i].type == "LUAGLGROUP" then
			doingRedo = true
			group = true
			for j = #redo[i].obj,1,-1 do
				cnvobj:undo(redo[i].obj[j])
			end
			table.remove(redo,i)
			doingRedo = false
			group = false
			break
		end
	end	
end

-- TO save data to file
function GUI.toolbar.buttons.saveButton:action()
	local fileDlg = iup.filedlg{
		dialogtype = "SAVE",
		extfilter = "Demo Files|*.dia",
		title = "Select file to save drawing...",
		extdefault = "dia"
	} 
	fileDlg:popup(iup.CENTER, iup.CENTER)
	if fileDlg.status == "-1" then
		return
	end
	local f = io.open(fileDlg.value,"w+")
	f:write(cnvobj:save())
	f:close()
end

-- To load data from a file
function GUI.toolbar.buttons.loadButton:action()
	local hook,helpID
	local function resumeSel()
		print("Resuming Selection")
		popHelpText(helpID)
		cnvobj:removeHook(hook)
		sel.resumeSelection()
	end
	local fileDlg = iup.filedlg{
		dialogtype = "OPEN",
		extfilter = "Demo Files|*.dia",
		title = "Select file to save drawing...",
		extdefault = "dia"
	} 
	fileDlg:popup(iup.CENTER, iup.CENTER)
	if fileDlg.status == "-1" then
		return
	end
	f = io.open(fileDlg.value,"r")
	local s = f:read("*a")
	f:close()
	sel.pauseSelection()
	helpID = pushHelpText("Click to place the diagram")
	local stat,msg = cnvobj:load(s,nil,nil,true)
	--local stat,msg = cnvobj:load(s,450,300)	-- Non interactive load at the given coordinate
	if not stat then
		print("Error loading file: ",msg)
		local dlg = iup.messagedlg{dialogtype="ERROR",title = "Error loading file...",value = "File cannot be loaded.\n"..msg}
		dlg:popup()
		resumeSel()
	else
		hook = cnvobj:addHook("UNDOADDED",resumeSel)
	end
end

-- Turn ON/OFF snapping on the grid
function GUI.toolbar.buttons.snapGridButton:action()
	if self.image == GUI.images.ongrid then
		self.image = GUI.images.offgrid
		self.tip = "Set Snapping On"
		cnvobj.grid.snapGrid = false
	else
		self.image = GUI.images.ongrid
		self.tip = "Set Snapping Off"
		cnvobj.grid.snapGrid = true
	end
end

-- Show/Hide the grid
function GUI.toolbar.buttons.showGridButton:action(v)
	if v == 1 then
		self.tip = "Turn grid off"
		cnvobj.viewOptions.gridVisibility = true
	else 
		self.tip = "Turn grid on"
		cnvobj.viewOptions.gridVisibility = false
	end
	cnvobj:refresh()
end

-- Show/Hide the Blocking Rectangles
function GUI.toolbar.buttons.showBlockingRect:action(v)
	if v == 1 then
		self.tip = "Hide Blocking Rectangles"
		self.image = GUI.images.blockingRectVisible
		cnvobj.viewOptions.showBlockingRect = true
	else 
		self.tip = "Show Blocking Rectangles"
		self.image = GUI.images.blockingRectHidden
		cnvobj.viewOptions.showBlockingRect = false
	end
	cnvobj:refresh()
end

-- Change the grid action
function GUI.toolbar.buttons.xygrid:action()
	local ret,x,y = iup.GetParam("Enter the Grid Size",nil,"X Grid%i{The grid size in X dimension}\nY Grid%i{The grid size in Y dimension}\n",cnvobj.grid.grid_x,cnvobj.grid.grid_y)
	if ret and x > 0 and y > 0 then
		cnvobj.grid.grid_x = x
		cnvobj.grid.grid_y = y
		cnvobj:refresh()
	end
end

local function getStartClick(msg1,msg2,cb)
	local hook,helpID
	local function resumeSel()
		popHelpText(helpID)
		cnvobj:removeHook(hook)
		sel.resumeSelection()
	end
	local function getClick(button,pressed,x,y,status)
		if button == cnvobj.MOUSE.BUTTON1 and pressed == 1 then
			cnvobj:removeHook(hook)
			popHelpText(helpID)
			helpID = pushHelpText(msg2)
			hook = cnvobj:addHook("UNDOADDED",resumeSel)
			cb()
		end
	end
	sel.pauseSelection()
	helpID = pushHelpText(msg1)
	-- Add the hook
	hook = cnvobj:addHook("MOUSECLICKPOST",getClick)
end

-- Draw line object
function GUI.toolbar.buttons.lineButton:action()
	-- Non interactive line draw
	--[[cnvobj:drawObj("LINE",{
			{x=10,y=10},
			{x=100,y=100}
		})]]
	--cnvobj:refresh()
	local function cb()
		cnvobj:drawObj("LINE")	-- interactive line drawing
	end
	getStartClick("Click starting point for line","Click ending point for line",cb)
end

-- Draw rectangle object
function GUI.toolbar.buttons.rectButton:action()
	local function cb()
		cnvobj:drawObj("RECT")	-- interactive rectangle drawing
	end
	getStartClick("Click starting point for rectangle","Click ending point for rectangle",cb)
end

-- Draw filled rectangle object
function GUI.toolbar.buttons.fRectButton:action()
	local function cb()
		cnvobj:drawObj("FILLEDRECT")	-- interactive filled rectangle drawing
	end
	getStartClick("Click starting point for rectangle","Click ending point for rectangle",cb)
end

-- Draw blocking rectangle object
function GUI.toolbar.buttons.bRectButton:action()
	local function cb()
		cnvobj:drawObj("BLOCKINGRECT")	-- interactive blocking rectangle drawing
	end
	getStartClick("Click starting point for rectangle","Click ending point for rectangle",cb)
end

-- Draw ellipse object
function GUI.toolbar.buttons.elliButton:action()
	local function cb()
		cnvobj:drawObj("ELLIPSE")	-- interactive ellipse drawing
	end
	getStartClick("Click starting point for ellipse","Click ending point for ellipse",cb)
end

-- Draw filled ellipse object
function GUI.toolbar.buttons.fElliButton:action()
	local function cb()
		cnvobj:drawObj("FILLEDELLIPSE")	-- interactive filled ellipse drawing
	end
	getStartClick("Click starting point for ellipse","Click ending point for ellipse",cb)
end

-- Draw Arc
function GUI.toolbar.buttons.arcButton:action()
	local hook, helpID, hook1
	local count = 1
	local msg = {
		"Click to mark starting angle of the arc",
		"Click to mark ending angle of the arc"
	}
	local function removeHelpText()
		popHelpText(helpID)
		cnvobj:removeHook(hook1)
	end
	local function getClick(button,pressed,x,y,status)
		if button == cnvobj.MOUSE.BUTTON1 and pressed == 1 then
			popHelpText(helpID)
			helpID = pushHelpText(msg[count])
			if count == 2 then
				cnvobj:removeHook(hook)
			else
				count = count + 1
			end
		end
	end
	local function cb()
		hook = cnvobj:addHook("MOUSECLICKPOST",getClick)
		hook1 = cnvobj:addHook("UNDOADDED",removeHelpText)
		cnvobj:drawObj("ARC")
	end
	getStartClick("Click starting point for ellipse","Click ending point for ellipse",cb)
end

-- Draw Sector
function GUI.toolbar.buttons.filledarcButton:action()
	local hook, helpID, hook1
	local count = 1
	local msg = {
		"Click to mark starting angle of the arc",
		"Click to mark ending angle of the arc"
	}
	local function removeHelpText()
		popHelpText(helpID)
		cnvobj:removeHook(hook1)
	end
	local function getClick(button,pressed,x,y,status)
		if button == cnvobj.MOUSE.BUTTON1 and pressed == 1 then
			popHelpText(helpID)
			helpID = pushHelpText(msg[count])
			if count == 2 then
				cnvobj:removeHook(hook)
			else
				count = count + 1
			end
		end
	end
	local function cb()
		hook = cnvobj:addHook("MOUSECLICKPOST",getClick)
		hook1 = cnvobj:addHook("UNDOADDED",removeHelpText)
		cnvobj:drawObj("FILLEDARC")
	end
	getStartClick("Click starting point for ellipse","Click ending point for ellipse",cb)
end

-- Draw text object
function GUI.toolbar.buttons.textButton:action()
	local c = cnvobj.viewOptions.constants
	local align = {
		north = c.NORTH,
		south = c.SOUTH, 
		east = c.EAST,
		west = c.WEST,
		["north east"] = c.NORTH_EAST, 
		["north west"] = c.NORTH_WEST, 
		["south east"] = c.SOUTH_EAST, 
		["south west"] = c.SOUTH_WEST, 
		["center"] = c.CENTER, 
		["base left"] = c.BASE_LEFT, 
		["base center"] = c.BASE_CENTER, 
		["base right"] = c.BASE_RIGHT
	}
	local alignList = {}
	local asi
	for k,v in pairs(align) do
		alignList[#alignList + 1] = k
		if k == "base right" then
			asi = #alignList - 1
		end
	end
	local ret, text, font, color,as,ori = iup.GetParam("Enter Text information",nil,
		"Text: %m\n"..
		"Font: %n\n"..
		"Color: %c{Color Tip}\n"..
		"Alignment: %l|"..table.concat(alignList,"|").."|\n"..
		"Orientation: %a[0,360]\n","","Courier, 12","0 0 0",asi,0)
	if ret then
		-- Create a representation of the text at the location of the mouse pointer and then start its move
		-- Set refX,refY as the mouse coordinate on the canvas
		local refX,refY = cnvobj:snap(cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas()))
		local o = cnvobj:drawObj("TEXT",{{x=refX,y=refY}},{text=text})
		-- If the formatting is not the same as the default then add a formatting attribute for the text
		if color ~= "0 0 0" or font ~= "Courier, 12" or as ~= "base right" or ori ~= 0 then
			local typeface,style,size = font:match("(.-),([%a%s]*)%s*([+-]?%d+)$")
			size = cnvobj:fontPt2Pixel(tonumber(size))
			style = "" and c.PLAIN or style
			local clr = {}
			clr[1],clr[2],clr[3] = color:match("(%d%d*)%s%s*(%d%d*)%s%s*(%d%d*)")
			clr[1] = tonumber(clr[1])
			clr[2] = tonumber(clr[2])
			clr[3] = tonumber(clr[3])
			-- Also add the attribute to the object
			o.vattr = {color = clr,typeface = typeface, style = style,size=size,align=align[alignList[as+1]],orient = ori}
			cnvobj.attributes.visualAttr[o] = {
				visualAttr = cnvobj.getTextAttrFunc(o.vattr),
				vAttr = 100	-- Unique attribute not stored in the bank
			}
		end
		cnvobj:moveObj({o})
	end
end

function GUI.toolbar.buttons.printButton:action()
	local ret, mL, mR, mU,mD = iup.GetParam("Enter Print Information",nil,
	"Margin Left (mm): %i\n"..
	"Margin Right (mm): %i\n"..
	"Margin Up (mm): %i\n"..
	"Margin Down (mm): %i\n",10,10,10,10)
	if ret then
		cnvobj:doprint("Lua-GL diagram",mL,mR,mU,mD)
	end
end

function GUI.toolbar.buttons.checkButton:action()
	cnvobj:drawConnector({
			{start_x = 300,start_y=130,end_x=300,end_y=380},
			{start_x = 300,start_y=380,end_x=500,end_y=380},
			{start_x = 500,start_y=360,end_x=320,end_y=360},
			{start_x = 320,start_y=360,end_x=320,end_y=130},
		})
	cnvobj:refresh()
end


-- Start Move operation
function GUI.toolbar.buttons.moveButton:action()
	local hook, helpID
	local function resumeSel()
		popHelpText(helpID)
		cnvobj:removeHook(hook)
		sel.resumeSelection()
	end
	local function getClick(button,pressed,x,y,status)
		cnvobj:removeHook(hook)
		popHelpText(helpID)
		helpID = pushHelpText("Click to place")
		hook = cnvobj:addHook("UNDOADDED",resumeSel)
		cnvobj:move(sel.selListCopy())
	end
	local function movecb()
		popHelpText(helpID)
		sel.pauseSelection()
		helpID = pushHelpText("Click to start move")
		-- Add the hook
		hook = cnvobj:addHook("MOUSECLICKPOST",getClick)
	end
	-- First get items to move
	if #sel.selListCopy() == 0 then
		-- No items so stop the selection and resume it with a callback which is called as soon as a selection is made.
		sel.pauseSelection()
		helpID = pushHelpText("Select items to move")
		sel.resumeSelection(movecb)
	else
		movecb()
	end
end

-- Start Drag operation
function GUI.toolbar.buttons.dragButton:action()
	local hook, helpID
	local function resumeSel()
		popHelpText(helpID)
		cnvobj:removeHook(hook)
		sel.resumeSelection()
	end
	local function getClick(button,pressed,x,y,status)
		cnvobj:removeHook(hook)
		popHelpText(helpID)
		helpID = pushHelpText("Click to place")
		hook = cnvobj:addHook("UNDOADDED",resumeSel)
		cnvobj:drag(sel.selListCopy())
	end
	local function dragcb()
		popHelpText(helpID)
		sel.pauseSelection()
		helpID = pushHelpText("Click to start drag")
		-- Add the hook
		hook = cnvobj:addHook("MOUSECLICKPOST",getClick)
	end
	-- First get items to move
	if #sel.selListCopy() == 0 then
		-- No items so stop the selection and resume it with a callback which is called as soon as a selection is made.
		sel.pauseSelection()
		helpID = pushHelpText("Select items to drag")
		sel.resumeSelection(dragcb)
	else
		dragcb()
	end
end

function GUI.toolbar.buttons.groupButton:action()
	-- Function to group objects together
	local helpID
	local function groupcb()
		local _,objs = sel.selListCopy() 
		if #objs < 2 then
			return
		end
		sel.pauseSelection()
		popHelpText(helpID)
		cnvobj:groupObjects(objs)
		sel.resumeSelection()
	end
	-- First get objects to group
	local _,objs = sel.selListCopy() 
	if #objs < 2 then
		-- No items so stop the selection and resume it with a callback which is called as soon as a selection is made.
		sel.pauseSelection()
		helpID = pushHelpText("Select objects to group")
		sel.resumeSelection(groupcb)
	else
		groupcb()
	end	
end

function GUI.toolbar.buttons.portButton:action()
	-- Check if port mode already on then do nothing
	if MODE == "ADDPORT" then
		return
	end
	sel.pauseSelection()
	-- Create a representation of the port at the location of the mouse pointer and then start its move
	-- Create a MOUSECLICKPOST hook to check whether the move ended on a object. If not continue the move
	-- Set refX,refY as the mouse coordinate on the canvas transformed to the database coordinates snapped
	group = true
	local x,y = cnvobj:snap(cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas()))
	cnvobj.grid.snapGrid = false
	local o = cnvobj:drawObj("FILLEDRECT",{{x=x-3,y=y-3},{x=x+3,y=y+3}})
	cnvobj.grid.snapGrid = true
	-- Now we need to put the mouse exactly on the center of the filled rectangle
	-- Set the cursor position to be right on the center of the object
	local rx,ry = cnvobj:setMouseOnCanvas(cnvobj:dCoor2sCoor(x,y))
	-- Create the hook
	local hook
	local function getClick(button,pressed,x,y,status)
		print("Run Hook getClick")
		x,y = cnvobj:snap(x,y)
		-- Check if there is an object here
		local allObjs = cnvobj:getObjFromXY(x,y)
		local stop
		for i = 1,#allObjs do
			if allObjs[i] ~= o then
				stop = true	-- There is an object there other than the object drawn for the port visualization above
				break
			end
		end
		if stop then
			cnvobj:removeHook(hook)
			-- group o with the 1st object
			cnvobj:groupObjects({allObjs[1],o})
			-- Create a port
			print("Create the port at ",x,y)
			cnvobj:addPort(x,y,allObjs[1].id)
			MODE = nil
			group = false
			popHelpText()
			sel.resumeSelection()
		elseif cnvobj.op[#cnvobj.op].mode ~= "MOVEOBJ" then
			print("Continuing Move",#allObjs)
			-- Continue the move only if it is out of the move mode
			cnvobj:moveObj({o})
		end
		print("End Hook execution getClick")
	end
	-- Add the hook
	hook = cnvobj:addHook("MOUSECLICKPOST",getClick)
	-- Start the interactive move
	MODE = "ADDPORT"
	pushHelpText("Click to place port")
	cnvobj:moveObj({o})
end

function GUI.toolbar.buttons.refreshButton:action()
	cnvobj:refresh()
end

local mode = 0

function GUI.toolbar.buttons.connButton:action()
	local router1,router2
	local js1,js2
	if mode == 0 then
		router1 = cnvobj.options.router[0]
		router2 = router1
		js1 = 2
		js2 = 2
	elseif mode == 1 then
		router1 = cnvobj.options.router[1]
		router2 = router1
		js1 = 0
		js2 = 0
	elseif mode == 2 then
		router1 = cnvobj.options.router[2]
		router2 = router1
		js1 = 0
		js2 = 0
	else
		router1 = cnvobj.options.router[9]
		router2 = router1
		js1 = 1
		js2 = 1
	end
	local function cb()
		cnvobj:drawConnector(nil,router1,js1,router2,js2)
	end
	getStartClick("Click starting point for connector","Click ending point/waypoint for connector",cb)
end

function GUI.toolbar.buttons.connModeList:action(text,item,state)
	mode = item-1
	if item == 4 then
		mode = 9
	end
end 

function GUI.toolbar.buttons.newButton:action()
	cnvobj:erase()
	sel.deselectAll()
	clearHelpTextStack()
	sel.pauseSelection()
	cnvobj:addHook("UNDOADDED",addUndoStack)
	sel.init(cnvobj,GUI)
	sel.resumeSelection()
	cnvobj:refresh()
end

-- 90 degree rotate
local function rotateFlip(para)
	local op = cnvobj.op[#cnvobj.op]
	local mode = op.mode
	local refX,refY = cnvobj:snap(cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas()))
	if mode == "DRAG" or  mode == "DRAGSEG" or mode == "DRAGOBJ" then
		-- Compile item list
		local items = {}
		for i = 1,#op.objList do
			items[#items + 1] = op.objList[i]
		end
		if op.segList then
			for i = 1,#op.segList do
				items[#items + 1] = op.segList[i]
			end
		end
		-- Do the rotation 
		cnvobj:rotateFlipItems(items,refX,refY,para)
		local prx,pry = cnvobj:snap(op.ref.x,op.ref.y)
		op.coor1.x,op.coor1.y = cnvobj.rotateFlip(op.coor1.x,op.coor1.y,prx,pry,para)
		cnvobj:refresh()
	elseif mode == "MOVE" or mode == "MOVESEG" or mode == "MOVEOBJ" then
		-- Compile item list
		local items = {}
		for i = 1,#op.objList do
			items[#items + 1] = op.objList[i]
		end
		if op.connList then
			for i = 1,#op.connList do
				local conn = op.connList[i]
				for j = 1,#conn.segments do
					items[#items + 1] = {
						conn = conn,
						seg = j
					}
				end
			end
		end
		-- Do the rotation 
		cnvobj:rotateFlipItems(items,refX,refY,para)
		local prx,pry = cnvobj:snap(op.ref.x,op.ref.y)
		op.coor1.x,op.coor1.y = cnvobj.rotateFlip(op.coor1.x,op.coor1.y,prx,pry,para)
		cnvobj:refresh()
	else
		-- Get list of items
		local helpID
		local function rotateItems()
			local items = sel.selListCopy()
			local refX,refY = cnvobj:snap(cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas()))
			-- get all group memebers for the objects selected
			local objList = {}
			local segList = {}
			for i = 1,#items do
				if items[i].id then
					-- This must be an object
					objList[#objList + 1] = items[i]
				else
					-- This must be a segment specification
					segList[#segList + 1] = items[i]
				end
			end			
			objList = cnvobj.populateGroupMembers(objList)
			items = objList
			for i = 1,#segList do
				items[#items + 1] = segList[i]
			end
			cnvobj:rotateFlipItems(items,refX,refY,para)
			cnvobj:refresh()
		end
		local function startRotation()
			popHelpText(helpID)
			getStartClick("Click at coordinate about which to rotate/flip",nil,rotateItems)
		end
		-- first we need to select items
		if #sel.selListCopy() == 0 then
			-- No items so stop the selection and resume it with a callback which is called as soon as a selection is made.
			sel.pauseSelection()
			helpID = pushHelpText("Select items to rotate/flip")
			sel.resumeSelection(startRotation)
		else
			startRotation()
		end	
		
	end
end

function GUI.mainDlg:k_any(c)
	if c < 255 then
		print("Pressed "..string.char(c))
		local map = {
			r = 90,
			e = 180,
			w = 270,
			h = "h",
			v = "v"
		}
		if map[string.char(c)] then
			rotateFlip(map[string.char(c)])
			return iup.IGNORE 
		end
	end
	if c == iup.K_LEFT then
		-- Change the viewport and refresh
		-- Move the viewport 10% to the left
		local vp = cnvobj.viewPort
		local dx = vp.xmax - vp.xmin + 1
		local shift = math.floor(dx/10)
		vp.xmin = vp.xmin - shift
		vp.xmax = vp.xmax - shift
		cnvobj:refresh()
		return iup.IGNORE 
	elseif c == iup.K_RIGHT then
		-- Change the viewport and refresh
		-- Move the viewport 10% to the right
		local vp = cnvobj.viewPort
		local dx = vp.xmax - vp.xmin + 1
		local shift = math.floor(dx/10)
		vp.xmin = vp.xmin + shift
		vp.xmax = vp.xmax + shift
		cnvobj:refresh()
		return iup.IGNORE 
	elseif c == iup.K_DOWN then
		-- Change the viewport and refresh
		-- Move the viewport 10% to the down
		local vp = cnvobj.viewPort
		local xm,xmax,ym,ymax,zoom = cnvobj:viewportPara(vp)
		
		local dy = ymax - ym + 1
		local shift = math.floor(dy/10)
		vp.ymin = vp.ymin - shift
		cnvobj:refresh()	
		return iup.IGNORE 
	elseif c == iup.K_UP then
		-- Change the viewport and refresh
		-- Move the viewport 10% to the up
		local vp = cnvobj.viewPort
		local xm,xmax,ym,ymax,zoom = cnvobj:viewportPara(vp)
		
		local dy = ymax - ym + 1
		local shift = math.floor(dy/10)
		vp.ymin = vp.ymin + shift
		cnvobj:refresh()				
		return iup.IGNORE 
	elseif c == iup.K_bracketleft then
		-- Zoom out with the center remaining in the center
		local zoomFac = 1.5
		local vp = cnvobj.viewPort
		local xm,xmax,ym,ymax,zoom = cnvobj:viewportPara(vp)
		local dx = math.floor(zoom/zoomFac*cnvobj.width)
		dx = math.floor((dx-(xmax-xm+1))/2)
		local dy = math.floor(zoom/zoomFac*cnvobj.height)
		dy = math.floor((dy-(ymax-ym+1))/2)
		vp.ymin = vp.ymin-dy
		vp.xmax = vp.xmax+dx
		vp.xmin = vp.xmin-dx
		
		cnvobj:refresh()				
		return iup.IGNORE 
	elseif c == iup.K_bracketright then
		-- Zoom in with the center remaining in the center
		local zoomFac = 1.5
		local vp = cnvobj.viewPort
		local xm,xmax,ym,ymax,zoom = cnvobj:viewportPara(vp)
		local dx = math.floor(zoom*zoomFac*cnvobj.width)
		dx = math.floor((xmax-xm+1-dx)/2)
		local dy = math.floor(zoom*zoomFac*cnvobj.height)
		dy = math.floor((ymax-ym+1-dy)/2)
		vp.ymin = vp.ymin+dy
		vp.xmax = vp.xmax-dx
		vp.xmin = vp.xmin+dx
		cnvobj:refresh()				
		return iup.IGNORE 
	end
	return iup.CONTINUE
end

-- Set the mainDlg user size to nil so that the show uses the Natural Size
GUI.mainDlg.size = nil
GUI.mainDlg:showxy(iup.CENTER, iup.CENTER)
GUI.mainDlg.minsize = GUI.mainDlg.rastersize	-- To limit the minimum size of the dialog to the natural size
GUI.mainDlg.maxsize = GUI.mainDlg.rastersize	-- To limit the maximum size of the dialog to the natural size
GUI.mainDlg.resize = "NO"
GUI.mainDlg.maxbox = "NO"

local timer = iup.timer{
	time = 1000,
	run = "NO"
}
function timer:action_cb()
	timer.run = "NO"
	--print("Timer ran")
	-- Update the screen coordinates
	local refX,refY = cnvobj:sCoor2dCoor(cnvobj:getMouseOnCanvas())	-- mouse position on canvas coordinates
	GUI.statBarR.title = "X="..refX..", Y="..refY
	--print("X="..refX..", Y="..refY)
	timer.time = 50
	timer.run = "YES"
end

--print("Timer is ",timer)

timer.run = "YES"

if iup.MainLoopLevel()==0 then
    iup.MainLoop()
    iup.Close()
end

