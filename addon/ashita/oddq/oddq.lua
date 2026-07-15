addon.name = "oddq"
addon.author = "Odd"
addon.version = "0.1.0"
addon.desc = "Quest, mission, and route guidance shell."

require("common")

local config = require("config/default")
local route_window = require("ui/route_window")
local guidance_state = require("guidance_state")
local map_layers = require("ui/map_layers")
local bridge_client = require("bridge/client")
local player_state = require("player_state")
local mission_state = require("mission_state")
local pilot_recorder = require("pilot_recorder")
local live_routes = require("live_routes")
local command_router = require("command_router")
local assist_hub = require("assist_hub")
local addon_integration = require("addon_integration")
local guidance_cursor = require("guidance_cursor")
local route_test = require("route_test")
local progression_ledger = require("progression_ledger")
local progression_triggers = require("progression_triggers")
local objective_catalog = require("objective_catalog")
local npc_tracker = require("npc_tracker")
local objective_pointer = require("objective_pointer")
local tuner_window = require("ui/tuner_window")
local local_filesystem = require("local_filesystem")
local imgui_ok, imgui = pcall(require, "imgui")
if not imgui_ok then
    imgui = nil
end

local SANDORIA_RANK1_QUEST_ID = "catseyexi.mission.san_doria_1_1"

local oddq = {
    visible = true,
    guidance = guidance_state.new(),
    tracked_objectives = {},
    tracked_objective = nil,
    objective_plan = nil,
    active_segment_index = 1,
    locked_route_objective_id = nil,
    locked_route = {
        route_id = "route_sample_static_shell",
        locked = true,
        segments = {
            {
                type = "walk",
                zone_id = 230,
                from = "current_position",
                to = "home_point",
            },
        },
        signature = "ed25519:sample-static-shell",
    },
}

local sandoria_rank1_steps = {
    start = {
        key = "start",
        objective_id = "catseyexi.mission.san_doria_1_1.start",
        quest_id = SANDORIA_RANK1_QUEST_ID,
        quest_name = "San d'Oria 1-1: Accept mission",
        step_id = "start",
        step_kind = "talk",
        zone_id = 230,
        position = { x = 93.419, y = -0.001, z = -57.347 },
        npc_name = "Ambrotien / Endracion gate guard",
        map_grid = "K-10 / F-9",
        instruction = "Talk to Ambrotien or Endracion in Southern San d'Oria, or Grilau in Northern San d'Oria, to begin the mission. Talk to the same NPC twice if it does not initiate!",
    },
    axe = {
        key = "axe",
        objective_id = "catseyexi.mission.san_doria_1_1.farm_orcish_axe",
        quest_id = SANDORIA_RANK1_QUEST_ID,
        quest_name = "San d'Oria 1-1: Farm Orcish Axe",
        step_id = "farm_orcish_axe",
        step_kind = "farm_item",
        zone_id = 140,
        position = { x = -12.0, y = 0.0, z = 23.0 },
        npc_name = "Orcish Fodder camp for Orcish Axe",
        map_grid = "East Ronfaure / West Ronfaure",
        instruction = "Kill Orcish Fodder outside San d'Oria until an Orcish Axe drops.",
    },
    turnin = {
        key = "turnin",
        objective_id = "catseyexi.mission.san_doria_1_1.turnin_southern",
        quest_id = SANDORIA_RANK1_QUEST_ID,
        quest_name = "San d'Oria 1-1: Turn in Orcish Axe",
        step_id = "turnin_southern",
        step_kind = "trade",
        zone_id = 230,
        position = { x = 93.419, y = -0.001, z = -57.347 },
        npc_name = "Ambrotien / Endracion gate guard",
        map_grid = "K-10 / F-9",
        instruction = "Trade the Orcish Axe to the same San d'Orian gate guard used to start the mission.",
    },
    ["turnin-north"] = {
        key = "turnin-north",
        objective_id = "catseyexi.mission.san_doria_1_1.turnin_northern",
        quest_id = SANDORIA_RANK1_QUEST_ID,
        quest_name = "San d'Oria 1-1: Turn in Orcish Axe (north)",
        step_id = "turnin_northern",
        step_kind = "trade",
        zone_id = 231,
        position = { x = -241.987, y = 6.999, z = 57.887 },
        npc_name = "Grilau gate guard",
        map_grid = "D-8",
        instruction = "Trade the Orcish Axe to Grilau in Northern San d'Oria.",
    },
}

sandoria_rank1_steps["turnin_north"] = sandoria_rank1_steps["turnin-north"]
sandoria_rank1_steps.north = sandoria_rank1_steps["turnin-north"]

local pilot_batch = {
    active = false,
    total = 0,
    completed = 0,
    delay_seconds = 2,
    next_run_at = 0,
}

local frame_metrics = {
    last_present_clock = nil,
    last_frame_delta_ms = 0,
    visible_since_clock = nil,
}


local route_test_state = route_test.new_state()
local progress_trigger_state = progression_triggers.new_state()
local guided_command_session = command_router.new_session()

local render
local handle_command

local function ashita_install_path()
    if AshitaCore ~= nil and AshitaCore.GetInstallPath ~= nil then
        local ok, path = pcall(function()
            return AshitaCore:GetInstallPath()
        end)
        if ok and type(path) == "string" and path ~= "" then
            return path:gsub("\\", "/"):gsub("/$", "")
        end
    end

    return "."
end

local function ensure_parent_dir(path)
    return local_filesystem.ensure_parent(path)
end

local function file_exists(path)
    local file = io.open(path, "r")
    if file == nil then
        return false
    end
    file:close()
    return true
end

local function first_launch_seen_path()
    return ashita_install_path() .. "/config/addons/oddq/first-launch-seen.txt"
end

local function guidance_preferences_path()
    return ashita_install_path() .. "/config/addons/oddq/preferences.txt"
end

local function ui_tuner_constants_path()
    return ashita_install_path() .. "/config/addons/oddq/ui-tuner-constants.lua"
end

local function ui_tuner_constants_document()
    return table.concat({
        "-- Generated by OddQ /odd ui save",
        "-- Review these values, then paste the layout/colors blocks into addon/ashita/oddq/ui/skin.lua.",
        "",
        tuner_window.layout_snippet(),
        "",
    }, "\n")
end

local function save_ui_tuner_constants()
    local path = ui_tuner_constants_path()
    ensure_parent_dir(path)

    local file, err = io.open(path, "w")
    if file == nil then
        print("odd ui constants save failed: " .. tostring(err or path))
        return false, path
    end

    file:write(ui_tuner_constants_document())
    file:close()
    print("odd ui constants saved: " .. path)
    return true, path
end

local function mark_first_launch_seen()
    local path = first_launch_seen_path()
    ensure_parent_dir(path)
    local file = io.open(path, "w")
    if file == nil then
        return false
    end
    file:write(os.date("!%Y-%m-%dT%H:%M:%SZ"))
    file:close()
    return true
end

local saved_guidance_preferences = nil

local function load_guidance_preferences()
    local file = io.open(guidance_preferences_path(), "r")
    if file == nil then
        saved_guidance_preferences = nil
        return false
    end
    local document = file:read("*a")
    file:close()
    guidance_state.apply_preferences(oddq.guidance, document)
    saved_guidance_preferences = guidance_state.serialize_preferences(oddq.guidance)
    return true
end

local function save_guidance_preferences()
    if oddq.guidance.first_launch_seen ~= true then
        return false
    end
    local document = guidance_state.serialize_preferences(oddq.guidance)
    if document == saved_guidance_preferences then
        return true
    end
    local path = guidance_preferences_path()
    ensure_parent_dir(path)
    local file = io.open(path, "w")
    if file == nil then
        return false
    end
    file:write(document)
    file:close()
    saved_guidance_preferences = document
    return true
end

local function apply_first_launch_state()
    local seen = file_exists(first_launch_seen_path())
    oddq.guidance.first_launch_seen = true
    oddq.guidance.guide_notes_open = false
    oddq.guidance.detailed_information_open = false
    oddq.guidance.main_view = "browse"
    oddq.guidance.main_window_open = not seen
    oddq.visible = not seen
    if seen then
        load_guidance_preferences()
    else
        mark_first_launch_seen()
    end
    for _, mode in ipairs({ "missions", "jobs", "quests", "exp" }) do
        oddq.guidance.modes[mode] = true
    end
    guidance_state.pick_active_mode(oddq.guidance)
end

local function completion_ledger_path()
    return ashita_install_path() .. "/" .. progression_ledger.default_path
end

local function append_unique_string(values, value)
    if type(value) ~= "string" or value == "" then
        return
    end
    for _, existing in ipairs(values) do
        if existing == value then
            return
        end
    end
    table.insert(values, value)
end

local function append_requirement_names(values, names)
    for _, value in ipairs(names or {}) do
        append_unique_string(values, value)
    end
end

local function tracked_requirement_names()
    local objective = oddq.tracked_objective
    local required_items = {}
    local required_key_items = {}
    if type(objective) ~= "table" then
        return required_items, required_key_items
    end

    append_requirement_names(required_items, objective.required_items)
    append_requirement_names(required_key_items, objective.required_key_items)
    for _, step in ipairs(objective.steps or {}) do
        append_requirement_names(required_items, step.required_items)
        append_requirement_names(required_key_items, step.required_key_items)
    end
    return required_items, required_key_items
end

local function normalized_lookup_key(value)
    return tostring(value or ""):lower():match("^%s*(.-)%s*$")
end

local function list_lookup(values, present_value)
    local lookup = {}
    for _, value in ipairs(values or {}) do
        local key = normalized_lookup_key(value)
        if key ~= "" then
            lookup[key] = present_value
        end
    end
    return lookup
end

local function build_assist_readiness_provider(live_state)
    local transport = (live_state or {}).known_transport_flags or {}
    return {
        items = list_lookup(transport.items, 1),
        key_items = list_lookup((live_state or {}).key_items, true),
    }
end

local function build_assist_live_context(live_state, objective)
    live_state = live_state or {}
    local checkpoint = npc_tracker.resolve_next_checkpoint(objective, live_state)
    return {
        current_zone_id = live_state.current_zone_id,
        current_map_id = live_state.current_map_id,
        current_map_label = live_state.current_map_label,
        current_target_name = checkpoint.targeted == true and checkpoint.name or nil,
        target_distance = checkpoint.distance,
    }
end

local function build_live_state()
    local fallback_context = {
        current_zone_id = 230,
        current_position = {
            x = 12.1,
            y = 0,
            z = -84.2,
        },
    }
    local tracked_required_items, tracked_required_key_items = tracked_requirement_names()
    local live_context = player_state.current_live_context(fallback_context, {
        scan_item_names = tracked_required_items,
        scan_key_items = #tracked_required_key_items > 0,
    })
    local completions = progression_ledger.completed_lists(completion_ledger_path())

    return player_state.build(config, {
        addon_version = addon.version,
        server_profile = "catseyexi",
        game_mode = "CW",
        current_zone_id = live_context.current_zone_id,
        current_position = live_context.current_position,
        current_heading_yaw = live_context.current_heading_yaw,
        current_map_id = live_context.current_map_id,
        current_map_label = live_context.current_map_label,
        level = live_context.level,
        enabled_modes = guidance_state.enabled_mode_keys(oddq.guidance),
        enabled_exp_camp_categories = guidance_state.enabled_exp_type_keys(oddq.guidance),
        completed_quests = completions.completed_quests,
        completed_missions = completions.completed_missions,
        key_items = live_context.key_items,
        target_objective_id = "catseyexi.thread_bare.investigate",
        known_unlocks_hash = "sha256:unknown",
        known_transport_flags = {
            home_points = {},
            survival_guides = {},
            outposts = {},
            teleport_crystals = {},
            exp_guides = {},
            city_teleporters = {},
            spells = {},
            items = live_context.items,
            cooldowns = {
                warp_ring_seconds_remaining = 0,
                instant_warp_scroll_count = 0,
            },
        },
        movement_context = {
            has_movement_speed_buff = false,
            mount_available = false,
        },
    })
end

local function update_active_segment_from_live_state(live_state)
    if route_test.is_active(route_test_state) then
        local resolved_index, events = route_test.update(route_test_state, oddq.locked_route, oddq.active_segment_index, live_state)
        oddq.active_segment_index = resolved_index
        for _, event in ipairs(events) do
            pilot_recorder.record_route_test_event(event)
            if event.event == "route_waypoint_passed" then
                print("odd route test waypoint passed: " .. tostring(event.waypoint_label or event.waypoint_id))
            elseif event.event == "route_waypoint_skipped" then
                print("odd route test waypoint skipped: " .. tostring(event.waypoint_label or event.waypoint_id) .. " (" .. tostring(event.skip_reason or "cursor_rebased") .. ")")
            elseif event.event == "route_zone_changed" then
                print("odd route test zone changed: " .. tostring(event.from_zone_id) .. " -> " .. tostring(event.to_zone_id))
            elseif event.event == "route_completion_observed" then
                print("odd route test completion observed: zone " .. tostring(event.completion_zone_id))
            end
        end
        return oddq.active_segment_index
    end

    local resolved_index = guidance_cursor.resolve_segment_index(oddq.locked_route, oddq.active_segment_index, live_state)
    if resolved_index ~= oddq.active_segment_index then
        oddq.active_segment_index = resolved_index
    end
    return oddq.active_segment_index
end

local function append_events(target, source)
    for _, event in ipairs(source or {}) do
        table.insert(target, event)
    end
end

local function record_progress_events(events)
    for _, event in ipairs(events or {}) do
        pilot_recorder.record_progress_event(event)
    end
end

local function handle_progress_triggers(live_state, source)
    local events = {}
    append_events(events, progression_triggers.drain_pending_events(progress_trigger_state))
    append_events(events, progression_triggers.observe_live(progress_trigger_state, live_state))
    if #events == 0 then
        return false
    end

    for _, event in ipairs(events) do
        event.source = event.source or source or "live_state"
    end
    record_progress_events(events)

    if progression_triggers.should_refresh_pointer(events) then
        update_active_segment_from_live_state(live_state)
        return true
    end
    return false
end

local function copy_position(position)
    position = position or {}
    return {
        x = tonumber(position.x or position.X) or 0,
        y = tonumber(position.y or position.Y) or 0,
        z = tonumber(position.z or position.Z) or 0,
    }
end

local function round_ms(value)
    return math.floor((value * 1000) + 0.5) / 1000
end

local function current_ui_open_seconds()
    if not oddq.visible or frame_metrics.visible_since_clock == nil then
        return 0
    end

    return math.floor(os.clock() - frame_metrics.visible_since_clock)
end

local function build_route_window_output()
    local live_state = build_live_state()
    return route_window.render_state({
        guidance = oddq.guidance,
        objective = oddq.tracked_objective,
        route = oddq.locked_route,
        active_segment_index = oddq.active_segment_index,
        objective_plan = oddq.objective_plan,
        known_items = (live_state.known_transport_flags or {}).items,
        known_key_items = live_state.key_items,
        npc_status = npc_tracker.resolve_next_checkpoint(oddq.tracked_objective, live_state),
    })
end

local function print_multiline(text)
    for line in tostring(text or ""):gmatch("[^\n]+") do
        print(line)
    end
end

local function tracked_objective_uses_tabbed_guide()
    return route_window.should_use_tabbed_guide ~= nil and route_window.should_use_tabbed_guide(oddq.tracked_objective)
end

local function tabbed_guide_chat_summary(output)
    local lines = {}
    for line in tostring(output or ""):gmatch("[^\n]+") do
        if line == "Directions:" then
            break
        end
        table.insert(lines, line)
    end
    table.insert(lines, "Directions: open in the current OddQ guide.")
    table.insert(lines, "Use Summary and numbered steps; chat output stays concise for client stability.")
    return table.concat(lines, "\n")
end

local function open_guide_notes_window()
    oddq.guidance.guide_notes_open = false
    oddq.guidance.detailed_information_open = false
    oddq.guidance.main_view = "guide"
    oddq.guidance.main_window_open = true
    oddq.guidance.settings_open = false
    oddq.guidance.assist_hub_open = false
    oddq.visible = true
    frame_metrics.visible_since_clock = frame_metrics.visible_since_clock or os.clock()
end

local function print_ui_tuner_constants()
    save_ui_tuner_constants()
end

local function handle_ui_command(args)
    local action = (args[2] or "toggle"):lower()

    if action == "toggle" or action == "" then
        oddq.guidance.ui_tuner_open = oddq.guidance.ui_tuner_open ~= true
        if oddq.guidance.ui_tuner_open then
            open_guide_notes_window()
            print("odd ui tuner opened.")
        else
            print("odd ui tuner hidden.")
        end
        return
    end

    if action == "show" or action == "open" then
        oddq.guidance.ui_tuner_open = true
        open_guide_notes_window()
        print("odd ui tuner opened.")
        return
    end

    if action == "hide" or action == "close" then
        oddq.guidance.ui_tuner_open = false
        print("odd ui tuner hidden.")
        return
    end

    if action == "reset" then
        tuner_window.reset()
        oddq.guidance.ui_tuner_open = true
        open_guide_notes_window()
        print("odd ui tuner reset layout and color constants.")
        return
    end

    if action == "print" or action == "copy" or action == "constants" or action == "save" then
        print_ui_tuner_constants()
        return
    end

    print("odd ui expects show|hide|reset|print|save.")
end

local function enable_objective_pointer_for_current_guide()
    if type(oddq.guidance.arrow) == "table" then
        oddq.guidance.arrow.visible = objective_pointer.supports(oddq.tracked_objective)
    end
end

local function publish_loaded_local_guide(label)
    enable_objective_pointer_for_current_guide()
    if tracked_objective_uses_tabbed_guide() then
        oddq.guidance.guide_step_tab_index = 0
    end
    open_guide_notes_window()
    print("odd guide loaded: " .. label)
end

local function build_objectives_by_mode()
    return {
        missions = oddq.tracked_objectives.missions,
        jobs = oddq.tracked_objectives.jobs,
        quests = oddq.tracked_objectives.quests or oddq.tracked_objective,
        exp = oddq.tracked_objectives.exp,
    }
end

local function current_guidance_objective()
    local active_mode = (oddq.guidance or {}).active_mode
    local active_objective = active_mode ~= nil and oddq.tracked_objectives[active_mode] or nil
    if active_objective ~= nil then
        return active_objective
    end
    return guidance_state.first_available_objective(oddq.guidance, build_objectives_by_mode())
end

local plan_modes = {
    missions = true,
    jobs = true,
    quests = true,
    exp = true,
}

local function normalize_plan_mode(mode)
    local normalized = objective_catalog.normalize_mode(mode)
    if normalized ~= nil and plan_modes[normalized] == true then
        return normalized
    end
    return nil
end

local function set_guidance_mode_only(mode)
    if plan_modes[mode] ~= true then
        return false
    end

    guidance_state.set_mode(oddq.guidance, "missions", mode == "missions")
    guidance_state.set_mode(oddq.guidance, "jobs", mode == "jobs")
    guidance_state.set_mode(oddq.guidance, "quests", mode == "quests")
    guidance_state.set_mode(oddq.guidance, "exp", mode == "exp")
    return true
end

local function set_active_guidance_mode(mode)
    if plan_modes[mode] ~= true then
        return false
    end
    oddq.guidance.active_mode = mode
    return true
end

local function apply_objective_plan(plan, local_entry)
    oddq.objective_plan = plan
    oddq.tracked_objectives = {}
    oddq.tracked_objective = nil
    oddq.locked_route_objective_id = nil
    if plan == nil or type(plan.actions) ~= "table" then
        return
    end
    for _, action in ipairs(plan.actions) do
        local objective = objective_catalog.to_runtime_objective(action.objective, local_entry)
        if objective ~= nil then
            objective.mode = action.mode
            if action.mode == "mission" then
                oddq.tracked_objectives.missions = objective
            elseif action.mode == "job" then
                oddq.tracked_objectives.jobs = objective
            elseif action.mode == "quest" then
                oddq.tracked_objectives.quests = objective
            elseif action.mode == "exp" then
                oddq.tracked_objectives.exp = objective
            end
        end
    end
    oddq.tracked_objective = current_guidance_objective()
    oddq.active_segment_index = 1
end

local function normalize_objective_target(value)
    local text = tostring(value or "")
    text = text:gsub("^objective:", "")
    return text
end

local function target_root(value)
    local text = normalize_objective_target(value)
    return text:gsub("%.start$", "")
end

local function starts_with(value, prefix)
    return string.sub(value, 1, string.len(prefix)) == prefix
end

local function objective_matches_target(objective, target_objective_id)
    if type(objective) ~= "table" then
        return false
    end

    local target = normalize_objective_target(target_objective_id)
    if target == "" or target == "manual.none" then
        return true
    end

    local root = target_root(target)
    local candidates = {
        objective.objective_id,
        objective.quest_id,
    }
    if type(objective.route_request_hint) == "table" then
        table.insert(candidates, objective.route_request_hint.target_objective_id)
    end

    for _, candidate in ipairs(candidates) do
        local value = normalize_objective_target(candidate)
        if value == target or value == root then
            return true
        end
        if root ~= "" and starts_with(value, root .. ".") then
            return true
        end
    end

    return false
end

local function plan_matches_target(plan, target_objective_id)
    if type(plan) ~= "table" or type(plan.actions) ~= "table" then
        return false
    end
    for _, action in ipairs(plan.actions) do
        if objective_matches_target(action.objective, target_objective_id) then
            return true
        end
    end
    return false
end

local function open_tracked_objective()
    if oddq.tracked_objective == nil then
        print("odd plan has no eligible objective.")
        return false
    end
    oddq.guidance.guide_step_tab_index = 0
    enable_objective_pointer_for_current_guide()
    open_guide_notes_window()
    print("odd plan selected: " .. tostring(oddq.tracked_objective.quest_name or oddq.tracked_objective.objective_id))
    return true
end

local function request_objective_plan(target_objective_id, fallback_plan)
    local live_state = build_live_state()
    if type(target_objective_id) == "string" and target_objective_id ~= "" then
        live_state.target_objective_id = target_objective_id
    else
        live_state.target_objective_id = "manual.none"
    end

    if fallback_plan ~= nil then
        apply_objective_plan(fallback_plan)
    end

    local next_plan, err = bridge_client.request_objective_plan(config, live_state, oddq.objective_plan)
    if err ~= nil then
        if fallback_plan ~= nil then
            print("odd plan using local guide: " .. err)
            open_tracked_objective()
            return
        end
        print("odd plan kept current plan: " .. err)
        return
    end

    if fallback_plan ~= nil and not plan_matches_target(next_plan, live_state.target_objective_id) then
        print("odd plan kept local guide: bridge returned a different objective")
        open_tracked_objective()
        return
    end

    apply_objective_plan(next_plan)
    if not open_tracked_objective() then
        return
    end
end

local function local_catalog_label(entry)
    if type(entry) ~= "table" then
        return "selected guide"
    end
    local label = entry.name or entry.objective_id or entry.id
    if type(label) ~= "string" or label == "" then
        return "selected guide"
    end
    return label
end

local function load_local_catalog_guide(entry)
    local entry_mode = objective_catalog.mode_for_entry(entry)
    if entry_mode ~= nil then
        set_active_guidance_mode(entry_mode)
    end

    local plan = objective_catalog.to_objective_plan(entry, build_live_state())
    if plan == nil then
        print("odd guide could not build local guide: " .. local_catalog_label(entry))
        return false
    end

    apply_objective_plan(plan, entry)
    if oddq.tracked_objective == nil then
        print("odd guide had no local objective: " .. local_catalog_label(entry))
        return false
    end

    publish_loaded_local_guide(local_catalog_label(entry))
    return true
end

local function request_catalog_objective_plan(args)
    local mode = normalize_plan_mode(args[2])
    local query_start = 2
    if mode ~= nil then
        query_start = 3
    end

    local query = table.concat(args, " ", query_start)
    if query == "" then
        if mode ~= nil then
            set_guidance_mode_only(mode)
        end
        request_objective_plan()
        return
    end

    local matches = objective_catalog.search(query, mode, 1)
    local entry = matches[1]
    if entry == nil then
        print("odd plan found no matching OddQ entry: " .. query)
        if mode ~= nil then
            print("Try /odd list " .. mode .. " or /odd find " .. query .. ".")
        else
            print("Try /odd find " .. query .. ".")
        end
        return
    end

    load_local_catalog_guide(entry)
end

local function request_job_unlock_plan(args)
    local query = table.concat(args or {}, " ", 2)
    if query ~= "" then
        local plan_args = { "plan", "jobs" }
        for index = 2, #(args or {}) do
            table.insert(plan_args, args[index])
        end
        request_catalog_objective_plan(plan_args)
        return
    end

    set_guidance_mode_only("jobs")
    request_objective_plan()
end

local function record_current_frame_sample(timing_source, metadata)
    metadata = metadata or {}
    local render_started = os.clock()
    local _ = build_route_window_output()
    local frame_cost_ms = round_ms((os.clock() - render_started) * 1000)

    local sample_metadata = {}
    for key, value in pairs(metadata) do
        sample_metadata[key] = value
    end
    sample_metadata.frame_cost_ms = frame_cost_ms
    sample_metadata.frame_delta_ms = frame_metrics.last_frame_delta_ms
    sample_metadata.timing_source = timing_source or "manual_render_sample"
    sample_metadata.route_visible = oddq.visible

    pilot_recorder.record_frame_sample(
        oddq.locked_route.route_id,
        current_ui_open_seconds(),
        sample_metadata
    )
end

local function approximate_payload_bytes(value)
    local value_type = type(value)
    if value_type == "string" then
        return #value
    end
    if value_type == "number" or value_type == "boolean" then
        return #tostring(value)
    end
    if value_type ~= "table" then
        return 4
    end

    local total = 2
    for key, child in pairs(value) do
        total = total + #tostring(key) + approximate_payload_bytes(child) + 4
    end
    return total
end

local function apply_tracked_objective_to_state(state)
    local objective = oddq.tracked_objective
    local hint = objective and objective.route_request_hint or nil
    if type(hint) ~= "table" then
        return state
    end

    state.target_objective_id = hint.target_objective_id or state.target_objective_id
    state.known_unlocks_hash = hint.known_unlocks_hash or state.known_unlocks_hash
    if type(hint.key_items) == "table" then
        state.key_items = hint.key_items
    end
    if type(hint.known_transport_flags) == "table" then
        state.known_transport_flags = hint.known_transport_flags
    end
    return state
end

local function replace_locked_route(response, target_objective_id)
    local current_route = oddq.locked_route
    oddq.locked_route = bridge_client.apply_route_response(current_route, response)
    if oddq.locked_route ~= current_route then
        oddq.active_segment_index = 1
        oddq.locked_route_objective_id = target_objective_id
        if type(oddq.guidance.arrow) == "table"
            and type(oddq.locked_route) == "table"
            and type(oddq.locked_route.segments) == "table"
            and #oddq.locked_route.segments > 0 then
            oddq.guidance.arrow.visible = true
        end
    end
end

local function clamp_integer(value, default_value, minimum, maximum)
    local parsed = tonumber(value)
    if parsed == nil then
        return default_value
    end

    parsed = math.floor(parsed)
    if parsed < minimum then
        return minimum
    end
    if parsed > maximum then
        return maximum
    end
    return parsed
end

local function batch_metadata()
    return {
        source = "pilot_batch",
        evidence_type = "route_generation_transport",
    }
end

local function request_locked_route(metadata)
    local started = os.clock()
    local current_route_id = oddq.locked_route.route_id
    local live_state = apply_tracked_objective_to_state(build_live_state())
    local next_route, err, request = bridge_client.request_route(config, live_state, oddq.locked_route)
    local attempt_id = nil
    if pilot_recorder.is_active() then
        attempt_id = pilot_recorder.next_route_attempt(request, metadata)
    end

    replace_locked_route(next_route, request and request.target_objective_id or nil)

    if pilot_recorder.is_active() then
        local result = {
            success = err == nil,
            fallback_used = err ~= nil,
            cache_hit = oddq.locked_route.route_id == current_route_id,
            payload_bytes = approximate_payload_bytes(request) + approximate_payload_bytes(next_route),
            solve_time_ms = math.floor(((os.clock() - started) * 1000) + 0.5),
            error = err or "",
        }
        if metadata ~= nil then
            result.source = metadata.source
            result.evidence_type = metadata.evidence_type
        end
        pilot_recorder.record_route_result(attempt_id, result)
    end

    return err
end

local function normalize_sandoria_rank1_step(step)
    step = (step or "start"):lower()
    if step == "accept" or step == "guard" then
        return "start"
    end
    if step == "farm" or step == "orcish" or step == "orcish-axe" or step == "orcish_axe" then
        return "axe"
    end
    if step == "turn-in" or step == "return" or step == "south" or step == "southern" then
        return "turnin"
    end
    if step == "grilau" or step == "north" or step == "northern" or step == "turnin_north" then
        return "turnin-north"
    end
    return step
end

local function set_manual_mission_objective(step, detected)
    local preset = sandoria_rank1_steps[step]
    if preset == nil then
        return false
    end

    local live_state = build_live_state()
    local evidence_source = "local_curated_seed"
    local evidence_status = "provisional route target"
    local evidence_run_id = "sandy-r1m1-provisional-route-v1"
    if detected ~= nil then
        evidence_source = detected.source or "mission_autodetect"
        evidence_status = "auto-detected mission step; route target remains provisional until walked"
        evidence_run_id = "sandy-r1m1-autodetect-route-v1"
    end

    local objective = {
        mode = "missions",
        objective_id = preset.objective_id,
        objective_kind = "mission",
        quest_id = preset.quest_id,
        quest_name = preset.quest_name,
        step_id = preset.step_id,
        step_kind = preset.step_kind,
        zone_id = preset.zone_id,
        position = copy_position(preset.position),
        npc_name = preset.npc_name,
        map_grid = preset.map_grid,
        instruction = preset.instruction,
        evidence = {
            source = evidence_source,
            status = evidence_status,
            confidence = detected and detected.confidence or nil,
            reason = detected and detected.reason or nil,
            run_id = evidence_run_id,
            validated = false,
        },
        route_request_hint = {
            server_profile = live_state.server_profile,
            game_mode = live_state.game_mode,
            current_zone_id = live_state.current_zone_id,
            current_position = copy_position(live_state.current_position),
            target_objective_id = preset.objective_id,
            key_items = live_state.key_items,
            known_unlocks_hash = live_state.known_unlocks_hash,
            known_transport_flags = live_state.known_transport_flags,
        },
    }

    oddq.tracked_objective = objective
    oddq.tracked_objectives.missions = objective
    oddq.locked_route_objective_id = nil
    guidance_state.set_mode(oddq.guidance, "missions", true)
    oddq.guidance.guide_step_tab_index = 0
    enable_objective_pointer_for_current_guide()
    open_guide_notes_window()
    oddq.active_segment_index = 1
    frame_metrics.visible_since_clock = frame_metrics.visible_since_clock or os.clock()

    if detected ~= nil then
        print("odd mission auto detected: " .. preset.quest_name .. " -> zone " .. tostring(preset.zone_id) .. " (" .. tostring(detected.confidence) .. ")")
    else
        print("odd mission sandy1 provisional route target: " .. preset.quest_name .. " -> zone " .. tostring(preset.zone_id))
    end
    return true
end

local function apply_detected_mission_objective(trigger)
    local detected = mission_state.detect()
    if detected == nil then
        return false
    end
    if detected.mission_key ~= "sandoria_rank1" then
        return false
    end
    if not set_manual_mission_objective(detected.step, detected) then
        return false
    end

    print("odd mission auto selected read-only directions; route navigation is disabled.")
    return true
end

local function current_tracked_mission()
    local objective = oddq.tracked_objective
    if objective ~= nil and objective.objective_kind == "mission" then
        return objective
    end
    return oddq.tracked_objectives.missions
end

local function record_detected_mission_completion(trigger)
    local objective = current_tracked_mission()
    if objective == nil then
        return false
    end

    local completion = mission_state.detect_completion(objective.quest_id)
    if completion == nil then
        return false
    end

    if progression_ledger.record(completion_ledger_path(), "mission", completion.quest_id) then
        print("odd mission auto recorded local guidance completion: " .. tostring(completion.quest_id))
    else
        print("odd mission auto failed to record local guidance completion.")
        return false
    end

    if oddq.tracked_objective == objective then
        oddq.tracked_objective = nil
    end
    oddq.tracked_objectives.missions = nil
    oddq.objective_plan = nil
    oddq.active_segment_index = 1
    return true
end

local function refresh_detected_objective_state(trigger)
    if record_detected_mission_completion(trigger) then
        return "completed"
    end
    if apply_detected_mission_objective(trigger) then
        return "updated"
    end
    return nil
end

local function handle_mission_command(args)
    local mission = (args[2] or ""):lower()
    local step = normalize_sandoria_rank1_step(args[3])

    if mission == "auto" or mission == "detect" then
        if refresh_detected_objective_state("mission_auto") == nil then
            print("odd mission auto found no supported mission state yet.")
        end
        render()
        return
    end

    if mission ~= "sandy1" and mission ~= "sandoria1" and mission ~= "sandoria-rank1" then
        if mission == "" then
            print("odd mission expects text, auto, or sandy1.")
            print("/odd mission sandy 2-3")
            print("/odd mission auto")
            print("/odd mission sandy1 start|axe|turnin|turnin-north")
            return
        end

        local plan_args = { "plan", "missions" }
        for index = 2, #args do
            table.insert(plan_args, args[index])
        end
        request_catalog_objective_plan(plan_args)
        render()
        return
    end

    if not set_manual_mission_objective(step) then
        print("/odd mission sandy1 start|axe|turnin|turnin-north")
        return
    end

    print("odd mission sandy1 selected read-only directions; route navigation is disabled.")
    render()
end

local function tracked_completion_kind()
    local objective = oddq.tracked_objective
    if objective == nil then
        return nil, nil
    end
    if objective.objective_kind == "mission" then
        return "mission", objective.quest_id
    end
    if objective.objective_kind == "quest" then
        return "quest", objective.quest_id
    end
    if objective.objective_kind == "job_unlock" then
        return "quest", objective.quest_id
    end
    return nil, nil
end

local function mark_tracked_done()
    local kind, id = tracked_completion_kind()
    if kind == nil then
        print("odd done needs a tracked mission or quest objective.")
        return
    end
    if progression_ledger.record(completion_ledger_path(), kind, id) then
        print("odd done recorded local guidance completion: " .. tostring(id))
    else
        print("odd done failed to record local guidance completion.")
    end
end

local function undo_tracked_done()
    local kind, id = tracked_completion_kind()
    if kind == nil then
        print("odd undo needs a tracked mission or quest objective.")
        return
    end
    if progression_ledger.remove(completion_ledger_path(), kind, id) then
        print("odd undo removed local guidance completion: " .. tostring(id))
    else
        print("odd undo failed to update local guidance completion.")
    end
end

local function activate_live_route(route)
    oddq.tracked_objective = live_routes.to_objective(route)
    oddq.tracked_objectives.quests = oddq.tracked_objective
    oddq.locked_route = live_routes.to_locked_route(route)
    oddq.locked_route_objective_id = route.route_id
    oddq.active_segment_index = 1
    route_test.reset(route_test_state)
    guidance_state.set_mode(oddq.guidance, "quests", true)
    oddq.guidance.guide_step_tab_index = 0
    if type(oddq.guidance.arrow) == "table" then
        oddq.guidance.arrow.visible = type(oddq.locked_route.segments) == "table" and #oddq.locked_route.segments > 0
    end
    open_guide_notes_window()
    frame_metrics.visible_since_clock = frame_metrics.visible_since_clock or os.clock()
end

local function print_current_route_status()
    local live_state = build_live_state()
    update_active_segment_from_live_state(live_state)
    local output = build_route_window_output()
    if tracked_objective_uses_tabbed_guide() then
        output = tabbed_guide_chat_summary(output)
    end
    print_multiline(output)
end

local function objective_display_label(objective)
    local source = objective or {}
    local label = source.quest_name or source.objective_id or ""
    if type(label) ~= "string" then
        label = tostring(label or "")
    end
    if label == "" then
        return "No guide loaded"
    end
    return label
end

local function build_guided_command_snapshot()
    local objective = oddq.tracked_objective
    local live_state = build_live_state()
    local checkpoint = npc_tracker.resolve_next_checkpoint(objective, live_state)
    local segments = oddq.locked_route and oddq.locked_route.segments
    local route_id = (oddq.locked_route and oddq.locked_route.route_id) or ""
    if type(segments) ~= "table" then
        segments = {}
    end

    local checkpoint_label = ""
    if checkpoint.status ~= "no_checkpoint" and checkpoint.name ~= nil then
        checkpoint_label = "Next checkpoint: " .. tostring(checkpoint.name)
        if checkpoint.map_grid ~= nil and checkpoint.map_grid ~= "" then
            checkpoint_label = checkpoint_label .. " (" .. tostring(checkpoint.map_grid) .. ")"
        end
        if checkpoint.distance ~= nil then
            checkpoint_label = checkpoint_label .. " - nearby " .. tostring(round_ms(checkpoint.distance)) .. " yalms"
        end
        if checkpoint.targeted == true then
            checkpoint_label = checkpoint_label .. " - targeted"
        end
    end

    return {
        mode_label = guidance_state.mode_label(oddq.guidance.active_mode),
        objective_label = objective_display_label(objective),
        has_tracked_objective = objective ~= nil,
        has_live_route = objective ~= nil and route_id ~= "" and route_id ~= "route_sample_static_shell",
        route_label = route_id ~= "" and route_id or "No route loaded",
        active_segment_index = oddq.active_segment_index or 1,
        segment_count = #segments,
        checkpoint_label = checkpoint_label,
    }
end

local function print_guided_text(text)
    print_multiline(text)
end

local function refresh_guided_command_actions()
    command_router.refresh_actions(build_guided_command_snapshot(), guided_command_session)
end

local function request_guided_go(query)
    query = (tostring(query or ""):match("^%s*(.-)%s*$") or "")
    if query == "" then
        print_guided_text(command_router.not_found_text(query))
        return
    end

    local matches = objective_catalog.search(query, nil, 1)
    local entry = matches[1]
    if entry ~= nil then
        load_local_catalog_guide(entry)
        refresh_guided_command_actions()
        render()
        return
    end

    local route = live_routes.find(query)
    if route ~= nil then
        activate_live_route(route)
        print("odd go loaded route: " .. tostring(route.name or route.route_id) .. " (Guidance only; movement remains manual.)")
        print_current_route_status()
        refresh_guided_command_actions()
        render()
        return
    end

    print_guided_text(command_router.not_found_text(query))
end

local function catalog_list_limit(mode)
    if mode == "missions" then
        return 128
    end
    if mode == "quests" then
        return 48
    end
    return 12
end

local function handle_catalog_command(args)
    local command = (args[1] or "list"):lower()
    if command == "list" or command == "catalog" or command == "browse" then
        local mode = args[2] or "all"
        local normalized = objective_catalog.normalize_mode(mode)
        local query_start = 3
        if normalized ~= nil and plan_modes[normalized] ~= true then
            normalized = nil
            query_start = 2
        end
        local query = table.concat(args, " ", query_start)
        local title_mode = normalized or "all"
        local title = "odd list " .. title_mode
        if query ~= "" then
            title = title .. " " .. query
        end
        local entries = objective_catalog.browse(normalized, query, catalog_list_limit(normalized))
        command_router.remember_result_actions(entries, normalized, guided_command_session)
        print_multiline(objective_catalog.render_results(entries, {
            title = title,
            mode = normalized,
        }))
        return
    end

    local query = table.concat(args, " ", 2)
    if query == "" then
        print("odd find expects a guide name. Try /odd find ranger or /odd find sandy 2-2.")
        return
    end
    request_guided_go(query)
end

local function handle_route_test_command(args)
    local action = (args[3] or "status"):lower()

    if action == "start" then
        if not pilot_recorder.is_active() then
            print("odd route test needs an active pilot recorder; run /odd pilot start first.")
            return
        end

        local mode = (args[4] or ""):lower()
        local from_start = mode == "from-start" or mode == "from_start" or mode == "start"
        oddq.active_segment_index = 1
        local events = route_test.start(route_test_state, oddq.locked_route, build_live_state(), {
            from_start = from_start,
        })
        for _, event in ipairs(events) do
            pilot_recorder.record_route_test_event(event)
        end
        if from_start then
            print("odd route test started from route start: " .. tostring(oddq.locked_route.route_id) .. " (private-server progress evidence only).")
        else
            print("odd route test started: " .. tostring(oddq.locked_route.route_id) .. " (private-server progress evidence only).")
        end
        return
    end

    if action == "reset" or action == "stop" then
        route_test.reset(route_test_state)
        print("odd route test reset.")
        return
    end

    print(route_test.status(route_test_state, oddq.locked_route))
    if route_test.is_active(route_test_state) and pilot_recorder.is_active() then
        pilot_recorder.record_route_test_event(route_test.status_event(route_test_state, oddq.locked_route))
    end
end

local function handle_route_command(args)
    local route_key = (args[2] or "list"):lower()
    if route_key == "list" or route_key == "" then
        print("odd route list:")
        for _, label in ipairs(live_routes.list_labels()) do
            print("- " .. label)
        end
        return
    end

    if route_key == "test" then
        handle_route_test_command(args)
        return
    end

    if route_key == "status" or route_key == "nearest" then
        print_current_route_status()
        return
    end

    local route = live_routes.find(route_key)
    if route == nil then
        print("odd route expects list|port|status|test.")
        return
    end

    activate_live_route(route)
    print("odd route loaded: " .. tostring(route.name) .. " (Guidance only; movement remains manual.)")
    print_current_route_status()
    render()
end

local function clear_pilot_batch()
    pilot_batch.active = false
    pilot_batch.total = 0
    pilot_batch.completed = 0
    pilot_batch.delay_seconds = 2
    pilot_batch.next_run_at = 0
end

local function stop_pilot_batch(note)
    if not pilot_batch.active then
        return false
    end

    pilot_recorder.record_batch_stop(pilot_batch.completed, note or "batch complete")
    clear_pilot_batch()
    return true
end

local function run_pilot_batch_tick(timing_source)
    if not pilot_batch.active then
        return
    end
    if os.time() < pilot_batch.next_run_at then
        return
    end

    local metadata = batch_metadata()
    local err = request_locked_route(metadata)
    pilot_batch.completed = pilot_batch.completed + 1
    record_current_frame_sample(timing_source or "manual_render_sample", metadata)

    if err ~= nil then
        print("odd pilot batch route-generation attempt " .. tostring(pilot_batch.completed) .. " kept existing route: " .. err)
    else
        print("odd pilot batch route-generation attempt " .. tostring(pilot_batch.completed) .. " accepted a locked route.")
    end

    if pilot_batch.completed >= pilot_batch.total then
        local completed_attempts = pilot_batch.completed
        stop_pilot_batch("batch complete: route-generation/transport evidence only; no manual arrival claimed")
        pilot_recorder.stop_session("batch complete")
        print("odd pilot batch complete: " .. tostring(completed_attempts) .. " route-generation/transport attempt(s); no manual route-quality proof claimed.")
        return
    end

    pilot_batch.next_run_at = os.time() + pilot_batch.delay_seconds
end

local function start_pilot_batch(count_arg, delay_arg)
    if pilot_batch.active then
        print("odd pilot batch already running: " .. tostring(pilot_batch.completed) .. "/" .. tostring(pilot_batch.total))
        return
    end
    if pilot_recorder.is_active() then
        print("odd pilot batch requires an inactive pilot recorder; run /odd pilot stop first.")
        return
    end

    local count = clamp_integer(count_arg, 8, 1, 25)
    local delay_seconds = clamp_integer(delay_arg, 2, 0, 60)
    local id, err = pilot_recorder.start_session("batch route-generation/transport evidence only")
    if id == nil then
        print("odd pilot batch failed: " .. tostring(err))
        return
    end

    pilot_batch.active = true
    pilot_batch.total = count
    pilot_batch.completed = 0
    pilot_batch.delay_seconds = delay_seconds
    pilot_batch.next_run_at = os.time()
    pilot_recorder.record_batch_start(count, delay_seconds)
    print("odd pilot batch started: " .. tostring(count) .. " route-generation/transport attempt(s), " .. tostring(delay_seconds) .. "s delay; no movement or manual arrival claims.")
    run_pilot_batch_tick("pilot_batch_start")
end

local function request_tracked_objective()
    if refresh_detected_objective_state("track") == "updated" then
        return
    end

    local next_objective, err = bridge_client.request_objective(config, build_live_state(), oddq.tracked_objective)
    if err ~= nil then
        print("odd track kept current objective: " .. err)
        return
    end

    oddq.tracked_objective = next_objective
    local mode = oddq.guidance.active_mode
    if mode == "missions" or mode == "quests" or mode == "exp" then
        oddq.tracked_objectives[mode] = next_objective
    else
        oddq.tracked_objectives.quests = next_objective
    end
    oddq.active_segment_index = 1
    if oddq.tracked_objective == nil then
        print("odd track has no eligible objective.")
        return
    end

    print("odd track selected: " .. tostring(oddq.tracked_objective.quest_name or oddq.tracked_objective.objective_id))
end

local function move_active_segment(delta)
    local segments = oddq.locked_route and oddq.locked_route.segments or {}
    if #segments == 0 then
        print("odd route has no segment to select.")
        return
    end

    oddq.active_segment_index = oddq.active_segment_index + delta
    if oddq.active_segment_index < 1 then
        oddq.active_segment_index = 1
    end
    if oddq.active_segment_index > #segments then
        oddq.active_segment_index = #segments
    end
end

local function move_mission_guide(delta)
    local entry, boundary = objective_catalog.mission_neighbor(oddq.tracked_objective, delta)
    if entry ~= nil then
        load_local_catalog_guide(entry)
        refresh_guided_command_actions()
        return true
    end

    if boundary == "start" then
        print("odd guide has no previous mission in this sequence.")
        return true
    end
    if boundary == "end" then
        print("odd guide has no next mission in this sequence.")
        return true
    end

    return false
end

local function move_tabbed_guide_step(delta)
    if not tracked_objective_uses_tabbed_guide() then
        return false
    end

    local steps = oddq.tracked_objective.steps or {}
    local selected = math.floor(tonumber(oddq.guidance.guide_step_tab_index) or 0)
    selected = math.max(0, math.min(selected, #steps))
    local next_selected = selected + delta
    if next_selected < 0 or next_selected > #steps then
        return false
    end

    oddq.guidance.guide_step_tab_index = next_selected
    return true
end

local function print_help()
    print("/odd - open the OddQ guide browser")
    print("/odd close - close OddQ windows")
    print("/odd <text> - load a matching mission, quest, job, EXP camp, or route")
    print("/odd find <text> - find and load a guide")
    print("/odd status - show the current guide")
    print("/odd next|previous - move through the current guide")
    print("/odd recalc - refresh the current route")
    print("/odd done|undo - update local guide completion")
    print("/odd welcome - open the Guide Browser")
    print("/odd settings - toggle OddQ preferences")
    print("/odd assist - open contextual help for the current guide")
    print("/odd help advanced - diagnostic and reviewer commands")
end

local function current_chat_manager()
    if AshitaCore == nil or AshitaCore.GetChatManager == nil then
        return nil
    end
    local ok, chat = pcall(function()
        return AshitaCore:GetChatManager()
    end)
    if ok then
        return chat
    end
    return nil
end

local function run_assist_action(command)
    if not addon_integration.is_allowed_command(command) then
        print("OddQ blocked unsafe helper command.")
        return
    end

    local ok, err = addon_integration.queue_allowed(command, current_chat_manager())
    if not ok then
        print("OddQ helper command unavailable: " .. tostring(err))
    end
end

local function current_guide_step_index(objective)
    local selected = tonumber(oddq.guidance.guide_step_tab_index)
    if selected ~= nil and selected > 0 and type((objective or {}).steps) == "table" and selected <= #objective.steps then
        return math.floor(selected)
    end
    return oddq.active_segment_index
end

function render()
    if not oddq.visible then
        return
    end

    local output = build_route_window_output()
    if tracked_objective_uses_tabbed_guide() then
        output = tabbed_guide_chat_summary(output)
    end
    print_multiline(output)
end

local function render_ui(live_state)
    if imgui == nil then
        return
    end
    tuner_window.render(imgui, oddq.guidance)
    if oddq.guidance.ui_tuner_save_requested == true then
        oddq.guidance.ui_tuner_save_requested = false
        save_ui_tuner_constants()
    end
    if not oddq.visible then
        return
    end

    live_state = live_state or build_live_state()
    local objective = current_guidance_objective()
    local locked_route_matches = oddq.locked_route_objective_id ~= nil
        and oddq.locked_route_objective_id ~= ""
        and oddq.locked_route_objective_id ~= "manual.none"
        and objective_matches_target(objective, oddq.locked_route_objective_id)
    if locked_route_matches then
        update_active_segment_from_live_state(live_state)
    else
        oddq.active_segment_index = 1
    end
    local pointer_route = objective_pointer.build_route(objective, oddq.guidance, live_state)
    local effective_route = pointer_route
    if effective_route == nil and locked_route_matches then
        effective_route = oddq.locked_route
    end
    local current_assist_state = assist_hub.build_state(
        oddq.guidance,
        objective,
        effective_route,
        current_guide_step_index(objective),
        build_assist_live_context(live_state, objective),
        build_assist_readiness_provider(live_state)
    )
    local auto_filterscan_command = assist_hub.next_auto_filterscan_command(oddq.guidance, current_assist_state, os.clock())
    if auto_filterscan_command ~= nil then
        run_assist_action(auto_filterscan_command)
    end
    map_layers.render(imgui, oddq.guidance, live_state.current_zone_id, effective_route, objective, oddq.active_segment_index, "", function(args)
        handle_command(args or {})
    end, current_assist_state, run_assist_action)
end

local function handle_pilot_command(args)
    local action = (args[2] or "status"):lower()
    local note = table.concat(args, " ", 3)

    if action == "start" then
        local id, err = pilot_recorder.start_session(note)
        if id == nil then
            print("odd pilot failed: " .. tostring(err))
            return
        end
        print("odd pilot started: " .. tostring(id))
        return
    end

    if action == "batch" then
        start_pilot_batch(args[3], args[4])
        return
    end

    if action == "stop" then
        stop_pilot_batch(note)
        if pilot_recorder.stop_session(note) then
            print("odd pilot stopped.")
        else
            print("odd pilot was not active.")
        end
        return
    end

    if action == "ok" then
        pilot_recorder.record_manual_result(true, note)
        print("odd pilot marked manual success.")
        return
    end

    if action == "fail" then
        pilot_recorder.record_manual_result(false, note)
        print("odd pilot marked manual failure.")
        return
    end

    if action == "note" then
        pilot_recorder.record_note(note)
        print("odd pilot note recorded.")
        return
    end

    if action == "frame" then
        record_current_frame_sample("manual_render_sample")
        print("odd pilot frame sample recorded.")
        return
    end

    print(pilot_recorder.status())
end

local function handle_verify_command(args)
    local subject = (args[2] or ""):lower()
    local outcome = (args[3] or ""):lower()
    local note = table.concat(args, " ", 4)
    local success = outcome == "ok"

    if outcome ~= "ok" and outcome ~= "fail" then
        print("odd verify expects point|route ok|fail <note>.")
        return
    end

    if subject == "point" then
        if pilot_recorder.record_point_verification(success, note) then
            print("odd verify point recorded: " .. outcome .. ".")
        else
            print("odd verify point needs an active pilot recorder; run /odd pilot start first.")
        end
        return
    end

    if subject == "route" then
        if pilot_recorder.record_route_quality(success, note) then
            print("odd verify route recorded: " .. outcome .. ".")
        else
            print("odd verify route needs an active pilot recorder; run /odd pilot start first.")
        end
        return
    end

    print("odd verify expects point|route ok|fail <note>.")
end

local function execute_guided_intent(intent)
    if type(intent) ~= "table" then
        print_help()
        return
    end

    if intent.intent == "render_menu" or intent.intent == "show_help" then
        print_guided_text(intent.text)
        return
    end

    if intent.intent == "render_status" then
        print_current_route_status()
        refresh_guided_command_actions()
        return
    end

    if intent.intent == "load_guide" then
        request_guided_go(intent.query)
        return
    end

    if intent.intent == "run_existing_command" then
        handle_command(intent.args or {})
        return
    end

    print_help()
end

function handle_command(args)
    local command = (args[1] or ""):lower()
    local guided_intent

    if command == "" or command == "menu" then
        oddq.guidance.guide_notes_open = false
        oddq.guidance.detailed_information_open = false
        oddq.guidance.settings_open = false
        oddq.guidance.assist_hub_open = false
        oddq.guidance.main_view = "browse"
        oddq.guidance.main_window_open = true
        oddq.visible = true
        frame_metrics.visible_since_clock = frame_metrics.visible_since_clock or os.clock()
        refresh_guided_command_actions()
        return
    end

    if command == "close" then
        oddq.guidance.main_window_open = false
        oddq.guidance.settings_open = false
        oddq.guidance.assist_hub_open = false
        oddq.guidance.guide_notes_open = false
        oddq.guidance.ui_tuner_open = false
        oddq.visible = false
        frame_metrics.visible_since_clock = nil
        return
    end

    if command == "status" or command == "where" or command == "current" or command == "back" or command == "go" or command == "load" or command == "help" or tonumber(command) ~= nil then
        guided_intent = command_router.resolve(args, build_guided_command_snapshot(), guided_command_session)
        execute_guided_intent(guided_intent)
        return
    end

    if command == "ui" or command == "tuner" then
        handle_ui_command(args)
        return
    end

    if command == "settings" or command == "preferences" then
        local opening = oddq.guidance.settings_open ~= true
        oddq.guidance.settings_open = opening
        oddq.guidance.main_window_open = not opening
        oddq.guidance.assist_hub_open = false
        if opening then
            oddq.guidance.ui_tuner_open = false
        end
        if not opening then
            oddq.guidance.main_view = "browse"
        end
        oddq.visible = true
        print("odd settings: " .. tostring(oddq.guidance.settings_open == true))
        return
    end

    if command == "assist" or command == "hub" then
        oddq.guidance.assist_hub_open = false
        oddq.guidance.settings_open = false
        oddq.guidance.main_view = oddq.tracked_objective ~= nil and "guide" or "browse"
        oddq.guidance.main_window_open = true
        oddq.visible = true
        print("odd step assistance is shown inside the current guide.")
        return
    end

    if command == "welcome" then
        oddq.guidance.guide_notes_open = false
        oddq.guidance.main_view = "browse"
        oddq.guidance.main_window_open = true
        oddq.visible = true
        print("odd guide browser opened.")
        return
    end

    if command == "mode" then
        print("odd guide families are always available; use /odd to browse them.")
        return
    end

    if command == "pilot" then
        handle_pilot_command(args)
        return
    end

    if command == "mission" then
        handle_mission_command(args)
        return
    end

    if command == "route" then
        handle_route_command(args)
        return
    end

    if command == "list" or command == "catalog" or command == "browse" or command == "find" or command == "search" then
        handle_catalog_command(args)
        return
    end

    if command == "sandy1" then
        handle_mission_command({ "mission", "sandy1", args[2] })
        return
    end

    if command == "verify" then
        handle_verify_command(args)
        return
    end

    if command == "recalc" then
        local refresh_result = refresh_detected_objective_state("recalc")
        if refresh_result == "completed" then
            request_objective_plan()
        end
        local err = request_locked_route(nil)
        if err ~= nil then
            print("odd recalc kept existing route: " .. err)
        else
            print("odd recalc accepted a new locked route.")
        end
        render()
        return
    end

    if command == "done" then
        mark_tracked_done()
        return
    end

    if command == "undo" then
        undo_tracked_done()
        return
    end

    if command == "plan" then
        request_catalog_objective_plan(args)
        render()
        return
    end

    if command == "jobs" then
        request_job_unlock_plan(args)
        render()
        return
    end

    if command == "track" then
        request_tracked_objective()
        render()
        return
    end

    if command == "next" then
        if not move_tabbed_guide_step(1) and not move_mission_guide(1) then
            move_active_segment(1)
        end
        render()
        return
    end

    if command == "previous" then
        if not move_tabbed_guide_step(-1) and not move_mission_guide(-1) then
            move_active_segment(-1)
        end
        render()
        return
    end

    guided_intent = command_router.resolve(args, build_guided_command_snapshot(), guided_command_session)
    execute_guided_intent(guided_intent)
end

local function parse_command_line(command_line)
    local args = {}
    for token in tostring(command_line or ""):gmatch("%S+") do
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
        return
    end
    handle_command(parse_command_line(command_or_args))
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
    -- ODD_SECURITY_NOTE: read-only addon shell; no packet mutation, movement, targeting, trading, or chat upload.
    -- ODD_FILE_WRITE: future cache path is config/addons/oddq/cache/last_route.json; Slice 2 ships static sample data only.
    local _ = config.server_name
    apply_first_launch_state()
    if oddq.guidance.main_window_open then
        print("OddQ loaded. Guide Browser is open.")
    else
        print("OddQ loaded. Use /odd.")
    end
end)

ashita.events.register("packet_in", "oddq_packet_in", function(e)
    mission_state.observe_packet(e.id, e)
    progression_triggers.observe_packet(progress_trigger_state, e.id, e)
end)

ashita.events.register("d3d_present", "oddq_pilot_batch_tick", function()
    local now = os.clock()
    if frame_metrics.last_present_clock ~= nil then
        frame_metrics.last_frame_delta_ms = round_ms((now - frame_metrics.last_present_clock) * 1000)
    end
    frame_metrics.last_present_clock = now

    local live_state = build_live_state()
    handle_progress_triggers(live_state, "d3d_present")

    if mission_state.consume_dirty() then
        local refresh_result = refresh_detected_objective_state("packet_in")
        if refresh_result == "completed" then
            request_objective_plan()
        end
        if refresh_result == "updated" or refresh_result == "completed" then
            request_locked_route({ source = "mission_state_refresh", evidence_type = "objective_state_refresh" })
        end
    end

    run_pilot_batch_tick("ashita_d3d_present")
    render_ui(live_state)
    save_guidance_preferences()
end)

return oddq
