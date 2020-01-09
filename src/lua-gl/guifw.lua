-- Module containing all graphical and user interface manipulation functions for IUP and CD library.
-- This module aims to abstract away the underlying framework of IUP and CD libraries

require("iuplua")
require("iupluaimglib")
require("cdlua")
require("iupluacd")

local iup = iup 
local cd = cd
local math = math
local type = type

local print = print

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

-- Constants

-- Line style constants
M.CONTINUOUS = cd.CONTINUOUS
M.DASHED = cd.DASHED
M.DOTTED = cd.DOTTED
M.DASH_DOT = cd.DASH_DOT
M.DASH_DOT_DOT = cd.DASH_DOT_DOT
-- Line Join Constants
M.MITER = cd.MITER
M.BEVEL = cd.BEVEL
M.ROUND = cd.ROUND
-- Line Cap constants
M.CAPFLAT = cd.CAPFLAT
M.CAPSQUARE = cd.CAPSQUARE
M.CAPROUND = cd.CAPROUND
-- Back Opacity
M.OPAQUE = cd.OPAQUE
M.TRANSPARENT = cd.TRANSPARENT
-- Fill style
M.SOLID = cd.SOLID
M.HOLLOW = cd.HOLLOW
M.STIPPLE = cd.STIPPLE
M.HATCH = cd.HATCH
M.PATTERN = cd.PATTERN
-- Hatch styles
M.HORIZONTAL = cd.HORIZONTAL
M.VERTICAL = cd.VERTICAL
M.FDIAGONAL = cd.FDIAGNOL
M.BDIAGONAL = cd.BDIAGNOL
M.CROSS = cd.CROSS
M.DIAGCROSS = cd.DIAGCROSS

function mapCB(cnvobj)
	--local cd_Canvas = cd.CreateCanvas(cd.IUP, cnvobj.cnv)
	local cd_bCanvas = cd.CreateCanvas(cd.IUPDBUFFER,cnvobj.cnv) --cd_Canvas)
	--cnvobj.cdCanvas = cd_Canvas
	cnvobj.cdbCanvas = cd_bCanvas
end

function unmapCB(cnvobj)
	local cd_bCanvas = cnvobj.cdbCanvas
	--local cd_Canvas = cnvobj.cdCanvas
	cd_bCanvas:Kill()
	--cd_Canvas:Kill()
end

function buttonCB(cnvobj,button,pressed,x,y, status)
	cnvobj:processHooks("MOUSECLICKPRE",{button,pressed,x,y,status})
	cnvobj:processHooks("MOUSECLICKPOST",{button,pressed,x,y,status})
end

function motionCB(cnvobj,x, y, status)
	
end

function newCanvas()
	return iup.canvas{}
end

-- Set of functions to setup attributes of something that is being drawn. Each function returns a closure (function with associated up values). The rendering loop just calls the function before drawing it
--[[
There are 5 types of items for which attributes need to be set:
		- Non filled object		(1)
		- Blocking rectangle	(2)	-- attribute set using setNonFilledObjectAttr function
		- Filled object			(3)
		- Normal Connector		(4)	-- attribute set using setNonFilledObjectAttr function
		- Jumping Connector		(5)	-- attribute set using setNonFilledObjectAttr function
	So there are 2 functions below:
]]

-- Function to return closure for setting attributes for non filled objects
--[[ Attributes to set are: (given a table (attr) with all these keys and attributes
* Draw color(color)	- Table with RGB e.g. {127,230,111}
* Line Style(style)	- number or a table. Number should be one of M.CONTINUOUS, M.DASHED, M.DOTTED, M.DASH_DOT, M.DASH_DOT_DOT. FOr table it should be array of integers specifying line length in pixels and then space length in pixels. Pattern repeats
* Line width(width) - number for width in pixels
* Line Join style(join) - should be one of the constants M.MITER, M.BEVEL, M.ROUND
* Line Cap style (cap) - should be one of the constants M.CAPFLAT, M.CAPROUND, M.CAPSQUARE
]]
function getNonFilledObjAttrFunc(attr)
	local color = cd.EncodeColor(attr.color[1],attr.color[2],attr.color[3])
	local style = attr.style
	local width = attr.width
	local join = attr.join
	local cap = attr.cap

	-- Function to set the attributes when the line style is a number
	local function nfoaNUM(canvas)
		-- Set the foreground color
		canvas:SetForeground(color)
		-- Set the line style
		canvas:LineStyle(style)
		-- Set line width
		canvas:LineWidth(width)
		-- Set Line Join
		canvas:LineJoin(join)
		-- Set Line cap
		canvas:LineCap(cap)
	end
	-- Function to set the attributes when the line style is a table
	local function nfoaTAB()
		-- Set the foreground color
		canvas:SetForeground(color)
		-- Set the line style
		canvas:LineStyleDashes(style, #style)
		-- Set line width
		canvas:LineWidth(width)
		-- Set Line Join
		canvas:LineJoin(join)
		-- Set Line cap
		canvas:LineCap(cap)	
	end
	if type(style) == "number" then
		return nfoaNUM
	else
		return nfoaTAB
	end
end

-- Function to return closure for setting attributes for non filled objects
--[[
The attributes to be set are:
* Fill Color(color)	- Table with RGB e.g. {127,230,111}
* Background Opacity (bopa) - One of the constants M.OPAQUE, M.TRANSPARENT	
* Fill interior style (style) - One of the constants M.SOLID, M.HOLLOW, M.STIPPLE, M.HATCH, M.PATTERN
* Hatch style (hatch) (OPTIONAL) - Needed if style == M.HATCH. Must be one of the constants M.HORIZONTAL, M.VERTICAL, M.FDIAGONAL, M.BDIAGONAL, M.CROSS or M.DIAGCROSS
* Stipple style (stipple) (OPTIONAL) - Needed if style = M.STIPPLE. Should be a  wxh matrix of zeros (0) and ones (1). The zeros are mapped to the background color or are transparent, according to the background opacity attribute. The ones are mapped to the foreground color.
* Pattern style (pattern) (OPTIONAL) - Needed if style = M.PATTERN. Should be a wxh color matrix of tables with RGB numbers`
]]
function getFilledObjAttrFunc(attr)
	local color = cd.EncodeColor(attr.color[1],attr.color[2],attr.color[3])
	local bopa = attr.bopa
	local style = attr.style
	local hatch = attr.hatch
	local r,c
	if attr.style == M.STIPPLE then
		r,c = #attr.stipple,#attr.stipple[1]
		local stipple = cd.CreateStipple(r,c)
		for i = 0,r do
			for j = 0,c do
				stipple[i*c+j] = attr.stipple[i+1][j+1]
			end
		end
	end
	
	if attr.style == M.PATTERN then
		r,c = #attr.pattern,#attr.pattern[1]
		local pattern = cd.CreatePattern(r,c)
		for i = 0,r do
			for j = 0,c do
				pattern[i*c+j] = cd.EncodeColor(attr.pattern[i+1][j+1][1],attr.pattern[i+1][j+1][2],attr.pattern[i+1][j+1][3])
			end
		end
	end
	
	local function foaSOHO(canvas)
		-- Set the foreground color
		canvas:SetForeground(color)
		-- Set the background opacity
		canvas:BackOpacity(bopa)
		-- Set interior style
		canvas:InteriorStyle(style)		
	end
	local function foaST(canvas)
		-- Set the foreground color
		canvas:SetForeground(color)		
		-- Set the background opacity
		canvas:BackOpacity(bopa)
		-- Set the stipple
		canvas:Stipple(stipple)		
	end
	local function foaHA(canvas)
		-- Set the foreground color
		canvas:SetForeground(color)		
		-- Set the background opacity
		canvas:BackOpacity(bopa)
		-- Set the hatch style
		canvas:Hatch(hatch)
	end
	local function foaPA(canvas)
		-- Set the foreground color
		canvas:SetForeground(color)		
		-- Set the background opacity
		canvas:BackOpacity(bopa)
		-- Set the pattern style
		canvas:Hatch(pattern)
	end
	
	if style == M.PATTERN then
		return foaPA
	elseif style == M.STIPPLE then
		return foaST
	elseif style == M.HATCH then
		return foaHA
	else
		return foaSOHO
	end
	
end

-- to draw grid
-- One experiment was to draw the grid using a stipple but was told there is no guaranteed way to align the stipple pattern to
-- known canvas coordinates so always drawing the grid manually
local function drawGrid(cnv,cnvobj,bColore,br,bg,bb)
	--print("DRAWGRID!")
    local w,h = cnvobj.width, cnvobj.height
    local x,y
    local grid_x = cnvobj.grid.grid_x
    local grid_y = cnvobj.grid.grid_y
	
	cnv:SetForeground(cd.EncodeColor(255-br,255-bg,255-bb))	-- Bitwise NOT of the background color
    --first for loop to draw horizontal line
    for y=0, h, grid_y do
      cnv:Line(0,y,w,y)
    end
	if cnvobj.viewOptions.gridMode == 1 then
		cnv:SetForeground(bColor)		-- Draw with backfround color
	end		
    -- for loop used to draw vertical line
    for x=0, w, grid_x do
      cnv:Line(x,0,x,h)
    end
	if cnvobj.viewOptions.gridMode == 1 then
		cnv:WriteMode(cd.XOR)
		cnv:SetForeground(cd.EncodeColor(255,255,255))	-- XOR with White
		for y=0, h, grid_y do
		  cnv:Line(0,y,w,y)
		end
		cnv:WriteMode(cd.REPLACE)
	end		
end

function  render(cnvobj)
	local canvas = cnvobj.cnv
	local cd_bcanvas = cnvobj.cdbCanvas
	local canvas_width, canvas_height = cnvobj.width, cnvobj.height
	local vOptions = cnvobj.viewOptions
	local attr = cnvobj.attributes
	local bColor = vOptions.backgroundColor
	local bColore = cd.EncodeColor(bColor[1], bColor[2], bColor[3])

	cd_bcanvas:Activate()
	cd_bcanvas:Background(bColore)
	cd_bcanvas:Clear()

	if cnvobj.viewOptions.gridVisibility then
		drawGrid(cd_bcanvas,cnvobj,bColore,bColor[1], bColor[2], bColor[3])
	end
	-- Now loop through the order array to draw every element in order
	local order = cnvobj.drawn.order
	for i = 1,#order do
		local item = order[i].item
		if order[i].type == "object" then
			-- This is an object
			--cd_bcanvas:SetForeground(cd.EncodeColor(0, 162, 232))
			local x1,y1,x2,y2 = item.start_x,item.start_y,item.end_x,item.end_y
			--y1 = cnv:InvertYAxis(y1)
			--y2 = cnv:InvertYAxis(y2)
			y1 = cnvobj.height - y1
			y2 = cnvobj.height - y2
			
			if M[item.shape] and M[item.shape].draw then
				M[item.shape].draw(cnvobj,cd_bcanvas,item.shape,x1,y1,x2,y2)
			end
		else
			-- This is a connector
			--cd_bcanvas:SetForeground(cd.EncodeColor(255, 128, 0))
			local segs = item.segments
			for j = 1,#segs do
				local s = segs[j]
				local x1,y1,x2,y2 = s.start_x,s.start_y,s.end_x,s.end_y
				--y1 = cnv:InvertYAxis(y1)
				--y2 = cnv:InvertYAxis(y2)
				y1 = cnvobj.height - y1
				y2 = cnvobj.height - y2
				M.LINE.draw(cnvobj,cd_bcanvas,"CONNECTOR",x1,y1,x2,y2)
			end
		end
	end
	cd_bcanvas:Flush()
end

function update(cnvobj)
	render(cnvobj)
end
