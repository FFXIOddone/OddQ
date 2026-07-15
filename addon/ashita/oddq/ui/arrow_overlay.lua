local arrow_overlay = {}

local guidance_cursor = require("guidance_cursor")
local imgui_text = require("ui/imgui_text")
local skin = require("ui/skin")
local window_state = require("ui/window_state")

local bit_ok, bit = pcall(require, "bit")
if not bit_ok then
    bit = nil
end

local function flag(value)
    return type(value) == "number" and value or 0
end

local function bor_flags(...)
    local result = 0
    for _, value in ipairs({ ... }) do
        if bit ~= nil and bit.bor ~= nil then
            result = bit.bor(result, flag(value))
        else
            result = result + flag(value)
        end
    end
    return result
end

local function clamp(value, minimum, maximum)
    value = tonumber(value)
    if value == nil then
        return nil
    end
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function active_segment(route, index)
    local segments = route and route.segments or {}
    if #segments == 0 then
        return nil
    end
    index = tonumber(index) or 1
    if index < 1 then
        index = 1
    end
    if index > #segments then
        index = #segments
    end
    return segments[index]
end

local function color_u32(imgui, color)
    if imgui.GetColorU32 ~= nil then
        return imgui.GetColorU32(color)
    end
    return color
end

local function cue_layout()
    return skin.layout.direction_cue or {}
end

local function cue_number(key, fallback)
    return tonumber(cue_layout()[key]) or fallback
end

local function cue_gap(imgui)
    local gap = cue_number("body_gap", 0.0)
    if imgui ~= nil and imgui.Dummy ~= nil and gap > 0.0 then
        imgui.Dummy({ 1.0, gap })
    end
end

local function cue_same_line(imgui, gap)
    if imgui == nil or imgui.SameLine == nil then
        return
    end
    gap = tonumber(gap)
    if gap == nil then
        imgui.SameLine()
        return
    end
    local ok = pcall(imgui.SameLine, 0.0, gap)
    if not ok then
        imgui.SameLine()
    end
end

local function direction_vector(cue)
    local precise = (cue or {}).pointer_vector
    if type(precise) == "table" then
        local x = tonumber(precise.x)
        local y = tonumber(precise.y)
        if x ~= nil and y ~= nil then
            local length = math.sqrt((x * x) + (y * y))
            if length > 0.000001 then
                return {
                    x = x / length,
                    y = y / length,
                }
            end
        end
    end

    local symbol = tostring((cue or {}).direction_symbol or "")
    local vectors = {
        ["^^^"] = { x = 0.0, y = -1.0 },
        ["^>>"] = { x = 0.72, y = -0.72 },
        [">>>"] = { x = 1.0, y = 0.0 },
        ["v>>"] = { x = 0.72, y = 0.72 },
        ["vvv"] = { x = 0.0, y = 1.0 },
        ["<<v"] = { x = -0.72, y = 0.72 },
        ["<<<"] = { x = -1.0, y = 0.0 },
        ["<<^"] = { x = -0.72, y = -0.72 },
    }
    return vectors[symbol]
end

local function vertical_strength(cue)
    local vector_3d = (cue or {}).pointer_vector_3d
    if type(vector_3d) == "table" then
        local y = clamp(vector_3d.y, -1.0, 1.0)
        if y ~= nil then
            return y
        end
    end

    local delta = tonumber((cue or {}).vertical_delta)
    local distance = tonumber((cue or {}).distance)
    if delta ~= nil and distance ~= nil and distance > 0.000001 then
        return clamp(delta / distance, -1.0, 1.0)
    end
    return nil
end

local function draw_center_marker(imgui, draw, center)
    if draw.AddCircleFilled ~= nil then
        draw:AddCircleFilled(center, 18.0, color_u32(imgui, { 0.098, 0.858, 1.000, 0.20 }), 24)
        draw:AddCircleFilled(center, 8.0, color_u32(imgui, skin.colors.blue_highlight), 18)
    end
    if draw.AddLine ~= nil then
        draw:AddLine({ center[1] - 15.0, center[2] }, { center[1] + 15.0, center[2] }, color_u32(imgui, skin.colors.text), 2.0)
        draw:AddLine({ center[1], center[2] - 15.0 }, { center[1], center[2] + 15.0 }, color_u32(imgui, skin.colors.text), 2.0)
    end
end

local function draw_vertical_indicator(imgui, draw, center, cue)
    if draw.AddLine == nil or draw.AddTriangleFilled == nil then
        return
    end

    local strength = vertical_strength(cue)
    if strength == nil or math.abs(strength) < 0.05 then
        return
    end

    local rail_x = center[1] + 39.0
    local top_y = center[2] - 22.0
    local bottom_y = center[2] + 22.0
    local marker_y = center[2] - (strength * 18.0)

    draw:AddLine({ rail_x, bottom_y }, { rail_x, top_y }, color_u32(imgui, { 0.78, 0.96, 1.0, 0.38 }), 2.0)
    draw:AddLine({ rail_x - 4.0, center[2] }, { rail_x + 4.0, center[2] }, color_u32(imgui, skin.colors.text), 1.0)

    if strength > 0 then
        draw:AddTriangleFilled(
            { rail_x, marker_y - 6.0 },
            { rail_x - 5.0, marker_y + 4.0 },
            { rail_x + 5.0, marker_y + 4.0 },
            color_u32(imgui, skin.colors.blue_highlight)
        )
    else
        draw:AddTriangleFilled(
            { rail_x, marker_y + 6.0 },
            { rail_x - 5.0, marker_y - 4.0 },
            { rail_x + 5.0, marker_y - 4.0 },
            color_u32(imgui, skin.colors.blue_highlight)
        )
    end
end

local function draw_direction_arrow(imgui, cue)
    if imgui.GetWindowDrawList == nil or imgui.GetCursorScreenPos == nil then
        imgui_text.colored(imgui, { 1.0, 0.88, 0.45, 1.0 }, tostring((cue or {}).status_label or "Route cue"))
        return
    end

    local draw = imgui.GetWindowDrawList()
    if draw == nil or draw.AddTriangleFilled == nil or draw.AddLine == nil then
        imgui_text.colored(imgui, { 1.0, 0.88, 0.45, 1.0 }, tostring((cue or {}).status_label or "Route cue"))
        return
    end

    local size = cue_number("arrow_size", 58.0)
    local arrow_gap = cue_number("arrow_gap", 18.0)
    local x, y = imgui.GetCursorScreenPos()
    local center = { x + (size * 0.5), y + (size * 0.5) }
    local vector = direction_vector(cue)
    if vector == nil then
        draw_center_marker(imgui, draw, center)
        draw_vertical_indicator(imgui, draw, center, cue)
        if imgui.Dummy ~= nil then
            imgui.Dummy({ size + arrow_gap, size + 2.0 })
        end
        return
    end

    local fx = vector.x
    local fy = vector.y
    local rx = -fy
    local ry = fx
    local function point(forward, right, lift)
        return {
            center[1] + (fx * forward) + (rx * right) + (lift or 0.0),
            center[2] + (fy * forward) + (ry * right) + (lift or 0.0),
        }
    end

    local tail = point(-24.0, 0.0, 3.0)
    local neck = point(2.0, 0.0, 3.0)
    local tip_shadow = point(26.0, 0.0, 3.0)
    local left_shadow = point(-4.0, -15.0, 3.0)
    local right_shadow = point(-4.0, 15.0, 3.0)
    draw:AddLine(tail, neck, color_u32(imgui, { 0.0, 0.0, 0.0, 0.42 }), 12.0)
    draw:AddTriangleFilled(tip_shadow, left_shadow, right_shadow, color_u32(imgui, { 0.0, 0.0, 0.0, 0.42 }))

    if draw.AddCircleFilled ~= nil then
        draw:AddCircleFilled(center, 24.0, color_u32(imgui, { 0.098, 0.858, 1.000, 0.12 }), 28)
    end

    draw:AddLine(point(-24.0, 0.0), point(2.0, 0.0), color_u32(imgui, skin.colors.blue), 11.0)
    draw:AddLine(point(-23.0, -1.5), point(1.0, -1.5), color_u32(imgui, skin.colors.blue_highlight), 6.0)
    draw:AddTriangleFilled(point(26.0, 0.0), point(-4.0, -15.0), point(-4.0, 15.0), color_u32(imgui, skin.colors.blue_highlight))
    draw:AddTriangleFilled(point(19.0, -2.0), point(-2.0, -10.5), point(-2.0, 1.5), color_u32(imgui, { 0.78, 0.96, 1.0, 0.62 }))
    draw:AddLine(point(-5.0, 15.0), point(26.0, 0.0), color_u32(imgui, skin.colors.text), 2.0)
    draw_vertical_indicator(imgui, draw, center, cue)

    if imgui.Dummy ~= nil then
        imgui.Dummy({ size + arrow_gap, size + 2.0 })
    end
end

function arrow_overlay.label(route, active_segment_index)
    local segment = active_segment(route, active_segment_index)
    if segment == nil then
        return "Route cue"
    end
    if segment.type == "teleport" then
        return "Teleport"
    end
    if segment.type == "zone_line" then
        return "Zone line"
    end
    return "Walk"
end

local function wrong_zone_travel_line(cue)
    if cue == nil then
        return "Travel to the target zone."
    end
    if cue.travel_path ~= nil and cue.travel_path ~= "" then
        return "Travel: " .. tostring(cue.travel_path)
    end
    if cue.travel_summary ~= nil and cue.travel_summary ~= "" then
        return "Travel: " .. tostring(cue.travel_summary)
    end
    local message = tostring(cue.message or ""):gsub("^Wrong zone:%s*", "")
    if message ~= "" then
        return "Travel: " .. message
    end
    return "Travel: Travel to the target zone."
end

local function wrong_zone_title(cue)
    return "Travel needed"
end

function arrow_overlay.render_state(state, route, active_segment_index, live_context)
    local cue = guidance_cursor.build(route, active_segment_index, live_context)
    if cue.available ~= true then
        return "No visual route target\nManual guidance"
    end

    if cue.zone_mismatch == true then
        return table.concat({
            wrong_zone_title(cue),
            wrong_zone_travel_line(cue),
            "Mode: Manual guidance",
        }, "\n")
    end

    local lines = {
        cue.message,
    }
    if cue.map_mismatch ~= true and cue.checkpoint_only ~= true then
        table.insert(lines, "Cue: " .. tostring(cue.direction_symbol or "?"))
    end
    if cue.segment_index ~= nil and cue.segment_count ~= nil then
        table.insert(lines, "Segment: " .. tostring(cue.segment_index) .. "/" .. tostring(cue.segment_count))
    end
    if cue.target_map_label ~= nil and cue.target_map_label ~= "" then
        table.insert(lines, "Target map: " .. tostring(cue.target_map_label))
    end
    if cue.current_map_label ~= nil and cue.current_map_label ~= "" then
        table.insert(lines, "Current map: " .. tostring(cue.current_map_label))
    end
    if cue.travel_path ~= nil and cue.travel_path ~= "" then
        table.insert(lines, "Travel: " .. tostring(cue.travel_path))
    end
    if cue.map_grid ~= nil and cue.map_grid ~= "" then
        table.insert(lines, "Map grid: " .. tostring(cue.map_grid))
    end
    if cue.distance_label ~= nil and cue.distance_label ~= "" then
        table.insert(lines, "Distance: " .. cue.distance_label)
    end
    if cue.vertical_label ~= nil and cue.vertical_label ~= "" and cue.vertical_label ~= "Level" then
        table.insert(lines, "Vertical: " .. cue.vertical_label)
    end
    if cue.route_complete == true then
        table.insert(lines, "Status: zone reached; verify manually")
    elseif cue.zone_mismatch == true then
        table.insert(lines, "Status: wrong zone")
    elseif cue.map_mismatch == true then
        table.insert(lines, "Status: wrong map")
    elseif cue.checkpoint_only == true then
        table.insert(lines, "Status: manual checkpoint")
    elseif cue.off_route == true then
        table.insert(lines, "Status: " .. tostring(cue.status_label or "off route"))
    elseif cue.status_label == "nearest route point" then
        table.insert(lines, "Status: nearest route point")
    elseif cue.arrived == true then
        table.insert(lines, "Status: Near target; use /odd next")
    else
        table.insert(lines, "Status: " .. tostring(cue.status_label or "keep going"))
    end
    table.insert(lines, "Manual guidance")
    return table.concat(lines, "\n")
end

function arrow_overlay.render(imgui, state, route, active_segment_index, live_context)
    if imgui == nil or imgui.Begin == nil or imgui.End == nil then
        return
    end
    if state == nil or state.arrow == nil or state.arrow.visible ~= true then
        return
    end

    local flags = bor_flags(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoSavedSettings)
    if imgui.SetNextWindowPos ~= nil then
        imgui.SetNextWindowPos({ state.arrow.x, state.arrow.y }, ImGuiCond_FirstUseEver)
    end
    local layout = cue_layout()
    if imgui.SetNextWindowSize ~= nil then
        imgui.SetNextWindowSize({ layout.width or 320.0, layout.height or 178.0 }, ImGuiCond_FirstUseEver)
    end
    if imgui.SetNextWindowBgAlpha ~= nil then
        imgui.SetNextWindowBgAlpha(layout.alpha or 0.35)
    end
    local pushed = skin.push_window(imgui, layout.alpha or 0.35)
    local visible, open = window_state.begin(imgui, "OddQ Pointer", true, flags)
    state.arrow.visible = open
    if visible then
        local cue = guidance_cursor.build(route, active_segment_index, live_context)
        if cue.available == true then
            if cue.zone_mismatch == true then
                imgui_text.colored(imgui, skin.colors.blue_highlight, wrong_zone_title(cue))
                cue_gap(imgui)
                imgui_text.wrapped(imgui, wrong_zone_travel_line(cue))
            elseif cue.map_mismatch == true then
                imgui_text.colored(imgui, { 1.0, 0.35, 0.25, 1.0 }, "Wrong map")
                cue_gap(imgui)
                imgui_text.wrapped(imgui, tostring(cue.message or "Move to the target map."))
            elseif cue.checkpoint_only == true then
                imgui_text.colored(imgui, skin.colors.blue_highlight, "Checkpoint")
                cue_gap(imgui)
                imgui_text.wrapped(imgui, tostring(cue.label or "Route target"))
            else
                imgui_text.colored(imgui, skin.colors.blue_highlight, "Go Here")
                cue_gap(imgui)
                draw_direction_arrow(imgui, cue)
                cue_same_line(imgui, cue_number("label_gap", nil))
                imgui_text.wrapped(imgui, tostring(cue.label or "Route target"))
            end
            if cue.zone_mismatch ~= true then
                if cue.map_grid ~= nil and cue.map_grid ~= "" then
                    cue_gap(imgui)
                    imgui_text.text(imgui, "Map grid: " .. tostring(cue.map_grid))
                end
                if cue.distance_label ~= nil and cue.distance_label ~= "" then
                    cue_gap(imgui)
                    imgui_text.text(imgui, "Distance: " .. cue.distance_label)
                end
                if cue.vertical_label ~= nil and cue.vertical_label ~= "" and cue.vertical_label ~= "Level" then
                    cue_gap(imgui)
                    imgui_text.text(imgui, "Vertical: " .. cue.vertical_label)
                end
                if cue.route_complete == true then
                    imgui_text.colored(imgui, skin.colors.blue_highlight, "Zone reached; verify manually")
                elseif cue.off_route == true then
                    imgui_text.colored(imgui, skin.colors.blue, tostring(cue.status_label or "Off route"))
                elseif cue.arrived == true then
                    imgui_text.colored(imgui, skin.colors.blue_highlight, "Near target; use /odd next")
                end
            end
        else
            imgui_text.colored(imgui, skin.colors.blue, "No visual route target")
        end
        if imgui.GetWindowPos ~= nil then
            local x, y = imgui.GetWindowPos()
            state.arrow.x = x
            state.arrow.y = y
        end
    end
    imgui.End()
    skin.pop(imgui, pushed)
end

return arrow_overlay
