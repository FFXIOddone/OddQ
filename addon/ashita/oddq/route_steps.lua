local route_steps = {}

local DEFAULT_MODE = "WARP"
local VALID_MODES = {
    WARP = true,
    NO_WARP = true,
}

local function safe_text(value)
    if value == nil or type(value) == "table" or type(value) == "function"
        or type(value) == "thread" or type(value) == "userdata" then
        return ""
    end
    return tostring(value)
end

local function copy_table(value)
    local copied = {}
    for key, item in pairs(type(value) == "table" and value or {}) do
        copied[key] = item
    end
    return copied
end

local function append_unique_strings(target, seen, values)
    for _, value in ipairs(type(values) == "table" and values or {}) do
        local text = safe_text(value)
        if text ~= "" and seen[text] ~= true then
            seen[text] = true
            target[#target + 1] = text
        end
    end
end

local function phase_specs_by_step_id(objective)
    local specs = type(objective) == "table" and objective.guide_phases or nil
    if type(specs) ~= "table" or #specs == 0 then
        return nil
    end

    local by_step_id = {}
    for order, value in ipairs(specs) do
        local spec = type(value) == "table" and value or {}
        local phase_id = safe_text(spec.phase_id)
        if phase_id == "" then
            phase_id = "phase_" .. tostring(order)
        end
        local normalized = {
            key = "authored:" .. tostring(order),
            id = phase_id,
            title = safe_text(spec.title),
            instruction = safe_text(spec.instruction),
        }
        for _, value_step_id in ipairs(type(spec.step_ids) == "table" and spec.step_ids or {}) do
            local step_id = safe_text(value_step_id)
            -- Schema/source validation rejects duplicates. Runtime keeps the
            -- first owner so malformed data cannot silently move a leg.
            if step_id ~= "" and by_step_id[step_id] == nil then
                by_step_id[step_id] = normalized
            end
        end
    end
    return by_step_id
end

local function build_phase_display_step(phase)
    local pointer_steps = phase.pointer_steps or {}
    local terminal = pointer_steps[#pointer_steps] or {}
    local display = copy_table(terminal)
    local notes, note_seen = {}, {}
    local required_items, item_seen = {}, {}
    local required_key_items, key_item_seen = {}, {}
    for _, step in ipairs(pointer_steps) do
        append_unique_strings(notes, note_seen, step.notes)
        append_unique_strings(required_items, item_seen, step.required_items)
        append_unique_strings(required_key_items, key_item_seen, step.required_key_items)
        if step.warp_home_recommended == true then
            display.warp_home_recommended = true
        end
    end
    display.guide_phase_id = phase.id
    display.guide_phase_title = phase.title
    display.guide_phase_instruction = phase.instruction
    if phase.instruction ~= "" then
        display.instruction = phase.instruction
    end
    display.notes = notes
    display.required_items = required_items
    display.required_key_items = required_key_items
    display.pointer_first_index = phase.first_index
    display.pointer_last_index = phase.last_index
    display.pointer_leg_count = phase.last_index - phase.first_index + 1
    return display
end

local function guide_phases(objective)
    local steps = type(objective) == "table" and objective.steps or nil
    if type(steps) ~= "table" or #steps == 0 then
        return {}
    end

    local phase_specs = phase_specs_by_step_id(objective)
    local phases = {}
    for index, step in ipairs(steps) do
        step = type(step) == "table" and step or {}
        local step_id = safe_text(step.step_id)
        local spec = phase_specs ~= nil and phase_specs[step_id] or nil
        local phase_id = spec ~= nil and spec.id or step_id
        if phase_id == "" then phase_id = "step_" .. tostring(index) end
        local phase_key = spec ~= nil and spec.key or ("legacy:" .. tostring(index))

        local phase = phases[#phases]
        if phase == nil or phase.key ~= phase_key then
            phase = {
                key = phase_key,
                id = phase_id,
                title = spec ~= nil and spec.title or "",
                instruction = spec ~= nil and spec.instruction or "",
                first_index = index,
                last_index = index,
                pointer_steps = {},
            }
            phases[#phases + 1] = phase
        end
        phase.last_index = index
        phase.pointer_steps[#phase.pointer_steps + 1] = step
    end

    for _, phase in ipairs(phases) do
        phase.display_step = build_phase_display_step(phase)
    end
    return phases
end

local function phase_for_index(phases, pointer_index)
    if #phases == 0 then
        return nil, 0
    end
    pointer_index = math.floor(tonumber(pointer_index) or 1)
    pointer_index = math.max(phases[1].first_index, math.min(pointer_index, phases[#phases].last_index))
    for index, phase in ipairs(phases) do
        if pointer_index >= phase.first_index and pointer_index <= phase.last_index then
            return phase, index
        end
    end
    return phases[#phases], #phases
end

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

function route_steps.guide_phases(objective)
    return guide_phases(objective)
end

function route_steps.guide_projection(objective, pointer_index)
    local projected = copy_table(objective)
    local phases = guide_phases(objective)
    projected.steps = {}
    for _, phase in ipairs(phases) do
        projected.steps[#projected.steps + 1] = phase.display_step
    end
    local phase, selected = phase_for_index(phases, pointer_index)
    projected.pointer_phase = phase
    projected.pointer_phase_index = selected
    projected.pointer_phase_count = #phases
    return projected, selected, #phases, phase
end

function route_steps.move_phase_index(objective, pointer_index, delta)
    local phases = guide_phases(objective)
    local phase, selected = phase_for_index(phases, pointer_index)
    if phase == nil then
        return nil, "no_steps"
    end
    delta = tonumber(delta) or 0
    if delta > 0 then
        if pointer_index < phase.last_index then
            return nil, "phase_in_progress"
        end
        if selected >= #phases then
            return nil, "end"
        end
        return phases[selected + 1].first_index
    end
    if delta < 0 then
        if pointer_index > phase.first_index then
            return phase.first_index
        end
        if selected <= 1 then
            return nil, "start"
        end
        return phases[selected - 1].first_index
    end
    return pointer_index
end

return route_steps
