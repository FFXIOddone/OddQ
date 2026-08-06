local objective_catalog = require("objective_catalog")
local imgui_text = require("ui/imgui_text")
local skin = require("ui/skin")
local zone_names_loaded, zone_names = pcall(require, "data/zone_names")
if not zone_names_loaded then
    zone_names = {}
end

local guide_browser = {}

local OWNERSHIP_MODES = {
    { id = "ACE", label = "ACE" },
    { id = "CW", label = "CW" },
    { id = "WEW", label = "WeW" },
}

local categories = {
    {
        id = "catseye",
        label = "Catseye Quests",
        mode = "all",
        catalog_group = "catseye_custom_quests",
        empty_hint = "Imported Catseye-specific quest guides from BG-Wiki.",
    },
    {
        id = "quests",
        label = "All Quests",
        mode = "quests",
        empty_hint = "Retail and server quest guides.",
    },
    {
        id = "zilart_quests",
        label = "Zilart Quests",
        mode = "quests",
        expansion_keys = { "rise_of_the_zilart" },
        empty_hint = "Outlands quest-log entries associated with Rise of the Zilart.",
    },
    {
        id = "promathia_quests",
        label = "Promathia Quests",
        mode = "quests",
        expansion_keys = { "chains_of_promathia" },
        empty_hint = "Tavnazian quest-log entries associated with Chains of Promathia.",
    },
    {
        id = "aht_urhgan_quests",
        label = "Aht Urhgan Quests",
        mode = "quests",
        expansion_keys = { "treasures_of_aht_urhgan" },
        empty_hint = "Aht Urhgan quest-log entries.",
    },
    {
        id = "missions",
        label = "Missions",
        mode = "missions",
        empty_hint = "Mission guides by nation and expansion.",
    },
    {
        id = "jobs",
        label = "Job Unlocks",
        mode = "jobs",
        empty_hint = "Advanced job unlock guides.",
    },
    {
        id = "npcs",
        label = "NPC Finder",
        mode = "npcs",
        empty_hint = "Search an NPC name or something a source-backed merchant sells.",
    },
    {
        id = "exp_solo",
        label = "Solo (Trust) Camps",
        mode = "exp",
        exp_category_keys = { "solo_trusts", "duo_trusts" },
        empty_hint = "Solo and duo camp guidance with Trust support.",
    },
    {
        id = "exp_6man",
        label = "6man Camps",
        mode = "exp",
        exp_category_keys = { "parties" },
        empty_hint = "Traditional six-player party camp guidance.",
    },
    {
        id = "exp_mageburn",
        label = "MageBurn Camps",
        mode = "exp",
        exp_category_keys = { "manaburns" },
        empty_hint = "Source-backed magic-burn camp guidance.",
    },
    {
        id = "exp_meleeburn",
        label = "MeleeBurn Camps",
        mode = "exp",
        exp_category_keys = { "pet_parties" },
        empty_hint = "Source-backed pet and melee-burn camp guidance.",
    },
}

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

local function copy_args(args)
    local copied = {}
    for index, value in ipairs(args or {}) do
        copied[index] = tostring(value or "")
    end
    return copied
end

local function category_by_id(id)
    local target = trim(id)
    if target == "exp" then
        target = "exp_solo"
    end
    for _, category in ipairs(categories) do
        if category.id == target then
            return category
        end
    end
    return categories[1]
end

local function category_index(id)
    local target = trim(id)
    for index, category in ipairs(categories) do
        if category.id == target then
            return index
        end
    end
    return 1
end

local function ensure_state(state)
    state = state or {}
    if trim(state.guide_browser_category) == "" then
        state.guide_browser_category = "catseye"
    end
    if state.guide_browser_query == nil then
        state.guide_browser_query = ""
    end
    if tonumber(state.guide_browser_selected_index) == nil or tonumber(state.guide_browser_selected_index) < 1 then
        state.guide_browser_selected_index = 1
    end
    if tonumber(state.guide_browser_page) == nil or tonumber(state.guide_browser_page) < 1 then
        state.guide_browser_page = 1
    end
    return state
end

local function level_label(entry)
    if (entry or {}).level_requirement_unknown == true then
        return "Level: Unknown"
    end
    local level_min = tonumber((entry or {}).level_min) or 0
    local level_max = tonumber((entry or {}).level_max) or 0
    if trim((entry or {}).kind) == "mission" and level_min <= 1 and level_max <= 0 then
        return ""
    end
    if level_min > 0 and level_max > 0 then
        return "Lv." .. tostring(level_min) .. "-" .. tostring(level_max)
    end
    if level_min > 0 then
        return "Lv." .. tostring(level_min) .. "+"
    end
    if level_max > 0 then
        return "Up to Lv." .. tostring(level_max)
    end
    return ""
end

local function first_step(entry)
    if type((entry or {}).steps) == "table" then
        for _, step in ipairs(entry.steps) do
            if type(step) == "table" then
                return step
            end
        end
    end
    return {}
end

local function first_zone_name(entry)
    local step = first_step(entry)
    local zone_id = tonumber(step.zone_id or (entry or {}).first_zone_id)
    if zone_id == nil then
        return ""
    end
    return trim(zone_names[zone_id])
end

local function guide_kind(entry)
    local mode = objective_catalog.mode_for_entry(entry)
    if mode == "missions" then
        return "mission"
    end
    if mode == "jobs" then
        return "job"
    end
    if mode == "exp" then
        return "exp"
    end
    if mode == "npcs" then
        return "npc"
    end
    return "quest"
end

local function guide_action(entry)
    local mode = objective_catalog.mode_for_entry(entry)
    local objective_id = trim((entry or {}).objective_id)
    if mode == "" or objective_id == "" then
        return {}
    end
    return { "plan", mode, objective_id }
end

local function format_gil(value)
    local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
    return text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") .. " gil"
end

local function matching_service(entry, query)
    local wanted = trim(query):lower()
    if wanted == "" then
        return nil
    end
    for _, service in ipairs(type((entry or {}).services) == "table" and entry.services or {}) do
        local parts = { trim(service.name), trim(service.detail) }
        for _, term in ipairs(type(service.search_terms) == "table" and service.search_terms or {}) do
            table.insert(parts, trim(term))
        end
        if table.concat(parts, " "):lower():find(wanted, 1, true) ~= nil then
            return service
        end
    end
    return nil
end

local function game_mode_ownership(entry)
    local supported = {}
    for _, mode in ipairs(type((entry or {}).game_modes) == "table" and entry.game_modes or {}) do
        supported[trim(mode):upper()] = true
    end
    local ownership = {}
    local labels = {}
    for _, mode in ipairs(OWNERSHIP_MODES) do
        table.insert(ownership, {
            id = mode.id,
            label = mode.label,
            supported = supported[mode.id] == true,
        })
        table.insert(labels, mode.label)
    end
    return table.concat(labels, " / "), ownership
end

local function guide_meta(entry, query)
    local parts = {}
    local level = level_label(entry)
    if level ~= "" then
        table.insert(parts, level)
    end
    if trim((entry or {}).kind) == "exp_camp" then
        local category = trim((entry or {}).category)
        local zone = first_zone_name(entry)
        if category ~= "" then
            table.insert(parts, category)
        end
        if zone ~= "" then
            table.insert(parts, zone)
        end
        return table.concat(parts, " - "), nil
    end
    if trim((entry or {}).kind) == "npc_service" then
        local service = matching_service(entry, query)
        if service ~= nil then
            local service_kind = trim(service.kind)
            if service_kind == "sells" then
                table.insert(parts, "Sells " .. trim(service.name))
            elseif service_kind == "exchanges" then
                table.insert(parts, "Exchanges: " .. trim(service.name))
            else
                table.insert(parts, "Offers: " .. trim(service.name))
            end
            if service_kind == "sells" and (tonumber(service.price) or 0) > 0 then
                table.insert(parts, format_gil(service.price))
            end
        else
            table.insert(parts, tostring(tonumber((entry or {}).service_count) or 0) .. " shop items")
        end
        local zone = trim((entry or {}).zone_name)
        if zone ~= "" then
            table.insert(parts, zone)
        end
        return table.concat(parts, " - "), nil
    end
    return game_mode_ownership(entry)
end

local function result_from_guide(entry, query)
    local meta, ownership = guide_meta(entry, query)
    return {
        kind = "guide",
        label = trim((entry or {}).name),
        meta = meta,
        ownership = ownership,
        entry = entry,
        args = guide_action(entry),
    }
end

local function search_query(state, category)
    local query = trim(state.guide_browser_query)
    if query ~= "" then
        return query
    end
    return trim((category or {}).default_query)
end

local function build_results(state, category, limit)
    local max_count = math.max(1, math.floor(tonumber(limit) or 8))
    local page = math.max(1, math.floor(tonumber(state.guide_browser_page) or 1))
    local cache_key = table.concat({
        category.id,
        category.mode,
        trim(category.catalog_group),
        table.concat(type(category.exp_category_keys) == "table" and category.exp_category_keys or {}, ","),
        table.concat(type(category.expansion_keys) == "table" and category.expansion_keys or {}, ","),
        search_query(state, category),
        tostring(page),
        tostring(max_count),
    }, "\0")
    if state._guide_browser_results_cache_key == cache_key then
        return state._guide_browser_results_cache, page, state._guide_browser_results_cache_has_next
    end
    local results = {}
    local query = search_query(state, category)
    local last_index = page * max_count
    local rows = objective_catalog.browse(
        category.mode,
        query,
        last_index + 1,
        category.catalog_group,
        category.exp_category_keys,
        category.expansion_keys
    )
    for index = ((page - 1) * max_count) + 1, math.min(last_index, #rows) do
        table.insert(results, result_from_guide(rows[index], query))
    end
    local has_next = #rows > last_index
    state._guide_browser_results_cache_key = cache_key
    state._guide_browser_results_cache = results
    state._guide_browser_results_cache_has_next = has_next
    return results, page, has_next
end

function guide_browser.model(state, limit)
    state = ensure_state(state)
    local category = category_by_id(state.guide_browser_category)
    state.guide_browser_category = category.id
    local results, page, has_next = build_results(state, category, limit)
    if #results == 0 and page > 1 then
        state.guide_browser_page = 1
        results, page, has_next = build_results(state, category, limit)
    end
    state.guide_browser_page = page
    if #results > 0 and state.guide_browser_selected_index > #results then
        state.guide_browser_selected_index = 1
    end
    return {
        categories = categories,
        category = category,
        category_index = category_index(category.id),
        query = trim(state.guide_browser_query),
        effective_query = search_query(state, category),
        page = page,
        has_previous = page > 1,
        has_next = has_next,
        selected_index = tonumber(state.guide_browser_selected_index) or 1,
        results = results,
        selected = results[tonumber(state.guide_browser_selected_index) or 1],
    }
end

function guide_browser.render_state(state)
    local model = guide_browser.model(state, 8)
    local counts = objective_catalog.counts()
    local lines = {
        "Guide Browser",
        "Category: " .. model.category.label,
        "Categories: Catseye Quests, All Quests, Zilart Quests, Promathia Quests, Aht Urhgan Quests, Missions, Job Unlocks, NPC Finder, Solo (Trust) Camps, 6man Camps, MageBurn Camps, MeleeBurn Camps",
        "Query: " .. (model.query ~= "" and model.query or "(browse)"),
        "Page: " .. tostring(model.page),
        "Catalog Counts: "
            .. tostring(counts.missions or 0)
            .. " missions, "
            .. tostring(counts.jobs or 0)
            .. " jobs, "
            .. tostring(counts.quests or 0)
            .. " quests, "
            .. tostring(counts.exp or 0)
            .. " exp",
        "Results:",
    }
    if #model.results == 0 then
        table.insert(lines, "No browser results. " .. tostring(model.category.empty_hint or ""))
    else
        for index, result in ipairs(model.results) do
            local kind = guide_kind(result.entry)
            local suffix = result.meta ~= "" and " - " .. result.meta or ""
            table.insert(lines, tostring(index) .. ". [" .. kind .. "] " .. result.label .. suffix)
        end
    end
    return table.concat(lines, "\n")
end

local function text_line(imgui, text)
    imgui_text.wrapped(imgui, text)
end

local function muted_line(imgui, text)
    if imgui ~= nil and imgui.GetWindowWidth ~= nil then
        local wrap = math.max(1.0, (tonumber(imgui.GetWindowWidth()) or 0.0) - 16.0)
        skin.text_colored_wrapped_at(imgui, skin.colors.muted, text, wrap, "body")
        return
    end
    skin.text_colored(imgui, skin.colors.muted, text, "body")
end

local function same_line(imgui, gap)
    if imgui == nil or imgui.SameLine == nil then
        return
    end
    gap = tonumber(gap)
    if gap == nil then
        imgui.SameLine()
        return
    end
    local ok = pcall(imgui.SameLine, 0.0, gap)
    if not ok then
        imgui.SameLine()
    end
end

local function render_ownership(imgui, ownership)
    for index, mode in ipairs(type(ownership) == "table" and ownership or {}) do
        if index > 1 then
            same_line(imgui)
            skin.text_colored(imgui, skin.colors.white, "/", "body")
            same_line(imgui)
        end
        local color = mode.supported == true and skin.colors.blue_highlight or skin.colors.white
        skin.text_colored(imgui, color, mode.label, "body")
    end
end

local function inset_cursor_x(imgui, inset)
    if imgui == nil or imgui.GetCursorScreenPos == nil or imgui.SetCursorScreenPos == nil then
        return
    end
    local x, y = imgui.GetCursorScreenPos()
    if type(x) == "table" then
        y = x[2]
        x = x[1]
    end
    x = tonumber(x)
    y = tonumber(y)
    if x ~= nil and y ~= nil then
        imgui.SetCursorScreenPos({ x + math.max(0.0, tonumber(inset) or 0.0), y })
    end
end

local function input_text(imgui, label, current)
    if imgui == nil or imgui.InputText == nil then
        return current
    end
    local value = { tostring(current or "") }
    local ok, changed, returned = pcall(function()
        return imgui.InputText(label, value, 128)
    end)
    if not ok then
        ok, changed, returned = pcall(function()
            return imgui.InputText(label, tostring(current or ""), 128)
        end)
    end
    if not ok then
        return current
    end
    if type(returned) == "string" then
        return returned
    end
    if type(changed) == "string" then
        return changed
    end
    if changed == true and type(value[1]) == "string" then
        return value[1]
    end
    if type(value[1]) == "string" then
        return value[1]
    end
    return current
end

local function begin_child(imgui, id, size)
    if imgui == nil or imgui.BeginChild == nil then
        return true, false
    end
    local ok, opened = pcall(imgui.BeginChild, tostring(id or ""), size, true)
    if ok then
        return opened ~= false, true
    end
    ok, opened = pcall(imgui.BeginChild, tostring(id or ""), size)
    if ok then
        return opened ~= false, true
    end
    return true, false
end

local function end_child(imgui, used_child)
    if used_child and imgui ~= nil and imgui.EndChild ~= nil then
        imgui.EndChild()
    end
end

local function dispatch(on_command, args)
    if type(on_command) == "function" and type(args) == "table" and #args > 0 then
        on_command(copy_args(args))
    end
end

local function render_category_row(imgui, state, model, layout)
    for index, category in ipairs(model.categories) do
        local row_break = (layout.wrap_categories == true and (index == 4 or index == 7 or index == 10))
            or (layout.wrap_categories ~= true and (index == 6 or index == 10))
        if index > 1 and not row_break then
            same_line(imgui, tonumber(layout.category_gap) or 6.0)
        end
        local active = category.id == model.category.id
        if skin.button(imgui, category.label .. "##oddq_browser_category_" .. category.id, active and "active" or "secondary") then
            state.guide_browser_category = category.id
            state.guide_browser_page = 1
            state.guide_browser_selected_index = 1
        end
    end
end

local function result_button_label(label, width)
    label = trim(label)
    local max_characters = math.max(8, math.floor((math.max(1.0, tonumber(width) or 1.0) - 16.0) / 8.0))
    if #label <= max_characters then
        return label
    end
    return label:sub(1, math.max(1, max_characters - 3)):gsub("%s+$", "") .. "..."
end

local function render_results_pane(imgui, state, model, on_command, layout)
    skin.text_colored(imgui, skin.colors.blue_highlight, model.category.label, "section")
    inset_cursor_x(imgui, layout.gutter_width)
    local list_height = math.max(72.0, (tonumber(layout.height) or 420.0) - 78.0)
    local opened, child = begin_child(
        imgui,
        "oddq_guide_browser_result_list",
        { layout.results_width, list_height }
    )
    if opened then
        if #model.results == 0 then
            text_line(imgui, model.category.empty_hint or "No results.")
        end
        for index, result in ipairs(model.results) do
            local button_width = math.max(1.0, (tonumber(layout.results_width) or 390.0) - 24.0)
            local label = result_button_label(result.label, button_width)
            local active = index == model.selected_index
            if skin.button(
                imgui,
                label .. "##oddq_browser_result_" .. tostring(index),
                active and "active" or "secondary",
                { button_width, 0.0 }
            ) then
                state.guide_browser_selected_index = index
            end
            if type(result.ownership) == "table" and #result.ownership > 0 then
                render_ownership(imgui, result.ownership)
            elseif result.meta ~= "" then
                muted_line(imgui, result.meta)
            end
        end
    end
    end_child(imgui, child)
    text_line(imgui, "Page " .. tostring(model.page))
    if skin.button(imgui, "Previous Page##oddq_browser_previous", model.has_previous and "secondary" or "disabled") then
        state.guide_browser_page = model.page - 1
        state.guide_browser_selected_index = 1
    end
    same_line(imgui, 6.0)
    if skin.button(imgui, "Next Page##oddq_browser_more", model.has_next and "secondary" or "disabled") then
        state.guide_browser_page = model.page + 1
        state.guide_browser_selected_index = 1
    end
    if model.selected ~= nil then
        same_line(imgui, 6.0)
        if skin.button(imgui, "Open Guide##oddq_browser_load", "primary") then
            dispatch(on_command, model.selected.args)
        end
    end
end

function guide_browser.render(imgui, state, on_command)
    if state == nil then
        return
    end
    ensure_state(state)
    local layout = ((skin.layout.main_window or {}).guide_browser or {})
    skin.text_colored(imgui, skin.colors.blue_highlight, "Find a guide", "title")
    text_line(imgui, "Search guides, EXP camps, NPC names, and merchant stock.")
    local previous_query = state.guide_browser_query
    if imgui.SetNextItemWidth ~= nil then
        pcall(imgui.SetNextItemWidth, tonumber(layout.search_width) or -1.0)
    end
    state.guide_browser_query = input_text(imgui, "##oddq_guide_browser_search", previous_query)
    if state.guide_browser_query ~= previous_query then
        state.guide_browser_page = 1
        state.guide_browser_selected_index = 1
    end
    local result_limit = math.max(1, math.floor(tonumber(layout.limit) or 8))
    if imgui ~= nil and imgui.GetWindowHeight ~= nil then
        local window_height = tonumber(imgui.GetWindowHeight()) or 0.0
        local compact_limit = math.max(1, math.floor((window_height - 240.0) / 48.0))
        result_limit = math.min(result_limit, compact_limit)
    end
    local model = guide_browser.model(state, result_limit)

    local child_layout = {
        results_width = tonumber(layout.results_width) or 550.0,
        height = tonumber(layout.height) or 420.0,
        category_gap = tonumber(layout.category_gap) or 6.0,
        column_gap = tonumber(layout.column_gap) or 4.0,
        gutter_width = 0.0,
    }
    if imgui ~= nil and imgui.GetWindowWidth ~= nil then
        local window_width = tonumber(imgui.GetWindowWidth()) or 0.0
        local available_width = math.max(1.0, window_width - 16.0)
        child_layout.gutter_width = available_width * 0.025
        if child_layout.results_width > available_width then
            child_layout.results_width = math.floor(available_width * 0.95)
        end
        child_layout.wrap_categories = window_width < 640.0
    end
    if imgui ~= nil and imgui.GetWindowHeight ~= nil then
        child_layout.height = math.max(
            140.0,
            math.min(child_layout.height, (tonumber(imgui.GetWindowHeight()) or 0.0) - 168.0)
        )
    end
    render_category_row(imgui, state, model, child_layout)
    if imgui.Separator ~= nil then
        imgui.Separator()
    end
    render_results_pane(imgui, state, model, on_command, child_layout)
end

return guide_browser
