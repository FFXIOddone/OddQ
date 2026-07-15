local mission_state = {}

local SANDORIA_NATION_ID = 0
local SANDORIA_MISSION_LOG_ID = 0
local SANDORIA_RANK1_MISSION_ID = 0
local NONE_MISSION_ID = 65535
local ORCISH_AXE_ITEM_ID = 16656
local SANDORIA_RANK1_QUEST_ID = "catseyexi.mission.san_doria_1_1"
local SANDORIA_RANK1_LEGACY_QUEST_ID = "catseyexi.mission.sandoria_rank1"

mission_state.constants = {
    SANDORIA_NATION_ID = SANDORIA_NATION_ID,
    SANDORIA_MISSION_LOG_ID = SANDORIA_MISSION_LOG_ID,
    SANDORIA_RANK1_MISSION_ID = SANDORIA_RANK1_MISSION_ID,
    NONE_MISSION_ID = NONE_MISSION_ID,
    ORCISH_AXE_ITEM_ID = ORCISH_AXE_ITEM_ID,
    SANDORIA_RANK1_QUEST_ID = SANDORIA_RANK1_QUEST_ID,
    SANDORIA_RANK1_LEGACY_QUEST_ID = SANDORIA_RANK1_LEGACY_QUEST_ID,
}

mission_state.state = {
    current_missions_by_log = {},
    last_packet = nil,
    dirty = false,
}

local function safe_call(callback)
    local ok, value = pcall(callback)
    if ok then
        return value
    end
    return nil
end

local function read_member(object, key)
    if object == nil then
        return nil
    end

    return safe_call(function()
        return object[key]
    end)
end

local function to_number(value)
    if value == nil then
        return nil
    end
    return tonumber(value)
end

local function call_method(object, method_name, ...)
    local method = object and object[method_name] or nil
    if type(method) ~= "function" then
        return nil
    end

    local args = { ... }
    return safe_call(function()
        return method(object, unpack(args))
    end)
end

local function memory_manager()
    if AshitaCore == nil or AshitaCore.GetMemoryManager == nil then
        return nil
    end

    return safe_call(function()
        return AshitaCore:GetMemoryManager()
    end)
end

local function inventory_object()
    local memory = memory_manager()
    if memory == nil or memory.GetInventory == nil then
        return nil
    end

    return safe_call(function()
        return memory:GetInventory()
    end)
end

local function read_item_field(item, ...)
    for _, key in ipairs({ ... }) do
        local value = read_member(item, key)
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

local function read_inventory_item_count(item_id)
    local inventory = inventory_object()
    if inventory == nil then
        return 0
    end

    -- Mission hand-ins require the item to be in the active inventory container.
    local container = 0
    local max_count = to_number(call_method(inventory, "GetContainerCountMax", container)) or 0
    local total = 0

    for index = 0, max_count, 1 do
        local item = read_container_item(inventory, container, index)
        local id = to_number(read_item_field(item, "Id", "id", "ItemId", "item_id"))
        if id == item_id then
            local count = to_number(read_item_field(item, "Count", "count", "Quantity", "quantity")) or 1
            if count <= 0 then
                count = 1
            end
            total = total + count
        end
    end

    return total
end

local function read_player_profile()
    local memory = memory_manager()
    if memory == nil or memory.GetPlayer == nil then
        return {}
    end

    local player = safe_call(function()
        return memory:GetPlayer()
    end)
    if player == nil then
        return {}
    end

    return {
        nation = to_number(call_method(player, "GetNation")),
        rank = to_number(call_method(player, "GetRank")),
        rank_points = to_number(call_method(player, "GetRankPoints")),
    }
end

mission_state.read_player_profile = read_player_profile

local function packet_id_matches(packet_id)
    return packet_id == 0x056 or packet_id == 86 or packet_id == "0x056" or packet_id == "86"
end

local function raw_packet_data(event)
    if event == nil then
        return nil
    end
    return event.data_modified or event.data
end

local function unpack_from_packet(fmt, data, offset)
    if struct == nil or struct.unpack == nil or data == nil then
        return nil
    end

    return safe_call(function()
        return struct.unpack(fmt, data, offset + 1)
    end)
end

local function parse_raw_mission_packet(event)
    local data = raw_packet_data(event)
    if data == nil then
        return nil
    end

    local port = to_number(unpack_from_packet("H", data, 0x24))
    if port ~= nil and port ~= 0xFFFF then
        return nil
    end

    local nation = to_number(unpack_from_packet("L", data, 0x04))
    local current_mission = to_number(unpack_from_packet("L", data, 0x08))
    if nation == nil or current_mission == nil then
        return nil
    end

    return {
        mission_log_id = nation,
        current_mission_id = current_mission,
        mission_status = 0,
        nation = nation,
        port = port or 0xFFFF,
    }
end

local function parse_table_mission_packet(packet)
    if type(packet) ~= "table" then
        return nil
    end

    local mission_log_id = to_number(packet.mission_log_id or packet.log_id or packet.Nation)
    local current_mission_id = to_number(packet.current_mission_id or packet.mission_id or packet.NationMission)
    if mission_log_id == nil or current_mission_id == nil then
        return nil
    end

    return {
        mission_log_id = mission_log_id,
        current_mission_id = current_mission_id,
        mission_status = to_number(packet.mission_status or packet.status) or 0,
        rank = to_number(packet.rank),
        nation = to_number(packet.nation or packet.Nation or mission_log_id),
        port = to_number(packet.port or packet.Port) or 0xFFFF,
    }
end

local function parse_mission_packet(packet)
    return parse_table_mission_packet(packet) or parse_raw_mission_packet(packet)
end

function mission_state.reset()
    mission_state.state.current_missions_by_log = {}
    mission_state.state.last_packet = nil
    mission_state.state.dirty = false
end

function mission_state.observe_packet(packet_id, packet)
    if not packet_id_matches(packet_id) then
        return nil
    end

    local parsed = parse_mission_packet(packet)
    if parsed == nil or parsed.port ~= 0xFFFF then
        return nil
    end

    local previous = mission_state.state.current_missions_by_log[parsed.mission_log_id]
    mission_state.state.current_missions_by_log[parsed.mission_log_id] = parsed.current_mission_id
    mission_state.state.last_packet = parsed
    if previous ~= parsed.current_mission_id then
        mission_state.state.dirty = true
    end
    return parsed
end

function mission_state.consume_dirty()
    if mission_state.state.dirty ~= true then
        return false
    end
    mission_state.state.dirty = false
    return true
end

local function canonical_sandoria_rank1_id(quest_id)
    if quest_id == SANDORIA_RANK1_QUEST_ID or quest_id == SANDORIA_RANK1_LEGACY_QUEST_ID then
        return SANDORIA_RANK1_QUEST_ID
    end
    return nil
end

local function detection(step, confidence, source, reason)
    return {
        mission_key = "sandoria_rank1",
        mission_name = "San d'Oria 1-1",
        quest_id = SANDORIA_RANK1_QUEST_ID,
        step = step,
        confidence = confidence,
        source = source,
        reason = reason,
    }
end

function mission_state.detect_completion(quest_id)
    local canonical_id = canonical_sandoria_rank1_id(quest_id)
    if canonical_id == nil then
        return nil
    end

    local current = mission_state.state.current_missions_by_log[SANDORIA_MISSION_LOG_ID]
    if current == nil then
        return nil
    end
    if current ~= NONE_MISSION_ID and current <= SANDORIA_RANK1_MISSION_ID then
        return nil
    end

    return {
        mission_key = "sandoria_rank1",
        quest_id = canonical_id,
        completed_quest_id = canonical_id,
        confidence = "mission_packet",
        source = "mission_packet_0x056",
        reason = "0x056 shows Sandy 1-1 is no longer the active nation mission",
    }
end

function mission_state.detect()
    local profile = read_player_profile()
    local last_packet = mission_state.state.last_packet or {}
    local nation = profile.nation or last_packet.nation
    local rank = profile.rank or last_packet.rank
    if nation ~= SANDORIA_NATION_ID then
        return nil
    end

    local current = mission_state.state.current_missions_by_log[SANDORIA_MISSION_LOG_ID]
    if current ~= nil then
        if current == SANDORIA_RANK1_MISSION_ID then
            if read_inventory_item_count(ORCISH_AXE_ITEM_ID) > 0 then
                return detection(
                    "turnin",
                    "mission_packet_inventory",
                    "mission_packet_0x056",
                    "0x056 shows Sandy 1-1 active and Orcish Axe is in inventory"
                )
            end

            return detection(
                "axe",
                "mission_packet",
                "mission_packet_0x056",
                "0x056 shows Sandy 1-1 active"
            )
        end

        if current == NONE_MISSION_ID or current > SANDORIA_RANK1_MISSION_ID then
            return nil
        end
    end

    if rank == 1 then
        return detection(
            "start",
            "rank_nation_fallback",
            "player_memory",
            "player memory shows San d'Oria rank 1; no mission packet has been observed"
        )
    end

    return nil
end

-- ODD_PACKET_READ: 0x056 incoming mission state detection reads nation and current nation mission only.
-- ODD_SECURITY_NOTE: mission_state is read-only; it does not write fields, block packets, create packets, target, trade, move, or read chat.

return mission_state
