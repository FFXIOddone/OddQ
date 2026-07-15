local main_window = require("ui/main_window")
local settings_window = require("ui/settings_window")

local map_layers = {}

function map_layers.render_state(state, current_zone_id, route, objective, active_segment_index)
    return main_window.render_state(state, objective, route, active_segment_index)
end

function map_layers.render(
    imgui,
    state,
    current_zone_id,
    route,
    objective,
    active_segment_index,
    guided_menu_text,
    on_command,
    assist_state,
    on_assist_action
)
    if imgui == nil or state == nil then
        return
    end

    if state.settings_open == true then
        settings_window.render(imgui, state)
        return
    end

    main_window.render(
        imgui,
        state,
        objective,
        route,
        active_segment_index,
        guided_menu_text,
        on_command,
        assist_state,
        on_assist_action
    )
end

return map_layers
