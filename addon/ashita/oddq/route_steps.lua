local route_steps = {}

local DEFAULT_MODE = "WARP"
local VALID_MODES = {
    WARP = true,
    NO_WARP = true,
}

function route_steps.normalize_mode(value)
    local mode = tostring(value or ""):upper()
    if VALID_MODES[mode] then
        return mode
    end
    return DEFAULT_MODE
end

function route_steps.has_modes(objective)
    for _, step in ipairs(type(objective) == "table" and objective.steps or {}) do
        if VALID_MODES[tostring((step or {}).route_mode or ""):upper()] then
            return true
        end
    end
    return false
end

function route_steps.project(objective, mode)
    if type(objective) ~= "table" or not route_steps.has_modes(objective) then
        return objective
    end

    mode = route_steps.normalize_mode(mode)
    local projected = {}
    for key, value in pairs(objective) do
        projected[key] = value
    end
    projected.steps = {}
    projected.has_route_modes = true
    projected.selected_route_mode = mode
    for _, step in ipairs(objective.steps or {}) do
        local step_mode = tostring((step or {}).route_mode or ""):upper()
        if step_mode == "" or step_mode == mode then
            projected.steps[#projected.steps + 1] = step
        end
    end
    return projected
end

function route_steps.remap_index(objective, old_mode, new_mode, old_index)
    local old_objective = route_steps.project(objective, old_mode) or {}
    local new_objective = route_steps.project(objective, new_mode) or {}
    local old_steps = old_objective.steps or {}
    local new_steps = new_objective.steps or {}
    if #new_steps == 0 then
        return 0
    end

    old_index = math.floor(tonumber(old_index) or 1)
    old_index = math.max(1, math.min(old_index, #old_steps))
    local selected = old_steps[old_index] or {}
    local step_id = tostring(selected.step_id or "")
    if step_id ~= "" then
        for index, step in ipairs(new_steps) do
            if tostring((step or {}).step_id or "") == step_id then
                return index
            end
        end
    end

    local route_group = tostring(selected.route_group or "")
    if route_group ~= "" then
        for index, step in ipairs(new_steps) do
            if tostring((step or {}).route_group or "") == route_group then
                return index
            end
        end
    end

    return math.max(1, math.min(old_index, #new_steps))
end

return route_steps
