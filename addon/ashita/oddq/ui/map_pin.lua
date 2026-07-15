local map_pin = {}

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

local function pin_layout()
    return skin.layout.map_pin or {}
end

local function pin_number(key, fallback)
    return tonumber(pin_layout()[key]) or fallback
end

local function pin_gap(imgui)
    local gap = pin_number("body_gap", 0.0)
    if imgui ~= nil and imgui.Dummy ~= nil and gap > 0.0 then
        imgui.Dummy({ 1.0, gap })
    end
end

local function pin_same_line(imgui, gap)
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

function map_pin.render_state(state, route, active_segment_index, live_context)
    local cue = guidance_cursor.build(route, active_segment_index, live_context)
    if cue.available ~= true then
        return "OddQ Map Pin\nNo visual route target\nManual guidance"
    end

    local lines = {
        "OddQ Map Pin",
        cue.message,
        "Segment: " .. tostring(cue.segment_index or "?") .. "/" .. tostring(cue.segment_count or "?"),
        "Direction: " .. tostring(cue.direction_symbol or "?"),
    }
    if cue.distance_label ~= nil and cue.distance_label ~= "" then
        table.insert(lines, "Distance: " .. cue.distance_label)
    end
    if cue.route_complete == true then
        table.insert(lines, "Status: zone reached; verify manually")
    elseif cue.zone_mismatch == true then
        table.insert(lines, "Status: wrong zone")
    elseif cue.off_route == true then
        table.insert(lines, "Status: " .. tostring(cue.status_label or "off route"))
    elseif cue.status_label == "nearest route point" then
        table.insert(lines, "Status: nearest route point")
    elseif cue.arrived == true then
        table.insert(lines, "Status: near target")
    else
        table.insert(lines, "Status: " .. tostring(cue.status_label or "follow pin"))
    end
    table.insert(lines, "Manual guidance")
    return table.concat(lines, "\n")
end

function map_pin.render(imgui, state, route, active_segment_index, live_context)
    if imgui == nil or imgui.Begin == nil or imgui.End == nil then
        return
    end
    if state == nil or state.map_pin == nil or state.map_pin.visible ~= true then
        return
    end

    local flags = bor_flags(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoSavedSettings)
    local layout = pin_layout()
    imgui.SetNextWindowPos({ state.map_pin.x, state.map_pin.y }, ImGuiCond_FirstUseEver)
    imgui.SetNextWindowSize({ layout.width or 260.0, layout.height or 118.0 }, ImGuiCond_FirstUseEver)
    imgui.SetNextWindowBgAlpha(layout.alpha or 0.30)
    local pushed = skin.push_window(imgui, layout.alpha or 0.30)
    local visible, open = window_state.begin(imgui, "OddQ Map Pin", true, flags)
    state.map_pin.visible = open
    if visible then
        local cue = guidance_cursor.build(route, active_segment_index, live_context)
        if cue.available == true then
            imgui_text.colored(imgui, { 0.2, 1.0, 0.55, 1.0 }, "Go Here")
            pin_gap(imgui)
            imgui_text.wrapped(imgui, tostring(cue.label or "Route target"))
            pin_gap(imgui)
            imgui_text.text(imgui, "Segment: " .. tostring(cue.segment_index or "?") .. "/" .. tostring(cue.segment_count or "?"))
            pin_gap(imgui)
            imgui_text.colored(imgui, { 1.0, 0.88, 0.45, 1.0 }, tostring(cue.direction_symbol or "?"))
            if cue.distance_label ~= nil and cue.distance_label ~= "" then
                pin_same_line(imgui, pin_number("direction_gap", nil))
                imgui_text.text(imgui, "Distance: " .. cue.distance_label)
            end
            if cue.route_complete == true then
                pin_gap(imgui)
                imgui_text.colored(imgui, { 0.2, 1.0, 0.55, 1.0 }, "Zone reached; verify manually")
            elseif cue.zone_mismatch == true then
                pin_gap(imgui)
                imgui_text.colored(imgui, { 1.0, 0.35, 0.25, 1.0 }, "Wrong zone")
            elseif cue.off_route == true then
                pin_gap(imgui)
                imgui_text.colored(imgui, { 1.0, 0.88, 0.45, 1.0 }, tostring(cue.status_label or "Off route"))
            elseif cue.status_label == "nearest route point" then
                pin_gap(imgui)
                imgui_text.colored(imgui, { 0.2, 1.0, 0.55, 1.0 }, "Nearest route point")
            end
        else
            imgui_text.colored(imgui, { 1.0, 0.88, 0.45, 1.0 }, "No visual route target")
        end
        local x, y = imgui.GetWindowPos()
        state.map_pin.x = x
        state.map_pin.y = y
    end
    imgui.End()
    skin.pop(imgui, pushed)
end

return map_pin
