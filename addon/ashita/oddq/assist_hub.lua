local addon_integration = require("addon_integration")
local inventory_readiness = require("inventory_readiness")
local travel_advice = require("travel_advice")

local assist_hub = {}

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function has_text(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

local function current_step(objective, step_index)
    local steps = type(objective) == "table" and objective.steps or nil
    if type(steps) ~= "table" then
        return type(objective) == "table" and objective or {}
    end
    return steps[tonumber(step_index) or 1] or {}
end

local function card(cards, id, title, body, action)
    if has_text(body) then
        table.insert(cards, {
            id = id,
            title = title,
            body = body,
            action = action,
        })
    end
end

local function first_segment(route)
    if type(route) ~= "table" or type(route.segments) ~= "table" then
        return nil
    end
    return route.segments[1]
end

local function target_name(step, route)
    if has_text(step.npc_name) then
        return step.npc_name
    end
    if has_text(step.object_name) then
        return step.object_name
    end
    if has_text(step.mob_name) then
        return step.mob_name
    end
    if has_text(step.target_name) then
        return step.target_name
    end
    local segment = first_segment(route)
    if type(segment) == "table" and has_text(segment.destination_label) then
        return segment.destination_label
    end
    return nil
end

local function target_zone_id(step, route)
    local zone_id = tonumber(step.zone_id or step.destination_zone_id or step.target_zone_id)
    if zone_id ~= nil then
        return zone_id
    end
    local segment = first_segment(route)
    if type(segment) == "table" then
        return tonumber(segment.zone_id or segment.destination_zone_id or segment.target_zone_id)
    end
    return nil
end

local scan_target_index_ready = false
local scan_targets_by_zone = {}
local scan_targets_any_zone = {}

local scan_target_kinds = {
    mob = true,
    npc = true,
}

local generic_target_suffixes = {
    camp = true,
    ["for"] = true,
    gate = true,
    guard = true,
    npc = true,
    optional = true,
    prep = true,
    route = true,
}

local function normalize_scan_key(value)
    local text = trim(value):lower():gsub("\\", ""):gsub("'", "")
    text = text:gsub("[^a-z0-9]+", " ")
    return trim(text)
end

local function add_scan_target(bucket, key, target)
    if key == "" then
        return
    end
    if bucket[key] == nil then
        bucket[key] = target
    end
end

local function ensure_scan_target_index()
    if scan_target_index_ready == true then
        return
    end
    scan_target_index_ready = true

    local loaded, targets = pcall(require, "data/" .. "targets")
    if not loaded or type(targets) ~= "table" then
        return
    end

    for _, target in ipairs(targets) do
        if type(target) == "table" and scan_target_kinds[target.kind] == true and has_text(target.name) then
            local key = normalize_scan_key(target.name)
            add_scan_target(scan_targets_any_zone, key, target)

            local zone_id = tonumber(target.zone_id)
            if zone_id ~= nil then
                local zone_bucket = scan_targets_by_zone[zone_id]
                if zone_bucket == nil then
                    zone_bucket = {}
                    scan_targets_by_zone[zone_id] = zone_bucket
                end
                add_scan_target(zone_bucket, key, target)
            end
        end
    end
end

local function indexed_scan_name(name, zone_id)
    ensure_scan_target_index()
    local key = normalize_scan_key(name)
    if key == "" then
        return nil
    end

    local zone_bucket = zone_id ~= nil and scan_targets_by_zone[zone_id] or nil
    local target = zone_bucket ~= nil and zone_bucket[key] or nil
    if target == nil then
        target = scan_targets_any_zone[key]
    end
    return target ~= nil and target.name or nil
end

local function add_candidate(candidates, value)
    local candidate = trim(value)
    if candidate ~= "" then
        candidates[#candidates + 1] = candidate
    end
end

local function scan_name_variants(value)
    local variants = {}
    local text = trim(value)
    if text == "" then
        return variants
    end

    add_candidate(variants, text)
    add_candidate(variants, text:gsub("%b[]", " "):gsub("%b()", " "))
    add_candidate(variants, text:gsub("%s+[Cc]amp%s+.*$", ""))
    add_candidate(variants, text:gsub("%s+[Ff]or%s+.*$", ""))

    local tokens = {}
    for token in text:gmatch("%S+") do
        tokens[#tokens + 1] = token
    end
    while #tokens > 1 and generic_target_suffixes[normalize_scan_key(tokens[#tokens])] == true do
        tokens[#tokens] = nil
        add_candidate(variants, table.concat(tokens, " "))
    end

    return variants
end

local function split_scan_names(value)
    local names = {}
    local text = trim(value)
    if text == "" then
        return names
    end
    text = text:gsub("%s+[Oo][Rr]%s+", "/")
    text = text:gsub("%s+[Aa][Nn][Dd]%s+", "/")
    for part in text:gmatch("[^/]+") do
        add_candidate(names, part)
    end
    return names
end

local function scan_name_from_value(value, zone_id)
    for _, name in ipairs(split_scan_names(value)) do
        for _, candidate in ipairs(scan_name_variants(name)) do
            local indexed = indexed_scan_name(candidate, zone_id)
            if indexed ~= nil then
                return indexed
            end
        end
    end
    return nil
end

local function filterscan_target_name(step, route)
    local zone_id = target_zone_id(step, route)
    return scan_name_from_value((step or {}).npc_name, zone_id)
        or scan_name_from_value((step or {}).mob_name, zone_id)
end

local function first_nonblank(...)
    for _, value in ipairs({ ... }) do
        if has_text(value) then
            return tostring(value)
        end
    end
    return ""
end

local function target_card_body(target, live)
    if not has_text(target) then
        return "No target helper for this step."
    end
    local current = type(live) == "table" and live.current_target_name or nil
    local distance = type(live) == "table" and live.target_distance or nil
    local status = current == target and "Target confirmed" or "Target helper"
    if distance ~= nil then
        local numeric_distance = tonumber(distance)
        local distance_text = numeric_distance ~= nil and string.format("%.1f", numeric_distance) or tostring(distance)
        return status .. ": " .. target .. " (" .. distance_text .. " yalms)"
    end
    return status .. ": " .. target
end

local function objective_label(objective)
    if type(objective) ~= "table" then
        return "Current guide"
    end
    return objective.title
        or objective.quest_name
        or objective.name
        or objective.objective_id
        or "Current guide"
end

local function readiness_body(objective, step_index, readiness_provider)
    local rows = inventory_readiness.for_step(objective, step_index, readiness_provider)
    local lines = {}
    for _, row in ipairs(rows) do
        table.insert(lines, row.label .. ": " .. row.status)
    end
    return table.concat(lines, "\n")
end

local function travel_body(step, route)
    local segment = first_segment(route) or {}
    return travel_advice.summary({
        zone_id = target_zone_id(step, route),
        destination_zone_id = segment.destination_zone_id,
        target_map_label = first_nonblank(step.target_map_label, segment.target_map_label),
        target_map_name = first_nonblank(step.target_map_name, segment.target_map_name),
        map_grid = first_nonblank(step.map_grid, segment.map_grid),
    })
end

local function normalize_map(value)
    if not has_text(value) then
        return ""
    end
    return tostring(value):lower():gsub("%s+", ""):gsub("#", "")
end

local function target_map_label(step, route)
    local segment = first_segment(route) or {}
    return first_nonblank(
        step.target_map_label,
        step.target_map_name,
        segment.target_map_label,
        segment.target_map_name,
        segment.destination_map_label,
        segment.destination_map_name
    )
end

local function map_matches(step, route, live)
    local target_map = target_map_label(step, route)
    if target_map == "" then
        return true
    end
    local current = first_nonblank(
        (live or {}).current_map_label,
        (live or {}).current_map_name,
        (live or {}).map_label,
        (live or {}).map_name,
        (live or {}).map_floor
    )
    if current == "" then
        return false
    end
    return normalize_map(current) == normalize_map(target_map)
end

local function zone_matches(step, route, live)
    local target_zone = target_zone_id(step, route)
    local current_zone = tonumber((live or {}).current_zone_id or (live or {}).zone_id or (live or {}).zone)
    return target_zone == nil or (current_zone ~= nil and current_zone == target_zone)
end

function assist_hub.build_state(state, objective, route, step_index, live, readiness_provider)
    local prefs = ((state or {}).preferences or {})
    local display = prefs.display or {}
    local integrations = prefs.integrations or {}
    local safety = prefs.safety or {}
    local auto_filterscan_enabled = integrations.show_filterscan ~= false
        and integrations.allow_filterscan_command == true
        and integrations.auto_filterscan_on_match == true
    local inline_guide_visible = state ~= nil and state.main_view == "guide"
    if state ~= nil and state.assist_hub_open ~= true and not inline_guide_visible and not auto_filterscan_enabled then
        return {
            visible = false,
            cards = {},
        }
    end
    if type(objective) ~= "table" or type(objective.steps) ~= "table" or #objective.steps == 0 then
        return {
            visible = state == nil or state.assist_hub_open == true or inline_guide_visible,
            cards = {
                {
                    id = "empty",
                    title = "No guide loaded",
                    body = "Open the Guide Browser and choose a mission, quest, job, or EXP guide.",
                },
            },
        }
    end
    local step = current_step(objective, step_index)
    local target = target_name(step, route)
    local scan_target = filterscan_target_name(step, route)
    local cards = {}

    if display.show_checklist ~= false then
        card(cards, "checklist", "Checklist", tostring(objective_label(objective)))
    end
    if display.show_travel_hints ~= false then
        card(cards, "travel", "Travel", travel_body(step, route))
    end
    if display.show_target_confirmation ~= false then
        card(cards, "target", "Target", target_card_body(target, live))
    end
    if display.show_readiness ~= false then
        card(cards, "readiness", "Readiness", readiness_body(objective, step_index, readiness_provider))
    end
    if integrations.show_filterscan ~= false and has_text(scan_target) then
        local command = addon_integration.filterscan_command(scan_target)
        local action = integrations.allow_filterscan_command == true and command or nil
        card(cards, "filterscan", "FilterScan", command, action)
    end
    if integrations.show_minimap ~= false then
        local command = addon_integration.minimap_zoom_command(integrations.minimap_zoom or 0.30)
        local action = integrations.allow_minimap_command == true and command or nil
        card(cards, "minimap", "MiniMap", command or "MiniMap zoom unavailable", action)
    end
    if display.show_objective_cards ~= false then
        card(cards, "objective", "Next", step.instruction or "No current step selected.")
    end
    if safety.show_integration_status ~= false then
        card(cards, "safety", "Safety", "Display helpers are safe by default; command helpers require explicit toggles.")
    end

    return {
        visible = state == nil or state.assist_hub_open == true or inline_guide_visible,
        target_name = target,
        filterscan_target_name = scan_target,
        filterscan_command = has_text(scan_target) and addon_integration.filterscan_command(scan_target) or nil,
        zone_matches = zone_matches(step, route, live),
        map_matches = map_matches(step, route, live),
        travel = travel_body(step, route),
        cards = cards,
    }
end

function assist_hub.next_auto_filterscan_command(state, assist_state, now)
    local prefs = ((state or {}).preferences or {})
    local integrations = prefs.integrations or {}
    if integrations.show_filterscan == false
        or integrations.allow_filterscan_command ~= true
        or integrations.auto_filterscan_on_match ~= true then
        return nil
    end
    if assist_state == nil
        or assist_state.zone_matches ~= true
        or assist_state.map_matches ~= true
        or not has_text(assist_state.filterscan_command) then
        return nil
    end
    if not addon_integration.is_allowed_command(assist_state.filterscan_command) then
        return nil
    end

    now = tonumber(now) or os.clock()
    local cooldown = tonumber(integrations.filterscan_cooldown_seconds) or 30
    if state._last_filterscan_command == assist_state.filterscan_command
        and tonumber(state._last_filterscan_at) ~= nil
        and (now - state._last_filterscan_at) < cooldown then
        return nil
    end

    state._last_filterscan_command = assist_state.filterscan_command
    state._last_filterscan_at = now
    return assist_state.filterscan_command
end

return assist_hub
