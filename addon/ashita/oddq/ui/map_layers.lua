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
    on_command
)
    if imgui == nil or state == nil then
        return
    end

    main_window.render(
        imgui,
        state,
        objective,
        route,
        active_segment_index,
        on_command
    )
    settings_window.render(imgui, state)
end

return map_layers
