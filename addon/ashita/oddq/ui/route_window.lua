local route_window = {}
local imgui_text = require("ui/imgui_text")
local skin = require("ui/skin")
local objective_catalog_loaded, objective_catalog = pcall(require, "objective_catalog")
if not objective_catalog_loaded or type(objective_catalog) ~= "table" then
    objective_catalog = nil
end

-- Read-only parser; no route visuals, movement, targeting, or trading.

local section_header
local label_value

local zone_names_loaded, zone_names = pcall(require, "data/zone_names")
if not zone_names_loaded then
    zone_names = {}
end

local function safe_text(value)
    local value_type = type(value)
    if value_type == "nil" or value_type == "function" or value_type == "thread" or value_type == "userdata" or value_type == "table" then
        return ""
    end

    local text = tostring(value)
    if text == "" or text:match("^function:") then
        return ""
    end
    return text
end

local function is_blank(value)
    return safe_text(value) == ""
end

local function runtime_state(state)
    state = type(state) == "table" and state or {}
    if objective_catalog == nil
        or type(objective_catalog.to_runtime_objective) ~= "function"
        or type(state.objective) ~= "table" then
        return state
    end

    local objective = objective_catalog.to_runtime_objective(state.objective)
    if objective == nil or objective == state.objective then
        return state
    end

    local projected = {}
    for key, value in pairs(state) do
        projected[key] = value
    end
    projected.objective = objective
    return projected
end

local function format_identifier(value)
    if is_blank(value) then
        return "?"
    end

    local text = safe_text(value)
    if text:match("^zone_line:") then
        return "Zone line"
    end
    text = text:gsub("_", " ")
    text = text:gsub("(%a)([%w']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)
    return text
end

local function zone_display(zone_id)
    local normalized = tonumber(zone_id)
    if normalized ~= nil and zone_names[normalized] ~= nil then
        return tostring(zone_names[normalized]) .. " (" .. tostring(normalized) .. ")"
    end
    local text = safe_text(zone_id)
    return text ~= "" and text or "?"
end

local function objective_label(objective)
    if type(objective) ~= "table" then
        return "No objective tracked"
    end

    local quest_name = safe_text(objective.quest_name)
    if quest_name ~= "" then
        return quest_name
    end
    local objective_id = safe_text(objective.objective_id)
    return objective_id ~= "" and objective_id or "No objective tracked"
end

function route_window.should_use_step_guide(objective)
    return type(objective) == "table" and type(objective.steps) == "table" and #objective.steps > 1
end

local function step_label(objective)
    if type(objective) ~= "table" then
        return "No objective"
    end

    if not is_blank(objective.instruction) then
        return safe_text(objective.instruction)
    end

    local parts = {
        safe_text(objective.step_kind),
    }
    if #parts == 0 or parts[1] == "" then
        return "Review objective details."
    end
    return table.concat(parts, " ")
end

local function endpoint_label(value, objective)
    if value == nil then
        return "?"
    end

    local text = safe_text(value)
    if text == "current_position" then
        return "Current position"
    end
    if text == "objective" then
        if type(objective) == "table" and not is_blank(objective.npc_name) then
            return safe_text(objective.npc_name)
        end
        if type(objective) == "table" and not is_blank(objective.quest_name) then
            return safe_text(objective.quest_name)
        end
        return "Objective"
    end
    if text == "arrival" then
        return "Zone arrival"
    end

    local as_zone = tonumber(text)
    if as_zone ~= nil then
        return zone_display(as_zone)
    end

    return format_identifier(text)
end

local function method_label(method)
    if is_blank(method) then
        return nil
    end
    return format_identifier(method)
end

local function floor_footnote(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "table" then
            local floor = value.map_floor or value.floor or value.map_layer or value.layer
            if not is_blank(floor) then
                return safe_text(floor)
            end
        end
    end

    return "M"
end

local function map_reference(segment, objective)
    if type(segment) == "table" and not is_blank(segment.map_grid) then
        return safe_text(segment.map_grid) .. " " .. floor_footnote(segment, objective)
    end
    if type(segment) == "table" and not is_blank(segment.destination_map_grid) then
        return safe_text(segment.destination_map_grid) .. " " .. floor_footnote(segment, objective)
    end
    if type(objective) == "table" and tostring(segment.to or "") == "objective" and not is_blank(objective.map_grid) then
        return safe_text(objective.map_grid) .. " " .. floor_footnote(objective, segment)
    end

    return ""
end

local function segment_details(segment, objective)
    if type(segment) ~= "table" then
        return {
            action = "no cached route",
            route_zone = "",
            map_ref = "",
        }
    end

    local destination = endpoint_label(segment.to, objective)
    if not is_blank(segment.destination_label) then
        destination = tostring(segment.destination_label)
    end
    local action
    if segment.type == "teleport" then
        local method = method_label(segment.method)
        if method ~= nil then
            action = "Teleport via " .. method .. " -> " .. destination
        else
            action = "Teleport -> " .. destination
        end
    elseif segment.type == "zone_line" then
        action = "Zone line -> " .. destination
    else
        action = "Walk -> " .. destination
    end

    return {
        action = action,
        route_zone = zone_display(segment.zone_id),
        map_ref = map_reference(segment, objective),
    }
end

local function prerequisites_label(objective)
    if type(objective) ~= "table" then
        return "None listed"
    end

    local parts = {}
    local prerequisites = {}
    if type(objective.prerequisites) == "table" then
        prerequisites = objective.prerequisites
    end

    local level_min = tonumber(objective.level_min)
    if level_min == nil or level_min <= 0 then
        level_min = tonumber(prerequisites.level_min) or 0
    end
    local level_max = tonumber(objective.level_max)
    if level_max == nil or level_max <= 0 then
        level_max = tonumber(prerequisites.level_max) or 0
    end
    local objective_kind = safe_text(objective["objective_kind"])
    if objective.level_requirement_unknown == true then
        level_min = 0
        level_max = 0
        table.insert(parts, "Level: Unknown")
    elseif objective_kind == "mission" and level_min <= 1 and level_max <= 0 then
        level_min = 0
    end
    if objective.level_requirement_unknown == true then
        -- The truthful unknown label was added above; do not invent a range.
    elseif level_min > 0 and level_max > 0 then
        table.insert(parts, "Lv." .. tostring(level_min) .. "-" .. tostring(level_max))
    elseif level_min > 0 then
        table.insert(parts, "Lv." .. tostring(level_min) .. "+")
    elseif level_max > 0 then
        table.insert(parts, "Up to Lv." .. tostring(level_max))
    end
    local job_requirement = safe_text(objective.job_requirement)
    if job_requirement ~= "" then
        table.insert(parts, "Job: " .. job_requirement)
    end

    local function append_list(label, values)
        if type(values) ~= "table" then
            return
        end
        local rows = {}
        for _, value in ipairs(values) do
            local text = safe_text(value)
            if text ~= "" then
                table.insert(rows, text)
            end
        end
        if #rows > 0 then
            table.insert(parts, label .. ": " .. table.concat(rows, ", "))
        end
    end
    append_list("Fame", prerequisites.fame)
    append_list("Quests", prerequisites.quests_completed)
    append_list("Missions", prerequisites.missions_completed)
    append_list("Transport", prerequisites.transport_unlocks)

    if #parts == 0 then
        return "None listed"
    end
    return table.concat(parts, "; ")
end

local function rounded_tenth(value)
    local number = tonumber(value)
    if number == nil then
        return nil
    end
    return string.format("%.1f", math.floor((number * 10) + 0.5) / 10)
end

local function map_grid_label(source)
    if type(source) ~= "table" then
        return ""
    end

    local map_grid = safe_text(source.map_grid)
    if map_grid == "" then
        return ""
    end
    if map_grid:match("[A-Za-z]+/[A-Za-z]+%-[0-9]+") then
        return ""
    end
    local tokens = {}
    local seen = {}
    for token in map_grid:gmatch("[A-Za-z]+%-[0-9]+") do
        token = token:upper()
        if seen[token] ~= true then
            seen[token] = true
            table.insert(tokens, token)
        end
    end
    if #tokens == 0 then
        return ""
    end
    return "(" .. table.concat(tokens, "/") .. ")"
end

local function target_map_label(source)
    if type(source) ~= "table" then
        return ""
    end

    local label = safe_text(source.target_map_label)
    if label ~= "" then
        return label
    end
    local map_id = tonumber(source.target_map_id)
    if map_id == nil or map_id <= 0 then
        return ""
    end
    return "Map " .. tostring(math.floor(map_id))
end

local function location_label(source, mark_missing_map)
    local map = target_map_label(source)
    local grid = map_grid_label(source)
    if map ~= "" and grid ~= "" then
        return map .. " - " .. grid
    end
    if map ~= "" then
        return map
    end
    if grid ~= "" and mark_missing_map == true then
        return grid .. " - map not recorded"
    end
    return grid
end

local function step_location_line(step)
    local location = location_label(step, true)
    if location == "" then
        return nil
    end
    return "Location: " .. location
end

local function named_map_grid_label(source)
    local name = safe_text((source or {}).name)
    if name == "" then
        return ""
    end

    local location = location_label(source, true)
    if location == "" then
        return name
    end
    return name .. " - " .. location
end

local function normalized_name(value)
    local text = safe_text(value):lower()
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function list_has_values(values)
    return type(values) == "table" and #values > 0
end

local function append_known_names(rows, values)
    if type(values) ~= "table" then
        return
    end
    for _, value in ipairs(values) do
        local text = safe_text(value)
        if text ~= "" then
            table.insert(rows, text)
        end
    end
end

local function known_requirement_state(state)
    state = state or {}
    local known_items = {}
    local known_key_items = {}

    append_known_names(known_items, state.known_items)
    append_known_names(known_items, (state.known_transport_flags or {}).items)
    append_known_names(known_key_items, state.known_key_items)
    append_known_names(known_key_items, state.key_items)

    local item_lookup = {}
    for _, item in ipairs(known_items) do
        item_lookup[normalized_name(item)] = true
    end
    local key_item_lookup = {}
    for _, item in ipairs(known_key_items) do
        key_item_lookup[normalized_name(item)] = true
    end

    return {
        known_items = known_items,
        known_key_items = known_key_items,
        item_lookup = item_lookup,
        key_item_lookup = key_item_lookup,
    }
end

local function missing_requirement(values, lookup)
    if type(values) ~= "table" then
        return nil
    end
    for _, value in ipairs(values) do
        local text = safe_text(value)
        if text ~= "" and lookup[normalized_name(text)] ~= true then
            return text
        end
    end
    return nil
end

local function has_requirement_fields(step)
    return type(step) == "table"
        and (list_has_values(step.required_items) or list_has_values(step.required_key_items))
end

local function objective_has_requirements(objective)
    if type(objective) ~= "table" or type(objective.steps) ~= "table" then
        return false
    end
    for _, step in ipairs(objective.steps) do
        if has_requirement_fields(step) then
            return true
        end
    end
    return false
end

local function requirement_prefix(step, known)
    if not has_requirement_fields(step) then
        return ""
    end

    local missing_item = missing_requirement(step.required_items, known.item_lookup)
    local missing_key_item = missing_requirement(step.required_key_items, known.key_item_lookup)
    local has_item_requirement = list_has_values(step.required_items)
    local has_key_item_requirement = list_has_values(step.required_key_items)

    if missing_item == nil and missing_key_item == nil then
        if has_item_requirement and has_key_item_requirement then
            return "[Have requirements] "
        end
        if has_key_item_requirement then
            return "[Have key item] "
        end
        if has_item_requirement then
            return "[Have item] "
        end
    end

    return ""
end

local function list_label(values)
    if type(values) ~= "table" or #values == 0 then
        return "none"
    end
    return table.concat(values, ", ")
end

local function requirement_summary_lines(objective, known)
    local lines = {}
    if not objective_has_requirements(objective) and #known.known_items == 0 and #known.known_key_items == 0 then
        return lines
    end

    local next_missing = nil
    if type(objective) == "table" and type(objective.steps) == "table" then
        for _, step in ipairs(objective.steps) do
            next_missing = missing_requirement(step.required_items, known.item_lookup)
            if next_missing ~= nil then
                break
            end
            next_missing = missing_requirement(step.required_key_items, known.key_item_lookup)
            if next_missing ~= nil then
                break
            end
        end
    end
    if next_missing == nil then
        next_missing = "none"
    end

    table.insert(lines, "Items checked: " .. list_label(known.known_items))
    table.insert(lines, "Key items checked: " .. list_label(known.known_key_items))
    table.insert(lines, "Next missing: " .. next_missing)
    return lines
end

local function checkpoint_label(npc_status)
    if type(npc_status) ~= "table" then
        return ""
    end

    local name = safe_text(npc_status.name)
    if name == "" then
        return ""
    end

    local status = safe_text(npc_status.status)
    if status == "no_checkpoint" then
        return ""
    end

    if status == "found" then
        local parts = {
            "Next checkpoint: " .. named_map_grid_label(npc_status),
        }
        table.insert(parts, "nearby")
        local distance = rounded_tenth(npc_status.distance)
        if distance ~= nil then
            parts[#parts] = parts[#parts] .. " " .. distance .. " yalms"
        end
        if npc_status.targeted == true then
            table.insert(parts, "targeted")
        end
        return table.concat(parts, " - ")
    end

    name = named_map_grid_label(npc_status)

    if status == "wrong_zone" then
        return "Next checkpoint: " .. name .. " - go to " .. zone_display(npc_status.zone_id)
    end

    if status == "scanner_unavailable" then
        return "Next checkpoint: " .. name .. " - scanner unavailable"
    end

    return "Next checkpoint: " .. name .. " - not visible nearby"
end

local function active_segment_summary(route, active_index, objective)
    local segments = route.segments or {}
    if #segments == 0 then
        local details = segment_details(nil, objective)
        return "0/0", details.action, details.route_zone, details.map_ref
    end

    if active_index < 1 then
        active_index = 1
    end
    if active_index > #segments then
        active_index = #segments
    end
    local details = segment_details(segments[active_index], objective)
    return tostring(active_index) .. "/" .. tostring(#segments), details.action, details.route_zone, details.map_ref
end

local function route_plan_lines(route, active_index, objective)
    local segments = route.segments or {}
    local lines = {}
    if #segments == 0 then
        return lines
    end

    if active_index < 1 then
        active_index = 1
    end
    if active_index > #segments then
        active_index = #segments
    end

    local stop_index = active_index + 4
    if stop_index > #segments then
        stop_index = #segments
    end

    for index = active_index, stop_index do
        local details = segment_details(segments[index], objective)
        table.insert(lines, tostring(index) .. ". " .. details.action)
    end
    if stop_index < #segments then
        table.insert(lines, "... " .. tostring(#segments - stop_index) .. " more; /odd next advances")
    end
    return lines
end

local function plan_lines(plan)
    if type(plan) ~= "table" or type(plan.actions) ~= "table" or #plan.actions == 0 then
        return {}
    end
    local lines = { "Plan: " .. tostring(plan.selection_note or "OddQ recommendations") }
    for index, action in ipairs(plan.actions) do
        local objective = action.objective or {}
        table.insert(lines, tostring(index) .. ". " .. tostring(action.mode or "objective") .. ": " .. tostring(objective.quest_name or objective.objective_id or "unknown"))
    end
    return lines
end

local function step_line(step, index, known)
    if type(step) ~= "table" then
        return nil
    end

    local instruction = step.instruction
    if is_blank(instruction) then
        return nil
    end

    local prefix = requirement_prefix(step, known or { item_lookup = {}, key_item_lookup = {} })
    local line = tostring(index) .. ". " .. prefix .. safe_text(instruction)
    return line
end

local function step_note_lines(step)
    local lines = {}
    if type(step) ~= "table" or type(step.notes) ~= "table" then
        return lines
    end

    for _, note in ipairs(step.notes) do
        local text = safe_text(note)
        if text ~= "" then
            table.insert(lines, "   - " .. text)
        end
    end
    return lines
end

local function step_target_name(step)
    if type(step) ~= "table" then
        return ""
    end

    local npc_name = safe_text(step.npc_name)
    if npc_name ~= "" then
        return npc_name
    end
    local object_name = safe_text(step.object_name)
    if object_name ~= "" then
        return object_name
    end
    local mob_name = safe_text(step.mob_name)
    if mob_name ~= "" then
        return mob_name
    end
    return safe_text(step.target_name)
end

local function tab_label_for_step(step, index)
    local target_name = step_target_name(step)
    if target_name ~= "" then
        return tostring(index) .. " " .. target_name
    end

    return tostring(index) .. " Step"
end

local function clamp_step_tab_index(guidance, max_index)
    if type(guidance) ~= "table" then
        return max_index > 0 and 1 or 0
    end

    local selected = math.floor(tonumber(guidance.guide_step_tab_index) or 1)
    if max_index <= 0 then
        selected = 0
    elseif selected < 1 then
        selected = 1
    elseif selected > max_index then
        selected = max_index
    end
    guidance.guide_step_tab_index = selected
    return selected
end

local function detail_layout()
    return skin.layout.detailed_information or { gap = 7.0, wrap_inset = 16.0 }
end

local function detail_number(key, fallback)
    local layout = detail_layout()
    return tonumber(layout[key]) or fallback
end

local function detail_gap(imgui, amount)
    if imgui ~= nil and imgui.Dummy ~= nil and amount ~= nil and amount > 0 then
        imgui.Dummy({ 1.0, amount })
    end
end

local function detail_context(imgui)
    local context = {
        base_x = 0.0,
    }
    if imgui ~= nil and imgui.GetCursorScreenPos ~= nil then
        local x = imgui.GetCursorScreenPos()
        context.base_x = tonumber(x) or 0.0
    end
    return context
end

local function detail_set_indent(imgui, context, indent)
    if imgui == nil or imgui.GetCursorScreenPos == nil or imgui.SetCursorScreenPos == nil then
        return
    end
    context = context or detail_context(imgui)
    local _, y = imgui.GetCursorScreenPos()
    local x = (context.base_x or 0.0) + detail_number("padding_x", 0.0) + (tonumber(indent) or 0.0)
    imgui.SetCursorScreenPos({ x, y })
end

local function detail_wrap_x(imgui, indent)
    if imgui ~= nil and imgui.GetWindowWidth ~= nil then
        return math.max(
            0.0,
            (tonumber(imgui.GetWindowWidth()) or 0.0)
                - detail_number("wrap_inset", 16.0)
                - detail_number("padding_x", 0.0)
                - (tonumber(indent) or 0.0)
        )
    end
    return nil
end

local function detail_text(imgui, value, context, indent)
    indent = indent or detail_number("body_indent_x", 0.0)
    detail_set_indent(imgui, context, indent)
    local wrap_x = detail_wrap_x(imgui, indent)
    if wrap_x ~= nil then
        skin.text_wrapped_at(imgui, value, wrap_x, "body")
        return
    end
    skin.text_wrapped(imgui, value, "body")
end

local function detail_section_header(imgui, label, context)
    detail_gap(imgui, detail_number("section_top_gap", 0.0))
    if imgui ~= nil and imgui.Separator ~= nil then
        imgui.Separator()
    end
    detail_gap(imgui, detail_number("section_gap", 0.0))
    detail_set_indent(imgui, context, detail_number("title_indent_x", 0.0))
    skin.text_colored(imgui, skin.colors.blue_highlight, tostring(label or ""), "section")
    detail_gap(imgui, detail_number("section_bottom_gap", 0.0))
end

local function detail_button_size(height_key, width_key)
    local width = detail_number(width_key or "tab_button_min_width", 0.0)
    local height = detail_number(height_key, 0.0)
    if width <= 0.0 and height <= 0.0 then
        return nil
    end
    return { width, height }
end

local function detail_same_line(imgui, gap)
    if imgui == nil or imgui.SameLine == nil then
        return
    end
    gap = gap or detail_number("gap", 7.0)
    local ok = pcall(imgui.SameLine, 0.0, gap)
    if not ok then
        imgui.SameLine()
    end
end

local function render_guide_step(imgui, objective, selected, max_index, known, context)
    local step = ((objective or {}).steps or {})[selected]
    if type(step) ~= "table" then
        return
    end

    local target = tab_label_for_step(step, selected):gsub("^%d+%s+", "")
    local heading = target ~= "Step" and target
        or ("Step " .. tostring(selected) .. " of " .. tostring(max_index))
    detail_section_header(imgui, heading, context)
    detail_gap(imgui, detail_number("step_body_gap", 4.0))
    local line = step_line(step, selected, known)
    if line ~= nil then
        line = line:gsub("^%d+%.%s*", "")
        detail_text(imgui, line, context, detail_number("body_indent_x", 0.0))
    end
    local location = step_location_line(step)
    if location ~= nil then
        detail_gap(imgui, detail_number("note_gap", 2.0))
        detail_text(imgui, location, context, detail_number("note_indent_x", 0.0))
    end
    for _, note_line in ipairs(step_note_lines(step)) do
        detail_gap(imgui, detail_number("note_gap", 2.0))
        detail_text(imgui, note_line, context, detail_number("note_indent_x", 0.0))
    end
end

local function render_step_navigation(imgui, guidance, objective, selected, max_index, on_command)
    if imgui.Button == nil then
        return
    end

    detail_gap(imgui, detail_number("nav_top_gap", 4.0))
    local mission = safe_text(objective.objective_kind) == "mission"
    local previous_enabled = selected > 1 or mission
    local previous_label = selected == 1 and mission and "Previous Mission" or "Previous"
    if skin.button(imgui, previous_label .. "##oddq_guide_prev", previous_enabled and "secondary" or "disabled", detail_button_size("nav_button_height", "nav_button_width")) then
        if selected > 1 then
            guidance.guide_step_tab_index = selected - 1
        elseif type(on_command) == "function" then
            on_command({ "previous" })
        end
    end
    detail_same_line(imgui, detail_number("nav_button_gap", 7.0))
    local next_enabled = selected < max_index or mission
    local next_label = selected == max_index and mission and "Next Mission" or "Next"
    if skin.button(imgui, next_label .. "##oddq_guide_next", next_enabled and "primary" or "disabled", detail_button_size("nav_button_height", "nav_button_width")) then
        if selected < max_index then
            guidance.guide_step_tab_index = selected + 1
        elseif type(on_command) == "function" then
            on_command({ "next" })
        end
    end
    detail_gap(imgui, detail_number("nav_bottom_gap", 4.0))
end

local function render_step_guide(imgui, state, summary, known, on_command)
    local objective = state.objective or {}
    local guidance = state.guidance or {}
    state.guidance = guidance

    local max_index = 0
    if type(objective.steps) == "table" then
        max_index = #objective.steps
    end
    local selected = clamp_step_tab_index(guidance, max_index)
    local context = detail_context(imgui)

    detail_gap(imgui, detail_number("padding_y", 0.0))
    detail_gap(imgui, detail_number("content_top_gap", 0.0))
    render_guide_step(imgui, objective, selected, max_index, known, context)
    render_step_navigation(imgui, guidance, objective, selected, max_index, on_command)
    detail_gap(imgui, detail_number("content_bottom_gap", 0.0))
end

local function objective_step_lines(objective, known)
    local lines = {}
    if type(objective) ~= "table" then
        return lines
    end

    if type(objective.steps) == "table" and #objective.steps > 0 then
        for index, step in ipairs(objective.steps) do
            local line = step_line(step, index, known)
            if line ~= nil then
                table.insert(lines, line)
            end
            local location = step_location_line(step)
            if location ~= nil then
                table.insert(lines, "   " .. location)
            end
            for _, note_line in ipairs(step_note_lines(step)) do
                table.insert(lines, note_line)
            end
        end
        return lines
    end

    local line = step_line({
        instruction = objective.instruction,
        step_id = objective.step_id,
        step_kind = objective.step_kind,
        zone_id = objective.zone_id,
        npc_name = objective.npc_name,
        map_grid = objective.map_grid,
        target_map_id = objective.target_map_id,
        target_map_label = objective.target_map_label,
    }, 1, known)
    if line ~= nil then
        table.insert(lines, line)
    end
    local location = step_location_line(objective)
    if location ~= nil then
        table.insert(lines, "   " .. location)
    end
    return lines
end

local function build_summary(state)
    local objective = state.objective
    local known = known_requirement_state(state)

    return {
        objective = objective_label(objective),
        prerequisites = prerequisites_label(objective),
        checkpoint = checkpoint_label(state.npc_status),
        requirement_lines = requirement_summary_lines(objective, known),
        step_lines = objective_step_lines(objective, known),
    }
end

function route_window.render_state(state)
    state = runtime_state(state)
    local summary = build_summary(state)
    local lines = {
        "OddQ",
        "Objective: " .. summary.objective,
        "Prerequisites: " .. summary.prerequisites,
    }
    for _, line in ipairs(summary.requirement_lines) do
        table.insert(lines, line)
    end
    if summary.checkpoint ~= "" then
        table.insert(lines, summary.checkpoint)
    end

    for _, line in ipairs(plan_lines(state.objective_plan)) do
        table.insert(lines, line)
    end

    if #summary.step_lines > 0 then
        table.insert(lines, "Directions:")
        for _, line in ipairs(summary.step_lines) do
            table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n")
end

section_header = skin.section_header
label_value = skin.label_value

local function dispatch_command(on_command, args)
    if type(on_command) == "function" then
        on_command(args)
    end
end

local function compact_objective_title(label)
    local text = safe_text(label)
    local mission_rank, mission_name = text:match("^San d'Oria Mission%s+([%d%-]+):%s*(.+)$")
    if mission_rank ~= nil and mission_name ~= nil then
        return "San d'Oria " .. mission_rank, mission_name
    end

    return text, ""
end

local function ellipsize(text, max_length)
    text = safe_text(text)
    max_length = tonumber(max_length) or 0
    if max_length <= 3 or #text <= max_length then
        return text
    end
    return text:sub(1, max_length - 3):gsub("%s+$", "") .. "..."
end

local function trim(text)
    text = safe_text(text)
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function compact_target_name(target)
    target = trim(target)
    if target == "" then
        return ""
    end
    if target:find("/", 1, true) == nil then
        return ellipsize(target, 34)
    end

    local parts = {}
    for part in target:gmatch("[^/]+") do
        part = trim(part)
        local first_word = part:match("^([^%s]+)")
        if first_word ~= nil and first_word ~= "" then
            table.insert(parts, first_word)
        end
    end
    if #parts == 0 then
        return ellipsize(target, 34)
    end
    return ellipsize(table.concat(parts, " / "), 34)
end

local function compact_map_grid_label(source)
    if type(source) ~= "table" then
        return ""
    end

    local map_grid = safe_text(source.map_grid)
    if map_grid == "" then
        return ""
    end
    if map_grid:match("[A-Za-z]+/[A-Za-z]+%-[0-9]+") then
        return ""
    end

    local tokens = {}
    local seen = {}
    for token in map_grid:gmatch("[A-Z]+%-[0-9]+") do
        if seen[token] ~= true then
            seen[token] = true
            table.insert(tokens, token)
        end
    end
    if #tokens == 1 then
        return "(" .. tokens[1] .. ")"
    end
    if #tokens == 2 then
        return "(" .. tokens[1] .. "/" .. tokens[2] .. ")"
    end
    if #tokens > 2 then
        return "(" .. tokens[1] .. "/" .. tokens[#tokens] .. ")"
    end

    return map_grid_label(source)
end

local function compact_location_label(source)
    local map = target_map_label(source)
    local grid = compact_map_grid_label(source)
    if map ~= "" and grid ~= "" then
        return map .. " " .. grid
    end
    if map ~= "" then
        return map
    end
    return grid
end

local function compact_step_target(step)
    if type(step) ~= "table" then
        return ""
    end

    local target = compact_target_name(step_target_name(step))
    local location = compact_location_label(step)
    if target ~= "" and location ~= "" then
        return ellipsize(target .. " " .. location, 44)
    end
    if target ~= "" then
        return target
    end

    local instruction = safe_text(step.instruction)
    return ellipsize(instruction, 44)
end

local function cluster_instruction_line(summary, selected, objective)
    if type(objective) == "table" and type(objective.steps) == "table" and #objective.steps > 1 then
        local index = tonumber(selected) or 0
        if index <= 0 then
            return tostring(#objective.steps) .. " steps"
        end

        local target = compact_step_target(objective.steps[index])
        if target ~= "" then
            return target
        end
    end

    local lines = summary.step_lines or {}
    local index = tonumber(selected) or 0
    if index < 1 then
        index = 1
    end
    local line = lines[index] or lines[1] or ""
    line = safe_text(line)
    line = line:gsub("^%d+%.%s*", "")
    return line
end

local function is_placeholder_objective(objective)
    if type(objective) ~= "table" then
        return true
    end
    local objective_id = safe_text(objective.objective_id)
    if objective_id == "mission.next"
        or objective_id == "quest.next"
        or objective_id == "job_unlock.next"
        or objective_id == "exp.next"
        or objective_id == "none" then
        return true
    end

    local quest_name = safe_text(objective.quest_name)
    return quest_name == "Next Mission Objective"
        or quest_name == "Next Quest Objective"
        or quest_name == "Recommended Job Unlock"
        or quest_name == "Recommended EXP Camp"
        or quest_name == "Enable Missions, Job Unlocks, Quests, or EXP"
end

local function render_objective_cluster(imgui, state, summary, on_command)
    local objective = (state or {}).objective
    local placeholder = is_placeholder_objective(objective)
    objective = objective or {}
    local guidance = (state or {}).guidance or {}
    if type(state) == "table" then
        state.guidance = guidance
    end
    local step_count = 0
    if type(objective.steps) == "table" then
        step_count = #objective.steps
    end
    local selected = tonumber(guidance.guide_step_tab_index) or 0
    if step_count > 0 and selected < 1 then
        selected = 1
        guidance.guide_step_tab_index = selected
    elseif selected < 0 then
        selected = 0
    elseif step_count > 0 and selected > step_count then
        selected = step_count
    end
    local title, subtitle = compact_objective_title(summary.objective)
    local instruction = cluster_instruction_line(summary, selected, objective)
    if placeholder then
        title = "No guide loaded"
        subtitle = "Use the Guide Browser or /odd find <text>."
        instruction = "Load a mission, quest, job, or EXP guide to show steps here."
    end
    if subtitle == "" then
        subtitle = summary.checkpoint:gsub("^Next checkpoint: ", "")
        if subtitle == "" then
            subtitle = summary.prerequisites
        end
    end
    local objective_kind = safe_text(objective.objective_kind)
    local segments = type((state or {}).route) == "table" and state.route.segments or nil
    local segment_count = type(segments) == "table" and #segments or 0
    local segment_index = math.floor(tonumber((state or {}).active_segment_index) or 1)
    local can_previous = objective_kind == "mission"
        or (step_count > 1 and selected > 0)
        or (segment_count > 1 and segment_index > 1)
    local can_next = objective_kind == "mission"
        or (step_count > 1 and selected < step_count)
        or (segment_count > 1 and segment_index < segment_count)
    local step_guide = route_window.should_use_step_guide(objective)
    local handlers = {}
    if not step_guide and can_previous then
        handlers.on_previous = function()
            dispatch_command(on_command, { "previous" })
        end
    end
    if not step_guide and can_next then
        handlers.on_next = function()
            dispatch_command(on_command, { "next" })
        end
    end
    local progress = nil
    local progress_label = ""
    if step_count == 1 then
        progress = 1
        progress_label = "Step 1 of 1"
    elseif step_count > 1 and selected > 0 then
        progress = selected / step_count
        progress_label = "Step " .. tostring(selected) .. " of " .. tostring(step_count)
    end
    if step_guide then
        instruction = ""
    end
    skin.objective_cluster(imgui, {
        title = title,
        subtitle = subtitle,
        progress = not placeholder and progress or nil,
        progress_label = progress_label,
        instruction = instruction,
        show_controls = not placeholder and not step_guide and (can_previous or can_next),
    }, handlers)
end

function route_window.render(imgui, state, on_command)
    if imgui == nil or imgui.Text == nil then
        return
    end

    state = runtime_state(state)
    local summary = build_summary(state)
    local known = known_requirement_state(state)

    render_objective_cluster(imgui, state, summary, on_command)
    if is_placeholder_objective(state.objective) then
        return
    end

    if route_window.should_use_step_guide(state.objective) then
        render_step_guide(imgui, state, summary, known, on_command)
        return
    end

    for _, line in ipairs(summary.requirement_lines) do
        skin.text_wrapped(imgui, line, "body")
    end

    if #summary.step_lines > 0 then
        section_header(imgui, "Directions")
        for _, line in ipairs(summary.step_lines) do
            skin.text_wrapped(imgui, line, "body")
        end
    end

    local objective_plan_lines = plan_lines(state.objective_plan)
    if #objective_plan_lines > 0 then
        for _, line in ipairs(objective_plan_lines) do
            skin.text_wrapped(imgui, line, "body")
        end
    end
end

function route_window.render_detailed_information(imgui, state, on_command)
    if imgui == nil or imgui.Text == nil then
        return
    end

    state = runtime_state(state)
    if is_placeholder_objective(state.objective) then
        return
    end

    local summary = build_summary(state)
    local known = known_requirement_state(state)
    if route_window.should_use_step_guide(state.objective) then
        render_step_guide(imgui, state, summary, known, on_command)
        return
    end

    for _, line in ipairs(summary.requirement_lines) do
        detail_text(imgui, line, detail_context(imgui), detail_number("body_indent_x", 0.0))
    end
    if #summary.step_lines > 0 then
        local context = detail_context(imgui)
        detail_section_header(imgui, "Directions", context)
        for _, line in ipairs(summary.step_lines) do
            detail_text(imgui, line, context, detail_number("body_indent_x", 0.0))
        end
    end
end

return route_window
