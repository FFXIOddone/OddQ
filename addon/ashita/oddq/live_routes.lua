local catalog_loaded, catalog = pcall(require, "data/live_routes")
if not catalog_loaded then
    catalog = {}
end

local live_routes = {}

local DEFAULT_LIVE_ROUTE_ARRIVAL_RADIUS_FLOOR = 10
local DEFAULT_LIVE_ROUTE_NEAREST_FORWARD_HYSTERESIS = 5
local DEFAULT_LIVE_ROUTE_OFF_ROUTE_DISTANCE = 60

local function normalize_key(value)
    return tostring(value or ""):lower():gsub("[_%s]+", "-")
end

local function route_number(route, key, alias, default_value)
    if type(route) ~= "table" then
        return default_value
    end

    local controller = type(route.controller) == "table" and route.controller or {}
    local value = tonumber(route[key])
    if value == nil and alias ~= nil then
        value = tonumber(route[alias])
    end
    if value == nil then
        value = tonumber(controller[key])
    end
    if value == nil and alias ~= nil then
        value = tonumber(controller[alias])
    end
    if value == nil or value <= 0 then
        return default_value
    end
    return value
end

local function route_quality_claimed(route)
    local quality = type(route) == "table" and route.quality or {}
    local status = tostring((quality or {}).status or "")
    if status == "" then
        return false
    end
    return status:find("candidate", 1, true) == nil and status:find("draft", 1, true) == nil
end

local function route_matches(route, key)
    if key == "" then
        return false
    end
    if normalize_key(route.route_id) == key or normalize_key(route.name) == key then
        return true
    end
    for _, alias in ipairs(route.aliases or {}) do
        if normalize_key(alias) == key then
            return true
        end
    end
    return false
end

local function copy_waypoint_position(waypoint)
    return {
        x = tonumber(waypoint.x) or 0,
        y = 0,
        z = tonumber(waypoint.y) or 0,
    }
end

local function copy_route_start_position(start)
    if type(start) ~= "table" then
        return nil
    end

    local x = tonumber(start.x)
    local z = tonumber(start.y)
    if z == nil then
        z = tonumber(start.z)
    end
    if x == nil or z == nil then
        return nil
    end

    return {
        x = x,
        y = tonumber(start.z) or 0,
        z = z,
    }
end

function live_routes.all()
    return catalog
end

function live_routes.find(query)
    local key = normalize_key(query)
    for _, route in ipairs(catalog) do
        if route_matches(route, key) then
            return route
        end
    end
    return nil
end

function live_routes.list_labels()
    local labels = {}
    for _, route in ipairs(catalog) do
        local alias = route.aliases and route.aliases[1] or route.route_id
        table.insert(labels, tostring(alias) .. " - " .. tostring(route.name))
    end
    return labels
end

function live_routes.to_locked_route(route)
    local segments = {}
    local previous = "current_position"
    local route_start_position = copy_route_start_position(route.start)
    local previous_position = route_start_position

    for _, waypoint in ipairs(route.waypoints or {}) do
        local waypoint_position = copy_waypoint_position(waypoint)
        local segment = {
            type = "walk",
            zone_id = waypoint.zone_id,
            from = previous,
            to = waypoint.id,
            destination_label = waypoint.label,
            arrival_radius = waypoint.radius,
            source = waypoint.source,
            positions = {
                waypoint_position,
            },
        }
        if previous_position ~= nil then
            segment.start_position = previous_position
        end
        table.insert(segments, segment)
        previous = waypoint.id
        previous_position = waypoint_position

        if waypoint.transition_zone ~= nil then
            local zone_segment = {
                type = "zone_line",
                zone_id = waypoint.zone_id,
                from = waypoint.id,
                to = waypoint.transition_zone,
                destination_label = route.completion and route.completion.zone_name or tostring(waypoint.transition_zone),
                destination_zone_id = waypoint.transition_zone,
                arrival_radius = waypoint.radius,
                source = waypoint.source,
                positions = {
                    waypoint_position,
                },
            }
            if previous_position ~= nil then
                zone_segment.start_position = previous_position
            end
            table.insert(segments, zone_segment)
        end
    end

    return {
        route_id = route.route_id,
        locked = true,
        segments = segments,
        start_position = route_start_position,
        signature = "local-live-route:" .. tostring(route.route_id),
        source = "data/live_routes",
        completion_zone_id = route.completion and route.completion.zone_id or nil,
        completion_label = route.completion and route.completion.zone_name or nil,
        completion_success = route.completion and route.completion.success or nil,
        arrival_radius_floor = route_number(route, "arrival_radius_floor", "waypoint_radius_floor", DEFAULT_LIVE_ROUTE_ARRIVAL_RADIUS_FLOOR),
        nearest_forward_hysteresis = route_number(route, "nearest_forward_hysteresis", "rebase_hysteresis", DEFAULT_LIVE_ROUTE_NEAREST_FORWARD_HYSTERESIS),
        off_route_distance = route_number(route, "off_route_distance", "off_route_radius", DEFAULT_LIVE_ROUTE_OFF_ROUTE_DISTANCE),
        route_quality_claimed = route_quality_claimed(route),
    }
end

function live_routes.to_objective(route)
    local quality = route.quality or {}
    local completion = route.completion or {}
    return {
        mode = "quests",
        objective_kind = "route",
        objective_id = route.route_id,
        quest_id = route.route_id,
        quest_name = route.name,
        step_id = "follow_route",
        step_kind = "manual route",
        zone_id = completion.zone_id,
        npc_name = completion.zone_name,
        evidence = {
            source = quality.source or "data/live_routes",
            status = quality.label or quality.status or "live route",
            validated = true,
        },
    }
end

return live_routes
