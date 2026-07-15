local guidance_cursor = {}

local travel_advice = require("travel_advice")

local DEFAULT_OFF_ROUTE_DISTANCE = 45
local DEFAULT_NEAREST_FORWARD_HYSTERESIS = 0.5
local PI = math.pi
local TWO_PI = PI * 2

local zone_names_loaded, zone_names = pcall(require, "data/zone_names")
if not zone_names_loaded then
    zone_names = {}
end

local function is_blank(value)
    return value == nil or tostring(value) == ""
end

local function zone_display(zone_id)
    local normalized = tonumber(zone_id)
    if normalized ~= nil and zone_names[normalized] ~= nil then
        return tostring(zone_names[normalized]) .. " (" .. tostring(normalized) .. ")"
    end
    return tostring(zone_id or "?")
end

local function format_identifier(value)
    if is_blank(value) then
        return "Route target"
    end

    local text = tostring(value):gsub("_", " ")
    text = text:gsub("(%a)([%w']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)
    text = text:gsub("Hp(%d+)", "HP%1")
    return text
end

local function active_segment(route, index)
    local segments = route and route.segments or {}
    if #segments == 0 then
        return nil
    end
    index = tonumber(index) or 1
    if index < 1 then
        index = 1
    end
    if index > #segments then
        index = #segments
    end
    return segments[index], index, #segments
end

local function clamp_segment_index(route, index)
    local segments = route and route.segments or {}
    local count = #segments
    if count == 0 then
        return 1, count
    end

    index = tonumber(index) or 1
    if index < 1 then
        index = 1
    end
    if index > count then
        index = count
    end
    return index, count
end

local function copy_position(position)
    if type(position) ~= "table" then
        return nil
    end
    local raw_y = position.y or position.Y
    local raw_z = position.z or position.Z
    local has_y = raw_y ~= nil
    local has_z = raw_z ~= nil
    return {
        x = tonumber(position.x or position.X) or 0,
        y = tonumber(raw_y) or 0,
        z = tonumber(raw_z or raw_y) or 0,
        has_y = has_y,
        has_z = has_z,
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

local function segment_start(segment)
    if type(segment) ~= "table" then
        return nil
    end
    if type(segment.start_position) == "table" then
        return copy_position(segment.start_position)
    end
    if type(segment.from_position) == "table" then
        return copy_position(segment.from_position)
    end
    if type(segment.previous_position) == "table" then
        return copy_position(segment.previous_position)
    end
    return nil
end

local function segment_label(segment)
    if type(segment) ~= "table" then
        return "Route target"
    end
    if not is_blank(segment.destination_label) then
        return tostring(segment.destination_label)
    end
    return format_identifier(segment.to)
end

local function segment_destination_zone(segment)
    if type(segment) ~= "table" then
        return nil
    end
    return tonumber(segment.destination_zone_id or segment.transition_zone or segment.to)
end

local function first_nonblank(...)
    for _, value in ipairs({ ... }) do
        if not is_blank(value) then
            return tostring(value)
        end
    end
    return ""
end

local function normalize_map_label(value)
    if is_blank(value) then
        return ""
    end
    return tostring(value):lower():gsub("%s+", ""):gsub("#", "")
end

local function current_map_id(live)
    live = live or {}
    return tonumber(live.current_map_id or live.map_id or live.map_index or live.map_page)
end

local function current_map_label(live)
    live = live or {}
    return first_nonblank(
        live.current_map_label,
        live.current_map_name,
        live.map_label,
        live.map_name,
        live.map_floor
    )
end

local function segment_target_map_id(segment)
    if type(segment) ~= "table" then
        return nil
    end
    return tonumber(segment.target_map_id or segment.destination_map_id or segment.map_id or segment.map_index)
end

local function segment_target_map_label(segment)
    if type(segment) ~= "table" then
        return ""
    end
    return first_nonblank(
        segment.target_map_label,
        segment.target_map_name,
        segment.destination_map_label,
        segment.destination_map_name,
        segment.map_label,
        segment.map_name,
        segment.map_floor
    )
end

local function live_position(live_context)
    if type(live_context) == "table" and live_context.current_position_available == false then
        return nil
    end
    return copy_position((live_context or {}).current_position)
end

local function segment_travel_source(segment)
    if type(segment) ~= "table" then
        return {}
    end
    return {
        zone_id = tonumber(segment.zone_id or segment.destination_zone_id or segment.target_zone_id),
        target_map_label = segment_target_map_label(segment),
        map_grid = segment.map_grid or segment.destination_map_grid,
    }
end

local function segment_travel_summary(segment)
    return travel_advice.summary(segment_travel_source(segment))
end

local function segment_travel_path(segment)
    return travel_advice.path(segment_travel_source(segment))
end

local function segment_map_mismatch(segment, live)
    local target_id = segment_target_map_id(segment)
    local live_id = current_map_id(live)
    local target_label = segment_target_map_label(segment)
    local live_label = current_map_label(live)

    if target_id ~= nil and live_id ~= nil and target_id ~= live_id then
        return true, target_label, live_label
    end

    local normalized_target = normalize_map_label(target_label)
    local normalized_live = normalize_map_label(live_label)
    if normalized_target ~= "" and normalized_live ~= "" and normalized_target ~= normalized_live then
        return true, target_label, live_label
    end

    return false, target_label, live_label
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

local function planar_distance(a, b)
    local dx = b.x - a.x
    local dz = b.z - a.z
    return math.sqrt((dx * dx) + (dz * dz)), dx, dz
end

local function has_vertical_coordinate(position)
    return type(position) == "table" and position.has_y == true and position.has_z == true
end

local function spatial_distance(a, b)
    local horizontal_distance, dx, dz = planar_distance(a, b)
    if has_vertical_coordinate(a) and has_vertical_coordinate(b) then
        local dy = b.y - a.y
        return math.sqrt((dx * dx) + (dy * dy) + (dz * dz)), dx, dy, dz, horizontal_distance
    end
    return horizontal_distance, dx, nil, dz, horizontal_distance
end

local function line_distance(current, start_position, target)
    if current == nil or start_position == nil or target == nil then
        return nil
    end

    local dx = target.x - start_position.x
    local use_vertical = has_vertical_coordinate(current)
        and has_vertical_coordinate(start_position)
        and has_vertical_coordinate(target)
    local dy = use_vertical and (target.y - start_position.y) or 0
    local dz = target.z - start_position.z
    local length_squared = (dx * dx) + (dy * dy) + (dz * dz)
    if length_squared <= 0.000001 then
        local distance = spatial_distance(current, target)
        return distance
    end

    local progress = (((current.x - start_position.x) * dx)
        + ((use_vertical and (current.y - start_position.y) or 0) * dy)
        + ((current.z - start_position.z) * dz)) / length_squared
    if progress < 0 then
        progress = 0
    elseif progress > 1 then
        progress = 1
    end

    local nearest = {
        x = start_position.x + (dx * progress),
        y = start_position.y + (dy * progress),
        z = start_position.z + (dz * progress),
        has_y = use_vertical,
        has_z = true,
    }
    local distance = spatial_distance(current, nearest)
    return distance
end

local function distance_label(distance)
    if distance == nil then
        return ""
    end
    if distance >= 100 then
        return tostring(math.floor(distance + 0.5)) .. "y"
    end
    return string.format("%.1fy", distance)
end

local function vertical_label(dy)
    if dy == nil then
        return ""
    end
    if math.abs(dy) < 0.05 then
        return "Level"
    end
    if dy > 0 then
        return "Up " .. distance_label(math.abs(dy))
    end
    return "Down " .. distance_label(math.abs(dy))
end

local function atan2(y, x)
    if math.atan2 ~= nil then
        return math.atan2(y, x)
    end
    return math.atan(y, x)
end

local function elevation_angle_degrees(horizontal_distance, dy)
    if dy == nil or horizontal_distance == nil then
        return nil
    end
    return (atan2(dy, horizontal_distance) * 180.0) / PI
end

local function display_vertical_delta(axis_delta)
    if axis_delta == nil then
        return nil
    end
    -- Ashita's live vertical axis is inverted relative to the player-facing cue:
    -- lower raw Y means the target is higher on screen/in-world.
    return -axis_delta
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

local function live_heading_yaw(live_context)
    local live = live_context or {}
    return tonumber(live.current_heading_yaw or live.current_yaw or live.heading_yaw or live.yaw)
end

local function relative_direction(dx, dz, heading_yaw)
    local abs_x = math.abs(dx)
    local abs_z = math.abs(dz)
    if abs_x < 0.001 and abs_z < 0.001 then
        return "Here", "..."
    end

    if heading_yaw == nil then
        return nil, nil
    end

    local target_yaw = atan2(dx, dz)
    local relative = normalize_angle(target_yaw - heading_yaw)
    local abs_relative = math.abs(relative)

    if abs_relative <= (PI / 4) then
        return "Ahead", "^^^"
    end
    if abs_relative >= (PI * 3 / 4) then
        return "Behind", "vvv"
    end
    if relative > 0 then
        return "Right", ">>>"
    end
    return "Left", "<<<"
end

local function world_direction(dx, dz)
    local abs_x = math.abs(dx)
    local abs_z = math.abs(dz)
    if abs_x < 0.001 and abs_z < 0.001 then
        return "Here", "..."
    end

    local horizontal = dx >= 0 and "East" or "West"
    local vertical = dz >= 0 and "North" or "South"
    if abs_x >= abs_z * 1.2 then
        return horizontal, dx >= 0 and ">>>" or "<<<"
    end
    if abs_z >= abs_x * 1.2 then
        return vertical, dz >= 0 and "^^^" or "vvv"
    end

    if dz >= 0 and dx >= 0 then
        return "Northeast", "^>>"
    end
    if dz >= 0 and dx < 0 then
        return "Northwest", "<<^"
    end
    if dz < 0 and dx >= 0 then
        return "Southeast", "v>>"
    end
    return "Southwest", "<<v"
end

local function direction(dx, dz, heading_yaw)
    local label, symbol = relative_direction(dx, dz, heading_yaw)
    if label ~= nil and symbol ~= nil then
        return label, symbol
    end
    return world_direction(dx, dz)
end

local function pointer_vector(dx, dz, horizontal_distance, heading_yaw)
    if horizontal_distance == nil or horizontal_distance <= 0.000001 then
        return { x = 0.0, y = 0.0 }
    end

    if heading_yaw ~= nil then
        local target_yaw = atan2(dx, dz)
        local relative = normalize_angle(target_yaw - heading_yaw)
        return {
            x = math.sin(relative),
            y = -math.cos(relative),
        }
    end

    return {
        x = dx / horizontal_distance,
        y = -dz / horizontal_distance,
    }
end

local function pointer_vector_3d(dx, dy, dz, distance)
    if dy == nil or distance == nil or distance <= 0.000001 then
        return nil
    end
    return {
        x = dx / distance,
        y = dy / distance,
        z = dz / distance,
    }
end

local function segment_reached(route, segment, live_context)
    if type(segment) ~= "table" or segment.type == "zone_line" then
        return false
    end

    local radius = segment_radius(route, segment)
    if radius <= 0 then
        return false
    end

    local target = segment_target(segment)
    local current = live_position(live_context)
    if target == nil or current == nil then
        return false
    end

    local distance = spatial_distance(current, target)
    return distance <= radius
end

local function segment_distance(segment, current)
    if type(segment) ~= "table" or segment.type == "zone_line" then
        return nil
    end
    local target = segment_target(segment)
    if target == nil or current == nil then
        return nil
    end
    local distance = spatial_distance(current, target)
    return distance
end

local function segment_path_distance(segment, current)
    if type(segment) ~= "table" or segment.type == "zone_line" then
        return nil
    end
    local target = segment_target(segment)
    local start_position = segment_start(segment)
    return line_distance(current, start_position, target)
end

local function segment_zone_matches(segment, zone_id)
    return zone_id ~= nil and type(segment) == "table" and tonumber(segment.zone_id) == zone_id
end

local function route_off_route_distance(route)
    local value = tonumber((route or {}).off_route_distance or (route or {}).off_route_radius)
    if value == nil or value <= 0 then
        return DEFAULT_OFF_ROUTE_DISTANCE
    end
    return value
end

local function route_nearest_forward_hysteresis(route)
    local value = tonumber((route or {}).nearest_forward_hysteresis or (route or {}).rebase_hysteresis)
    if value == nil or value < 0 then
        return DEFAULT_NEAREST_FORWARD_HYSTERESIS
    end
    return value
end

local function nearest_forward_segment_index(route, segments, index, current_zone, current)
    if current_zone == nil or current == nil then
        return nil, nil, nil
    end

    local current_distance = segment_distance(segments[index], current)
    local best_index = nil
    local best_distance = nil
    local hysteresis = route_nearest_forward_hysteresis(route)

    for candidate = index, #segments do
        local candidate_segment = segments[candidate]
        if segment_zone_matches(candidate_segment, current_zone) then
            local distance = segment_distance(candidate_segment, current)
            if distance ~= nil and (best_distance == nil or distance < best_distance) then
                best_index = candidate
                best_distance = distance
            end
        end
    end

    if best_index ~= nil and best_index > index then
        if current_distance == nil or best_distance + hysteresis < current_distance then
            return best_index, best_distance, current_distance
        end
    end

    return nil, best_distance, current_distance
end

local function state_with_status(route, state, segment, current_zone, current)
    state.status_label = "on route"
    state.distance = segment_distance(segment, current)
    state.path_distance = segment_path_distance(segment, current)
    state.off_route_distance = state.path_distance or state.distance
    state.off_route_threshold = route_off_route_distance(route)
    if state.off_route_distance ~= nil and segment_zone_matches(segment, current_zone) then
        state.off_route = state.off_route_distance > state.off_route_threshold
    else
        state.off_route = false
    end

    if state.off_route == true then
        state.status_label = "off route; head to nearest point"
    elseif state.resolution == "nearest_forward" then
        state.status_label = "nearest route point"
    elseif state.resolution == "advanced" then
        state.status_label = "next route point"
    elseif state.resolution == "zone_match" then
        state.status_label = "current zone route point"
    elseif state.resolution == "zone_reached" then
        state.status_label = "zone reached; verify manually"
    end

    return state
end

function guidance_cursor.resolve_segment_state(route, active_segment_index, live_context)
    local segments = route and route.segments or {}
    local index, count = clamp_segment_index(route, active_segment_index)
    local state = {
        index = index,
        count = count,
        previous_index = index,
        resolution = "current",
        status_label = "on route",
        off_route = false,
    }
    if count == 0 then
        return state
    end

    local live = live_context or {}
    local current_zone = tonumber(live.current_zone_id or live.zone_id or live.zone)
    local current = live_position(live)

    if current_zone ~= nil then
        local segment = segments[index]
        local destination_zone = segment_destination_zone(segment)
        if segment ~= nil and segment.type == "zone_line" and destination_zone == current_zone then
            if index < count then
                state.index = index + 1
                state.resolution = "zone_reached"
                return state_with_status(route, state, segments[state.index], current_zone, current)
            end
            state.resolution = "zone_reached"
            return state_with_status(route, state, segment, current_zone, current)
        end

        if not segment_zone_matches(segment, current_zone) then
            for candidate = index + 1, count do
                local candidate_segment = segments[candidate]
                if segment_zone_matches(candidate_segment, current_zone) then
                    state.index = candidate
                    state.resolution = "zone_match"
                    return state_with_status(route, state, candidate_segment, current_zone, current)
                end
                local candidate_destination = segment_destination_zone(candidate_segment)
                if candidate_segment ~= nil and candidate_segment.type == "zone_line" and candidate_destination == current_zone then
                    if candidate < count then
                        state.index = candidate + 1
                        state.resolution = "zone_match"
                        return state_with_status(route, state, segments[state.index], current_zone, current)
                    end
                    state.index = candidate
                    state.resolution = "zone_match"
                    return state_with_status(route, state, candidate_segment, current_zone, current)
                end
            end

            for candidate = 1, count do
                local candidate_segment = segments[candidate]
                if segment_zone_matches(candidate_segment, current_zone) then
                    state.index = candidate
                    state.resolution = "zone_match"
                    return state_with_status(route, state, candidate_segment, current_zone, current)
                end
                local candidate_destination = segment_destination_zone(candidate_segment)
                if candidate_segment ~= nil and candidate_segment.type == "zone_line" and candidate_destination == current_zone then
                    if candidate < count then
                        state.index = candidate + 1
                        state.resolution = "zone_match"
                        return state_with_status(route, state, segments[state.index], current_zone, current)
                    end
                    state.index = candidate
                    state.resolution = "zone_match"
                    return state_with_status(route, state, candidate_segment, current_zone, current)
                end
            end
        end
    end

    local reached_index = nil
    local nearest_index = nearest_forward_segment_index(route, segments, index, current_zone, current)
    if nearest_index ~= nil then
        index = nearest_index
        state.index = index
        state.resolution = "nearest_forward"
    end

    for candidate = index, count do
        local candidate_segment = segments[candidate]
        if (current_zone == nil or segment_zone_matches(candidate_segment, current_zone)) and segment_reached(route, candidate_segment, live) then
            reached_index = candidate
        end
    end
    if reached_index ~= nil and reached_index >= index and reached_index < count then
        index = reached_index + 1
        state.index = index
        state.resolution = "advanced"
    end

    while index < count do
        local segment = segments[index]
        if segment == nil then
            break
        end

        if segment.type == "zone_line" then
            local destination_zone = segment_destination_zone(segment)
            if destination_zone ~= nil and current_zone == destination_zone then
                index = index + 1
                state.index = index
                state.resolution = "zone_reached"
            else
                break
            end
        elseif segment_reached(route, segment, live) then
            index = index + 1
            state.index = index
            state.resolution = "advanced"
        else
            break
        end
    end

    state.index = index
    return state_with_status(route, state, segments[index], current_zone, current)
end

function guidance_cursor.resolve_segment_index(route, active_segment_index, live_context)
    return guidance_cursor.resolve_segment_state(route, active_segment_index, live_context).index
end

function guidance_cursor.build(route, active_segment_index, live_context)
    local resolved = guidance_cursor.resolve_segment_state(route, active_segment_index, live_context)
    local segment, index, count = active_segment(route, resolved.index)
    if segment == nil then
        return {
            available = false,
            message = "No visual route target",
            direction_label = "",
            direction_symbol = "?",
            distance_label = "",
            status_label = "no visual route target",
        }
    end

    local label = segment_label(segment)
    local target = segment_target(segment)
    local live = live_context or {}
    local current = live_position(live)
    local current_zone = tonumber(live.current_zone_id or live.zone_id or live.zone)
    local target_zone = tonumber(segment.zone_id)
    local destination_zone = segment_destination_zone(segment)
    local map_mismatch, target_map_label, live_map_label = segment_map_mismatch(segment, live)

    if segment.type == "zone_line" and current_zone ~= nil and destination_zone ~= nil and current_zone == destination_zone then
        local travel_path = segment_travel_path(segment)
        return {
            available = true,
            label = label,
            segment_index = index,
            segment_count = count,
            zone_mismatch = false,
            route_complete = index >= count,
            target_zone_id = destination_zone,
            travel_path = travel_path,
            travel_summary = segment_travel_summary(segment),
            message = "Zone reached: " .. label,
            direction_label = "Confirm manually",
            direction_symbol = "...",
            distance_label = "",
            arrived = true,
            status_label = resolved.status_label,
            resolution = resolved.resolution,
        }
    end

    if current_zone ~= nil and target_zone ~= nil and current_zone ~= target_zone then
        local travel_path = segment_travel_path(segment)
        local message = "Wrong zone: " .. travel_advice.zone_name(target_zone)
        if travel_path ~= "" then
            message = "Wrong zone: " .. travel_path
        end
        return {
            available = true,
            label = label,
            segment_index = index,
            segment_count = count,
            zone_mismatch = true,
            target_zone_id = target_zone,
            travel_path = travel_path,
            travel_summary = segment_travel_summary(segment),
            message = message,
            direction_label = "Wrong zone",
            direction_symbol = "?",
            distance_label = "",
            status_label = "wrong zone",
            resolution = resolved.resolution,
        }
    end

    if map_mismatch == true then
        local target_map = target_map_label ~= "" and target_map_label or "the target map"
        local travel_path = segment_travel_path(segment)
        local zone_name = travel_advice.zone_name(target_zone)
        local message = "Wrong map: go to " .. target_map .. " for " .. label
        if zone_name ~= "" then
            message = "Wrong map: go to " .. target_map .. " in " .. zone_name .. " for " .. label
        end
        return {
            available = true,
            label = label,
            segment_index = index,
            segment_count = count,
            map_mismatch = true,
            target_map_label = target_map_label,
            current_map_label = live_map_label,
            target_zone_id = target_zone,
            travel_path = travel_path,
            travel_summary = segment_travel_summary(segment),
            message = message,
            direction_label = "Wrong map",
            direction_symbol = "?",
            distance_label = "",
            status_label = "wrong map",
            resolution = resolved.resolution,
        }
    end

    if target == nil or current == nil then
        local travel_path = segment_travel_path(segment)
        return {
            available = true,
            label = label,
            segment_index = index,
            segment_count = count,
            checkpoint_only = true,
            target_map_label = target_map_label,
            current_map_label = live_map_label,
            travel_path = travel_path,
            travel_summary = segment_travel_summary(segment),
            map_grid = segment.map_grid,
            message = "Checkpoint: " .. label,
            direction_label = "",
            direction_symbol = "?",
            distance_label = "",
            status_label = "manual checkpoint",
            resolution = resolved.resolution,
        }
    end

    local distance, dx, dy, dz, horizontal_distance = spatial_distance(current, target)
    local display_dy = display_vertical_delta(dy)
    local heading_yaw = live_heading_yaw(live)
    local direction_label_value, direction_symbol_value = direction(dx, dz, heading_yaw)
    local radius = segment_radius(route, segment)
    local arrived = radius > 0 and distance <= radius

    return {
        available = true,
        label = label,
        segment_index = index,
        segment_count = count,
        target = target,
        current = current,
        distance = distance,
        horizontal_distance = horizontal_distance,
        vertical_delta = display_dy,
        vertical_label = vertical_label(display_dy),
        elevation_angle_degrees = elevation_angle_degrees(horizontal_distance, display_dy),
        path_distance = resolved.path_distance,
        off_route_distance = resolved.off_route_distance,
        off_route_threshold = resolved.off_route_threshold,
        distance_label = distance_label(distance),
        direction_label = direction_label_value,
        direction_symbol = direction_symbol_value,
        pointer_vector = pointer_vector(dx, dz, horizontal_distance, heading_yaw),
        pointer_vector_3d = pointer_vector_3d(dx, display_dy, dz, distance),
        arrived = arrived,
        zone_mismatch = false,
        off_route = resolved.off_route,
        target_map_label = target_map_label,
        current_map_label = live_map_label,
        travel_path = segment_travel_path(segment),
        travel_summary = segment_travel_summary(segment),
        map_grid = segment.map_grid,
        status_label = resolved.status_label,
        resolution = resolved.resolution,
        message = "Go Here: " .. label,
    }
end

return guidance_cursor
