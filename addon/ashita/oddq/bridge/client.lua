local bridge_client = {}

local transport_loaded, default_transport = pcall(require, "bridge/transport")
if transport_loaded and type(default_transport) == "table" and type(default_transport.post_json) == "function" then
    bridge_client.default_transport = default_transport.post_json
end

local function copy_list(values)
    local result = {}
    for index, value in ipairs(values or {}) do
        result[index] = value
    end
    return result
end

local function encode_json(value)
    local value_type = type(value)
    if value_type == "string" then
        return string.format("%q", value)
    end
    if value_type == "number" or value_type == "boolean" then
        return tostring(value)
    end
    if value_type ~= "table" then
        return "null"
    end

    local is_array = true
    local count = 0
    for key, _ in pairs(value) do
        count = count + 1
        if type(key) ~= "number" then
            is_array = false
        end
    end

    local parts = {}
    if is_array then
        for index = 1, count do
            table.insert(parts, encode_json(value[index]))
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    for key, child in pairs(value) do
        table.insert(parts, encode_json(tostring(key)) .. ":" .. encode_json(child))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function bridge_client.build_route_request(state)
    local position = state.current_position or {}
    local transport = state.known_transport_flags or {}
    local movement = state.movement_context or {}

    return {
        protocol_version = "1.0",
        addon_version = state.addon_version or "0.1.0",
        server_profile = state.server_profile or "catseyexi",
        game_mode = state.game_mode or "CW",
        current_zone_id = state.current_zone_id or 0,
        current_position = {
            x = position.x or 0,
            y = position.y or 0,
            z = position.z or 0,
        },
        current_map_id = state.current_map_id,
        current_map_label = state.current_map_label,
        target_objective_id = state.target_objective_id or "manual.none",
        key_items = copy_list(state.key_items),
        known_unlocks_hash = state.known_unlocks_hash or "sha256:unknown",
        known_transport_flags = {
            home_points = copy_list(transport.home_points),
            survival_guides = copy_list(transport.survival_guides),
            outposts = copy_list(transport.outposts),
            teleport_crystals = copy_list(transport.teleport_crystals or transport.crystals),
            exp_guides = copy_list(transport.exp_guides),
            city_teleporters = copy_list(transport.city_teleporters),
            spells = copy_list(transport.spells),
            items = copy_list(transport.items),
            cooldowns = {
                warp_ring_seconds_remaining = tonumber((transport.cooldowns or {}).warp_ring_seconds_remaining) or 0,
                instant_warp_scroll_count = tonumber((transport.cooldowns or {}).instant_warp_scroll_count) or 0,
            },
        },
        movement_context = {
            has_movement_speed_buff = movement.has_movement_speed_buff == true,
            mount_available = movement.mount_available == true,
        },
    }
end

function bridge_client.build_objective_request(state)
    local position = state.current_position or {}
    local transport = state.known_transport_flags or {}

    return {
        server_profile = state.server_profile or "catseyexi",
        game_mode = state.game_mode or "CW",
        current_zone_id = state.current_zone_id or 0,
        current_position = {
            x = position.x or 0,
            y = position.y or 0,
            z = position.z or 0,
        },
        current_map_id = state.current_map_id,
        current_map_label = state.current_map_label,
        level = tonumber(state.level) or 0,
        completed_quests = copy_list(state.completed_quests),
        completed_missions = copy_list(state.completed_missions),
        key_items = copy_list(state.key_items),
        enabled_modes = copy_list(state.enabled_modes),
        enabled_exp_camp_categories = copy_list(state.enabled_exp_camp_categories),
        target_objective_id = state.target_objective_id or "manual.none",
        known_unlocks_hash = state.known_unlocks_hash or "sha256:unknown",
        known_transport_flags = {
            home_points = copy_list(transport.home_points),
            survival_guides = copy_list(transport.survival_guides),
            outposts = copy_list(transport.outposts),
            teleport_crystals = copy_list(transport.teleport_crystals or transport.crystals),
            exp_guides = copy_list(transport.exp_guides),
            city_teleporters = copy_list(transport.city_teleporters),
            spells = copy_list(transport.spells),
            items = copy_list(transport.items),
            cooldowns = {
                warp_ring_seconds_remaining = tonumber((transport.cooldowns or {}).warp_ring_seconds_remaining) or 0,
                instant_warp_scroll_count = tonumber((transport.cooldowns or {}).instant_warp_scroll_count) or 0,
            },
        },
    }
end

function bridge_client.apply_route_response(current_route, response)
    if response == nil then
        return current_route
    end

    if response.locked ~= true then
        return current_route
    end

    if type(response.segments) ~= "table" or #response.segments == 0 then
        return current_route
    end

    if type(response.signature) ~= "string" or response.signature == "" then
        return current_route
    end

    return response
end

function bridge_client.apply_objective_response(current_objective, response)
    if response == nil then
        return current_objective
    end

    if type(response.objective_id) ~= "string" or response.objective_id == "" then
        return current_objective
    end

    if type(response.quest_name) ~= "string" or response.quest_name == "" then
        return current_objective
    end

    if type(response.route_request_hint) ~= "table" then
        return current_objective
    end

    return response
end

function bridge_client.apply_objective_plan_response(current_plan, response)
    if response == nil then
        return current_plan
    end
    if response.schema ~= "objective_plan.v1" then
        return current_plan
    end
    if type(response.actions) ~= "table" or #response.actions == 0 then
        return current_plan
    end
    for _, action in ipairs(response.actions) do
        if type(action) ~= "table" or type(action.objective) ~= "table" then
            return current_plan
        end
        if action.mode ~= "mission" and action.mode ~= "job" and action.mode ~= "quest" and action.mode ~= "exp" then
            return current_plan
        end
        if type(action.objective.objective_id) ~= "string" or action.objective.objective_id == "" then
            return current_plan
        end
        if type(action.objective.route_request_hint) ~= "table" then
            return current_plan
        end
    end
    return response
end

function bridge_client.cache_locked_route(path, route)
    if route == nil or route.locked ~= true then
        return false
    end

    local file = io.open(path, "w")
    if file == nil then
        return false
    end

    file:write(encode_json(route))
    file:close()
    return true
end

function bridge_client.request_objective(config, state, current_objective, transport)
    local request = bridge_client.build_objective_request(state)
    local objective_transport = transport or bridge_client.default_transport

    if objective_transport == nil then
        return current_objective, "bridge transport unavailable", request
    end

    -- ODD_NETWORK_CALL: localhost bridge objective_request only; backend policy stays in C# API.
    local response, err = objective_transport(config.bridge_base_url .. "/objective", request)
    if response == nil then
        return current_objective, err or "bridge objective request failed", request
    end

    return bridge_client.apply_objective_response(current_objective, response), nil, request
end

function bridge_client.request_objective_plan(config, state, current_plan, transport)
    local request = bridge_client.build_objective_request(state)
    local objective_transport = transport or bridge_client.default_transport

    if objective_transport == nil then
        return current_plan, "bridge transport unavailable", request
    end

    -- ODD_NETWORK_CALL: localhost bridge objective plan request only; no external endpoint policy in Lua.
    local response, err = objective_transport(config.bridge_base_url .. "/objectives/next", request)
    if response == nil then
        return current_plan, err or "bridge objective plan request failed", request
    end

    return bridge_client.apply_objective_plan_response(current_plan, response), nil, request
end

function bridge_client.request_route(config, state, current_route, transport)
    local request = bridge_client.build_route_request(state)
    local route_transport = transport or bridge_client.default_transport

    if route_transport == nil then
        return current_route, "bridge transport unavailable", request
    end

    -- ODD_NETWORK_CALL: localhost bridge route_request only; backend policy stays in C# bridge.
    local response, err = route_transport(config.bridge_base_url .. "/route", request)
    if response == nil then
        return current_route, err or "bridge request failed", request
    end

    local next_route = bridge_client.apply_route_response(current_route, response)
    if next_route ~= current_route then
        bridge_client.cache_locked_route(config.cache_path, next_route)
    end

    return next_route, nil, request
end

return bridge_client
