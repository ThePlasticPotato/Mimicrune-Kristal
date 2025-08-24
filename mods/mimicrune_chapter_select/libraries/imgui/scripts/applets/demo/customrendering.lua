local imgui = Imgui.lib
local ffi = require("ffi")
local bit = require("bit")
---@class ExampleAppCustomRendering: ImguiApplet
local ExampleAppCustomRendering, super = Class(ImguiApplet, "ExampleAppCustomRendering")
---@cast super ImguiApplet

function ExampleAppCustomRendering:init()
    super.init(self, "Example: Custom Rendering (New! Funky Mode!)")
    self.canvas = {
        points = {}; ---@type imgui.ImVec2[]
        scrolling = imgui.ImVec2_Nil();
        opt_enable_grid = imgui.bool(true);
        opt_enable_context_menu = imgui.bool(true);
        adding_line = imgui.bool(false);
    }
end

function ExampleAppCustomRendering:show()
    if imgui.BeginTabBar("##TabBar") then
        if false and imgui.BeginTabItem("Primatives") then
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem("Canvas") then
            imgui.Checkbox("Enable grid", self.canvas.opt_enable_grid)
            imgui.Checkbox("Enable context menu", self.canvas.opt_enable_context_menu)
            imgui.Text("Mouse Left: drag to add lines,\nMouse Right: drag to scroll, click for context menu.");

            -- Typically you would use a BeginChild()/EndChild() pair to benefit from a clipping region + own scrolling.
            -- Here we demonstrate that this can be replaced by simple offsetting + custom drawing + PushClipRect/PopClipRect() calls.
            -- To use a child window instead we could use, e.g:
            --      imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(0, 0));      -- Disable padding
            --      imgui.PushStyleColor(ImGuiCol_ChildBg, imgui.color255(50, 50, 50, 255));  -- Set a background color
            --      imgui.BeginChild("canvas", ImVec2(0.0f, 0.0f), ImGuiChildFlags_Borders, ImGuiWindowFlags_NoMove);
            --      imgui.PopStyleColor();
            --      imgui.PopStyleVar();
            --      [...]
            --      imgui.EndChild();
            
            local canvas_p0 = imgui.GetCursorScreenPos()      -- ImDrawList API uses screen coordinates!
            local canvas_sz = imgui.GetContentRegionAvail()   -- Resize canvas to what's available

            if (canvas_sz.x < 50.0) then canvas_sz.x = 50.0 end;
            if (canvas_sz.y < 50.0) then canvas_sz.y = 50.0 end;
            -- Using InvisibleButton() as a convenience 1) it will advance the layout cursor and 2) allows us to use IsItemHovered()/IsItemActive()
            local canvas_p1 = imgui.ImVec2_Float(canvas_p0.x + canvas_sz.x, canvas_p0.y + canvas_sz.y);
            local io = imgui.C.igGetIO();
            local draw_list = imgui.GetWindowDrawList(); ---@type imgui.ImDrawList
            draw_list:AddRectFilled(canvas_p0, canvas_p1, imgui.color255(50,50,50,255))
            -- Draw border and background color
            draw_list:AddRectFilled(canvas_p0, canvas_p1, imgui.color255(50, 50, 50, 255));
            draw_list:AddRect(canvas_p0, canvas_p1, imgui.color255(255, 255, 255, 255));

            -- This will catch our interactions
            imgui.InvisibleButton("canvas", canvas_sz, bit.bor(imgui.ImGuiButtonFlags_MouseButtonLeft, imgui.ImGuiButtonFlags_MouseButtonRight));
            local is_hovered = imgui.IsItemHovered(); ---@type boolean Hovered
            local is_active = imgui.IsItemActive();   ---@type boolean Held
            local origin = imgui.ImVec2_Float(canvas_p0.x + self.canvas.scrolling.x, canvas_p0.y + self.canvas.scrolling.y); ---@type imgui.ImVec2 Lock scrolled origin
            local mouse_pos_in_canvas = imgui.ImVec2_Float(io.MousePos.x - origin.x, io.MousePos.y - origin.y); ---@type imgui.ImVec2

            -- Add first and second point
            if (is_hovered and not self.canvas.adding_line[0] and imgui.IsMouseClicked(imgui.ImGuiMouseButton_Left)) then
                table.insert(self.canvas.points, mouse_pos_in_canvas);
                table.insert(self.canvas.points, mouse_pos_in_canvas);
                self.canvas.adding_line[0] = true;
            end
            if (self.canvas.adding_line[0]) then
                self.canvas.points[#self.canvas.points] = mouse_pos_in_canvas
                if (not imgui.IsMouseDown(imgui.ImGuiMouseButton_Left)) then
                    self.canvas.adding_line[0] = false;
                end
            end
            -- Pan (we use a zero mouse threshold when there's no context menu)
            -- You may decide to make that threshold dynamic based on whether the mouse is hovering something etc.
            local mouse_threshold_for_pan = self.canvas.opt_enable_context_menu[0] and -1.0 or 0.0;
            if (is_active and imgui.IsMouseDragging(imgui.ImGuiMouseButton_Right, mouse_threshold_for_pan)) then
                self.canvas.scrolling.x = self.canvas.scrolling.x + io.MouseDelta.x;
                self.canvas.scrolling.y = self.canvas.scrolling.y + io.MouseDelta.y;
            end

            -- Context menu (under default mouse threshold)
            local drag_delta = imgui.GetMouseDragDelta(imgui.ImGuiMouseButton_Right);
            if (self.canvas.opt_enable_context_menu[0] and drag_delta.x == 0.0 and drag_delta.y == 0.0) then
                imgui.OpenPopupOnItemClick("context", imgui.ImGuiPopupFlags_MouseButtonRight);
            end
            if (imgui.BeginPopup("context")) then
                if (self.canvas.adding_line[0]) then
                    table.remove(self.canvas.points, #self.canvas.points)
                    table.remove(self.canvas.points, #self.canvas.points)
                end
                self.canvas.adding_line[0] = false;
                if (imgui.MenuItem_Bool("Remove one", nil, false, #self.canvas.points > 0)) then
                    table.remove(self.canvas.points, #self.canvas.points)
                    table.remove(self.canvas.points, #self.canvas.points)
                end
                if (imgui.MenuItem_Bool("Remove all", nil, false, #self.canvas.points > 0)) then
                    Utils.clear(self.canvas.points)
                end
                imgui.EndPopup();
            end

            -- Draw grid + all lines in the canvas
            draw_list:PushClipRect(canvas_p0, canvas_p1, true);
            if (self.canvas.opt_enable_grid[0]) then
                local GRID_STEP = 64.0;
                for x = self.canvas.scrolling.x % GRID_STEP, canvas_sz.x, GRID_STEP do
                    draw_list:AddLine(imgui.ImVec2_Float(canvas_p0.x + x, canvas_p0.y), imgui.ImVec2_Float(canvas_p0.x + x, canvas_p1.y), imgui.color255(200, 200, 200, 40));
                end
                for y = self.canvas.scrolling.y % GRID_STEP, canvas_sz.y, GRID_STEP do
                    draw_list:AddLine(imgui.ImVec2_Float(canvas_p0.x, canvas_p0.y + y), imgui.ImVec2_Float(canvas_p1.x, canvas_p0.y + y), imgui.color255(200, 200, 200, 40));
                end
            end
            for n=1, #self.canvas.points, 2 do
                draw_list:AddLine(
                    imgui.ImVec2_Float(origin.x + self.canvas.points[n].x, origin.y + self.canvas.points[n].y),
                    imgui.ImVec2_Float(origin.x + self.canvas.points[n + 1].x, origin.y + self.canvas.points[n + 1].y),
                    imgui.color255(255, 255, 0, 255), 2.0
                );
                
            end
            draw_list:PopClipRect();
            imgui.EndTabItem()
        end
        imgui.EndTabBar()
    end
end

return ExampleAppCustomRendering
