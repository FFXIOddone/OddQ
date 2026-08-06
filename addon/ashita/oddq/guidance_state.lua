local guidance_state = {}

guidance_state.priority_order = { "missions", "jobs", "quests", "exp" }

local mode_labels = {
    missions = "Missions",
    jobs = "Job Unlocks",
    quests = "Quests",
    exp = "EXP",
}

local exp_type_labels = {
    solo_trusts = "Solo + Trusts",
    duo_trusts = "Duo + Trusts",
    manaburns = "Manaburns",
    pet_parties = "Pet Parties",
    parties = "EXP Parties",
}

function guidance_state.new()
    return {
        first_launch_seen = false,
        main_window_open = false,
        main_view = "browse",
        modes = {
            missions = true,
            jobs = true,
            quests = true,
            exp = true,
        },
        guide_browser_category = "catseye",
        guide_browser_query = "",
        guide_browser_page = 1,
        guide_browser_selected_index = 1,
        route_mode = "WARP",
        exp_types = {
            solo_trusts = true,
            duo_trusts = true,
            manaburns = true,
            pet_parties = true,
            parties = true,
        },
        active_mode = "missions",
        status_message = "OddQ ready.",
    }
end

function guidance_state.reset_step_transition(state)
    if type(state) ~= "table" then
        return
    end
    state._step_transition_key = nil
    state._step_transition_zone_id = nil
end

function guidance_state.observe_step_zone_transition(state, objective, current_zone_id)
    local steps = type(objective) == "table" and objective.steps or nil
    local zone_id = math.floor(tonumber(current_zone_id) or 0)
    if type(state) ~= "table" or type(steps) ~= "table" or #steps == 0 or zone_id <= 0 then
        return false
    end

    local selected = math.floor(tonumber(state.guide_step_tab_index) or 1)
    selected = math.max(1, math.min(selected, #steps))
    local step = steps[selected] or {}
    local objective_id = tostring(objective.objective_id or objective.id or objective.name or "")
    local transition_key = objective_id .. "|" .. tostring(selected) .. "|" .. tostring(step.step_id or "")

    if state._step_transition_key ~= transition_key then
        state._step_transition_key = transition_key
        state._step_transition_zone_id = zone_id
        return false
    end

    local previous_zone_id = tonumber(state._step_transition_zone_id)
    state._step_transition_zone_id = zone_id
    local destination_zone_id = math.floor(tonumber(step.auto_advance_zone_id) or 0)
    if destination_zone_id <= 0
        or previous_zone_id == nil
        or previous_zone_id == zone_id
        or zone_id ~= destination_zone_id
        or selected >= #steps then
        return false
    end

    state.guide_step_tab_index = selected + 1
    guidance_state.reset_step_transition(state)
    return true, selected + 1
end

function guidance_state.advance_for_progress_events(state, objective, events, matcher)
    local steps = type(objective) == "table" and objective.steps or nil
    if type(state) ~= "table" or type(steps) ~= "table" or #steps == 0 or type(matcher) ~= "function" then
        return false
    end
    local selected = math.max(1, math.min(math.floor(tonumber(state.guide_step_tab_index) or 1), #steps))
    if selected >= #steps then return false end
    local complete, evidence = matcher(steps[selected], events)
    if complete ~= true then return false end
    state.guide_step_tab_index = selected + 1
    guidance_state.reset_step_transition(state)
    return true, selected + 1, evidence
end

function guidance_state.mode_label(mode)
    return mode_labels[mode] or tostring(mode or "unknown")
end

function guidance_state.exp_type_label(kind)
    return exp_type_labels[kind] or tostring(kind or "unknown")
end

function guidance_state.exp_guidance_enabled(state)
    return state ~= nil and state.modes ~= nil and state.modes.exp == true
end

function guidance_state.enabled_mode_labels(state)
    local labels = {}
    if state == nil or state.modes == nil then
        return labels
    end

    for _, mode in ipairs(guidance_state.priority_order) do
        if state.modes[mode] == true then
            table.insert(labels, guidance_state.mode_label(mode))
        end
    end

    return labels
end

function guidance_state.enabled_mode_keys(state)
    local keys = {}
    if state == nil or state.modes == nil then
        return keys
    end
    if state.modes.missions == true then
        table.insert(keys, "missions")
    end
    if state.modes.jobs == true then
        table.insert(keys, "jobs")
    end
    if state.modes.quests == true then
        table.insert(keys, "quests")
    end
    if state.modes.exp == true then
        table.insert(keys, "exp")
    end
    return keys
end

function guidance_state.enabled_exp_type_labels(state)
    local labels = {}
    if state == nil or state.exp_types == nil then
        return labels
    end

    for _, kind in ipairs({ "solo_trusts", "duo_trusts", "manaburns", "pet_parties", "parties" }) do
        if state.exp_types[kind] == true then
            table.insert(labels, guidance_state.exp_type_label(kind))
        end
    end

    return labels
end

function guidance_state.enabled_exp_type_keys(state)
    local keys = {}
    if state == nil or state.exp_types == nil then
        return keys
    end
    for _, kind in ipairs({ "solo_trusts", "duo_trusts", "manaburns", "pet_parties", "parties" }) do
        if state.exp_types[kind] == true then
            table.insert(keys, kind)
        end
    end
    return keys
end

function guidance_state.pick_active_mode(state)
    if state == nil or state.modes == nil then
        return "missions"
    end

    for _, mode in ipairs(guidance_state.priority_order) do
        if state.modes[mode] == true then
            state.active_mode = mode
            return mode
        end
    end

    state.active_mode = "none"
    return "none"
end

function guidance_state.toggle_mode(state, mode)
    if state == nil or state.modes == nil or state.modes[mode] == nil then
        return false
    end

    state.modes[mode] = not state.modes[mode]
    if state.modes[mode] == true then
        state.active_mode = mode
    elseif state.active_mode == mode then
        guidance_state.pick_active_mode(state)
    end
    return true
end

function guidance_state.set_mode(state, mode, enabled)
    if state == nil or state.modes == nil or state.modes[mode] == nil then
        return false
    end

    state.modes[mode] = enabled == true
    if enabled == true then
        state.active_mode = mode
    elseif state.active_mode == mode then
        guidance_state.pick_active_mode(state)
    end
    return true
end

function guidance_state.toggle_exp_type(state, kind)
    if state == nil or state.exp_types == nil or state.exp_types[kind] == nil then
        return false
    end

    state.exp_types[kind] = not state.exp_types[kind]
    return true
end

return guidance_state
