local command_router = {}

local function safe_text(value)
    local value_type = type(value)
    if
        value_type == "nil"
        or value_type == "table"
        or value_type == "function"
        or value_type == "thread"
        or value_type == "userdata"
    then
        return ""
    end
    return tostring(value)
end

local function trim(value)
    return safe_text(value):match("^%s*(.-)%s*$") or ""
end

local function lower(value)
    return trim(value):lower()
end

local function copy_args(args)
    local copied = {}
    for index, value in ipairs(args or {}) do
        copied[index] = value
    end
    return copied
end

local function join_args(args, start_index)
    local parts = {}
    local start = start_index or 1
    for index = start, #(args or {}) do
        local text = safe_text(args[index])
        if text ~= "" then
            table.insert(parts, text)
        end
    end
    return table.concat(parts, " ")
end

local function prefixed_args(prefix, args, start_index)
    local resolved = copy_args(prefix)
    for index = start_index or 1, #(args or {}) do
        table.insert(resolved, args[index])
    end
    return resolved
end

local function has_mission_number_spec(query)
    local text = lower(query)
    return text:find("%f[%w]m%d+%s*[- ]%s*%d+%f[%W]") ~= nil
        or text:find("%f[%d]%d+%s*[-]%s*%d+%f[%W]") ~= nil
        or text:find("%f[%w]rank%s+%d+%s+mission%s+%d+%f[%W]") ~= nil
end

local function contains_word(text, word)
    return text:find(" " .. word .. " ", 1, true) ~= nil
end

local function remove_word(text, word)
    return text:gsub("%f[%w]" .. word .. "%f[%W]", " ")
end

local function is_broad_nation_mission_query(query)
    if has_mission_number_spec(query) then
        return false
    end

    local text = lower(query):gsub("[^%w]+", " ")
    text = " " .. trim(text:gsub("%s+", " ")) .. " "
    local has_nation = contains_word(text, "sandy")
        or contains_word(text, "sandoria")
        or (contains_word(text, "san") and contains_word(text, "doria"))
        or contains_word(text, "basty")
        or contains_word(text, "bastok")
        or contains_word(text, "windy")
        or contains_word(text, "windurst")
    if not has_nation then
        return false
    end

    local remainder = text
    for _, word in ipairs({ "sandy", "sandoria", "san", "doria", "basty", "bastok", "windy", "windurst", "mission", "rank" }) do
        remainder = remove_word(remainder, word)
    end
    remainder = remainder:gsub("%d+", " ")
    remainder = trim(remainder:gsub("%s+", " "))
    return remainder == ""
end

local expansion_mission_aliases = {
    rov = { chapter_browse = true },
    cop = { chapter_browse = true },
    pm = { chapter_browse = true },
    toau = { chapter_browse = false },
    wotg = { chapter_browse = false },
    zilart = { chapter_browse = false },
    zm = { chapter_browse = false },
}

local function is_broad_expansion_mission_query(query)
    if has_mission_number_spec(query) then
        return false
    end

    local text = lower(query):gsub("[^%w]+", " ")
    text = " " .. trim(text:gsub("%s+", " ")) .. " "
    local matched_alias = nil
    local matched_spec = nil
    for alias, spec in pairs(expansion_mission_aliases) do
        if contains_word(text, alias) then
            matched_alias = alias
            matched_spec = spec
            break
        end
    end
    if matched_alias == nil then
        return false
    end

    local remainder = remove_word(text, matched_alias)
    for _, word in ipairs({ "mission", "missions", "chapter" }) do
        remainder = remove_word(remainder, word)
    end
    remainder = trim(remainder:gsub("%s+", " "))
    return remainder == "" or (matched_spec.chapter_browse == true and remainder:match("^%d+$") ~= nil)
end

local function is_exp_level_query(query)
    local text = lower(query):gsub("[^%w]+", " ")
    text = trim(text:gsub("%s+", " "))
    if text:match("^%d+$") ~= nil then
        return true
    end
    return text:match("^lv%s+%d+$") ~= nil
        or text:match("^level%s+%d+$") ~= nil
end

local function normalized_words(query)
    local text = lower(query):gsub("[^%w]+", " ")
    return trim(text:gsub("%s+", " "))
end

local function broad_quest_chain_target(query)
    local text = normalized_words(query)
    if text == "lb" or text == "limit" or text == "limit break" or text == "limit breaks" or text == "genkai" then
        return { "limit", "break" }
    end
    if text == "gobbiebag" or text == "gobbie bag" or text == "gobbiebag chain" or text == "bag" or text == "inventory" then
        return { "gobbiebag" }
    end
    return nil
end

local function make_action(label, intent, options)
    options = options or {}
    return {
        label = label,
        intent = intent,
        args = options.args,
        query = options.query,
        topic = options.topic,
    }
end

local result_mode_for_kind = {
    mission = "missions",
    job_unlock = "jobs",
    quest = "quests",
    exp = "exp",
    exp_camp = "exp",
}

local function entry_result_mode(entry, mode)
    local resolved = trim(mode)
    if resolved ~= "" then
        return resolved
    end
    return result_mode_for_kind[safe_text((entry or {}).kind)]
end

local function entry_result_target(entry)
    entry = entry or {}
    local target = trim(entry.objective_id)
    if target ~= "" then
        return target
    end
    target = trim(entry.id)
    if target ~= "" then
        return target
    end
    return trim(entry.name)
end

local function entry_result_label(entry)
    local label = trim((entry or {}).name)
    if label == "" then
        label = entry_result_target(entry)
    end
    if label == "" then
        label = "selected result"
    end
    return "Load " .. label
end

local function objective_label(snapshot)
    local label = trim((snapshot or {}).objective_label)
    if label == "" then
        return "No guide loaded"
    end
    return label
end

local function mode_label(snapshot)
    local label = trim((snapshot or {}).mode_label)
    if label == "" then
        return "Missions"
    end
    return label
end

local function has_tracked_objective(snapshot)
    snapshot = snapshot or {}
    if snapshot.has_tracked_objective == true then
        return true
    end
    local label = objective_label(snapshot)
    return label ~= "No guide loaded" and label ~= "No objective tracked"
end

local function has_live_route(snapshot)
    snapshot = snapshot or {}
    return snapshot.has_live_route == true
end

local function build_actions(snapshot)
    if has_live_route(snapshot) then
        return {
            make_action("Show current guide", "render_status"),
            make_action("Next step", "run_existing_command", { args = { "next" } }),
            make_action("Refresh route", "run_existing_command", { args = { "recalc" } }),
            make_action("Browse guides", "run_existing_command", { args = { "menu" } }),
        }
    end

    if has_tracked_objective(snapshot) then
        return {
            make_action("Show current guide", "render_status"),
            make_action("Refresh route", "run_existing_command", { args = { "recalc" } }),
            make_action("Mark current guide done", "run_existing_command", { args = { "done" } }),
            make_action("Browse guides", "run_existing_command", { args = { "menu" } }),
        }
    end

    return {
        make_action("Plan next recommendations", "run_existing_command", { args = { "plan" } }),
        make_action("Browse guides", "run_existing_command", { args = { "menu" } }),
        make_action("Browse missions", "run_existing_command", { args = { "list", "missions" } }),
        make_action("Browse job unlocks", "run_existing_command", { args = { "list", "jobs" } }),
    }
end

local function menu_text(snapshot, actions, note)
    local lines = {
        "OddQ",
        "Mode: " .. mode_label(snapshot),
        "Current: " .. objective_label(snapshot),
    }
    local checkpoint = trim((snapshot or {}).checkpoint_label)
    if checkpoint ~= "" then
        table.insert(lines, checkpoint)
    end
    if note ~= nil and note ~= "" then
        table.insert(lines, note)
    end
    table.insert(lines, "Next:")
    for index, action in ipairs(actions or {}) do
        table.insert(lines, tostring(index) .. ". " .. safe_text(action.label))
    end
    table.insert(lines, "Use /odd <text>, /odd status, /odd help, /odd open <number>.")
    return table.concat(lines, "\n")
end

local function refresh_actions(snapshot, session)
    session = session or command_router.new_session()
    local actions = build_actions(snapshot or {})
    session.last_actions = actions
    session.last_context = "top"
    return actions
end

local function has_remembered_result_actions(session)
    return session ~= nil
        and session.last_context == "results"
        and type(session.last_actions) == "table"
        and #session.last_actions > 0
end

local function render_menu(snapshot, session, note, preserve_context)
    local actions = nil
    if preserve_context == true and has_remembered_result_actions(session) then
        actions = session.last_actions
    else
        actions = refresh_actions(snapshot, session)
    end
    return menu_text(snapshot or {}, actions, note)
end

local function from_action(action, snapshot, session)
    if action == nil then
        return nil
    end
    if action.intent == "show_help" then
        return {
            intent = action.intent,
            text = command_router.help_text(action.topic),
            topic = action.topic,
        }
    end
    return {
        intent = action.intent,
        args = copy_args(action.args),
        query = action.query,
        topic = action.topic,
    }
end

local function select_remembered_result(choice, snapshot, session)
    local index = tonumber(choice)
    if index == nil then
        return {
            intent = "render_menu",
            text = render_menu(snapshot, session, "Pick a result number, for example /odd open 2."),
        }
    end

    if not has_remembered_result_actions(session) then
        return {
            intent = "render_menu",
            text = render_menu(snapshot, session, "No recent results. Browse first, for example /odd sandy 2."),
        }
    end

    local resolved = from_action((session.last_actions or {})[index])
    if resolved ~= nil then
        return resolved
    end
    return {
        intent = "render_menu",
        text = render_menu(snapshot, session, "That result choice is not available anymore."),
    }
end

local function render_recent_results(snapshot, session)
    if not has_remembered_result_actions(session) then
        return render_menu(snapshot, session, "No recent results. Browse first, for example /odd sandy 2.")
    end
    return render_menu(snapshot, session, "Recent results:", true)
end

function command_router.new_session()
    return {
        last_actions = {},
        last_context = "top",
    }
end

function command_router.render_menu(snapshot, session, note)
    return render_menu(snapshot, session, note, true)
end

function command_router.refresh_actions(snapshot, session)
    return refresh_actions(snapshot, session)
end

function command_router.remember_result_actions(entries, mode, session)
    session = session or command_router.new_session()
    local actions = {}
    for _, entry in ipairs(entries or {}) do
        local target = entry_result_target(entry)
        if target ~= "" then
            local args = { "plan" }
            local resolved_mode = entry_result_mode(entry, mode)
            if resolved_mode ~= nil and resolved_mode ~= "" then
                table.insert(args, resolved_mode)
            end
            table.insert(args, target)
            table.insert(actions, make_action(entry_result_label(entry), "run_existing_command", { args = args }))
        end
    end
    session.last_actions = actions
    session.last_context = "results"
    return actions
end

function command_router.help_text(topic)
    topic = lower(topic)
    if topic == "advanced" or topic == "diagnostics" or topic == "review" then
        return table.concat({
            "OddQ advanced diagnostics",
            "Route tests: /odd route test start|status|reset",
            "Pilot evidence: /odd pilot start|stop|status|ok|fail|note|frame",
            "Manual verification: /odd verify point|route ok|fail <note>",
            "UI tuning: /odd ui, /odd ui save",
            "These commands are for private-server validation and reviewer evidence.",
        }, "\n")
    end
    if topic == "bridge" or topic == "service" or topic == "local" then
        return table.concat({
            "OddQ bridge",
            "OddQ bridge is the local route service on this PC.",
            "Used by: /odd recalc, /odd track, /odd plan with no text",
            "Not used by: /odd sandy 2-2, /odd exp 18, /odd open <number>",
            "Typed guide lookup stays local and can work while the route service is offline.",
        }, "\n")
    end
    local lines = {
        "OddQ help",
        "Start: /odd opens the guide browser; /odd <text> loads a guide",
        "Current guide: /odd status, /odd recalc, /odd done, /odd undo",
        "Browse: /odd find <guide>, /odd list missions|jobs|quests|exp",
        "Routes: /odd route list, /odd route status",
        "Results: /odd results, /odd open <number>, /odd select <number>, or /odd <number>",
        "Examples: /odd sandy 2-2, /odd exp 18, /odd open 2",
        "More: /odd help bridge or /odd help advanced",
    }
    if topic == "go" or topic == "start" then
        table.insert(lines, "Examples: /odd ranger, /odd sandy 2-2, /odd port.")
    end
    return table.concat(lines, "\n")
end

function command_router.not_found_text(query)
    query = trim(query)
    if query == "" then
        return table.concat({
            "OddQ did not get a guide search.",
            "Try /odd ranger, /odd sandy 2-2, /odd quests gobbiebag, or /odd routes.",
        }, "\n")
    end
    return table.concat({
        "OddQ did not find: " .. query,
        "Try /odd " .. query .. " again if the spelling is close.",
        "Search narrower: /odd missions " .. query .. " or /odd quests " .. query .. ".",
        "Browse instead: /odd missions, /odd quests, /odd routes.",
    }, "\n")
end

local passthrough_commands = {
    done = true,
    find = true,
    jobs = true,
    list = true,
    mission = true,
    mode = true,
    next = true,
    pilot = true,
    plan = true,
    previous = true,
    recalc = true,
    route = true,
    track = true,
    undo = true,
    verify = true,
    welcome = true,
}

local result_selection_commands = {
    choose = true,
    open = true,
    pick = true,
    select = true,
}

local browse_mode_aliases = {
    missions = "missions",
    quests = "quests",
    exp = "exp",
    camps = "exp",
}

local mode_command_aliases = {
    mission = "missions",
    m = "missions",
    quest = "quests",
    q = "quests",
    job = "jobs",
    j = "jobs",
}

local legacy_mission_subcommands = {
    auto = true,
    detect = true,
    sandy1 = true,
    sandoria1 = true,
    ["sandoria-rank1"] = true,
}

local function resolve_mode_command(mode, args, options)
    options = options or {}
    local query = join_args(args, 2)
    if query == "" then
        return {
            intent = "run_existing_command",
            args = { "list", mode },
        }
    end
    if mode == "missions" and (is_broad_nation_mission_query(query) or is_broad_expansion_mission_query(query)) then
        return {
            intent = "run_existing_command",
            args = prefixed_args({ "list", mode }, args, 2),
        }
    end
    if mode == "exp" and is_exp_level_query(query) then
        return {
            intent = "run_existing_command",
            args = prefixed_args({ "list", mode }, args, 2),
        }
    end
    if mode == "quests" and options.allow_broad_quest_browse == true then
        local target = broad_quest_chain_target(query)
        if target ~= nil then
            return {
                intent = "run_existing_command",
                args = prefixed_args({ "list", "quests" }, target, 1),
            }
        end
    end
    return {
        intent = "run_existing_command",
        args = prefixed_args({ "plan", mode }, args, 2),
    }
end

function command_router.resolve(args, snapshot, session)
    args = args or {}
    session = session or command_router.new_session()
    local command = lower(args[1])

    if command == "" or command == "menu" then
        return {
            intent = "render_menu",
            text = render_menu(snapshot, session),
        }
    end

    local choice = tonumber(command)
    if choice ~= nil then
        local action = (session.last_actions or {})[choice]
        local resolved = from_action(action)
        if resolved ~= nil then
            return resolved
        end
        return {
            intent = "render_menu",
            text = render_menu(snapshot, session, "That menu choice is not available anymore."),
        }
    end

    if result_selection_commands[command] == true then
        return select_remembered_result(args[2], snapshot, session)
    end

    if command == "results" or command == "recent" or command == "choices" then
        return {
            intent = "render_menu",
            text = render_recent_results(snapshot, session),
        }
    end

    if command == "help" then
        return {
            intent = "show_help",
            topic = args[2],
            text = command_router.help_text(args[2]),
        }
    end

    if command == "status" or command == "where" or command == "current" then
        return {
            intent = "render_status",
        }
    end

    if command == "back" then
        return {
            intent = "render_menu",
            text = render_menu(snapshot, session),
        }
    end

    if command == "load" then
        if tonumber(args[2]) ~= nil then
            return select_remembered_result(args[2], snapshot, session)
        end
        return {
            intent = "load_guide",
            query = join_args(args, 2),
        }
    end

    if command == "go" then
        return {
            intent = "load_guide",
            query = join_args(args, 2),
        }
    end

    local browse_mode = browse_mode_aliases[command]
    if browse_mode ~= nil then
        return resolve_mode_command(browse_mode, args, { allow_broad_quest_browse = true })
    end

    local mode_alias = mode_command_aliases[command]
    if mode_alias ~= nil then
        if command == "mission" and legacy_mission_subcommands[lower(args[2])] == true then
            return {
                intent = "run_existing_command",
                args = copy_args(args),
            }
        end
        return resolve_mode_command(mode_alias, args)
    end

    if expansion_mission_aliases[command] ~= nil then
        local query = join_args(args, 1)
        if is_broad_expansion_mission_query(query) then
            return {
                intent = "run_existing_command",
                args = prefixed_args({ "list", "missions" }, args, 1),
            }
        end
        return {
            intent = "load_guide",
            query = query,
        }
    end

    if command == "routes" then
        if join_args(args, 2) == "" then
            return {
                intent = "run_existing_command",
                args = { "route", "list" },
            }
        end
        return {
            intent = "run_existing_command",
            args = prefixed_args({ "route" }, args, 2),
        }
    end

    if command == "r" then
        if join_args(args, 2) == "" then
            return {
                intent = "run_existing_command",
                args = { "route", "list" },
            }
        end
        return {
            intent = "run_existing_command",
            args = prefixed_args({ "route" }, args, 2),
        }
    end

    if passthrough_commands[command] == true then
        return {
            intent = "run_existing_command",
            args = copy_args(args),
        }
    end

    local query = join_args(args, 1)
    if is_broad_nation_mission_query(query) or is_broad_expansion_mission_query(query) then
        return {
            intent = "run_existing_command",
            args = prefixed_args({ "list", "missions" }, args, 1),
        }
    end
    local quest_chain_target = broad_quest_chain_target(query)
    if quest_chain_target ~= nil then
        return {
            intent = "run_existing_command",
            args = prefixed_args({ "list", "quests" }, quest_chain_target, 1),
        }
    end

    return {
        intent = "load_guide",
        query = query,
    }
end

return command_router
