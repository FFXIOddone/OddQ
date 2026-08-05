local step_pointer = {}

local imgui_text = require("ui/imgui_text")
local skin = require("ui/skin")
local window_state = require("ui/window_state")
local uberwarp_routes = require("uberwarp_routes")

local PI = math.pi
local TWO_PI = PI * 2
local WARP_USE_RANGE_YALMS = 6.0

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

local function compact_position_label(step, target)
    local grid = compact_grid_label(step)
    if grid ~= "" then
        return grid
    end
    local function rounded(value)
        value = tonumber(value) or 0
        if value < 0 then
            return math.ceil(value - 0.5)
        end
        return math.floor(value + 0.5)
    end
    return string.format(
        "X(%d) Y(%d) Z(%d)",
        rounded(target.x),
        rounded(target.y),
        rounded(target.z)
    )
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
    return { x = x, y = y or 0, z = z }
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

local function next_destination(objective, guidance)
    local steps, selected = selected_step_index(objective, guidance)
    if steps == nil then return nil end
    if (steps[selected] or {}).pointer_suppressed == true then
        return nil, nil, selected, nil, "step_pointer_suppressed"
    end
    for index = selected, #steps do
        local positions = step_positions(steps[index])
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

local function arrow_vector(current, target, heading)
    local dx = target.x - current.x
    local dz = target.z - current.z
    local distance = math.sqrt((dx * dx) + (dz * dz))
    if distance <= 0.000001 then
        return { x = 0, y = 0 }, distance
    end
    local relative = normalize_angle(atan2(dx, dz) - heading)
    return {
        x = math.sin(relative),
        y = -math.cos(relative),
    }, distance
end

function step_pointer.build(objective, guidance, live_context)
    local step, index, selected_index, candidates, unavailable_reason = next_destination(objective, guidance)
    if step == nil then
        return { available = false, reason = unavailable_reason or "guide_has_no_forward_position" }
    end

    local live = type(live_context) == "table" and live_context or {}
    local target_zone = tonumber((step or {}).zone_id)
    local current_zone = tonumber(live.current_zone_id)
    if live.current_position_available == false then
        return { available = false, reason = "live_position_unavailable" }
    end

    local current = copy_position(live.current_position)
    local heading = tonumber(live.current_heading_yaw)
    if current == nil or heading == nil then
        return { available = false, reason = "live_direction_unavailable" }
    end

    local target, warp, best_cost = nil, nil, nil
    for _, candidate in ipairs(candidates) do
        local dx, dz = candidate.x - current.x, candidate.z - current.z
        local walking_cost = math.sqrt((dx * dx) + (dz * dz))
        local candidate_warp = nil
        local cost = walking_cost
        if target_zone ~= nil and current_zone ~= nil then
            local planned_warp = uberwarp_routes.plan(current_zone, current, target_zone, candidate)
            if target_zone ~= current_zone then
                candidate_warp = planned_warp
                cost = planned_warp and planned_warp.cost or nil
            elseif planned_warp ~= nil and planned_warp.cost < walking_cost then
                candidate_warp = planned_warp
                cost = planned_warp.cost
            end
        end
        if cost ~= nil and (best_cost == nil or cost < best_cost) then
            best_cost, target, warp = cost, candidate, candidate_warp
        end
    end
    if target == nil then return { available = false, reason = "no_uberwarp_route" } end
    if warp ~= nil then target = warp.source.position end
    local vector, distance = arrow_vector(current, target, heading)
    return {
        available = true,
        step_index = index,
        selected_step_index = selected_index,
        uses_forward_step = index ~= selected_index,
        step_id = tostring((step or {}).step_id or ""),
        target = target,
        target_zone_id = target_zone,
        current = current,
        distance = distance,
        distance_label = string.format("%.1fy", distance),
        position_kind = tostring((step or {}).position_kind or "exact_target"),
        position_label = compact_position_label(warp == nil and step or nil, target),
        pointer_vector = vector,
        warp_command = warp and warp.command or nil,
        source_label = warp and warp.source_label or nil,
        destination_label = warp and warp.destination_label or nil,
        route_label = warp and (
            compact_route_label(warp.source_label)
                .. " > "
                .. compact_route_label(warp.destination_label)
        ) or nil,
        warp_available = warp ~= nil and distance <= WARP_USE_RANGE_YALMS,
    }
end

local function color_u32(imgui, color)
    if imgui.GetColorU32 ~= nil then
        return imgui.GetColorU32(color)
    end
    return color
end

local function draw_arrow(imgui, cue)
    if imgui.GetWindowDrawList == nil or imgui.GetCursorScreenPos == nil then
        return false
    end
    local draw = imgui.GetWindowDrawList()
    if draw == nil or draw.AddLine == nil or draw.AddTriangleFilled == nil then
        return false
    end

    local x, y = imgui.GetCursorScreenPos()
    local center = { x + 34, y + 34 }
    local forward = cue.pointer_vector
    local right = { x = -forward.y, y = forward.x }
    local function point(along, across)
        return {
            center[1] + (forward.x * along) + (right.x * across),
            center[2] + (forward.y * along) + (right.y * across),
        }
    end

    draw:AddLine(point(-22, 0), point(4, 0), color_u32(imgui, skin.colors.blue), 10)
    draw:AddTriangleFilled(
        point(28, 0),
        point(-2, -15),
        point(-2, 15),
        color_u32(imgui, skin.colors.blue_highlight)
    )
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

function step_pointer.render(imgui, objective, guidance, live_context, on_warp)
    if imgui == nil or imgui.Begin == nil or imgui.End == nil then
        return
    end
    local cue = step_pointer.build(objective, guidance, live_context)

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
            if cue.warp_available and skin.button(
                imgui,
                "Warp##oddq_step_pointer_warp",
                "primary",
                { 72.0, 0.0 }
            ) then
                if type(on_warp) == "function" then on_warp(cue.warp_command) end
            end
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
                no_uberwarp_route = "No HP/SG route.",
            }
            local wrap_position = width - (tonumber(layout.text_right_inset) or 14.0)
            pointer_text(imgui, skin.colors.blue_highlight, "OddQ Pointer", wrap_position)
            pointer_text(
                imgui,
                skin.colors.text,
                messages[cue.reason] or "Open a guide with POS.",
                wrap_position
            )
        end
    end
    if font_scaled then
        imgui.SetWindowFontScale(1.0)
    end
    imgui.End()
    skin.pop(imgui, pushed)
end

return step_pointer
