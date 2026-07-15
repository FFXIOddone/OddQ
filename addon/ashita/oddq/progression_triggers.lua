local packet_readers = require("packet_state/readers")

local progression_triggers = {}

local function copy_list(values)
    local result = {}
    for index, value in ipairs(values or {}) do
        result[index] = value
    end
    return result
end

local function append_unique(values, value)
    if type(value) ~= "string" or value == "" then
        return
    end
    for _, existing in ipairs(values) do
        if existing == value then
            return
        end
    end
    table.insert(values, value)
end

local function set_from_list(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        if type(value) == "string" and value ~= "" then
            result[value] = true
        end
    end
    return result
end

local function sorted_set_delta(current, previous)
    local result = {}
    for value, present in pairs(current or {}) do
        if present == true and (previous or {})[value] ~= true then
            table.insert(result, value)
        end
    end
    table.sort(result)
    return result
end

local function map_value(live)
    live = live or {}
    return live.current_map_id or live.map_id or live.map_index or live.map_page
        or live.current_map_label or live.current_map_name or live.map_label or live.map_name or live.map_floor
end

local function known_items(live)
    live = live or {}
    local values = {}
    for _, value in ipairs(live.items or {}) do
        append_unique(values, value)
    end
    for _, value in ipairs(live.known_items or {}) do
        append_unique(values, value)
    end
    for _, value in ipairs(((live.known_transport_flags or {}).items) or {}) do
        append_unique(values, value)
    end
    table.sort(values)
    return values
end

local function snapshot(live)
    live = live or {}
    return {
        zone_id = tonumber(live.current_zone_id or live.zone_id or live.zone),
        map_value = map_value(live),
        key_items = set_from_list(live.key_items),
        items = set_from_list(known_items(live)),
        completed_quests = set_from_list(live.completed_quests),
        completed_missions = set_from_list(live.completed_missions),
    }
end

local function progress_event(name, fields)
    fields = fields or {}
    fields.event = name
    fields.evidence_type = "objective_progress_recon"
    fields.manual_result_claimed = false
    fields.route_quality_claimed = false
    fields.refresh_pointer = true
    return fields
end

local function append_events_for_delta(events, event_name, field_name, current, previous)
    for _, value in ipairs(sorted_set_delta(current, previous)) do
        local fields = {}
        fields[field_name] = value
        table.insert(events, progress_event(event_name, fields))
    end
end

local function packet_event(packet_id, observed)
    observed = observed or {}
    if packet_id == 0x034 or packet_id == "0x034" then
        return progress_event("quest_packet_observed", {
            packet_id = "0x034",
            event_id = observed.event_id,
            zone_id = observed.zone_id,
            quest_id = observed.quest_id,
        })
    end
    if packet_id == 0x056 or packet_id == "0x056" then
        return progress_event("mission_packet_observed", {
            packet_id = "0x056",
            mission_log_id = observed.mission_log_id,
            current_mission_id = observed.current_mission_id,
            mission_status = observed.mission_status,
            nation = observed.nation,
        })
    end
    return nil
end

function progression_triggers.new_state()
    return {
        seeded = false,
        last_snapshot = nil,
        pending_events = {},
    }
end

function progression_triggers.observe_live(state, live)
    state = state or progression_triggers.new_state()
    local current = snapshot(live)
    if state.seeded ~= true then
        state.seeded = true
        state.last_snapshot = current
        return {}
    end

    local previous = state.last_snapshot or snapshot({})
    local events = {}

    if previous.zone_id ~= nil and current.zone_id ~= nil and previous.zone_id ~= current.zone_id then
        table.insert(events, progress_event("zone_changed", {
            from_zone_id = previous.zone_id,
            to_zone_id = current.zone_id,
        }))
    end

    if previous.map_value ~= nil and current.map_value ~= nil and previous.map_value ~= current.map_value then
        table.insert(events, progress_event("map_changed", {
            from_map = previous.map_value,
            to_map = current.map_value,
        }))
    end

    append_events_for_delta(events, "key_item_gained", "key_item_name", current.key_items, previous.key_items)
    append_events_for_delta(events, "key_item_lost", "key_item_name", previous.key_items, current.key_items)
    append_events_for_delta(events, "item_gained", "item_name", current.items, previous.items)
    append_events_for_delta(events, "item_lost", "item_name", previous.items, current.items)
    append_events_for_delta(events, "quest_completed", "quest_id", current.completed_quests, previous.completed_quests)
    append_events_for_delta(events, "mission_completed", "mission_id", current.completed_missions, previous.completed_missions)

    state.last_snapshot = current
    return events
end

function progression_triggers.observe_packet(state, packet_id, packet)
    state = state or progression_triggers.new_state()
    local observed = packet_readers.observe(packet_id, packet)
    if observed == nil then
        return {}
    end

    local event = packet_event(packet_id, observed)
    if event == nil then
        return {}
    end

    state.pending_events = state.pending_events or {}
    table.insert(state.pending_events, event)
    return { event }
end

function progression_triggers.drain_pending_events(state)
    if state == nil or type(state.pending_events) ~= "table" or #state.pending_events == 0 then
        return {}
    end
    local events = copy_list(state.pending_events)
    state.pending_events = {}
    return events
end

function progression_triggers.should_refresh_pointer(events)
    for _, event in ipairs(events or {}) do
        if type(event) == "table" and event.refresh_pointer == true then
            return true
        end
    end
    return false
end

-- ODD_PACKET_READ: observes copied 0x034/0x056 packet fields through packet_state/readers only.
-- ODD_SECURITY_NOTE: progress triggers record local recon edges only; no packet mutation, targeting, trading, movement, or chat reading.

return progression_triggers
