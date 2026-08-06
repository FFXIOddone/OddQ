local player_state = {}

local PI = math.pi
local TWO_PI = PI * 2
local MOUNTED_EFFECT_ID = 252
local CUTSCENE_STATUS_ID = 4
local key_item_id_cache = {}

local function safe_call(callback)
    local ok, value = pcall(callback)
    if ok then
        return value
    end
    return nil
end

local function memory_manager()
    if AshitaCore == nil or AshitaCore.GetMemoryManager == nil then
        return nil
    end
    return safe_call(function()
        return AshitaCore:GetMemoryManager()
    end)
end

local function read_party()
    local memory = memory_manager()
    if memory == nil or memory.GetParty == nil then
        return nil
    end
    return safe_call(function()
        return memory:GetParty()
    end)
end

local function read_player()
    local memory = memory_manager()
    if memory == nil or memory.GetPlayer == nil then
        return nil
    end
    return safe_call(function()
        return memory:GetPlayer()
    end)
end

local function normalize_angle(radians)
    while radians <= -PI do
        radians = radians + TWO_PI
    end
    while radians > PI do
        radians = radians - TWO_PI
    end
    return radians
end

local function oddq_heading(yaw)
    local raw = tonumber(yaw)
    if raw == nil then
        return nil
    end
    return normalize_angle(raw + (PI / 2))
end

-- Ashita exposes local position as X/Y/Z where planar travel uses X/Y. OddQ's
-- route math uses x/z as its planar axes, so the vertical value is stored in y.
local function oddq_position(position)
    if position == nil then
        return nil
    end
    return {
        x = tonumber(position.X or position.x) or 0,
        y = tonumber(position.Z or position.z) or 0,
        z = tonumber(position.Y or position.y) or 0,
    }
end

local function copied_position(position)
    if type(position) ~= "table" then
        return nil
    end
    return {
        x = tonumber(position.x or position.X) or 0,
        y = tonumber(position.y or position.Y) or 0,
        z = tonumber(position.z or position.Z) or 0,
    }
end

local function read_zone_id()
    local party = read_party()
    if party == nil or party.GetMemberZone == nil then
        return nil
    end
    return tonumber(safe_call(function()
        return party:GetMemberZone(0)
    end))
end

local function read_level()
    local player = read_player()
    if player ~= nil and player.GetMainJobLevel ~= nil then
        local level = tonumber(safe_call(function()
            return player:GetMainJobLevel()
        end))
        if level ~= nil and level > 0 then
            return level
        end
    end

    local party = read_party()
    if party ~= nil and party.GetMemberMainJobLevel ~= nil then
        local level = tonumber(safe_call(function()
            return party:GetMemberMainJobLevel(0)
        end))
        if level ~= nil and level > 0 then
            return level
        end
    end
    return nil
end

local function read_mounted()
    local player = read_player()
    if player == nil or player.GetBuffs == nil then
        return nil
    end
    return safe_call(function()
        local buffs = player:GetBuffs()
        if buffs == nil then
            return nil
        end
        for _, buff_id in pairs(buffs) do
            if tonumber(buff_id) == MOUNTED_EFFECT_ID then
                return true
            end
        end
        return false
    end)
end

local function normalized(value)
    return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function read_status()
    local memory = memory_manager()
    if memory == nil or memory.GetParty == nil or memory.GetEntity == nil then return nil end
    local party = safe_call(function() return memory:GetParty() end)
    local entity = safe_call(function() return memory:GetEntity() end)
    local index = party and party.GetMemberTargetIndex and safe_call(function()
        return party:GetMemberTargetIndex(0)
    end) or nil
    if entity == nil or entity.GetStatus == nil or tonumber(index) == nil then return nil end
    return tonumber(safe_call(function() return entity:GetStatus(index) end))
end

local function tracked_inventory_names(wanted)
    if type(wanted) ~= "table" or #wanted == 0 then return {} end
    local memory = memory_manager()
    local inventory = memory and memory.GetInventory and safe_call(function() return memory:GetInventory() end) or nil
    local resources = AshitaCore and AshitaCore.GetResourceManager and safe_call(function()
        return AshitaCore:GetResourceManager()
    end) or nil
    if inventory == nil or resources == nil then return {} end
    local wanted_set, found = {}, {}
    for _, name in ipairs(wanted) do wanted_set[normalized(name)] = tostring(name) end
    local maximum = tonumber(safe_call(function() return inventory:GetContainerCountMax(0) end)) or 0
    for index = 1, maximum do
        local item = safe_call(function() return inventory:GetContainerItem(0, index) end)
        local id = tonumber(item and (item.Id or item.id)) or 0
        if id > 0 then
            local resource = safe_call(function() return resources:GetItemById(id) end)
            local key = normalized(resource and (resource.Name or resource.name or resource.LogName or resource.log_name))
            if wanted_set[key] ~= nil then found[#found + 1] = wanted_set[key] end
        end
    end
    return found
end

local function key_item_id(resources, name)
    local key = normalized(name)
    if key_item_id_cache[key] ~= nil then return key_item_id_cache[key] or nil end
    for id = 0, 4096 do
        local label = safe_call(function() return resources:GetString("keyitems.names", id) end)
        if normalized(label) == key then key_item_id_cache[key] = id return id end
    end
    key_item_id_cache[key] = false
    return nil
end

local function tracked_key_item_names(wanted)
    if type(wanted) ~= "table" or #wanted == 0 then return {} end
    local memory = memory_manager()
    local player = memory and memory.GetPlayer and safe_call(function() return memory:GetPlayer() end) or nil
    local resources = AshitaCore and AshitaCore.GetResourceManager and safe_call(function()
        return AshitaCore:GetResourceManager()
    end) or nil
    if player == nil or player.HasKeyItem == nil or resources == nil then return {} end
    local found = {}
    for _, name in ipairs(wanted) do
        local id = key_item_id(resources, name)
        local owned = id ~= nil and safe_call(function() return player:HasKeyItem(id) end) or false
        if owned == true or owned == 1 then found[#found + 1] = name end
    end
    return found
end

local function read_player_entity_position()
    if GetPlayerEntity == nil then
        return nil, nil
    end
    local entity = safe_call(function()
        return GetPlayerEntity()
    end)
    local position = entity and entity.Movement and entity.Movement.LocalPosition or nil
    if position == nil then
        return nil, nil
    end
    return oddq_position(position), oddq_heading(
        position.Yaw or position.yaw or position.Heading or position.heading
    )
end

-- Passive fallback for Ashita builds where GetPlayerEntity is unavailable.
-- GetMemberTargetIndex(0) resolves the local party member's entity index; this
-- code only reads coordinates and never changes the player's selected target.
local function read_memory_position()
    local memory = memory_manager()
    if memory == nil or memory.GetParty == nil or memory.GetEntity == nil then
        return nil, nil
    end
    local party = safe_call(function() return memory:GetParty() end)
    local entity = safe_call(function() return memory:GetEntity() end)
    if party == nil or entity == nil or party.GetMemberTargetIndex == nil then
        return nil, nil
    end
    local index = tonumber(safe_call(function()
        return party:GetMemberTargetIndex(0)
    end))
    if index == nil or index <= 0
        or entity.GetLocalPositionX == nil
        or entity.GetLocalPositionY == nil
        or entity.GetLocalPositionZ == nil then
        return nil, nil
    end
    return oddq_position({
        x = safe_call(function() return entity:GetLocalPositionX(index) end),
        y = safe_call(function() return entity:GetLocalPositionY(index) end),
        z = safe_call(function() return entity:GetLocalPositionZ(index) end),
    }), nil
end

function player_state.current_live_context(fallback)
    fallback = type(fallback) == "table" and fallback or {}
    local position, heading = read_player_entity_position()
    if position == nil then
        position, heading = read_memory_position()
    end
    local fallback_position = copied_position(fallback.current_position)
    local position_available = position ~= nil or fallback_position ~= nil
    local mounted = read_mounted()
    if mounted == nil and type(fallback.is_mounted) == "boolean" then
        mounted = fallback.is_mounted
    end

    local result = {
        current_zone_id = read_zone_id() or tonumber(fallback.current_zone_id) or 0,
        current_position = position or fallback_position,
        current_position_available = position_available,
        current_heading_yaw = heading
            or fallback.current_heading_yaw
            or fallback.current_yaw
            or fallback.yaw,
        current_map_id = fallback.current_map_id or fallback.map_id or fallback.map_index or fallback.map_page,
        current_map_label = fallback.current_map_label
            or fallback.current_map_name
            or fallback.map_label
            or fallback.map_name
            or fallback.map_floor,
        level = read_level() or tonumber(fallback.level or fallback.current_level),
        is_mounted = mounted,
        in_cutscene = read_status() == CUTSCENE_STATUS_ID,
        cutscene_event_id = fallback.cutscene_event_id,
        cutscene_zone_id = fallback.cutscene_zone_id,
    }
    if type(fallback.scan_item_names) == "table" and #fallback.scan_item_names > 0 then
        result.items = tracked_inventory_names(fallback.scan_item_names)
    end
    if type(fallback.scan_key_item_names) == "table" and #fallback.scan_key_item_names > 0 then
        result.key_items = tracked_key_item_names(fallback.scan_key_item_names)
    end
    return result
end

return player_state
