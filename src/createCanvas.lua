
--********************************** Utilities ****************************************

local M = {}
local snap = require("snap")
  -- this function create a white image. and draw a grid on the image
function M.create_white_image_and_draw_grid_on_image(cnvobj)
    local canvas = cnvobj.cnv
    local w, h = cnvobj.width, cnvobj.height
    
    --create imimage
    local image = im.ImageCreate(w, h, im.RGB, im.BYTE)
    --fill new image with white color
    local i, j
    local r = image[0]
    local g = image[1]
    local b = image[2]
    for i = 0, image:Height()-1 do
      for j = 0, image:Width()-1 do
        r[i][j] = 255
        g[i][j] = 255
        b[i][j] = 255
      end
    end
    canvas.image = image
    --[[if cnvobj.gridVisibility then
      if image then
        local grid_canvas = cd.CreateCanvas(cd.IMIMAGE,image)
        --M.drawGrid(grid_canvas,cnvobj)
        grid_canvas:Kill()
      end
    end]]
end

  -- to draw grid
function M.drawGrid(cd_canvas,cnvobj)
    --local w,h = string.match(canvas.size,"(%d*)x(%d*)")
    local w,h = cnvobj.width, cnvobj.height
    local x,y
    local grid_x = cnvobj.grid_x
    local grid_y = cnvobj.grid_y
    --first for loop to draw horizontal line
    cd_canvas:SetForeground(cd.EncodeColor(192,192,192))
    for y=0, h, grid_y do
      cd_canvas:Line(0,y,w,y)
    end
    -- for loop used to draw vertical line
    for x=0, w, grid_x do
      cd_canvas:Line(x,0,x,h)
    end
end



  --Used to Draw Shape
function  M.DrawShape(cnv, start_x, start_y, end_x, end_y, shapeName)
  
    cnv:Foreground(cd.EncodeColor(0, 0, 255))
    canvas.shape = shapeName
   
    if (canvas.shape == "LINE") then
      cnv:Line(start_x, start_y, end_x, end_y)
    elseif (canvas.shape == "RECT") then
      cnv:Rect(start_x, end_x, start_y, end_y)
    elseif (canvas.shape == "FILLEDRECT") then
      cnv:Box(start_x, end_x, start_y, end_y)
    elseif (canvas.shape == "ELLIPSE") then
      cnv:Arc(math.floor((end_x + start_x) / 2), math.floor((end_y + start_y) / 2), math.abs(end_x - start_x), math.abs(end_y - start_y), 0, 360)
    elseif (canvas.shape == "FILLEDELLIPSE") then
      cnv:Sector(math.floor((end_x + start_x) / 2), math.floor((end_y + start_y) / 2), math.abs(end_x - start_x), math.abs(end_y - start_y), 0, 360)
    end
end

--********************************** End Utilities *****************************************
function  M.render(cnvobj)
    canvas = cnvobj.cnv
    local image = canvas.image
    local cd_bcanvas = cnvobj.cdbCanvas
    shapeName = cnvobj.shape
    grid_x = cnvobj.grid_x
    grid_y = cnvobj.grid_y 
  
    local canvas_width, canvas_height = cnvobj.width, cnvobj.height
    
    cd_bcanvas:Activate()
    cd_bcanvas:Background(cd.EncodeColor(255, 255, 255))
    cd_bcanvas:Clear()
    
    --canvas.image = image
    if cnvobj.gridVisibility then
      if image then
        local grid_canvas = cd.CreateCanvas(cd.IMIMAGE,image)
        M.drawGrid(grid_canvas,cnvobj)
        grid_canvas:Kill()
      end
    end

    if (image) then
      cd_bcanvas:PutImImage(image, 0, 0, canvas_width, canvas_height)  
      if cnvobj.drawing == "START" then
        if (canvas.shape) then
          local start_x = canvas.start_x
          local start_y = canvas.start_y
          local end_x = canvas.end_x
          local end_y = canvas.end_y
        
          start_x =snap.Sx(start_x, grid_x)
          start_y = snap.Sy(start_y, grid_y)
          end_x = snap.Sx(end_x, grid_x)
          end_y = snap.Sy(end_y, grid_y)
          M.DrawShape(cd_bcanvas, start_x, start_y, end_x, end_y, canvas.shape)
  
        end
      end
    end
    cd_bcanvas:Flush()
end

function M.button_cb(cnvobj,button, pressed, x, y)
    canvas = cnvobj.cnv
    local image = canvas.image
  
    shapeName = cnvobj.shape
    grid_x = cnvobj.grid_x
    grid_y = cnvobj.grid_y 

    local canvas_width, canvas_height = cnvobj.width, cnvobj.height

    if (image) then
    
      y = canvas_height - y 
      --if button is pressed then simply set start_x and start_y
      if (button) then
        if (pressed == 1) then
          canvas.start_x = x
          canvas.start_y = y
        
          -- when mouse button is release then draw shape from starting point to end point
        else
          if (canvas.shape) then
        
            local temp_canvas = cd.CreateCanvas(cd.IMIMAGE, image)         
            local start_x = canvas.start_x
            local start_y = canvas.start_y
            start_x = snap.Sx(start_x, grid_x)
            start_y = snap.Sy(start_y, grid_y)
            x = snap.Sx(x, grid_x)
            y = snap.Sy(y, grid_y)
          
            local index = #cnvobj.drawnEle
            cnvobj.drawnEle[index+1] = {}
            cnvobj.drawnEle[index+1].shape = shapeName
            cnvobj.drawnEle[index+1].start_x = start_x
            cnvobj.drawnEle[index+1].start_y = start_y
            cnvobj.drawnEle[index+1].end_x = x
            cnvobj.drawnEle[index+1].end_y = y 

            M.DrawShape(temp_canvas, start_x, start_y, x, y,shapeName,nil)
            temp_canvas:Kill()
            canvas.shape = nil
            iup.Update(canvas)
          end
        end
      end
    end
end
 
function M.motion_cb(cnvobj, x, y, status)
    canvas = cnvobj.cnv
    local  image = canvas.image
  
    local canvas_width, canvas_height = cnvobj.width, cnvobj.height

    if (image) then
      y = canvas_height - y 
      if (iup.isbutton1(status)) then -- button1 is pressed 
        canvas.end_x = x
        canvas.end_y = y 
        canvas.shape = cnvobj.shape 
      
        iup.Update(canvas)
      end
    end
end

return M 