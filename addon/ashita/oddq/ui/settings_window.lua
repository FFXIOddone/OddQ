local skin = require("ui/skin")
local window_state = require("ui/window_state")

local settings_window = {}

local function bool_text(value)
    return tostring(value == true)
end

function settings_window.render_state(state)
    state = state or {}
    local prefs = state.preferences or {}
    local integrations = prefs.integrations or {}
    local lines = {
        "OddQ Settings",
        "Allow FilterScan Commands: " .. bool_text(integrations.allow_filterscan_command),
        "Allow MiniMap Commands: " .. bool_text(integrations.allow_minimap_command),
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

    local layout = (skin.layout and skin.layout.tuner_window) or { width = 520.0, height = 520.0 }
    if imgui.SetNextWindowSize ~= nil then
        imgui.SetNextWindowSize({ layout.width, layout.height }, ImGuiCond_FirstUseEver)
    end

    local pushed = skin.push_window(imgui)
    local visible, open = window_state.begin(imgui, "OddQ Settings", true, 0)
    state.settings_open = open
    if not open then
        state.main_view = "browse"
        state.main_window_open = true
    end
    if visible then
        local prefs = state.preferences or {}
        prefs.display = prefs.display or {}
        prefs.integrations = prefs.integrations or {}
        prefs.safety = prefs.safety or {}
        state.preferences = prefs

        imgui.Text("Optional command permissions")
        if imgui.TextWrapped ~= nil then
            imgui.TextWrapped("OddQ guidance is read-only. These permissions only allow the matching button inside a guide.")
        end
        checkbox(imgui, "Allow FilterScan Commands", prefs.integrations, "allow_filterscan_command")
        checkbox(imgui, "Allow MiniMap Commands", prefs.integrations, "allow_minimap_command")
    end
    imgui.End()
    skin.pop(imgui, pushed)
end

return settings_window
