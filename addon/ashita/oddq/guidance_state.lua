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
