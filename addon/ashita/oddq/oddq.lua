addon.name = "oddq"
addon.author = "Odd"
addon.version = "1.0.7"
addon.desc = "Local quest and mission guide browser."
addon.link = "https://github.com/FFXIOddone/OddQ/releases/latest"

require("common")

local route_window = require("ui/route_window")
local guidance_state = require("guidance_state")
local main_window = require("ui/main_window")
local objective_catalog = require("objective_catalog")
local local_filesystem = require("local_filesystem")
local player_state = require("player_state")
local rank10_milestone = require("rank10_milestone")
local route_steps = require("route_steps")
local rank10_popup = require("ui/rank10_popup")
local step_pointer = require("ui/step_pointer")
local warp_home = require("warp_home")
local progression_triggers = require("progression_triggers")
local command_spine = require("command_spine")
local update_checker = require("update_checker")
local update_config = require("config/update")

local imgui_ok, imgui = pcall(require, "imgui")
if not imgui_ok then
    imgui = nil
end

local oddq = {
    visible = false,
    guidance = guidance_state.new(),
    tracked_objective = nil,
    item_route_objective = nil,
    custom_pointer_objective = nil,
    progression_state = progression_triggers.new_state(),
    next_progress_poll = 0,
    cutscene_event_id = nil,
    cutscene_zone_id = nil,
    progression_step_key = nil,
    rank10_milestone = rank10_milestone.new_state(),
    next_rank_poll = 0,
    update_check = update_checker.new_state(),
}

local handle_command

local function safe_text(value)
    if value == nil or type(value) == "table" then
        return ""
    end
    return tostring(value)
end

local function trim(value)
    return safe_text(value):match("^%s*(.-)%s*$") or ""
end

local function join_args(args, start_index)
    local values = {}
    for index = start_index or 1, #(args or {}) do
        local value = trim(args[index])
        if value ~= "" then
            table.insert(values, value)
        end
    end
    return table.concat(values, " ")
end

local function ashita_install_path()
    if AshitaCore ~= nil and AshitaCore.GetInstallPath ~= nil then
        local ok, path = pcall(function()
            return AshitaCore:GetInstallPath()
        end)
        if ok and type(path) == "string" and path ~= "" then
            return path:gsub("\\", "/"):gsub("/$", "")
        end
    end
    return nil
end

local function first_launch_seen_path()
    local install_path = ashita_install_path()
    if install_path == nil then
        return nil
    end
    return install_path .. "/config/addons/oddq/first-launch-seen.txt"
end

local function resume_state_path()
    local install_path = ashita_install_path()
    if install_path == nil then
        return nil
    end
    return install_path .. "/config/addons/oddq/resume-state.txt"
end

local function file_exists(path)
    if type(path) ~= "string" or path == "" then
        return false
    end
    local file = io.open(path, "r")
    if file == nil then
        return false
    end
    file:close()
    return true
end

local function write_text(path, document)
    if type(path) ~= "string" or path == "" then
        return false
    end
    if not local_filesystem.ensure_parent(path) then
        return false
    end
    local file = io.open(path, "w")
    if file == nil then
        return false
    end
    file:write(document)
    file:close()
    return true
end

local function mark_first_launch_seen(path)
    return write_text(path, os.date("!%Y-%m-%dT%H:%M:%SZ"))
end

local function read_resume_state(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local file = io.open(path, "r")
    if file == nil then
        return nil
    end
    local state = {}
    for line in file:lines() do
        local key, value = line:match("^([%w_]+)=(.*)$")
        if key ~= nil then
            state[key] = value
        end
    end
    file:close()
    if state.version ~= "1" or trim(state.objective_id) == "" then
        return nil
    end
    return state
end

local function apply_first_launch_state()
    local marker_path = first_launch_seen_path()
    local seen = file_exists(marker_path)
    local can_persist_marker = marker_path ~= nil
    oddq.guidance.first_launch_seen = true
    oddq.guidance.main_view = "browse"
    oddq.guidance.main_window_open = can_persist_marker and not seen
    oddq.visible = can_persist_marker and not seen
    if can_persist_marker and not seen then
        mark_first_launch_seen(marker_path)
    end
end

local function current_guidance_objective()
    return route_steps.project(oddq.tracked_objective, oddq.guidance.route_mode)
end

local function clear_item_route()
    oddq.item_route_objective = nil
    oddq.guidance.item_route_source_id = ""
end

local function clear_custom_pointer()
    oddq.custom_pointer_objective = nil
    oddq.guidance.custom_pointer_input = ""
    oddq.guidance.custom_pointer_error = ""
    oddq.guidance.custom_pointer_active = false
    oddq.guidance.custom_pointer_count = 0
end

local function clear_transient_pointers()
    clear_item_route()
    clear_custom_pointer()
end

local MAX_CUSTOM_POINTER_POSITIONS = 32
local COORDINATE_COMPONENT = "([%+%-]?[%d%.]+)"

local function finite_coordinate(value)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return value
end

local function format_coordinate(value)
    if value == 0 then value = 0 end
    local formatted = string.format("%.3f", value)
    formatted = formatted:gsub("0+$", ""):gsub("%.$", "")
    return formatted
end

local function parse_custom_targets(raw)
    local text = trim(raw)
    if text == "" then
        return nil, "Paste coordinates like (-54.4, -21.5) or a grid like (E-5)."
    end

    local targets, seen = {}, {}
    local function append_target(key, value)
        if seen[key] == true then
            return true
        end
        if #targets >= MAX_CUSTOM_POINTER_POSITIONS then
            return false, "Paste at most 32 locations."
        end
        seen[key] = true
        targets[#targets + 1] = value
        return true
    end
    local function append_coordinate(first, second)
        local x = finite_coordinate(first)
        local z = finite_coordinate(second)
        if x == nil or z == nil then
            return false, "Coordinates must be finite numbers."
        end
        return append_target(string.format("xy:%.6f|%.6f", x, z), {
            kind = "coordinate",
            x = x,
            z = z,
            position_label = "X/Y(" .. format_coordinate(x) .. "," .. format_coordinate(z) .. ")",
        })
    end
    local function canonical_grid(column, row_text)
        column = tostring(column or ""):upper()
        local row = tonumber(row_text)
        if #column ~= 1 or column < "A" or column > "P"
            or row == nil or row < 1 or row > 16 or row ~= math.floor(row) then
            return nil
        end
        return column .. "-" .. tostring(row)
    end
    local function looks_like_grid_candidate(value)
        local compact = tostring(value or ""):upper():gsub("%s+", "")
        return compact:match("^[A-Z][A-Z]?%-[%+%-]?%d*$") ~= nil
            or compact:match("^%d+%-[A-Z]+$") ~= nil
            or compact:match("^[A-Z/]+%-[%+%-]?%d+$") ~= nil
            or compact:match("^[A-Z]%-%d+/.+$") ~= nil
    end
    local function append_grid(column, row_text, map_id)
        local grid = canonical_grid(column, row_text)
        map_id = tonumber(map_id)
        if grid == nil or (map_id ~= nil and (map_id < 1 or map_id ~= math.floor(map_id))) then
            return false, "Grid locations use columns A-P and rows 1-16, like (E-5)."
        end
        return append_target("grid:" .. tostring(map_id or "*") .. ":" .. grid, {
            kind = "grid",
            grid = grid,
            map_id = map_id,
            position_label = "(" .. grid .. ")",
        })
    end

    local explicit_grids = {}
    for map_text, column, row_text in text:gmatch(
        "[Mm][Aa][Pp]%s*(%d+)%s*%(%s*([%a]+)%s*%-%s*([%+%-]?%d+)%s*%)"
    ) do
        local grid = canonical_grid(column, row_text)
        local ok, message = append_grid(column, row_text, map_text)
        if not ok then return nil, message end
        if grid ~= nil then explicit_grids[grid] = true end
    end

    for inner in text:gmatch("%(([^()]*)%)") do
        local column, row_text = inner:match("^%s*([%a]+)%s*%-%s*([%+%-]?%d+)%s*$")
        if column ~= nil then
            local grid = canonical_grid(column, row_text)
            if grid == nil then
                return nil, "Grid locations use columns A-P and rows 1-16, like (E-5)."
            end
            if explicit_grids[grid] ~= true then
                local ok, message = append_grid(column, row_text, nil)
                if not ok then return nil, message end
            end
        elseif looks_like_grid_candidate(inner) then
            return nil, "Grid locations use columns A-P and rows 1-16, like (E-5)."
        end
    end

    local tuple_pattern = "%(%s*" .. COORDINATE_COMPONENT
        .. "%s*,%s*" .. COORDINATE_COMPONENT .. "%s*%)"
    for first, second in text:gmatch(tuple_pattern) do
        local ok, message = append_coordinate(first, second)
        if not ok then return nil, message end
    end

    if #targets == 0 then
        local map_text, column, row_text = text:match(
            "^%s*[Mm][Aa][Pp]%s*(%d+)%s+([%a]+)%s*%-%s*([%+%-]?%d+)%s*$"
        )
        if map_text ~= nil then
            local ok, message = append_grid(column, row_text, map_text)
            if not ok then return nil, message end
        else
            column, row_text = text:match("^%s*([%a]+)%s*%-%s*([%+%-]?%d+)%s*$")
            if column ~= nil then
                local ok, message = append_grid(column, row_text, nil)
                if not ok then return nil, message end
            end
        end
    end

    if #targets == 0 then
        local first, second = text:match(
            "^%s*" .. COORDINATE_COMPONENT .. "%s*,%s*" .. COORDINATE_COMPONENT .. "%s*$"
        )
        if first == nil then
            first, second = text:match(
                "^%s*[Xx]%s*[:=]%s*" .. COORDINATE_COMPONENT
                    .. "%s*[Yy]%s*[:=]%s*" .. COORDINATE_COMPONENT .. "%s*$"
            )
        end
        if first == nil then
            first, second = text:match(
                "^%s*" .. COORDINATE_COMPONENT .. "%s+" .. COORDINATE_COMPONENT .. "%s*$"
            )
        end
        if first == nil then
            return nil, "Paste (X, Y) coordinates or a grid like (E-5)."
        end
        local ok, message = append_coordinate(first, second)
        if not ok then return nil, message end
    end
    return targets
end

local function normalize_mode(value)
    return objective_catalog.normalize_mode(value)
end

local function category_for_mode(mode)
    if mode == "exp" then
        return "exp_solo"
    end
    if mode == "missions" or mode == "jobs" or mode == "quests" or mode == "npcs" or mode == "items" then
        return mode
    end
    return "catseye"
end

local function open_browser(mode, query, category)
    oddq.guidance.main_view = "browse"
    oddq.guidance.main_window_open = true
    oddq.visible = true
    if category ~= nil then
        oddq.guidance.guide_browser_category = category
        oddq.guidance.guide_browser_item_id = ""
    elseif mode ~= nil then
        oddq.guidance.guide_browser_category = category_for_mode(mode)
    end
    if query ~= nil then
        oddq.guidance.guide_browser_query = query
        oddq.guidance.guide_browser_page = 1
        oddq.guidance.guide_browser_selected_index = 1
        oddq.guidance.guide_browser_item_id = ""
    end
end

local function open_guide()
    oddq.guidance.main_view = "guide"
    oddq.guidance.main_window_open = true
    oddq.visible = true
end

local function entry_label(entry)
    return trim((entry or {}).name) ~= "" and trim(entry.name)
        or trim((entry or {}).objective_id) ~= "" and trim(entry.objective_id)
        or "selected guide"
end

local function current_player_rank()
    if player_state.current_rank == nil then
        return nil
    end
    local ok, rank = pcall(player_state.current_rank)
    return ok and tonumber(rank) or nil
end

local function load_local_catalog_guide(entry)
    if type(entry) ~= "table" then
        return false
    end
    local objective = objective_catalog.to_runtime_objective(entry, entry)
    if objective == nil then
        print("OddQ could not build that local guide.")
        return false
    end
    clear_transient_pointers()

    objective.quest_name = trim(objective.quest_name) ~= "" and objective.quest_name or entry.name
    objective.objective_kind = trim(objective.objective_kind) ~= "" and objective.objective_kind or entry.kind
    objective.mode = objective_catalog.mode_for_entry(entry)
    oddq.tracked_objective = objective
    rank10_milestone.arm_for_guide(oddq.rank10_milestone, objective, current_player_rank())
    oddq.guidance.active_mode = objective.mode or oddq.guidance.active_mode

    local steps = (current_guidance_objective() or {}).steps
    oddq.guidance.guide_step_tab_index = type(steps) == "table" and #steps > 0 and 1 or 0
    guidance_state.reset_step_transition(oddq.guidance)
    guidance_state.reset_step_proximity(oddq.guidance)
    open_guide()
    print("odd guide loaded: " .. entry_label(entry))
    return true
end

local resume_state_signature = nil

local function current_resume_state()
    local objective = oddq.tracked_objective
    local objective_id = trim(type(objective) == "table" and objective.objective_id or "")
    if objective_id == "" then
        return nil
    end
    local steps = (current_guidance_objective() or {}).steps or {}
    local step = math.floor(tonumber(oddq.guidance.guide_step_tab_index) or 1)
    step = math.max(1, math.min(step, math.max(1, #steps)))
    local step_id = trim(type(steps[step]) == "table" and steps[step].step_id or "")
    local main_view = oddq.guidance.main_view == "guide" and "guide" or "browse"
    return {
        objective_id = objective_id,
        step = step,
        step_id = step_id,
        route_mode = route_steps.normalize_mode(oddq.guidance.route_mode),
        main_view = main_view,
        main_window_open = oddq.guidance.main_window_open == true,
        rank10_milestone_armed = oddq.rank10_milestone.armed == true,
        rank10_milestone_pending = oddq.rank10_milestone.pending == true,
    }
end

local function resume_state_document(state)
    return table.concat({
        "version=1",
        "objective_id=" .. state.objective_id,
        "step=" .. tostring(state.step),
        "step_id=" .. tostring(state.step_id or ""),
        "route_mode=" .. state.route_mode,
        "main_view=" .. state.main_view,
        "main_window_open=" .. (state.main_window_open and "true" or "false"),
        "rank10_milestone_armed=" .. (state.rank10_milestone_armed and "true" or "false"),
        "rank10_milestone_pending=" .. (state.rank10_milestone_pending and "true" or "false"),
        "",
    }, "\n")
end

local function persist_resume_state()
    local path = resume_state_path()
    local state = current_resume_state()
    if path == nil or state == nil then
        return false
    end
    local document = resume_state_document(state)
    if document == resume_state_signature then
        return true
    end
    if not write_text(path, document) then
        return false
    end
    resume_state_signature = document
    return true
end

local function remove_resume_state()
    local path = resume_state_path()
    resume_state_signature = nil
    if path == nil or not file_exists(path) then
        return true
    end
    local ok, removed = pcall(os.remove, path)
    return ok and removed == true
end

local function restore_resume_state()
    local state = read_resume_state(resume_state_path())
    if state == nil then
        return false
    end
    local entry = objective_catalog.find_by_objective_id(state.objective_id)
    if entry == nil or not load_local_catalog_guide(entry) then
        return false
    end

    oddq.guidance.route_mode = route_steps.normalize_mode(state.route_mode)
    local steps = (current_guidance_objective() or {}).steps or {}
    local step = math.floor(tonumber(state.step) or 1)
    local saved_step_id = trim(state.step_id)
    if saved_step_id ~= "" then
        for index, candidate in ipairs(steps) do
            if trim(type(candidate) == "table" and candidate.step_id or "") == saved_step_id then
                step = index
                break
            end
        end
    end
    oddq.guidance.guide_step_tab_index = math.max(1, math.min(step, math.max(1, #steps)))
    oddq.guidance.main_view = state.main_view == "guide" and "guide" or "browse"
    oddq.guidance.main_window_open = state.main_window_open == "true"
    oddq.visible = oddq.guidance.main_window_open
    if state.rank10_milestone_armed ~= nil or state.rank10_milestone_pending ~= nil then
        rank10_milestone.restore(
            oddq.rank10_milestone,
            state.rank10_milestone_armed == "true",
            state.rank10_milestone_pending == "true"
        )
    end
    guidance_state.reset_step_transition(oddq.guidance)
    guidance_state.reset_step_proximity(oddq.guidance)
    resume_state_signature = resume_state_document(current_resume_state())
    return true
end

local function cancel_guide()
    local had_guide = oddq.tracked_objective ~= nil
    local had_custom_pointer = oddq.custom_pointer_objective ~= nil
    local had_item_pointer = oddq.item_route_objective ~= nil
    oddq.tracked_objective = nil
    clear_transient_pointers()
    oddq.guidance.guide_step_tab_index = 0
    oddq.guidance.warp_home_action = nil
    guidance_state.reset_step_transition(oddq.guidance)
    guidance_state.reset_step_proximity(oddq.guidance)
    oddq.progression_state = progression_triggers.new_state()
    oddq.progression_step_key = nil
    oddq.next_progress_poll = 0
    oddq.cutscene_event_id = nil
    oddq.cutscene_zone_id = nil
    oddq.rank10_milestone.armed = false
    oddq.rank10_milestone.last_rank = nil
    local resume_removed = remove_resume_state()
    open_browser()
    if had_guide then
        print("OddQ guide canceled.")
    elseif had_custom_pointer then
        print("OddQ custom pointer cleared.")
    elseif had_item_pointer then
        print("OddQ item-source pointer cleared.")
    end
    if not resume_removed then
        print("OddQ could not remove the saved guide state; check config/addons/oddq/resume-state.txt.")
    end
end

local function entry_matches_mode(entry, mode)
    return mode == nil or objective_catalog.mode_for_entry(entry) == mode
end

local function find_entry(query, mode)
    local exact = objective_catalog.find_by_objective_id(query)
    if exact ~= nil and entry_matches_mode(exact, mode) then
        return exact
    end
    return objective_catalog.search(query, mode, 1)[1]
end

local function open_item_detail(item)
    if type(item) ~= "table" then return false end
    clear_item_route()
    open_browser("items", safe_text(item.name), "items")
    oddq.guidance.guide_browser_item_id = safe_text(item.id)
    print("OddQ opened item: " .. safe_text(item.name)
        .. " (ID " .. tostring(math.floor(tonumber(item.item_id) or 0)) .. ").")
    return true
end

local function point_to_item_source(item_id, source_index)
    local item = objective_catalog.find_item_by_id(item_id)
    local index = math.floor(tonumber(source_index) or 0)
    local route = objective_catalog.item_source_route(item, index)
    local source = type(item) == "table" and type(item.sources) == "table"
        and item.sources[index] or nil
    if item == nil or route == nil or type(source) ~= "table" then
        print("OddQ: that item source has no verified exact pointer route.")
        return false
    end

    clear_custom_pointer()

    local step = {
        step_id = "reach_item_source",
        step_kind = "travel",
        zone_id = route.zone_id,
        target_name = route.target_name,
        map_grid = route.map_grid,
        position = {
            x = route.position.x,
            y = route.position.y,
            z = route.position.z,
        },
        instruction = "Follow the pointer to " .. route.target_name
            .. " for " .. safe_text(item.name) .. ".",
        required_items = {},
        required_key_items = {},
        notes = {},
    }
    if source.kind == "gil_shop" or source.kind == "guild_shop" then
        step.npc_name = route.target_name
        step.position.npc_name = route.target_name
    elseif source.kind == "drop" then
        step.mob_name = route.target_name
    end
    oddq.item_route_objective = {
        objective_id = "item_route:" .. safe_text(item.id) .. ":" .. tostring(index),
        objective_kind = "item_route",
        quest_name = "Item source: " .. safe_text(item.name),
        transient = true,
        steps = { step },
    }
    oddq.guidance.item_route_source_id = safe_text(item.id) .. ":" .. tostring(index)
    open_browser("items", safe_text(item.name), "items")
    oddq.guidance.guide_browser_item_id = safe_text(item.id)
    print("OddQ pointer set to " .. route.target_name .. " for " .. safe_text(item.name) .. ".")
    return true
end

local function handle_item_command(args)
    local action = trim((args or {})[1]):lower()
    if action == "route" then
        point_to_item_source(args[2], args[3])
        return
    end
    if action == "clear-route" then
        clear_item_route()
        print("OddQ item pointer cleared.")
        return
    end
    clear_item_route()
    open_browser("items", join_args(args, 1), "items")
end

local function set_custom_pointer(raw)
    raw = trim(raw)
    oddq.guidance.custom_pointer_input = raw
    local function reject(message)
        if oddq.custom_pointer_objective ~= nil then
            message = tostring(message) .. " Previous custom pointer remains active."
        end
        oddq.guidance.custom_pointer_error = message
        print("OddQ: " .. message)
        return false
    end
    if oddq.tracked_objective ~= nil then
        return reject("Cancel the active guide before setting a custom pointer.")
    end

    local parsed, parse_error = parse_custom_targets(raw)
    if parsed == nil then
        return reject(parse_error)
    end

    local ok, live = pcall(player_state.current_live_context)
    live = ok and type(live) == "table" and live or {}
    local zone_id = tonumber(live.current_zone_id)
    local current_map_id = tonumber(live.current_map_id or live.map_id or live.map_index or live.map_page)
    local current = type(live.current_position) == "table" and live.current_position or nil
    local elevation = type(current) == "table" and tonumber(current.y or current.Y) or nil
    if zone_id == nil or zone_id <= 0 or elevation == nil then
        return reject("Waiting for your current zone and position.")
    end

    local positions, seen_positions = {}, {}
    local pointer_map_id = nil
    local function append_position(position)
        local map_id = tonumber(position.map_id)
        local key = table.concat({
            tostring(map_id or "*"),
            string.format("%.6f", tonumber(position.x) or 0),
            string.format("%.6f", tonumber(position.z) or 0),
            tostring(position.position_label or ""),
        }, "|")
        if seen_positions[key] ~= true then
            if #positions >= MAX_CUSTOM_POINTER_POSITIONS then
                return false
            end
            seen_positions[key] = true
            positions[#positions + 1] = position
        end
        return true
    end
    for _, target in ipairs(parsed) do
        if target.kind == "grid" then
            local requested_map_id = tonumber(target.map_id) or current_map_id
            local anchors, resolution = objective_catalog.grid_anchors(zone_id, requested_map_id, target.grid)
            resolution = type(resolution) == "table" and resolution or {}
            if anchors == nil then
                if resolution.reason == "ambiguous_map" then
                    return reject("This zone has " .. target.grid
                        .. " on multiple maps; use Map N (" .. target.grid .. ").")
                end
                local map_label = requested_map_id ~= nil and ("Map " .. tostring(requested_map_id) .. " ") or ""
                return reject("OddQ has no verified " .. map_label .. "(" .. target.grid
                    .. ") pointer reference in this zone.")
            end
            local resolved_map_id = tonumber(resolution.map_id)
            if pointer_map_id ~= nil and resolved_map_id ~= pointer_map_id then
                return reject("All grid locations in one pointer must use the same map.")
            end
            pointer_map_id = pointer_map_id or resolved_map_id
            for _, anchor in ipairs(anchors) do
                if not append_position({
                    x = anchor.x,
                    y = elevation,
                    z = anchor.z,
                    map_id = resolved_map_id,
                    map_grid = target.grid,
                    position_kind = "map_grid_anchor",
                    position_label = "(" .. target.grid .. ")",
                }) then
                    return reject("A custom pointer can contain at most 32 verified locations.")
                end
            end
        else
            if not append_position({
                x = target.x,
                y = elevation,
                z = target.z,
                position_kind = "custom_coordinate",
                position_label = target.position_label,
            }) then
                return reject("A custom pointer can contain at most 32 verified locations.")
            end
        end
    end
    if #positions == 0 then
        return reject("OddQ could not resolve any verified pointer locations.")
    end
    local count = #positions
    local step = {
        step_id = "custom_coordinate",
        step_kind = "travel",
        zone_id = zone_id,
        position = positions[1],
        positions = positions,
        position_kind = "custom_coordinate",
        pointer_planar_only = true,
        pointer_current_zone_only = true,
        pointer_current_map_only = pointer_map_id ~= nil,
        target_map_id = pointer_map_id,
        target_map_label = pointer_map_id ~= nil and ("Map " .. tostring(pointer_map_id)) or nil,
        warp_suppressed = true,
        instruction = count == 1 and "Follow the pointer to the custom location."
            or "Follow the pointer to the nearest custom location.",
        required_items = {},
        required_key_items = {},
        notes = {},
    }

    clear_item_route()
    oddq.custom_pointer_objective = {
        objective_id = "custom_pointer:" .. tostring(zone_id) .. ":" .. tostring(pointer_map_id or "any"),
        objective_kind = "custom_pointer",
        quest_name = "Custom Pointer",
        transient = true,
        steps = { step },
    }
    oddq.guidance.custom_pointer_input = raw
    oddq.guidance.custom_pointer_error = ""
    oddq.guidance.custom_pointer_active = true
    oddq.guidance.custom_pointer_count = count
    open_browser()
    print(count == 1 and "OddQ custom pointer set."
        or ("OddQ custom pointer set to the nearest of " .. tostring(count) .. " locations."))
    return true
end

local function handle_pointer_command(args)
    local raw = join_args(args, 1)
    if trim(raw):lower() == "clear" then
        clear_custom_pointer()
        print("OddQ custom pointer cleared.")
        return
    end
    set_custom_pointer(raw)
end

local function load_query(query, mode)
    query = trim(query)
    if query == "" then
        open_browser(mode)
        return false
    end
    if mode == nil then
        local exact_item = objective_catalog.find_exact_item(query)
        if exact_item ~= nil then
            return open_item_detail(exact_item)
        end
    end
    local entry = find_entry(query, mode)
    if entry == nil then
        print("OddQ found no guide for: " .. query)
        open_browser(mode, query)
        return false
    end
    return load_local_catalog_guide(entry)
end

local function route_window_output()
    return route_window.render_state({
        guidance = oddq.guidance,
        objective = current_guidance_objective(),
        known_items = {},
        known_key_items = {},
    })
end

local function print_multiline(value)
    for line in safe_text(value):gmatch("[^\n]+") do
        print(line)
    end
end

local function uses_step_guide()
    return route_window.should_use_step_guide ~= nil
        and route_window.should_use_step_guide(current_guidance_objective())
end

local function concise_status(output)
    local lines = {}
    for line in safe_text(output):gmatch("[^\n]+") do
        if line == "Directions:" then
            break
        end
        table.insert(lines, line)
    end
    table.insert(lines, "Directions: open the OddQ guide window for full details.")
    return table.concat(lines, "\n")
end

local function print_status()
    if oddq.tracked_objective == nil then
        print("OddQ has no guide loaded. Use /odd to browse.")
        return
    end
    local output = route_window_output()
    if uses_step_guide() then
        output = concise_status(output)
    end
    print_multiline(output)
end

local function move_guide_step(delta)
    local objective = current_guidance_objective()
    local steps = type(objective) == "table" and objective.steps or nil
    if type(steps) ~= "table" or #steps == 0 then
        return false, "no_steps"
    end
    local selected = math.floor(tonumber(oddq.guidance.guide_step_tab_index) or 1)
    selected = math.max(1, math.min(selected, #steps))
    local next_selected, reason = route_steps.move_phase_index(objective, selected, delta)
    if next_selected == nil then
        return false, reason
    end
    oddq.guidance.guide_step_tab_index = next_selected
    guidance_state.reset_step_transition(oddq.guidance)
    guidance_state.reset_step_proximity(oddq.guidance)
    return true, nil
end

local function select_route_mode(value)
    if not route_steps.has_modes(oddq.tracked_objective) then
        print("This guide has no conditional warp route.")
        return true
    end
    local raw = trim(value):upper():gsub("%-", "_")
    if raw == "NOWARP" or raw == "NO_WARP" or raw == "NO" then
        raw = "NO_WARP"
    elseif raw == "WARP" or raw == "YES" then
        raw = "WARP"
    else
        print("Use /odd route warp or /odd route no-warp.")
        return true
    end

    local old_mode = route_steps.normalize_mode(oddq.guidance.route_mode)
    oddq.guidance.guide_step_tab_index = route_steps.remap_index(
        oddq.tracked_objective,
        old_mode,
        raw,
        oddq.guidance.guide_step_tab_index
    )
    oddq.guidance.route_mode = raw
    guidance_state.reset_step_transition(oddq.guidance)
    guidance_state.reset_step_proximity(oddq.guidance)
    print(raw == "WARP" and "OddQ is using the Warp route." or "OddQ is using the No SG/HP route.")
    return true
end

local function move_mission_guide(delta)
    local entry, boundary = objective_catalog.mission_neighbor(oddq.tracked_objective, delta)
    if entry ~= nil then
        return load_local_catalog_guide(entry)
    end
    if boundary == "start" then
        print("OddQ is at the first mission in this sequence.")
        return true
    end
    if boundary == "end" then
        print("OddQ is at the last mission in this sequence.")
        return true
    end
    return false
end

local function move_current_guide(delta)
    local moved, reason = move_guide_step(delta)
    if moved then
        print_status()
        return
    end
    if reason == "phase_in_progress" then
        print("OddQ: follow the pointer to finish this guide phase before advancing.")
        return
    end
    if move_mission_guide(delta) then
        return
    end
    print(delta > 0 and "OddQ is at the last guide phase." or "OddQ is at the first guide phase.")
end

local function print_help()
    for _, line in ipairs(command_spine.help_lines()) do
        print(line)
    end
end

local function announce_pointer_advance(objective, previous_index, next_index)
    if type(objective) ~= "table" then
        return
    end
    local _, previous_phase, phase_count = route_steps.guide_projection(objective, previous_index)
    local _, next_phase, _, phase = route_steps.guide_projection(objective, next_index)
    if type(objective.guide_phases) == "table" and #objective.guide_phases > 0 then
        if previous_phase == next_phase then
            return
        end
        local title = trim(type(phase) == "table" and phase.title or "")
        local suffix = title ~= "" and (": " .. title) or "."
        print("OddQ advanced to phase " .. tostring(next_phase)
            .. " of " .. tostring(phase_count) .. suffix)
        return
    end
    print("OddQ advanced to step " .. tostring(next_index)
        .. " of " .. tostring(#(objective.steps or {})) .. ".")
end

local function render_ui()
    local now = os.clock()
    if now >= (oddq.next_rank_poll or 0) then
        oddq.next_rank_poll = now + 0.5
        if rank10_milestone.observe_rank(oddq.rank10_milestone, current_player_rank()) then
            print("OddQ: Congratulations on Rank 10! Your CatsEyeXI milestone reward is ready.")
        end
    end
    local objective = current_guidance_objective()
    local selected = math.floor(tonumber(oddq.guidance.guide_step_tab_index) or 1)
    local step = type(objective) == "table" and type(objective.steps) == "table"
        and objective.steps[selected] or nil
    local progress_key = tostring(type(objective) == "table" and objective.objective_id or "")
        .. "|" .. tostring(selected) .. "|" .. tostring(type(step) == "table" and step.step_id or "")
    if oddq.progression_step_key ~= progress_key then
        oddq.progression_step_key = progress_key
        oddq.progression_state = progression_triggers.new_state()
        oddq.next_progress_poll = 0
    end
    local scan_items, scan_key_items = {}, {}
    for _, condition in ipairs(type(step) == "table" and step.auto_advance_events or {}) do
        if condition.event == "item_gained" or condition.event == "item_lost" then
            scan_items[#scan_items + 1] = condition.name
        elseif condition.event == "key_item_gained" or condition.event == "key_item_lost" then
            scan_key_items[#scan_key_items + 1] = condition.name
        end
    end
    local live_context = player_state.current_live_context({
        scan_item_names = scan_items,
        scan_key_item_names = scan_key_items,
        cutscene_event_id = oddq.cutscene_event_id,
        cutscene_zone_id = oddq.cutscene_zone_id,
    })
    local custom_step = type(oddq.custom_pointer_objective) == "table"
        and type(oddq.custom_pointer_objective.steps) == "table"
        and oddq.custom_pointer_objective.steps[1] or nil
    local custom_zone = tonumber(type(custom_step) == "table" and custom_step.zone_id or nil)
    local custom_map = tonumber(type(custom_step) == "table" and custom_step.target_map_id or nil)
    local live_zone = tonumber((live_context or {}).current_zone_id)
    local live_map = tonumber((live_context or {}).current_map_id
        or (live_context or {}).map_id
        or (live_context or {}).map_index
        or (live_context or {}).map_page)
    if custom_zone ~= nil and custom_zone > 0
        and live_zone ~= nil and live_zone > 0 and custom_zone ~= live_zone then
        clear_custom_pointer()
        print("OddQ custom pointer cleared after changing zones.")
    elseif type(custom_step) == "table" and custom_step.pointer_current_map_only == true
        and custom_map ~= nil and live_map ~= nil and custom_map ~= live_map then
        clear_custom_pointer()
        print("OddQ custom pointer cleared after changing maps.")
    end
    local previous_index = selected
    local progression_paused = oddq.item_route_objective ~= nil
        or oddq.custom_pointer_objective ~= nil
    local advanced, step_index = false, nil
    if not progression_paused then
        advanced, step_index = guidance_state.observe_step_zone_transition(
            oddq.guidance,
            objective,
            (live_context or {}).current_zone_id
        )
    end
    if advanced then
        announce_pointer_advance(objective, previous_index, step_index)
    end

    now = os.clock()
    if not progression_paused and not advanced and now >= (oddq.next_progress_poll or 0) then
        oddq.next_progress_poll = now + 0.5
        local events = progression_triggers.observe_live(oddq.progression_state, live_context)
        local progress_advanced, progress_step = guidance_state.advance_for_progress_events(
            oddq.guidance,
            objective,
            events,
            progression_triggers.step_completed
        )
        if progress_advanced then
            advanced = true
            step_index = progress_step
            announce_pointer_advance(objective, previous_index, progress_step)
        end
    end

    if not progression_paused and not advanced then
        local proximity_advanced, proximity_step = guidance_state.observe_step_proximity(
            oddq.guidance,
            objective,
            live_context
        )
        if proximity_advanced then
            advanced = true
            step_index = proximity_step
            announce_pointer_advance(objective, previous_index, proximity_step)
        end
    end

    if imgui == nil then
        persist_resume_state()
        return
    end

    if oddq.visible == true then
        objective = current_guidance_objective()
        oddq.guidance.warp_home_action = warp_home.current_action()
        main_window.render(imgui, oddq.guidance, objective, function(args)
            handle_command(args or {})
        end)
        objective = oddq.item_route_objective
            or oddq.custom_pointer_objective
            or current_guidance_objective()
        local pointer_guidance = oddq.guidance
        if oddq.item_route_objective ~= nil or oddq.custom_pointer_objective ~= nil then
            pointer_guidance = {
                guide_step_tab_index = 1,
                route_mode = oddq.guidance.route_mode,
            }
        end
        step_pointer.render(imgui, objective, pointer_guidance, live_context, function(command)
            local authorized = type(command) == "string" and (
                command:match("^/uw [hs][pg] ") ~= nil
                or command == '/mount "Raptor"'
                or command == "/dismount"
            )
            if authorized then
                local chat = AshitaCore ~= nil and AshitaCore.GetChatManager ~= nil and AshitaCore:GetChatManager() or nil
                if chat ~= nil and chat.QueueCommand ~= nil then chat:QueueCommand(-1, command) end
            end
        end)
    end
    rank10_popup.render(imgui, oddq.rank10_milestone)
    persist_resume_state()
end

local function handle_plan_command(args)
    local mode = normalize_mode(args[1])
    local query_start = mode ~= nil and 2 or 1
    local query = join_args(args, query_start)
    if query == "" then
        open_browser(mode)
        return
    end
    load_query(query, mode)
end

local function handle_browse_command(args)
    local category_spec = command_spine.resolve({ args[1] })
    if category_spec.handler ~= "category" then category_spec = nil end
    local mode = category_spec and category_spec.mode or normalize_mode(args[1])
    local category = category_spec and category_spec.category or nil
    local query_start = (category_spec ~= nil or mode ~= nil) and 2 or 1
    open_browser(mode, join_args(args, query_start), category)
end

local command_handlers = {}

command_handlers.open = function()
        open_browser(nil, nil, "catseye")
end
command_handlers.close = function()
        oddq.guidance.main_window_open = false
        oddq.visible = false
end
command_handlers.cancel = cancel_guide
command_handlers.back = function() open_browser() end
command_handlers.status = print_status
command_handlers.next = function() move_current_guide(1) end
command_handlers.previous = function() move_current_guide(-1) end
command_handlers.route = function(resolved) select_route_mode(resolved.args[1]) end
command_handlers.pointer = function(resolved) handle_pointer_command(resolved.args) end
command_handlers.warp_home = function()
        local objective = current_guidance_objective()
        local step = type(objective) == "table" and type(objective.steps) == "table"
            and objective.steps[tonumber(oddq.guidance.guide_step_tab_index) or 1] or nil
        local action = type(step) == "table" and step.warp_home_recommended == true
            and warp_home.current_action() or nil
        local chat = AshitaCore ~= nil and AshitaCore.GetChatManager ~= nil
            and AshitaCore:GetChatManager() or nil
        if action ~= nil and chat ~= nil and chat.QueueCommand ~= nil then
            for _, queued in ipairs(action.commands or {}) do
                chat:QueueCommand(-1, queued)
            end
        end
end
command_handlers.help = print_help
command_handlers.plan = function(resolved) handle_plan_command(resolved.args) end
command_handlers.browse = function(resolved) handle_browse_command(resolved.args) end
command_handlers.find = function(resolved) load_query(join_args(resolved.args, 1), nil) end
command_handlers.category = function(resolved)
        local query = join_args(resolved.args, 1)
        if resolved.category == "items" then
            handle_item_command(resolved.args)
            return
        end
        if query == "" then
            open_browser(resolved.mode, nil, resolved.category)
        else
            load_query(query, resolved.mode)
        end
end
command_handlers.search = function(resolved) load_query(join_args(resolved.args, 1), nil) end

function handle_command(args)
    local resolved = command_spine.resolve(args)
    local handler = command_handlers[resolved.handler]
    if handler == nil then
        print("OddQ command is unavailable: " .. tostring(resolved.name or "unknown"))
        return
    end
    handler(resolved)
end

local function parse_command_line(command_line)
    local args = {}
    for token in safe_text(command_line):gmatch("%S+") do
        table.insert(args, token)
    end
    if args[1] == "/odd" then
        table.remove(args, 1)
    end
    return args
end

oddq.handle_command = function(command_or_args)
    if type(command_or_args) == "table" then
        handle_command(command_or_args)
    else
        handle_command(parse_command_line(command_or_args))
    end
end

ashita.events.register("command", "oddq_command", function(e)
    local args = e.command:args()
    if #args == 0 or args[1] ~= "/odd" then
        return
    end
    e.blocked = true
    table.remove(args, 1)
    handle_command(args)
end)

ashita.events.register("packet_in", "oddq_cutscene_capture", function(e)
    if (e.id ~= 0x032 and e.id ~= 0x033) or type(e.data) ~= "string" or struct == nil then return end
    local ok, zone_id, event_id = pcall(function()
        return struct.unpack("H", e.data, 0x0A + 1), struct.unpack("H", e.data, 0x0C + 1)
    end)
    if ok then
        oddq.cutscene_zone_id = tonumber(zone_id)
        oddq.cutscene_event_id = tonumber(event_id)
    end
end)

ashita.events.register("load", "oddq_load", function()
    -- ODD_SECURITY_NOTE: local guidance plus one opt-out, read-only GitHub release check; no packet mutation, movement, targeting, trading, or chat upload.
    -- ODD_FILE_WRITE: first-launch marker and validated guide resume state under config/addons/oddq.
    apply_first_launch_state()
    local restored = restore_resume_state()
    if restored then
        local steps = (current_guidance_objective() or {}).steps or {}
        print("OddQ restored " .. entry_label(oddq.tracked_objective)
            .. ", step " .. tostring(oddq.guidance.guide_step_tab_index)
            .. " of " .. tostring(#steps) .. ".")
    elseif oddq.guidance.main_window_open then
        print("OddQ loaded. Guide Browser is open.")
    else
        print("OddQ loaded. Use /odd.")
    end
    if update_config.enabled ~= false and ashita.tasks ~= nil and ashita.tasks.once ~= nil then
        ashita.tasks.once(tonumber(update_config.delay_seconds) or 3, function()
            update_checker.check(oddq.update_check, addon.version)
        end)
    end
end)

ashita.events.register("unload", "oddq_unload", function()
    persist_resume_state()
end)

ashita.events.register("d3d_present", "oddq_mvp_render", function()
    render_ui()
end)

return oddq
