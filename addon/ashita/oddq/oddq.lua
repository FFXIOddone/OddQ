addon.name = "oddq"
addon.author = "Odd"
addon.version = "1.0.5"
addon.desc = "Local quest and mission guide browser."

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

local imgui_ok, imgui = pcall(require, "imgui")
if not imgui_ok then
    imgui = nil
end

local oddq = {
    visible = false,
    guidance = guidance_state.new(),
    tracked_objective = nil,
    progression_state = progression_triggers.new_state(),
    next_progress_poll = 0,
    cutscene_event_id = nil,
    cutscene_zone_id = nil,
    progression_step_key = nil,
    rank10_milestone = rank10_milestone.new_state(),
    next_rank_poll = 0,
}

local category_modes = {
    catseye = { category = "catseye", mode = "quests" },
    mission = { category = "missions", mode = "missions" },
    missions = { category = "missions", mode = "missions" },
    m = { category = "missions", mode = "missions" },
    job = { category = "jobs", mode = "jobs" },
    jobs = { category = "jobs", mode = "jobs" },
    j = { category = "jobs", mode = "jobs" },
    quest = { category = "quests", mode = "quests" },
    quests = { category = "quests", mode = "quests" },
    q = { category = "quests", mode = "quests" },
    exp = { category = "exp_solo", mode = "exp" },
    camp = { category = "exp_solo", mode = "exp" },
    camps = { category = "exp_solo", mode = "exp" },
    solo = { category = "exp_solo", mode = "exp" },
    trust = { category = "exp_solo", mode = "exp" },
    trusts = { category = "exp_solo", mode = "exp" },
    ["6man"] = { category = "exp_6man", mode = "exp" },
    sixman = { category = "exp_6man", mode = "exp" },
    party = { category = "exp_6man", mode = "exp" },
    mageburn = { category = "exp_mageburn", mode = "exp" },
    manaburn = { category = "exp_mageburn", mode = "exp" },
    meleeburn = { category = "exp_meleeburn", mode = "exp" },
    petburn = { category = "exp_meleeburn", mode = "exp" },
    npc = { category = "npcs", mode = "npcs" },
    npcs = { category = "npcs", mode = "npcs" },
    finder = { category = "npcs", mode = "npcs" },
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

local function normalize_mode(value)
    return objective_catalog.normalize_mode(value)
end

local function category_for_mode(mode)
    if mode == "exp" then
        return "exp_solo"
    end
    if mode == "missions" or mode == "jobs" or mode == "quests" or mode == "npcs" then
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
    elseif mode ~= nil then
        oddq.guidance.guide_browser_category = category_for_mode(mode)
    end
    if query ~= nil then
        oddq.guidance.guide_browser_query = query
        oddq.guidance.guide_browser_page = 1
        oddq.guidance.guide_browser_selected_index = 1
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

    objective.quest_name = trim(objective.quest_name) ~= "" and objective.quest_name or entry.name
    objective.objective_kind = trim(objective.objective_kind) ~= "" and objective.objective_kind or entry.kind
    objective.mode = objective_catalog.mode_for_entry(entry)
    oddq.tracked_objective = objective
    rank10_milestone.arm_for_guide(oddq.rank10_milestone, objective, current_player_rank())
    oddq.guidance.active_mode = objective.mode or oddq.guidance.active_mode

    local steps = (current_guidance_objective() or {}).steps
    oddq.guidance.guide_step_tab_index = type(steps) == "table" and #steps > 0 and 1 or 0
    guidance_state.reset_step_transition(oddq.guidance)
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
    local main_view = oddq.guidance.main_view == "guide" and "guide" or "browse"
    return {
        objective_id = objective_id,
        step = step,
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
    resume_state_signature = resume_state_document(current_resume_state())
    return true
end

local function cancel_guide()
    local had_guide = oddq.tracked_objective ~= nil
    oddq.tracked_objective = nil
    oddq.guidance.guide_step_tab_index = 0
    oddq.guidance.warp_home_action = nil
    guidance_state.reset_step_transition(oddq.guidance)
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

local function load_query(query, mode)
    query = trim(query)
    if query == "" then
        open_browser(mode)
        return false
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
        return false
    end
    local selected = math.floor(tonumber(oddq.guidance.guide_step_tab_index) or 1)
    selected = math.max(1, math.min(selected, #steps))
    local next_selected = selected + delta
    if next_selected < 1 or next_selected > #steps then
        return false
    end
    oddq.guidance.guide_step_tab_index = next_selected
    guidance_state.reset_step_transition(oddq.guidance)
    return true
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
    if move_guide_step(delta) then
        print_status()
        return
    end
    if move_mission_guide(delta) then
        return
    end
    print(delta > 0 and "OddQ is at the last step." or "OddQ is at the first step.")
end

local function print_help()
    print("OddQ help")
    print("/odd - open the guide browser")
    print("/odd <search> - load the best matching local guide")
    print("/odd missions|quests|jobs|npcs - browse a guide category")
    print("/odd solo|6man|mageburn|meleeburn - browse an EXP camp category")
    print("/odd next|previous - move through the loaded guide")
    print("/odd cancel - cancel the loaded guide and clear its resume state")
    print("/odd route warp|no-warp - choose instructions for your teleport unlocks")
    print("/odd status - print the current step")
    print("/odd close - close OddQ")
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
    local advanced, step_index = guidance_state.observe_step_zone_transition(
        oddq.guidance,
        current_guidance_objective(),
        (live_context or {}).current_zone_id
    )
    if advanced then
        local steps = (current_guidance_objective() or {}).steps or {}
        print("OddQ advanced to step " .. tostring(step_index) .. " of " .. tostring(#steps) .. ".")
    end

    now = os.clock()
    if not advanced and now >= (oddq.next_progress_poll or 0) then
        oddq.next_progress_poll = now + 0.5
        local events = progression_triggers.observe_live(oddq.progression_state, live_context)
        local progress_advanced, progress_step = guidance_state.advance_for_progress_events(
            oddq.guidance,
            objective,
            events,
            progression_triggers.step_completed
        )
        if progress_advanced then
            print("OddQ advanced to step " .. tostring(progress_step) .. " of " .. tostring(#(objective.steps or {})) .. ".")
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
        objective = current_guidance_objective()
        step_pointer.render(imgui, objective, oddq.guidance, live_context, function(command)
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
    local mode = normalize_mode(args[2])
    local query_start = mode ~= nil and 3 or 2
    local query = join_args(args, query_start)
    if query == "" then
        open_browser(mode)
        return
    end
    load_query(query, mode)
end

local function handle_browse_command(args)
    local category_spec = category_modes[trim(args[2]):lower()]
    local mode = category_spec and category_spec.mode or normalize_mode(args[2])
    local category = category_spec and category_spec.category or nil
    local query_start = (category_spec ~= nil or mode ~= nil) and 3 or 2
    open_browser(mode, join_args(args, query_start), category)
end

function handle_command(args)
    args = args or {}
    local command = trim(args[1]):lower()

    if command == "" or command == "open" or command == "menu" or command == "welcome" then
        open_browser(nil, nil, "catseye")
        return
    end
    if command == "close" then
        oddq.guidance.main_window_open = false
        oddq.visible = false
        return
    end
    if command == "cancel" then
        cancel_guide()
        return
    end
    if command == "back" then
        open_browser()
        return
    end
    if command == "status" or command == "where" or command == "current" then
        print_status()
        return
    end
    if command == "next" then
        move_current_guide(1)
        return
    end
    if command == "previous" or command == "prev" then
        move_current_guide(-1)
        return
    end
    if command == "route" or command == "route-mode" then
        select_route_mode(args[2])
        return
    end
    if command == "warp-home" then
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
        return
    end
    if command == "help" then
        print_help()
        return
    end
    if command == "plan" then
        handle_plan_command(args)
        return
    end
    if command == "list" or command == "browse" or command == "catalog" then
        handle_browse_command(args)
        return
    end
    if command == "find" or command == "search" or command == "load" or command == "go" then
        load_query(join_args(args, 2), nil)
        return
    end

    local category_spec = category_modes[command]
    if category_spec ~= nil then
        local query = join_args(args, 2)
        if query == "" then
            open_browser(category_spec.mode, nil, category_spec.category)
        else
            load_query(query, category_spec.mode)
        end
        return
    end

    load_query(join_args(args, 1), nil)
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
    -- ODD_SECURITY_NOTE: local guidance only; receive-only cutscene observation, no packet mutation, networking, movement, targeting, trading, or chat upload.
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
end)

ashita.events.register("unload", "oddq_unload", function()
    persist_resume_state()
end)

ashita.events.register("d3d_present", "oddq_mvp_render", function()
    render_ui()
end)

return oddq
