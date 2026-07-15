local npc_tracker = {}

local MAX_ENTITY_INDEX = 1023
local VISIBLE_RENDER_FLAG = 0x200

local generic_name_tokens = {
    ["and"] = true,
    ["camp"] = true,
    ["for"] = true,
    ["gate"] = true,
    ["guard"] = true,
    ["npc"] = true,
    ["optional"] = true,
    ["prep"] = true,
    ["route"] = true,
}

local function safe_call(callback)
    local ok, value = pcall(callback)
    if ok then
        return value
    end
    return nil
end

local function safe_text(value)
    local value_type = type(value)
    if value_type == "nil" or value_type == "function" or value_type == "thread" or value_type == "userdata" or value_type == "table" then
        return ""
    end
    return tostring(value)
end

local function trim(value)
    return safe_text(value):match("^%s*(.-)%s*$") or ""
end

local function normalize_name(value)
    local text = trim(value):lower()
    text = text:gsub("%b()", " ")
    text = text:gsub("%b[]", " ")
    text = text:gsub("[^%w%s']", " ")
    text = text:gsub("%s+", " ")
    return trim(text)
end

local function add_candidate(candidates, value)
    local normalized = normalize_name(value)
    if normalized == "" then
        return
    end

    candidates[normalized] = true
    for token in normalized:gmatch("%S+") do
        if #token >= 3 and generic_name_tokens[token] ~= true then
            candidates[token] = true
        end
    end
end

local function candidate_names(value)
    local candidates = {}
    local text = safe_text(value)
    add_candidate(candidates, text)
    text = text:gsub("[Oo][Rr]", "/")
    text = text:gsub("[Aa][Nn][Dd]", "/")
    for part in text:gmatch("[^/]+") do
        add_candidate(candidates, part)
    end
    return candidates
end

local function name_matches(expected_name, actual_name)
    local actual = normalize_name(actual_name)
    if actual == "" then
        return false
    end

    local candidates = candidate_names(expected_name)
    if candidates[actual] == true then
        return true
    end
    for token in actual:gmatch("%S+") do
        if candidates[token] == true then
            return true
        end
    end
    return false
end

local function is_actionable_name(name)
    local normalized = normalize_name(name)
    if normalized == "" then
        return false
    end
    if generic_name_tokens[normalized] == true then
        return false
    end
    return true
end

local function checkpoint_from_step(step)
    if type(step) ~= "table" or not is_actionable_name(step.npc_name) then
        return nil
    end

    return {
        name = safe_text(step.npc_name),
        zone_id = tonumber(step.zone_id) or 0,
        map_grid = safe_text(step.map_grid),
        position = type(step.position) == "table" and step.position or nil,
        instruction = safe_text(step.instruction),
        step_id = safe_text(step.step_id),
    }
end

function npc_tracker.next_checkpoint(objective)
    if type(objective) ~= "table" then
        return nil
    end

    if type(objective.steps) == "table" then
        for _, step in ipairs(objective.steps) do
            local checkpoint = checkpoint_from_step(step)
            if checkpoint ~= nil then
                return checkpoint
            end
        end
    end

    if is_actionable_name(objective.npc_name) then
        return {
            name = safe_text(objective.npc_name),
            zone_id = tonumber(objective.zone_id) or 0,
            map_grid = safe_text(objective.map_grid),
            position = type(objective.position) == "table" and objective.position or nil,
            instruction = safe_text(objective.instruction),
            step_id = safe_text(objective.step_id),
        }
    end

    return nil
end

local function current_zone_from_live()
    if AshitaCore == nil or AshitaCore.GetMemoryManager == nil then
        return nil
    end

    local memory = safe_call(function()
        return AshitaCore:GetMemoryManager()
    end)
    local party = safe_call(function()
        return memory and memory:GetParty()
    end)
    if party == nil or party.GetMemberZone == nil then
        return nil
    end

    return tonumber(safe_call(function()
        return party:GetMemberZone(0)
    end))
end

local function target_index_from_live(memory)
    local target = safe_call(function()
        return memory and memory:GetTarget()
    end)
    if target == nil or target.GetTargetIndex == nil then
        return nil
    end
    return tonumber(safe_call(function()
        return target:GetTargetIndex(0)
    end))
end

local function provider_target_index(provider)
    provider = provider or {}
    local direct = tonumber(provider.target_index or provider.current_target_index)
    if direct ~= nil then
        return direct
    end

    local memory = provider.memory
    if memory == nil and AshitaCore ~= nil and AshitaCore.GetMemoryManager ~= nil then
        memory = safe_call(function()
            return AshitaCore:GetMemoryManager()
        end)
    end
    return target_index_from_live(memory)
end

local function scan_provider_entities(provider)
    local results = {}
    provider = provider or {}

    if type(provider.entities) == "table" then
        for _, entity in ipairs(provider.entities) do
            local name = safe_text(entity.name or entity.Name)
            if name ~= "" and entity.visible ~= false then
                table.insert(results, {
                    index = tonumber(entity.index or entity.Index) or 0,
                    server_id = tonumber(entity.server_id or entity.ServerId or entity.Id) or 0,
                    name = name,
                    distance = tonumber(entity.distance or entity.Distance),
                })
            end
        end
        return results, true
    end

    local memory = provider.memory
    if memory == nil and AshitaCore ~= nil and AshitaCore.GetMemoryManager ~= nil then
        memory = safe_call(function()
            return AshitaCore:GetMemoryManager()
        end)
    end

    local entity = provider.entity or safe_call(function()
        return memory and memory:GetEntity()
    end)
    if entity == nil or entity.GetName == nil then
        return results, false
    end

    for index = 0, MAX_ENTITY_INDEX, 1 do
        local exists = true
        if entity.GetEntity ~= nil then
            exists = safe_call(function()
                return entity:GetEntity(index)
            end) ~= nil
        end
        if exists then
            local visible = true
            if entity.GetRenderFlags0 ~= nil and bit ~= nil and bit.band ~= nil then
                local flags = tonumber(safe_call(function()
                    return entity:GetRenderFlags0(index)
                end)) or 0
                visible = bit.band(flags, VISIBLE_RENDER_FLAG) == VISIBLE_RENDER_FLAG
            end
            local name = safe_text(safe_call(function()
                return entity:GetName(index)
            end))
            if visible and name ~= "" then
                local raw_distance = tonumber(safe_call(function()
                    return entity:GetDistance(index)
                end))
                local distance = nil
                if raw_distance ~= nil and raw_distance >= 0 then
                    distance = math.sqrt(raw_distance)
                end
                table.insert(results, {
                    index = index,
                    server_id = tonumber(safe_call(function()
                        return entity:GetServerId(index)
                    end)) or 0,
                    name = name,
                    distance = distance,
                })
            end
        end
    end

    return results, true
end

local function better_match(left, right)
    if right == nil then
        return true
    end
    if left.distance == nil then
        return false
    end
    if right.distance == nil then
        return true
    end
    return left.distance < right.distance
end

function npc_tracker.resolve_next_checkpoint(objective, live_context, provider)
    local checkpoint = npc_tracker.next_checkpoint(objective)
    if checkpoint == nil then
        return {
            status = "no_checkpoint",
        }
    end

    live_context = live_context or {}
    provider = provider or {}
    local expected_zone_id = tonumber(checkpoint.zone_id) or 0
    local current_zone_id = tonumber(live_context.current_zone_id or provider.current_zone_id) or current_zone_from_live() or 0

    local status = {
        status = "not_seen",
        name = checkpoint.name,
        zone_id = expected_zone_id,
        current_zone_id = current_zone_id,
        map_grid = checkpoint.map_grid,
        position = checkpoint.position,
        found = false,
        targeted = false,
    }

    if expected_zone_id > 0 and current_zone_id > 0 and current_zone_id ~= expected_zone_id then
        status.status = "wrong_zone"
        return status
    end

    local target_index = provider_target_index(provider)
    local entities, scanned = scan_provider_entities(provider)
    if not scanned then
        status.status = "scanner_unavailable"
        return status
    end

    local match = nil
    for _, entity in ipairs(entities) do
        if name_matches(checkpoint.name, entity.name) and better_match(entity, match) then
            match = entity
        end
    end

    if match ~= nil then
        status.status = "found"
        status.found = true
        status.index = match.index
        status.server_id = match.server_id
        status.matched_name = match.name
        status.distance = match.distance
        status.targeted = target_index ~= nil and target_index > 0 and match.index == target_index
    end

    return status
end

return npc_tracker
