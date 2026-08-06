local rank10_milestone = {}

local RANK_NINE_ONE_OBJECTIVES = {
    ["catseyexi.mission.san_doria_9_1.start"] = true,
    ["catseyexi.mission.bastok_9_1.start"] = true,
    ["catseyexi.mission.windurst_9_1.start"] = true,
}

rank10_milestone.source_url =
    "https://www.bg-wiki.com/ffxi/CatsEyeXI_Systems/Milestone_Rewards"

rank10_milestone.reward_choices = {
    {
        name = "Any Stage 4 Relic Weapon",
        detail = "You still complete the final Relic upgrade afterward.",
    },
    {
        name = "Mythos Token",
        detail = "Completes the HNM trophy stage of one Mythic; its other materials are still required.",
    },
    {
        name = "Defending Ring",
        detail = "A direct item reward.",
    },
    {
        name = "Octave Club",
        detail = "A modified Kraken Club equivalent that cannot be equipped with Kraken Club.",
    },
}

function rank10_milestone.new_state()
    return {
        armed = false,
        pending = false,
        last_rank = nil,
    }
end

function rank10_milestone.is_rank_nine_one(objective)
    local objective_id = type(objective) == "table" and objective.objective_id or objective
    return RANK_NINE_ONE_OBJECTIVES[tostring(objective_id or "")] == true
end

function rank10_milestone.arm_for_guide(state, objective, rank)
    if type(state) ~= "table"
        or not rank10_milestone.is_rank_nine_one(objective)
        or tonumber(rank) ~= 9 then
        return false
    end
    state.armed = true
    state.last_rank = 9
    return true
end

function rank10_milestone.observe_rank(state, rank)
    if type(state) ~= "table" or tonumber(rank) == nil then
        return false
    end
    local observed = tonumber(rank)
    state.last_rank = observed
    if state.armed == true and observed == 10 then
        state.armed = false
        state.pending = true
        return true
    end
    return false
end

function rank10_milestone.restore(state, armed, pending)
    if type(state) ~= "table" then
        return
    end
    state.armed = armed == true
    state.pending = pending == true
end

function rank10_milestone.dismiss(state)
    if type(state) == "table" then
        state.pending = false
    end
end

return rank10_milestone
