local readers = {}

readers.manifest = {
    {
        packet_id = "0x034",
        direction = "incoming",
        purpose = "quest state detection",
        reader = "quest_state_event",
        fields_read = { "event_id", "zone_id", "quest_id" },
        fields_modified = {},
        mutates_packet = false,
        evidence = "tests/packet_replay/quest_state_event_034.json",
    },
    {
        packet_id = "0x056",
        direction = "incoming",
        purpose = "mission state detection",
        reader = "mission_state_event",
        fields_read = { "mission_log_id", "current_mission_id", "mission_status", "rank", "nation" },
        fields_modified = {},
        mutates_packet = false,
        evidence = "tests/packet_replay/mission_state_event_056.json",
    },
}

local function read_declared_fields(packet, fields)
    local observed = {}
    if packet == nil then
        return observed
    end

    for _, field in ipairs(fields) do
        observed[field] = packet[field]
    end

    return observed
end

function readers.quest_state_event(packet)
    return read_declared_fields(packet, readers.manifest[1].fields_read)
end

function readers.mission_state_event(packet)
    return read_declared_fields(packet, readers.manifest[2].fields_read)
end

function readers.observe(packet_id, packet)
    if packet_id == 0x034 or packet_id == "0x034" then
        return readers.quest_state_event(packet)
    end
    if packet_id == 0x056 or packet_id == "0x056" then
        return readers.mission_state_event(packet)
    end

    return nil
end

-- ODD_PACKET_READ: 0x034 incoming quest state detection reads event_id, zone_id, quest_id.
-- ODD_PACKET_READ: 0x056 incoming mission state detection reads mission_log_id, current_mission_id, mission_status, rank, nation.
-- ODD_SECURITY_NOTE: packet_state readers return copied fields only; they do not write fields, block packets, create packets, target, trade, move, or read chat.

return readers
