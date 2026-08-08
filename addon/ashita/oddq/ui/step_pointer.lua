local step_pointer = {}

local imgui_text = require("ui/imgui_text")
local skin = require("ui/skin")
local window_state = require("ui/window_state")
local uberwarp_routes = require("uberwarp_routes")
local crystal_pointer = require("ui/crystal_pointer")
local mount_zones = require("data/mount_zones")
local zone_approaches = require("data/zone_approaches")
local zone_exit_routes = require("data/zone_exit_routes")

local ZONE_EXIT_REVERSE = {}
for from_zone, exits in pairs(zone_exit_routes) do
    for _, exit in ipairs(exits or {}) do
        local to_zone = tonumber(exit.to_zone_id)
        if to_zone ~= nil then
            ZONE_EXIT_REVERSE[to_zone] = ZONE_EXIT_REVERSE[to_zone] or {}
            ZONE_EXIT_REVERSE[to_zone][#ZONE_EXIT_REVERSE[to_zone] + 1] = tonumber(from_zone)
        end
    end
end
local ZONE_HOPS_CACHE = {}

local PI = math.pi
local TWO_PI = PI * 2
local WARP_USE_RANGE_YALMS = 6.0
local DEFAULT_MOUNT_NAME = "Raptor"
-- User-captured raw X/Y/Z is 7.146/-29.7/-44.999. OddQ stores the raw
-- vertical Z axis as y and the raw planar Y axis as z.
local HEAVENS_TOWER_TRANSPORTER = {
    zone_id = 242,
    upper_floor_y_threshold = -40.0,
    position = {
        x = 7.146,
        y = -44.999,
        z = -29.7,
        object_name = "Transporter",
        position_kind = "exact_target",
    },
}
-- The fixed 300px pointer leaves about 190px after the arrow, spacing,
-- padding, and right inset. At the scaled 14px font, 27 characters is the
-- conservative single-line label budget.
local POSITION_LABEL_CHARACTER_LIMIT = 27

local ROUTE_ABBREVIATIONS = {
    { "Northern San d'Oria", "N. Sandy" },
    { "Southern San d'Oria", "S. Sandy" },
    { "Port San d'Oria", "P. Sandy" },
    { "Bastok Markets", "B. Markets" },
    { "Bastok Mines", "B. Mines" },
    { "Port Bastok", "P. Bastok" },
    { "Windurst Waters", "W. Waters" },
    { "Windurst Walls", "W. Walls" },
    { "Windurst Woods", "W. Woods" },
    { "Port Windurst", "P. Windy" },
    { "Lower Jeuno", "L. Jeuno" },
    { "Upper Jeuno", "U. Jeuno" },
    { "Port Jeuno", "P. Jeuno" },
    { "Ru'Lude Gardens", "Ru'Lude" },
    { "Western Adoulin", "W. Adoulin" },
    { "Eastern Adoulin", "E. Adoulin" },
    { "Aht Urhgan Whitegate", "Whitegate" },
    { "Tavnazian Safehold", "Tav" },
}

local function compact_grid_label(step)
    local raw = tostring((step or {}).map_grid or "")
    local tokens, seen = {}, {}
    for token in raw:gmatch("[A-Za-z]+%-[0-9]+") do
        token = token:upper()
        if seen[token] ~= true then
            seen[token] = true
            tokens[#tokens + 1] = token
        end
    end
    if #tokens == 1 then
        return "(" .. tokens[1] .. ")"
    end
    if #tokens > 1 then
        return "(" .. tokens[1] .. "/" .. tokens[#tokens] .. ")"
    end
    return ""
end

local function shorten_to_limit(value, limit)
    value = tostring(value or "")
    if #value <= limit then return value end
    if limit <= 3 then return value:sub(1, limit) end
    return value:sub(1, limit - 3) .. "..."
end

local function abbreviated_npc_name(name, available)
    name = tostring(name or "")
    if #name <= available then return name end
    local first, last = name:match("^(.*%S)%s+(%S+)$")
    if first ~= nil and last ~= nil then
        name = first .. " " .. last:sub(1, 1) .. "."
    end
    return shorten_to_limit(name, available)
end

local OBJECT_PREFIX_ABBREVIATIONS = {
    ["Door:"] = "Dr:",
    ["Gate:"] = "Gt:",
    ["Entrance:"] = "Ent:",
}

local function abbreviated_object_name(name, available)
    local words = {}
    for word in tostring(name or ""):gmatch("%S+") do words[#words + 1] = word end
    if #table.concat(words, " ") <= available then return table.concat(words, " ") end
    for index = 1, math.max(1, #words - 1) do
        words[index] = OBJECT_PREFIX_ABBREVIATIONS[words[index]]
            or (words[index]:sub(1, 1) .. ".")
        local compact = table.concat(words, " ")
        if #compact <= available then return compact end
    end
    return shorten_to_limit(table.concat(words, " "), available)
end

local function compact_position_label(step, target)
    local grid = compact_grid_label(target)
    if grid == "" then
        grid = compact_grid_label(step)
    end
    local function rounded(value)
        value = tonumber(value) or 0
        if value < 0 then
            return math.ceil(value - 0.5)
        end
        return math.floor(value + 0.5)
    end
    local position = grid
    if position == "" then
        position = string.format(
            "X(%d) Y(%d) Z(%d)",
            rounded(target.x),
            rounded(target.y),
            rounded(target.z)
        )
    end
    local named_position = grid ~= "" and grid or string.format(
        "(%d,%d,%d)",
        rounded(target.x),
        rounded(target.y),
        rounded(target.z)
    )
    local npc_name = tostring((target or {}).npc_name or "")
    local object_name = tostring((target or {}).object_name or "")
    local general_anchor = tostring((target or {}).position_kind or "") == "map_grid_anchor"
    if not general_anchor and npc_name == "" and object_name == "" then
        npc_name = tostring((step or {}).npc_name or "")
        object_name = tostring((step or {}).object_name or "")
    end
    local name = ""
    if npc_name ~= "" then
        name = abbreviated_npc_name(npc_name, POSITION_LABEL_CHARACTER_LIMIT - #named_position - 1)
    elseif object_name ~= "" then
        name = abbreviated_object_name(object_name, POSITION_LABEL_CHARACTER_LIMIT - #named_position - 1)
    end
    if name == "" then return position end
    return shorten_to_limit(name .. " " .. named_position, POSITION_LABEL_CHARACTER_LIMIT)
end

local function compact_route_label(label)
    label = tostring(label or "")
    for _, replacement in ipairs(ROUTE_ABBREVIATIONS) do
        label = label:gsub(replacement[1], replacement[2])
    end
    label = label:gsub("Survival Guide", "SG")
    label = label:gsub("Home Point", "HP")
    label = label:gsub(" HP #(%d+)", " HP%1")
    return label
end

local function copy_position(position)
    if type(position) ~= "table" then
        return nil
    end
    local x = tonumber(position.x or position.X)
    local y = tonumber(position.y or position.Y)
    local z = tonumber(position.z or position.Z)
    if x == nil or z == nil then
        return nil
    end
    return {
        x = x,
        y = y or 0,
        z = z,
        map_id = tonumber(position.map_id or position.target_map_id),
        map_grid = tostring(position.map_grid or ""),
        position_kind = tostring(position.position_kind or ""),
        npc_name = tostring(position.npc_name or ""),
        object_name = tostring(position.object_name or ""),
    }
end

local function selected_step_index(objective, guidance)
    local steps = type(objective) == "table" and objective.steps or nil
    if type(steps) ~= "table" or #steps == 0 then
        return nil, nil
    end
    local index = math.floor(tonumber((guidance or {}).guide_step_tab_index) or 1)
    index = math.max(1, math.min(index, #steps))
    return steps, index
end

local function add_position(positions, seen, value)
    local position = copy_position(value)
    if position == nil then return end
    local key = string.format("%.3f|%.3f|%.3f", position.x, position.y, position.z)
    if seen[key] then return end
    seen[key] = true
    positions[#positions + 1] = position
end

local function step_positions(step)
    local positions, seen = {}, {}
    add_position(positions, seen, (step or {}).position)
    for _, position in ipairs((step or {}).positions or {}) do add_position(positions, seen, position) end
    return positions
end

local function heavens_tower_transit_target(current_zone, current, target_zone, candidates)
    local transit = HEAVENS_TOWER_TRANSPORTER
    if tonumber(current_zone) ~= transit.zone_id or type(current) ~= "table"
        or tonumber(current.y) == nil
        or current.y > transit.upper_floor_y_threshold then
        return nil
    end
    if tonumber(target_zone) == tonumber(current_zone) then
        for _, candidate in ipairs(candidates or {}) do
            if tonumber(candidate.y) ~= nil
                and candidate.y <= transit.upper_floor_y_threshold then
                return nil
            end
        end
    end
    return copy_position(transit.position)
end

local function has_authored_warp_stage(step)
    return type((step or {}).warp_stages) == "table" and #step.warp_stages > 0
end

local function next_destination(objective, guidance)
    local steps, selected = selected_step_index(objective, guidance)
    if steps == nil then return nil end
    if (steps[selected] or {}).pointer_suppressed == true then
        return nil, nil, selected, nil, "step_pointer_suppressed"
    end
    local positions = step_positions(steps[selected])
    if #positions > 0 then return steps[selected], selected, selected, positions end

    local selected_zone = tonumber((steps[selected] or {}).zone_id)
    if selected_zone ~= nil and selected_zone > 0 then
        for index = selected - 1, 1, -1 do
            if tonumber((steps[index] or {}).zone_id) == selected_zone then
                positions = step_positions(steps[index])
                if #positions > 0 then return steps[index], index, selected, positions end
            end
        end
        for index = selected + 1, #steps do
            if tonumber((steps[index] or {}).zone_id) == selected_zone then
                positions = step_positions(steps[index])
                if #positions > 0 then return steps[index], index, selected, positions end
            end
        end
    end
    for index = selected - 1, 1, -1 do
        positions = step_positions(steps[index])
        if #positions > 0 then return steps[index], index, selected, positions end
    end
    for index = selected + 1, #steps do
        positions = step_positions(steps[index])
        if #positions > 0 then return steps[index], index, selected, positions end
    end
    return nil, nil, selected, nil
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

local function atan2(y, x)
    if math.atan2 ~= nil then
        return math.atan2(y, x)
    end
    return math.atan(y, x)
end

local function spatial_distance(a, b)
    local dx = b.x - a.x
    local dy = (b.y or 0) - (a.y or 0)
    local dz = b.z - a.z
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function zone_hops_to(target_zone)
    if ZONE_HOPS_CACHE[target_zone] ~= nil then return ZONE_HOPS_CACHE[target_zone] end
    local hops, queue, head = { [target_zone] = 0 }, { target_zone }, 1
    while head <= #queue do
        local zone = queue[head]
        head = head + 1
        for _, previous in ipairs(ZONE_EXIT_REVERSE[zone] or {}) do
            if previous ~= nil and hops[previous] == nil then
                hops[previous] = hops[zone] + 1
                queue[#queue + 1] = previous
            end
        end
    end
    ZONE_HOPS_CACHE[target_zone] = hops
    return hops
end

local function select_zone_exit(current_zone, target_zone, current)
    current_zone = tonumber(current_zone)
    target_zone = tonumber(target_zone)
    if current_zone == nil or target_zone == nil or current_zone == target_zone then return nil end

    local hops = zone_hops_to(target_zone)

    local selected, selected_hops, selected_distance = nil, nil, nil
    for _, exit in ipairs(zone_exit_routes[current_zone] or {}) do
        local position = copy_position(exit.position)
        local remaining = hops[tonumber(exit.to_zone_id)]
        if position ~= nil and remaining ~= nil then
            local walking = spatial_distance(current, position)
            if selected == nil
                or remaining < selected_hops
                or (remaining == selected_hops and walking < selected_distance) then
                selected, selected_hops, selected_distance = position, remaining, walking
                selected.to_zone_id = tonumber(exit.to_zone_id)
                selected.object_name = tostring(exit.object_name or "Zone Exit")
                selected.position_kind = "exact_target"
            end
        end
    end
    if selected == nil then
        for _, exit in ipairs(zone_exit_routes[current_zone] or {}) do
            local position = copy_position(exit.position)
            if position ~= nil then
                local walking = spatial_distance(current, position)
                if selected == nil or walking < selected_distance then
                    selected, selected_distance = position, walking
                    selected.to_zone_id = tonumber(exit.to_zone_id)
                    selected.object_name = tostring(exit.object_name or "Zone Exit")
                    selected.position_kind = "exact_target"
                end
            end
        end
    end
    return selected
end

local function select_zone_approach(target_zone, candidates)
    local approaches = zone_approaches[tonumber(target_zone)] or {}
    if #approaches == 0 then return nil end
    if #approaches == 1 then return approaches[1] end
    local selected, selected_cost = approaches[1], nil
    for _, approach in ipairs(approaches) do
        local arrival = copy_position(approach.arrival_position)
        if arrival ~= nil then
            for _, candidate in ipairs(candidates or {}) do
                local cost = spatial_distance(arrival, candidate)
                if selected_cost == nil or cost < selected_cost then
                    selected, selected_cost = approach, cost
                end
            end
        end
    end
    return selected
end

local function arrow_vector(current, target, heading)
    local dx = target.x - current.x
    -- OddQ stores the live vertical axis in y, opposite the player-facing
    -- screen cue: lower raw y is above the player.
    local display_dy = -((target.y or 0) - (current.y or 0))
    local dz = target.z - current.z
    local horizontal_distance = math.sqrt((dx * dx) + (dz * dz))
    local distance = spatial_distance(current, target)
    local vertical_ratio = distance > 0.000001 and display_dy / distance or 0
    if horizontal_distance <= 0.000001 then
        return { x = 0, y = -1 }, { x = 0, y = vertical_ratio, z = 0 }, distance
    end
    local relative = normalize_angle(atan2(dx, dz) - heading)
    local horizontal_ratio = horizontal_distance / distance
    local vector = {
        x = math.sin(relative),
        y = -math.cos(relative),
    }
    return vector, {
        x = vector.x * horizontal_ratio,
        y = vertical_ratio,
        z = -vector.y * horizontal_ratio,
    }, distance
end

function step_pointer.mount_action(live_context, mount_name)
    local live = type(live_context) == "table" and live_context or {}
    if live.is_mounted == true then
        return {
            label = "Dismount",
            command = "/dismount",
            variant = "secondary",
        }
    end
    if live.is_mounted ~= false or not mount_zones.contains(live.current_zone_id) then
        return nil
    end
    mount_name = tostring(mount_name or DEFAULT_MOUNT_NAME)
    if mount_name == "" then
        return nil
    end
    return {
        label = "Mount",
        command = string.format('/mount "%s"', mount_name),
        variant = "primary",
    }
end

function step_pointer.build(objective, guidance, live_context)
    local step, index, selected_index, candidates, unavailable_reason = next_destination(objective, guidance)
    if step == nil then
        return { available = false, reason = unavailable_reason or "guide_has_no_forward_position" }
    end

    local live = type(live_context) == "table" and live_context or {}
    local target_zone = tonumber((step or {}).zone_id)
    local current_zone = tonumber(live.current_zone_id)
    local default_approach = select_zone_approach(target_zone, candidates)
    local preferred_warp_zone = tonumber((step or {}).preferred_warp_zone_id)
        or tonumber((default_approach or {}).zone_id)
    local preferred_warp_position = copy_position((step or {}).preferred_warp_position)
        or copy_position((default_approach or {}).position)
    local preferred_warp_destination_alias = tostring(
        (step or {}).preferred_warp_destination_alias or ""
    )
    if preferred_warp_destination_alias == "" then
        preferred_warp_destination_alias = tostring(
            (default_approach or {}).preferred_warp_destination_alias or ""
        )
    end
    local using_warp_approach = target_zone ~= nil
        and current_zone ~= nil
        and target_zone ~= current_zone
        and preferred_warp_zone ~= nil
        and preferred_warp_position ~= nil
    local target_map = tonumber((step or {}).target_map_id)
    local current_map = tonumber(live.current_map_id or live.map_id or live.map_index or live.map_page)
    local warp_suppressed = (step or {}).warp_suppressed == true
        or tostring((step or {}).route_mode or ""):upper() == "NO_WARP"
    if live.current_position_available == false then
        return { available = false, reason = "live_position_unavailable" }
    end

    local current = copy_position(live.current_position)
    -- The crystal is a screen-space cue, so camera heading is the correct
    -- reference whenever Ashita can expose it. Character heading remains the
    -- fail-safe fallback for clients where the view transform is unavailable.
    local heading = tonumber(live.current_camera_heading_yaw)
        or tonumber(live.current_heading_yaw)
    if current == nil or heading == nil then
        return { available = false, reason = "live_direction_unavailable" }
    end
    local local_transit = heavens_tower_transit_target(current_zone, current, target_zone, candidates)
    if local_transit ~= nil then
        candidates = { local_transit }
        using_warp_approach = false
    end
    if target_zone ~= nil
        and current_zone ~= nil
        and target_zone == current_zone
        and target_map ~= nil
        and current_map ~= nil
        and target_map ~= current_map then
        return {
            available = false,
            reason = "target_map_mismatch",
            target_map_label = tostring((step or {}).target_map_label or ("Map " .. tostring(target_map))),
        }
    end

    local map_filtered = {}
    local has_map_specific_candidates = false
    for _, candidate in ipairs(candidates) do
        if candidate.map_id ~= nil then
            has_map_specific_candidates = true
        end
        if candidate.map_id == nil or current_map == nil or candidate.map_id == current_map then
            map_filtered[#map_filtered + 1] = candidate
        end
    end
    if has_map_specific_candidates and current_map ~= nil and #map_filtered == 0 then
        local labels = {}
        for _, option in ipairs((step or {}).target_map_options or {}) do
            labels[#labels + 1] = tostring(option.map_label or ("Map " .. tostring(option.map_id)))
        end
        return {
            available = false,
            reason = "target_map_mismatch",
            target_map_label = table.concat(labels, " / "),
        }
    end
    candidates = map_filtered

    local target, warp, best_cost = nil, nil, nil
    for _, candidate in ipairs(candidates) do
        local route_candidate = using_warp_approach and preferred_warp_position or candidate
        local route_target_zone = local_transit ~= nil and current_zone
            or using_warp_approach and preferred_warp_zone
            or target_zone
        local walking_cost = spatial_distance(current, route_candidate)
        local candidate_warp = nil
        local cost = walking_cost
        if not warp_suppressed and has_authored_warp_stage(step) then
            local planned_warp = uberwarp_routes.plan_stage
                and uberwarp_routes.plan_stage(current_zone, current, step.warp_stages)
                or nil
            candidate_warp = planned_warp
            cost = planned_warp and planned_warp.cost or nil
        elseif route_target_zone ~= nil and current_zone ~= nil and not warp_suppressed then
            if using_warp_approach and route_target_zone == current_zone then
                cost = walking_cost
            else
                local planned_warp = uberwarp_routes.plan(
                    current_zone,
                    current,
                    route_target_zone,
                    route_candidate,
                    nil,
                    preferred_warp_destination_alias
                )
                if route_target_zone ~= current_zone then
                    candidate_warp = planned_warp
                    cost = planned_warp and planned_warp.cost or nil
                elseif planned_warp ~= nil and planned_warp.cost < walking_cost then
                    candidate_warp = planned_warp
                    cost = planned_warp.cost
                end
            end
        elseif route_target_zone ~= nil and current_zone ~= nil and route_target_zone ~= current_zone then
            cost = nil
        end
        if cost ~= nil and (best_cost == nil or cost < best_cost) then
            best_cost, target, warp = cost, route_candidate, candidate_warp
        end
    end
    if target == nil then
        if target_zone ~= nil and current_zone ~= nil and target_zone ~= current_zone then
            target = select_zone_exit(current_zone, target_zone, current)
            if target ~= nil then
                best_cost = spatial_distance(current, target)
            end
        end
    end
    if target == nil then
        return { available = false, reason = "route_data_unavailable" }
    end
    if warp ~= nil then target = warp.source.position end
    local vector, vector_3d, distance = arrow_vector(current, target, heading)
    return {
        available = true,
        step_index = index,
        selected_step_index = selected_index,
        uses_forward_step = index > selected_index,
        uses_backward_step = index < selected_index,
        step_id = tostring((step or {}).step_id or ""),
        target = target,
        target_zone_id = local_transit ~= nil and current_zone
            or using_warp_approach and preferred_warp_zone
            or target.to_zone_id ~= nil and current_zone
            or target_zone,
        current = current,
        distance = distance,
        distance_label = string.format("%.1fy", distance),
        position_kind = tostring(target.position_kind ~= "" and target.position_kind or (step or {}).position_kind or "exact_target"),
        position_label = compact_position_label(
            warp == nil and not using_warp_approach and step or nil,
            target
        ),
        position_label_character_limit = POSITION_LABEL_CHARACTER_LIMIT,
        pointer_vector = vector,
        pointer_vector_3d = vector_3d,
        warp_command = warp and warp.command or nil,
        source_label = warp and warp.source_label or nil,
        destination_label = warp and warp.destination_label or nil,
        route_label = warp and (
            compact_route_label(warp.source_label)
                .. " > "
                .. compact_route_label(warp.destination_label)
        ) or nil,
        warp_available = warp ~= nil and distance <= WARP_USE_RANGE_YALMS,
        uses_local_transit = local_transit ~= nil,
        uses_zone_exit_fallback = target.to_zone_id ~= nil,
    }
end

local function draw_arrow(imgui, cue)
    if imgui.GetWindowDrawList == nil or imgui.GetCursorScreenPos == nil then
        return false
    end
    local draw = imgui.GetWindowDrawList()
    if draw == nil or draw.AddTriangleFilled == nil then
        return false
    end

    local x, y = imgui.GetCursorScreenPos()
    local center = { x + 34, y + 34 }
    crystal_pointer.draw(imgui, draw, center, cue)
    if imgui.Dummy ~= nil then
        imgui.Dummy({ 72, 68 })
    end
    return true
end

local function pointer_text(imgui, color, value, wrap_position)
    if imgui.PushTextWrapPos ~= nil or imgui.TextWrapped ~= nil then
        imgui_text.colored_wrapped_at(imgui, color, value, wrap_position)
        return
    end
    imgui_text.colored(imgui, color, value)
end

local function render_mount_action(imgui, action, on_action, width)
    if type(action) ~= "table" then
        return false
    end
    local id = action.label == "Dismount"
        and "Dismount##oddq_step_pointer_dismount"
        or "Mount##oddq_step_pointer_mount"
    if skin.button(imgui, id, action.variant or "secondary", { width or 72.0, 0.0 }) then
        if type(on_action) == "function" then
            on_action(action.command)
        end
        return true
    end
    return false
end

function step_pointer.render(imgui, objective, guidance, live_context, on_action)
    if imgui == nil or imgui.Begin == nil or imgui.End == nil then
        return
    end
    local cue = step_pointer.build(objective, guidance, live_context)
    local mount_action = step_pointer.mount_action(live_context)

    local flags = (tonumber(ImGuiWindowFlags_NoResize) or 0)
        + (tonumber(ImGuiWindowFlags_NoScrollbar) or 0)
    local layout = skin.layout.step_pointer or {}
    local width = tonumber(layout.width) or 300.0
    local height = tonumber(layout.height) or 146.0
    if imgui.SetNextWindowSize ~= nil then
        imgui.SetNextWindowSize({ width, height }, ImGuiCond_Always)
    end

    local pushed = skin.push_window(imgui)
    local visible = window_state.begin(imgui, "OddQ Step Pointer", true, flags)
    local font_scaled = false
    if visible and imgui.SetWindowFontScale ~= nil then
        local base_size = tonumber(layout.fallback_text_size) or 16.0
        if imgui.GetFontSize ~= nil then
            base_size = tonumber(imgui.GetFontSize()) or base_size
        end
        local reduction = math.max(0.0, tonumber(layout.text_size_reduction) or 2.0)
        imgui.SetWindowFontScale(math.max(0.5, (base_size - reduction) / base_size))
        font_scaled = true
    end
    if visible then
        if cue.available == true then
            if imgui.BeginGroup ~= nil then imgui.BeginGroup() end
            draw_arrow(imgui, cue)
            local paired_actions = cue.warp_available and mount_action ~= nil
            local action_width = paired_actions and 36.0 or 72.0
            if cue.warp_available and skin.button(
                imgui,
                "Warp##oddq_step_pointer_warp",
                "primary",
                { action_width, 0.0 }
            ) then
                if type(on_action) == "function" then on_action(cue.warp_command) end
            end
            if paired_actions and imgui.SameLine ~= nil then imgui.SameLine(0.0, 0.0) end
            render_mount_action(imgui, mount_action, on_action, action_width)
            if imgui.EndGroup ~= nil then imgui.EndGroup() end
            if imgui.SameLine ~= nil then imgui.SameLine() end
            if imgui.BeginGroup ~= nil then imgui.BeginGroup() end
            local wrap_position = width - (tonumber(layout.text_right_inset) or 14.0)
            if imgui.GetWindowWidth ~= nil then
                wrap_position = (tonumber(imgui.GetWindowWidth()) or width)
                    - (tonumber(layout.text_right_inset) or 14.0)
            end
            pointer_text(imgui, skin.colors.blue_highlight, cue.position_label, wrap_position)
            pointer_text(imgui, skin.colors.text, "Dist: " .. cue.distance_label, wrap_position)
            if cue.route_label ~= nil then
                pointer_text(imgui, skin.colors.text, cue.route_label, wrap_position)
            end
            if imgui.EndGroup ~= nil then imgui.EndGroup() end
        else
            local messages = {
                guide_has_no_forward_position = "Guide has no POS.",
                step_pointer_suppressed = "Follow the only exit.",
                live_position_unavailable = "Waiting for POS.",
                live_direction_unavailable = "Waiting for heading.",
                route_data_unavailable = "Route data unavailable.",
            }
            local message = messages[cue.reason] or "Open a guide with POS."
            if cue.reason == "target_map_mismatch" then
                message = "Reach " .. tostring(cue.target_map_label or "the target map") .. " first."
            end
            local wrap_position = width - (tonumber(layout.text_right_inset) or 14.0)
            pointer_text(imgui, skin.colors.blue_highlight, "OddQ Pointer", wrap_position)
            pointer_text(
                imgui,
                skin.colors.text,
                message,
                wrap_position
            )
            render_mount_action(imgui, mount_action, on_action)
        end
    end
    if font_scaled then
        imgui.SetWindowFontScale(1.0)
    end
    imgui.End()
    skin.pop(imgui, pushed)
end

return step_pointer
