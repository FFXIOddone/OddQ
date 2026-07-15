local skin = require("ui/skin")
local window_state = require("ui/window_state")

local settings_window = {}

local function bool_text(value)
    return tostring(value == true)
end

function settings_window.render_state(state)
    state = state or {}
    local prefs = state.preferences or {}
    local display = prefs.display or {}
    local lines = {
        "OddQ Settings",
        "Show Objective Pointer: " .. bool_text(display.show_pointer ~= false),
    }
    return table.concat(lines, "\n")
end

local function checkbox(imgui, label, table_ref, key, enabled)
    if enabled == false then
        skin.disabled_checkbox(imgui, label, table_ref[key] == true)
        return false
    end
    if imgui.Checkbox(label, { table_ref[key] == true }) then
        table_ref[key] = table_ref[key] ~= true
        return true
    end
    return false
end

function settings_window.render(imgui, state)
    if state == nil or state.settings_open ~= true or imgui == nil then
        return
    end

    local layout = (skin.layout and skin.layout.settings_window) or { width = 420.0, height = 170.0 }
    if imgui.SetNextWindowSize ~= nil then
        imgui.SetNextWindowSize({ layout.width, layout.height }, ImGuiCond_FirstUseEver)
    end

    local pushed = skin.push_window(imgui)
    local visible, open = window_state.begin(imgui, "OddQ Settings##oddq_mvp", true, 0)
    state.settings_open = open
    if visible then
        local prefs = state.preferences or {}
        prefs.display = prefs.display or {}
        state.preferences = prefs

        imgui.Text("Guide display")
        if imgui.TextWrapped ~= nil then
            imgui.TextWrapped("The pointer shows the current step when coordinates are known and travel guidance when you are in another zone.")
        end
        if checkbox(imgui, "Show Objective Pointer", prefs.display, "show_pointer") then
            state.arrow = state.arrow or {}
            state.arrow.visible = prefs.display.show_pointer == true
        end
    end
    imgui.End()
    skin.pop(imgui, pushed)
end

return settings_window
