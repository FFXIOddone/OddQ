addon.name = "oddq"
addon.author = "Odd"
addon.version = "1.0.2"
addon.desc = "Local quest and mission guide browser."

require("common")

local route_window = require("ui/route_window")
local guidance_state = require("guidance_state")
local main_window = require("ui/main_window")
local objective_catalog = require("objective_catalog")
local local_filesystem = require("local_filesystem")

local imgui_ok, imgui = pcall(require, "imgui")
if not imgui_ok then
    imgui = nil
end

local oddq = {
    visible = false,
    guidance = guidance_state.new(),
    tracked_objective = nil,
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
    exp = { category = "exp", mode = "exp" },
    camp = { category = "exp", mode = "exp" },
    camps = { category = "exp", mode = "exp" },
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
    return oddq.tracked_objective
end

local function normalize_mode(value)
    return objective_catalog.normalize_mode(value)
end

local function category_for_mode(mode)
    if mode == "missions" or mode == "jobs" or mode == "quests" or mode == "exp" then
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
    oddq.guidance.active_mode = objective.mode or oddq.guidance.active_mode

    local steps = oddq.tracked_objective.steps
    oddq.guidance.guide_step_tab_index = type(steps) == "table" and #steps > 0 and 1 or 0
    open_guide()
    print("odd guide loaded: " .. entry_label(entry))
    return true
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
        and route_window.should_use_step_guide(oddq.tracked_objective)
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
    local objective = oddq.tracked_objective
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
    print("/odd missions|quests|jobs|exp - browse a guide category")
    print("/odd next|previous - move through the loaded guide")
    print("/odd status - print the current step")
    print("/odd close - close OddQ")
end

local function render_ui()
    if imgui == nil or oddq.visible ~= true then
        return
    end

    local objective = current_guidance_objective()
    main_window.render(imgui, oddq.guidance, objective, function(args)
        handle_command(args or {})
    end)
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

ashita.events.register("load", "oddq_load", function()
    -- ODD_SECURITY_NOTE: local guidance only; no networking, packet events, movement, targeting, trading, or chat upload.
    -- ODD_FILE_WRITE: first-launch marker only, under config/addons/oddq.
    apply_first_launch_state()
    if oddq.guidance.main_window_open then
        print("OddQ loaded. Guide Browser is open.")
    else
        print("OddQ loaded. Use /odd.")
    end
end)

ashita.events.register("d3d_present", "oddq_mvp_render", function()
    render_ui()
end)

return oddq
