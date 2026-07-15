local player_state = {}

local PI = math.pi
local TWO_PI = PI * 2
local KEY_ITEM_SCAN_MAX_ID = 4096
local KEY_ITEM_SCAN_SECONDS = 5
local ITEM_SCAN_SECONDS = 2
local key_item_cache = {
    scanned_at = nil,
    names = {},
}
local item_cache = {
    scanned_at = nil,
    signature = "",
    names = {},
}

local function copy_list(values)
    local result = {}
    for index, value in ipairs(values or {}) do
        result[index] = value
    end
    return result
end

local function safe_call(callback)
    local ok, value = pcall(callback)
    if ok then
        return value
    end
    return nil
end

local function trim_null(value)
    if type(value) ~= "string" then
        return value
    end

    local index = value:find("\0", 1, true)
    if index ~= nil then
        return value:sub(1, index - 1)
    end
    return value
end

local function trim(value)
    local text = tostring(value or "")
    return text:match("^%s*(.-)%s*$") or ""
end

local function canonical_item_name(value)
    local text = trim(value):lower()
    text = text:gsub("%s+x%d+$", "")
    text = text:gsub("%s+", " ")
    return text
end

local function requested_item_index(names)
    local lookup = {}
    local ordered = {}
    for _, name in ipairs(names or {}) do
        if type(name) == "string" and trim(name) ~= "" then
            local canonical = canonical_item_name(name)
            if canonical ~= "" and lookup[canonical] == nil then
                lookup[canonical] = name
                table.insert(ordered, {
                    canonical = canonical,
                    name = name,
                })
            end
        end
    end
    return lookup, ordered
end

local function item_signature(ordered)
    local parts = {}
    for _, entry in ipairs(ordered or {}) do
        table.insert(parts, entry.canonical)
    end
    table.sort(parts)
    return table.concat(parts, "|")
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

local function ashita_yaw_to_oddq_heading(yaw)
    local raw = tonumber(yaw)
    if raw == nil then
        return nil
    end

    return normalize_angle(raw + (PI / 2))
end

local function ashita_position_to_oddq_position(position)
    if position == nil then
        return nil
    end

    return {
        x = tonumber(position.X or position.x) or 0,
        y = tonumber(position.Z or position.z) or 0,
        z = tonumber(position.Y or position.y) or 0,
    }
end

local function read_heading_from_position(position)
    if position == nil then
        return nil
    end

    return ashita_yaw_to_oddq_heading(position.Yaw or position.yaw or position.Heading or position.heading)
end

local function read_party()
    if AshitaCore == nil or AshitaCore.GetMemoryManager == nil then
        return nil
    end

    local memory = safe_call(function()
        return AshitaCore:GetMemoryManager()
    end)
    if memory == nil or memory.GetParty == nil then
        return nil
    end

    return safe_call(function()
        return memory:GetParty()
    end)
end

local function read_player()
    if AshitaCore == nil or AshitaCore.GetMemoryManager == nil then
        return nil
    end

    local memory = safe_call(function()
        return AshitaCore:GetMemoryManager()
    end)
    if memory == nil or memory.GetPlayer == nil then
        return nil
    end

    return safe_call(function()
        return memory:GetPlayer()
    end)
end

local function read_inventory()
    if AshitaCore == nil or AshitaCore.GetMemoryManager == nil then
        return nil
    end

    local memory = safe_call(function()
        return AshitaCore:GetMemoryManager()
    end)
    if memory == nil or memory.GetInventory == nil then
        return nil
    end

    return safe_call(function()
        return memory:GetInventory()
    end)
end

local function read_resource_string(paths, id)
    if AshitaCore == nil or AshitaCore.GetResourceManager == nil then
        return nil
    end

    local resources = safe_call(function()
        return AshitaCore:GetResourceManager()
    end)
    if resources == nil or resources.GetString == nil then
        return nil
    end

    for _, path in ipairs(paths or {}) do
        local value = safe_call(function()
            return resources:GetString(path, id)
        end)
        if type(value) == "string" and value ~= "" then
            return trim_null(value)
        end

        value = safe_call(function()
            return resources:GetString(path, id, 2)
        end)
        if type(value) == "string" and value ~= "" then
            return trim_null(value)
        end
    end

    return nil
end

local function read_live_zone_id()
    local party = read_party()
    if party == nil or party.GetMemberZone == nil then
        return nil
    end

    return tonumber(safe_call(function()
        return party:GetMemberZone(0)
    end))
end

local function read_live_level()
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

local function read_live_key_items()
    local player = read_player()
    if player == nil or player.HasKeyItem == nil then
        return nil
    end

    local now = os.clock()
    if key_item_cache.scanned_at ~= nil
        and (now - key_item_cache.scanned_at) < KEY_ITEM_SCAN_SECONDS then
        return copy_list(key_item_cache.names)
    end

    local names = {}
    for key_item_id = 0, KEY_ITEM_SCAN_MAX_ID, 1 do
        local owned = safe_call(function()
            return player:HasKeyItem(key_item_id)
        end)
        if owned == true or owned == 1 then
            local name = read_resource_string({ "keyitems.names" }, key_item_id)
                or ("KeyItem " .. tostring(key_item_id))
            table.insert(names, name)
        end
    end

    key_item_cache.scanned_at = now
    key_item_cache.names = names
    return copy_list(names)
end

local function read_item_field(item, ...)
    if item == nil then
        return nil
    end
    for _, key in ipairs({ ... }) do
        local value = safe_call(function()
            return item[key]
        end)
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function read_container_item(inventory, container, index)
    if inventory == nil or inventory.GetContainerItem == nil then
        return nil
    end

    return safe_call(function()
        return inventory:GetContainerItem(container, index)
    end)
end

local function read_live_inventory_item_names(requested_names)
    local lookup, ordered = requested_item_index(requested_names)
    if #ordered == 0 then
        return nil
    end

    local signature = item_signature(ordered)
    local now = os.clock()
    if item_cache.scanned_at ~= nil
        and item_cache.signature == signature
        and (now - item_cache.scanned_at) < ITEM_SCAN_SECONDS then
        return copy_list(item_cache.names)
    end

    local inventory = read_inventory()
    if inventory == nil then
        item_cache.scanned_at = now
        item_cache.signature = signature
        item_cache.names = {}
        return {}
    end

    local container = 0
    local max_count = 0
    if inventory.GetContainerCountMax ~= nil then
        max_count = tonumber(safe_call(function()
            return inventory:GetContainerCountMax(container)
        end)) or 0
    end

    local present = {}
    for index = 0, max_count, 1 do
        local item = read_container_item(inventory, container, index)
        local item_id = tonumber(read_item_field(item, "Id", "id", "ItemId", "item_id"))
        local count = tonumber(read_item_field(item, "Count", "count", "Quantity", "quantity")) or 0
        if item_id ~= nil and item_id > 0 and count > 0 then
            local name = read_resource_string({ "items.names" }, item_id)
            local canonical = canonical_item_name(name)
            if lookup[canonical] ~= nil then
                present[canonical] = true
            end
        end
    end

    local names = {}
    for _, entry in ipairs(ordered) do
        if present[entry.canonical] == true then
            table.insert(names, entry.name)
        end
    end

    item_cache.scanned_at = now
    item_cache.signature = signature
    item_cache.names = names
    return copy_list(names)
end

local function should_scan_key_items(options)
    return type(options) == "table" and options.scan_key_items == true
end

local function read_position_from_player_entity()
    if GetPlayerEntity == nil then
        return nil
    end

    local entity = safe_call(function()
        return GetPlayerEntity()
    end)
    local movement = entity and entity.Movement or nil
    local position = movement and movement.LocalPosition or nil
    if position == nil then
        return nil
    end

    return ashita_position_to_oddq_position(position), read_heading_from_position(position)
end

local function read_position_from_entity_manager()
    if AshitaCore == nil or AshitaCore.GetMemoryManager == nil then
        return nil
    end

    local memory = safe_call(function()
        return AshitaCore:GetMemoryManager()
    end)
    if memory == nil or memory.GetParty == nil or memory.GetEntity == nil then
        return nil
    end

    local party = safe_call(function()
        return memory:GetParty()
    end)
    local entity = safe_call(function()
        return memory:GetEntity()
    end)
    if party == nil or entity == nil or party.GetMemberTargetIndex == nil then
        return nil
    end

    local index = tonumber(safe_call(function()
        return party:GetMemberTargetIndex(0)
    end))
    if index == nil or index <= 0 then
        return nil
    end

    if entity.GetLocalPositionX == nil or entity.GetLocalPositionY == nil or entity.GetLocalPositionZ == nil then
        return nil
    end

    local position = {
        x = safe_call(function() return entity:GetLocalPositionX(index) end),
        y = safe_call(function() return entity:GetLocalPositionY(index) end),
        z = safe_call(function() return entity:GetLocalPositionZ(index) end),
    }

    return ashita_position_to_oddq_position(position), nil
end

local function copy_position(position)
    position = position or {}
    return {
        x = tonumber(position.x or position.X) or 0,
        y = tonumber(position.y or position.Y) or 0,
        z = tonumber(position.z or position.Z) or 0,
    }
end

function player_state.current_live_context(fallback, options)
    fallback = fallback or {}
    local live_position, live_heading = read_position_from_player_entity()
    if live_position == nil then
        live_position, live_heading = read_position_from_entity_manager()
    end
    local fallback_position = fallback.current_position or {}
    local key_items = nil
    if should_scan_key_items(options) then
        key_items = read_live_key_items()
    end
    local items = nil
    if type(options) == "table" then
        items = read_live_inventory_item_names(options.scan_item_names)
    end

    return {
        current_zone_id = read_live_zone_id() or fallback.current_zone_id or 0,
        current_position = live_position or copy_position(fallback_position),
        current_heading_yaw = live_heading or fallback.current_heading_yaw or fallback.current_yaw or fallback.yaw,
        current_map_id = fallback.current_map_id or fallback.map_id or fallback.map_index or fallback.map_page,
        current_map_label = fallback.current_map_label or fallback.current_map_name or fallback.map_label or fallback.map_name or fallback.map_floor,
        level = read_live_level() or fallback.level or fallback.current_level,
        key_items = key_items or copy_list(fallback.key_items),
        items = items or copy_list(fallback.items),
    }
end

function player_state.build(config, live)
    live = live or {}
    local position = live.current_position or {}
    local transport = live.known_transport_flags or {}
    local movement = live.movement_context or {}

    return {
        addon_version = live.addon_version or "0.1.0",
        server_profile = live.server_profile or "catseyexi",
        game_mode = live.game_mode or "CW",
        current_zone_id = live.current_zone_id or 0,
        current_position = {
            x = position.x or 0,
            y = position.y or 0,
            z = position.z or 0,
        },
        current_heading_yaw = live.current_heading_yaw or live.current_yaw or live.yaw,
        current_map_id = live.current_map_id or live.map_id or live.map_index or live.map_page,
        current_map_label = live.current_map_label or live.current_map_name or live.map_label or live.map_name or live.map_floor,
        level = tonumber(live.level) or 0,
        completed_quests = copy_list(live.completed_quests),
        completed_missions = copy_list(live.completed_missions),
        key_items = copy_list(live.key_items),
        enabled_modes = copy_list(live.enabled_modes),
        enabled_exp_camp_categories = copy_list(live.enabled_exp_camp_categories),
        target_objective_id = live.target_objective_id or "manual.none",
        known_unlocks_hash = live.known_unlocks_hash or "sha256:unknown",
        known_transport_flags = {
            home_points = copy_list(transport.home_points),
            survival_guides = copy_list(transport.survival_guides),
            outposts = copy_list(transport.outposts),
            teleport_crystals = copy_list(transport.teleport_crystals or transport.crystals),
            exp_guides = copy_list(transport.exp_guides),
            city_teleporters = copy_list(transport.city_teleporters),
            spells = copy_list(transport.spells),
            items = copy_list(live.items or transport.items),
            cooldowns = {
                warp_ring_seconds_remaining = tonumber((transport.cooldowns or {}).warp_ring_seconds_remaining) or 0,
                instant_warp_scroll_count = tonumber((transport.cooldowns or {}).instant_warp_scroll_count) or 0,
            },
        },
        movement_context = {
            has_movement_speed_buff = movement.has_movement_speed_buff == true,
            mount_available = movement.mount_available == true,
        },
        server_name = config and config.server_name or "catseyexi",
    }
end

return player_state
