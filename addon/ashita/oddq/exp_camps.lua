local exp_camps = {}

local loaded, generated_camps = pcall(function()
    return require("data/exp_camps")
end)
exp_camps.camps = loaded and generated_camps or {}

function exp_camps.for_zone(zone_id)
    local results = {}
    for _, camp in ipairs(exp_camps.camps) do
        if tonumber(camp.zone_id) == tonumber(zone_id) then
            table.insert(results, camp)
        end
    end
    return results
end

function exp_camps.enabled_for_state(state, zone_id)
    local results = {}
    local active_types = state and state.exp_types or {}
    for _, camp in ipairs(exp_camps.for_zone(zone_id)) do
        local include = true
        if camp.category_key == "solo_trusts" then
            include = active_types.solo_trusts ~= false
        elseif camp.category_key == "duo_trusts" then
            include = active_types.duo_trusts ~= false
        elseif camp.category_key == "manaburns" then
            include = active_types.manaburns ~= false
        elseif camp.category_key == "pet_parties" then
            include = active_types.pet_parties ~= false
        elseif camp.category_key == "parties" then
            include = active_types.parties ~= false
        end

        if include then
            table.insert(results, camp)
        end
    end
    return results
end

return exp_camps
