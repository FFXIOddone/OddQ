local route_test = {}

local guidance_cursor = require("guidance_cursor")

local function current_zone_id(live_context)
    local live = live_context or {}
    return tonumber(live.current_zone_id or live.zone_id or live.zone)
end

local function completion_zone_id(route)
    return tonumber((route or {}).completion_zone_id or ((route or {}).completion or {}).zone_id)
end

local function completion_success(route)
    return tostring((route or {}).completion_success or ((route or {}).completion or {}).success or "")
end

local function event_with_defaults(event)
    event.evidence_type = "route_test_progress"
    event.manual_result_claimed = false
    event.route_quality_claimed = false
    return event
end

local function copy_position(position)
    if type(position) ~= "table" then
        return nil
    end
    return {
        x = tonumber(position.x or position.X) or 0,
        y = tonumber(position.y or position.Y) or 0,
        z = tonumber(position.z or position.Z or position.y or position.Y) or 0,
    }
end

local function segment_target(segment)
    if type(segment) ~= "table" then
        return nil
    end
    local positions = segment.positions or {}
    if #positions > 0 then
        return copy_position(positions[#positions])
    end
    if type(segment.target_position) == "table" then
        return copy_position(segment.target_position)
    end
    return nil
end

local function planar_distance(a, b)
    local dx = b.x - a.x
    local dz = b.z - a.z
    return math.sqrt((dx * dx) + (dz * dz))
end

local function route_arrival_radius_floor(route)
    local value = tonumber((route or {}).arrival_radius_floor or (route or {}).waypoint_radius_floor)
    if value == nil or value < 0 then
        return 0
    end
    return value
end

local function segment_radius(route, segment)
    if type(segment) ~= "table" then
        return 0
    end
    local radius = tonumber(segment.arrival_radius or segment.radius) or 0
    if radius <= 0 then
        return 0
    end
    local floor = route_arrival_radius_floor(route)
    if floor > radius then
        return floor
    end
    return radius
end

local function segment_reached(route, segment, live_context)
    if type(segment) ~= "table" or segment.type ~= "walk" then
        return false
    end
    local radius = segment_radius(route, segment)
    if radius <= 0 then
        return false
    end
    local target = segment_target(segment)
    local current = copy_position((live_context or {}).current_position)
    if target == nil or current == nil then
        return false
    end
    return planar_distance(current, target) <= radius
end

local function segment_waypoint_id(segment, index)
    if segment == nil then
        return "segment_" .. tostring(index)
    end
    return tostring(segment.to or segment.destination_label or ("segment_" .. tostring(index)))
end

local function segment_waypoint_label(segment, index)
    if segment == nil then
        return "Segment " .. tostring(index)
    end
    return tostring(segment.destination_label or segment.to or ("Segment " .. tostring(index)))
end

local function count_passed(state)
    local total = 0
    for _, passed in pairs(state.passed_segments or {}) do
        if passed == true then
            total = total + 1
        end
    end
    return total
end

local function count_walk_segments(route)
    local total = 0
    for _, segment in ipairs((route or {}).segments or {}) do
        if type(segment) == "table" and segment.type == "walk" then
            total = total + 1
        end
    end
    return total
end

local function count_skipped(state)
    local total = 0
    for _, skipped in pairs(state.skipped_segments or {}) do
        if skipped == true then
            total = total + 1
        end
    end
    return total
end

local function first_walk_index(route)
    for index, segment in ipairs((route or {}).segments or {}) do
        if type(segment) == "table" and segment.type == "walk" then
            return index
        end
    end
    return 1
end

local function last_walk_index(route)
    local last = nil
    for index, segment in ipairs((route or {}).segments or {}) do
        if type(segment) == "table" and segment.type == "walk" then
            last = index
        end
    end
    return last
end

local function mark_passed(state, route, index, events)
    local segment = ((route or {}).segments or {})[index]
    if segment == nil or segment.type ~= "walk" or state.passed_segments[index] == true then
        return
    end

    local recovered_from_skip = state.skipped_segments[index] == true
    state.passed_segments[index] = true
    state.skipped_segments[index] = nil
    table.insert(events, event_with_defaults({
        event = "route_waypoint_passed",
        route_id = state.route_id,
        segment_index = index,
        waypoint_id = segment_waypoint_id(segment, index),
        waypoint_label = segment_waypoint_label(segment, index),
        zone_id = tonumber(segment.zone_id),
        recovered_from_skip = recovered_from_skip,
    }))
end

local function mark_skipped(state, route, index, reason, events)
    local segment = ((route or {}).segments or {})[index]
    if segment == nil or segment.type ~= "walk" then
        return
    end
    if state.passed_segments[index] == true or state.skipped_segments[index] == true then
        return
    end

    state.skipped_segments[index] = true
    table.insert(events, event_with_defaults({
        event = "route_waypoint_skipped",
        route_id = state.route_id,
        segment_index = index,
        waypoint_id = segment_waypoint_id(segment, index),
        waypoint_label = segment_waypoint_label(segment, index),
        zone_id = tonumber(segment.zone_id),
        skip_reason = reason or "cursor_rebased",
    }))
end

function route_test.new_state()
    return {
        active = false,
        route_id = nil,
        last_zone_id = nil,
        last_segment_index = 1,
        passed_segments = {},
        skipped_segments = {},
        lock_start_until_first_pass = false,
        completion_observed = false,
    }
end

function route_test.reset(state)
    state.active = false
    state.route_id = nil
    state.last_zone_id = nil
    state.last_segment_index = 1
    state.passed_segments = {}
    state.skipped_segments = {}
    state.lock_start_until_first_pass = false
    state.completion_observed = false
end

function route_test.is_active(state)
    return state ~= nil and state.active == true
end

function route_test.start(state, route, live_context, options)
    options = options or {}
    route_test.reset(state)
    state.active = true
    state.route_id = tostring((route or {}).route_id or "")
    state.last_zone_id = current_zone_id(live_context)
    state.last_segment_index = 1
    state.lock_start_until_first_pass = options.from_start == true

    return {
        event_with_defaults({
            event = "route_test_start",
            route_id = state.route_id,
            start_zone_id = state.last_zone_id,
            completion_zone_id = completion_zone_id(route),
            note = "private-server route-test progress only; route quality still requires explicit ok/fail",
        }),
    }
end

function route_test.update(state, route, active_segment_index, live_context)
    if not route_test.is_active(state) then
        return active_segment_index, {}
    end

    local resolved = guidance_cursor.resolve_segment_state(route, active_segment_index, live_context)
    local next_index = resolved.index
    local events = {}
    local zone_id = current_zone_id(live_context)
    local segments = (route or {}).segments or {}

    if state.last_zone_id ~= nil and zone_id ~= nil and zone_id ~= state.last_zone_id then
        table.insert(events, event_with_defaults({
            event = "route_zone_changed",
            route_id = state.route_id,
            from_zone_id = state.last_zone_id,
            to_zone_id = zone_id,
        }))
    end

    if state.lock_start_until_first_pass == true then
        local first_index = first_walk_index(route)
        local first_segment = segments[first_index]
        if segment_reached(route, first_segment, live_context) then
            mark_passed(state, route, first_index, events)
            state.lock_start_until_first_pass = false
            state.last_segment_index = first_index + 1
            if zone_id ~= nil then
                state.last_zone_id = zone_id
            end
            return state.last_segment_index, events
        end

        state.last_segment_index = first_index
        if zone_id ~= nil then
            state.last_zone_id = zone_id
        end
        return first_index, events
    end

    for index, segment in ipairs(segments) do
        if zone_id ~= nil and tonumber(segment.zone_id) == zone_id and segment_reached(route, segment, live_context) then
            mark_passed(state, route, index, events)
        end
    end

    if next_index > state.last_segment_index and resolved.resolution == "advanced" then
        for index = state.last_segment_index, next_index - 1 do
            mark_passed(state, route, index, events)
        end
    elseif next_index > state.last_segment_index and (resolved.resolution == "nearest_forward" or resolved.resolution == "zone_match") then
        for index = state.last_segment_index, next_index - 1 do
            mark_skipped(state, route, index, resolved.resolution, events)
        end
    end

    local completion_zone = completion_zone_id(route)
    local completion_mode = completion_success(route)
    if completion_mode == "final_waypoint_reached" then
        local final_index = last_walk_index(route)
        if final_index ~= nil
            and state.passed_segments[final_index] == true
            and (completion_zone == nil or zone_id == completion_zone)
            and state.completion_observed ~= true then
            state.completion_observed = true
            table.insert(events, event_with_defaults({
                event = "route_completion_observed",
                route_id = state.route_id,
                completion_zone_id = completion_zone,
                completion_reason = "final_waypoint_reached",
            }))
        end
    elseif completion_zone ~= nil and zone_id == completion_zone and state.completion_observed ~= true then
        state.completion_observed = true
        table.insert(events, event_with_defaults({
            event = "route_completion_observed",
            route_id = state.route_id,
            completion_zone_id = completion_zone,
            completion_reason = "zone_changed",
        }))
    end

    if zone_id ~= nil then
        state.last_zone_id = zone_id
    end
    if next_index > state.last_segment_index then
        state.last_segment_index = next_index
    end

    return next_index, events
end

function route_test.status_event(state, route)
    local total = count_walk_segments(route)
    local passed = count_passed(state)
    local skipped = count_skipped(state)
    local remaining = total - passed - skipped
    if remaining < 0 then
        remaining = 0
    end

    return event_with_defaults({
        event = "route_test_status",
        route_id = state and state.route_id or "",
        active = route_test.is_active(state),
        passed_count = passed,
        skipped_count = skipped,
        remaining_count = remaining,
        completion_observed = state ~= nil and state.completion_observed == true,
    })
end

function route_test.status(state, route)
    if not route_test.is_active(state) then
        return "route test inactive"
    end

    local completion = state.completion_observed and "complete" or "in progress"
    local status_event = route_test.status_event(state, route)
    return "route test active: " .. tostring(state.route_id)
        .. ", passed=" .. tostring(status_event.passed_count)
        .. ", skipped=" .. tostring(status_event.skipped_count)
        .. ", remaining=" .. tostring(status_event.remaining_count)
        .. ", zone=" .. tostring(state.last_zone_id or "?")
        .. ", " .. completion
end

return route_test
