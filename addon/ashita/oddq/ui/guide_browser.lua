local objective_catalog = require("objective_catalog")
local imgui_text = require("ui/imgui_text")
local skin = require("ui/skin")
local zone_names_loaded, zone_names = pcall(require, "data/zone_names")
if not zone_names_loaded then
    zone_names = {}
end

local guide_browser = {}
local MAX_RESULTS_PER_PAGE = 5

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
        id = "items",
        label = "Items",
        mode = "items",
        empty_hint = "Search source-backed item acquisition by name or numeric item ID.",
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

local category_groups = {
    { id = "missions", label = "Missions", default_category = "missions", categories = { "missions" } },
    {
        id = "quests",
        label = "Catseye Quests",
        default_category = "catseye",
        categories = { "catseye", "quests", "zilart_quests", "promathia_quests", "aht_urhgan_quests", "jobs" },
        subcategories = { "quests", "zilart_quests", "promathia_quests", "aht_urhgan_quests", "jobs" },
    },
    { id = "npcs", label = "NPC Finder", default_category = "npcs", categories = { "npcs" } },
    { id = "items", label = "Items", default_category = "items", categories = { "items" } },
    {
        id = "exp",
        label = "EXP Camps",
        default_category = "exp_solo",
        categories = { "exp_solo", "exp_6man", "exp_mageburn", "exp_meleeburn" },
        subcategories = { "exp_solo", "exp_6man", "exp_mageburn", "exp_meleeburn" },
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

local function category_group_for(category_id)
    for _, group in ipairs(category_groups) do
        for _, id in ipairs(group.categories) do
            if id == category_id then
                return group
            end
        end
    end
    return category_groups[2]
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
    if state.guide_browser_item_id == nil then
        state.guide_browser_item_id = ""
    end
    if state.custom_pointer_input == nil then state.custom_pointer_input = "" end
    if state.custom_pointer_error == nil then state.custom_pointer_error = "" end
    if state.custom_pointer_active == nil then state.custom_pointer_active = false end
    if tonumber(state.custom_pointer_count) == nil then state.custom_pointer_count = 0 end
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

local function result_from_item(item)
    local source_count = math.max(0, math.floor(tonumber((item or {}).source_count) or 0))
    return {
        kind = "item",
        label = trim((item or {}).name),
        meta = "ID " .. tostring(math.floor(tonumber((item or {}).item_id) or 0))
            .. " - " .. tostring(source_count) .. (source_count == 1 and " source" or " sources"),
        item = item,
        args = {},
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
    local max_count = math.min(MAX_RESULTS_PER_PAGE, math.max(1, math.floor(tonumber(limit) or MAX_RESULTS_PER_PAGE)))
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
    local rows = nil
    if category.id == "items" then
        rows = objective_catalog.search_items(query, last_index + 1)
    else
        rows = objective_catalog.browse(
            category.mode,
            query,
            last_index + 1,
            category.catalog_group,
            category.exp_category_keys,
            category.expansion_keys
        )
    end
    for index = ((page - 1) * max_count) + 1, math.min(last_index, #rows) do
        if category.id == "items" then
            table.insert(results, result_from_item(rows[index]))
        else
            table.insert(results, result_from_guide(rows[index], query))
        end
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
        "Categories: Catseye Quests, All Quests, Zilart Quests, Promathia Quests, Aht Urhgan Quests, Missions, Job Unlocks, NPC Finder, Items, Solo (Trust) Camps, 6man Camps, MageBurn Camps, MeleeBurn Camps",
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
            .. " exp"
            .. (model.category.id == "items"
                and (", " .. tostring(objective_catalog.item_count()) .. " source-backed items") or ""),
        "Results:",
    }
    if #model.results == 0 then
        table.insert(lines, "No browser results. " .. tostring(model.category.empty_hint or ""))
    else
        for index, result in ipairs(model.results) do
            local kind = result.kind == "item" and "item" or guide_kind(result.entry)
            local suffix = result.meta ~= "" and " - " .. result.meta or ""
            table.insert(lines, tostring(index) .. ". [" .. kind .. "] " .. result.label .. suffix)
        end
    end
    return table.concat(lines, "\n")
end

local function joined_strings(values, separator)
    local rows = {}
    for _, value in ipairs(type(values) == "table" and values or {}) do
        local text = trim(value)
        if text ~= "" then rows[#rows + 1] = text end
    end
    return table.concat(rows, separator or ", ")
end

local function item_source_location(source)
    local zone = trim((source or {}).zone_name)
    if zone == "" and tonumber((source or {}).zone_id) ~= nil then
        zone = trim(zone_names[tonumber(source.zone_id)])
    end
    return zone
end

local DROP_RATE_TOKENS = {
    ["@ALWAYS"] = { percentage = "100%", label = "Guaranteed" },
    ["@VCOMMON"] = { percentage = "24%", label = "Very Common" },
    ["@COMMON"] = { percentage = "15%", label = "Common" },
    ["@UNCOMMON"] = { percentage = "10%", label = "Uncommon" },
    ["@RARE"] = { percentage = "5%", label = "Rare" },
    ["@VRARE"] = { percentage = "1%", label = "Very Rare" },
    ["@SRARE"] = { percentage = "0.5%", label = "Super Rare" },
    ["@URARE"] = { percentage = "0.1%", label = "Ultra Rare" },
}

local function drop_rate_text(rate)
    local token = string.upper(trim(rate))
    local mapped = DROP_RATE_TOKENS[token]
    if mapped ~= nil then
        return mapped.percentage .. " (" .. mapped.label .. ")"
    end
    return token .. " (unknown server drop token)"
end

local function item_source_line(source, index)
    source = type(source) == "table" and source or {}
    local kind = trim(source.kind)
    local label = trim(source.label)
    local location = item_source_location(source)
    local prefix = tostring(index) .. ". "
    if kind == "drop" then
        local line = prefix .. "Drop: " .. (label ~= "" and label or "Unknown target")
        if location ~= "" then line = line .. " - " .. location end
        if source.rate ~= nil and trim(source.rate) ~= "" then
            line = line .. " - Drop rate: " .. drop_rate_text(source.rate)
        end
        return line
    end
    if kind == "gil_shop" then
        local line = prefix .. "Buy: " .. (label ~= "" and label or "Unknown merchant")
        if (tonumber(source.price) or 0) > 0 then line = line .. " - " .. format_gil(source.price) end
        if location ~= "" then line = line .. " - " .. location end
        return line
    end
    if kind == "guild_shop" then
        local line = prefix .. "Guild shop: " .. (label ~= "" and label or "Unknown guild")
        local price_min = tonumber(source.price_min) or tonumber(source.price) or 0
        local price_max = tonumber(source.price_max) or tonumber(source.price) or 0
        if price_min > 0 and price_max > 0 and price_min ~= price_max then
            line = line .. " - " .. format_gil(price_min) .. " to " .. format_gil(price_max)
                .. " (stock and price vary)"
        elseif price_min > 0 then
            line = line .. " - " .. format_gil(price_min) .. " (stock may vary)"
        end
        if location ~= "" then line = line .. " - " .. location end
        return line
    end
    if kind == "synthesis" or kind == "desynthesis" then
        local parts = {}
        local crystal = trim(source.crystal)
        if crystal ~= "" then parts[#parts + 1] = crystal end
        local ingredients = joined_strings(source.ingredients)
        if ingredients ~= "" then parts[#parts + 1] = ingredients end
        local skills = {}
        for _, skill in ipairs(type(source.skills) == "table" and source.skills or {}) do
            local name = trim(skill.name)
            local level = math.floor(tonumber(skill.level) or 0)
            if name ~= "" then
                skills[#skills + 1] = name .. (level > 0 and (" " .. tostring(level)) or "")
            end
        end
        local line = prefix .. (kind == "desynthesis" and "Desynthesis" or "Synthesis")
        if tonumber(source.recipe_id) ~= nil then line = line .. " (recipe " .. tostring(source.recipe_id) .. ")" end
        if #skills > 0 then line = line .. " - " .. table.concat(skills, ", ") end
        if #parts > 0 then line = line .. " - " .. table.concat(parts, " + ") end
        if (tonumber(source.result_qty) or 0) > 1 then line = line .. " - yields " .. tostring(source.result_qty) end
        return line
    end
    return prefix .. "Source: " .. (label ~= "" and label or (kind ~= "" and kind or "Unknown"))
end

function guide_browser.item_detail_lines(item)
    if type(item) ~= "table" then return {} end
    local name = trim(item.name)
    local lines = {
        name ~= "" and name or "Unknown item",
        "Item ID: " .. tostring(math.floor(tonumber(item.item_id) or 0)),
        "Known source-backed paths: " .. tostring(math.max(0, math.floor(tonumber(item.source_count) or 0))),
    }
    local guidance = objective_catalog.item_find_guidance()
    if guidance ~= "" then
        guidance = guidance:gsub("<item>", function() return name end)
        lines[#lines + 1] = guidance
    end
    lines[#lines + 1] = "Current coverage: normal drops, gil/guild shops, synthesis, and desynthesis. Other acquisition families remain explicitly pending source parsers."
    if math.max(0, math.floor(tonumber(item.source_count) or 0)) == 0 then
        lines[#lines + 1] = "No sourced acquisition path yet. OddQ knows this item identity, but its acquisition family still needs a verified parser."
    end
    for index, source in ipairs(type(item.sources) == "table" and item.sources or {}) do
        lines[#lines + 1] = item_source_line(source, index)
        if objective_catalog.item_source_route(item, index) ~= nil then
            lines[#lines + 1] = "   Exact pointer route available for this source."
        end
    end
    return lines
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

local function render_ownership(imgui, ownership, center_x)
    ownership = type(ownership) == "table" and ownership or {}
    local labels = {}
    for _, mode in ipairs(ownership) do
        labels[#labels + 1] = tostring(mode.label or "")
    end
    local row_label = table.concat(labels, " / ")
    local row_width = #row_label * 8.0
    if imgui ~= nil and imgui.CalcTextSize ~= nil then
        local measured = imgui.CalcTextSize(row_label)
        if type(measured) == "number" then
            row_width = measured
        elseif type(measured) == "table" then
            row_width = tonumber(measured[1] or measured.x) or row_width
        end
    end
    if imgui ~= nil and imgui.GetCursorScreenPos ~= nil and imgui.SetCursorScreenPos ~= nil
        and tonumber(center_x) ~= nil then
        local _, y = imgui.GetCursorScreenPos()
        if type(_) == "table" then y = _[2] end
        if tonumber(y) ~= nil then
            imgui.SetCursorScreenPos({ center_x - (row_width / 2.0), y })
        end
    end
    for index, mode in ipairs(ownership) do
        if index > 1 then
            same_line(imgui)
            skin.text_colored(imgui, skin.colors.white, "/", "body")
            same_line(imgui)
        end
        local color = mode.supported == true and skin.colors.blue_highlight or skin.colors.white
        skin.text_colored(imgui, color, mode.label, "body")
    end
end

local function cursor_screen_x(imgui)
    if imgui == nil or imgui.GetCursorScreenPos == nil then
        return nil
    end
    local x = imgui.GetCursorScreenPos()
    if type(x) == "table" then
        x = x[1]
    end
    return tonumber(x)
end

local function align_cursor_x(imgui, target_x)
    if imgui == nil or imgui.GetCursorScreenPos == nil or imgui.SetCursorScreenPos == nil then
        return
    end
    local x, y = imgui.GetCursorScreenPos()
    if type(x) == "table" then
        y = x[2]
        x = x[1]
    end
    y = tonumber(y)
    target_x = tonumber(target_x)
    if target_x ~= nil and y ~= nil then
        imgui.SetCursorScreenPos({ target_x, y })
    end
end

local function input_text(imgui, label, current, maximum_length)
    if imgui == nil or imgui.InputText == nil then
        return current
    end
    local value = { tostring(current or "") }
    local ok, changed, returned = pcall(function()
        return imgui.InputText(label, value, tonumber(maximum_length) or 128)
    end)
    if not ok then
        ok, changed, returned = pcall(function()
            return imgui.InputText(label, tostring(current or ""), tonumber(maximum_length) or 128)
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

local function render_custom_pointer(imgui, state, on_command)
    skin.text_colored(imgui, skin.colors.blue_highlight, "Custom Pointer", "title")
    text_line(imgui, "Paste (X, Y) coordinates or a grid like (E-5); OddQ uses the nearest verified location.")
    if imgui.SetNextItemWidth ~= nil then
        pcall(imgui.SetNextItemWidth, -120.0)
    end
    state.custom_pointer_input = input_text(
        imgui,
        "##oddq_custom_pointer_input",
        state.custom_pointer_input,
        1024
    )
    same_line(imgui, 6.0)
    if skin.button(imgui, "OK##oddq_custom_pointer_set", "primary") then
        dispatch(on_command, { "pointer", state.custom_pointer_input })
    end
    if state.custom_pointer_active == true then
        if skin.button(imgui, "Clear Pointer##oddq_custom_pointer_clear", "secondary") then
            dispatch(on_command, { "pointer", "clear" })
        else
            same_line(imgui, 6.0)
        end
    end
    if trim(state.custom_pointer_error) ~= "" then
        skin.text_colored(imgui, skin.colors.white, state.custom_pointer_error, "body")
    elseif state.custom_pointer_active == true then
        local count = math.max(1, math.floor(tonumber(state.custom_pointer_count) or 1))
        muted_line(imgui, count == 1 and "Active in this zone for this session."
            or ("Active this session: nearest of " .. tostring(count) .. " locations."))
    end
    if imgui.Separator ~= nil then imgui.Separator() end
end

local function render_category_row(imgui, state, model, layout)
    local active_group = category_group_for(model.category.id)
    local gap = tonumber(layout.category_gap) or 6.0
    local available_width = math.max(1.0, tonumber(layout.results_width) or 764.0)
    local group_width = math.max(80.0, (available_width - (gap * (#category_groups - 1))) / #category_groups)
    for index, group in ipairs(category_groups) do
        if index > 1 then same_line(imgui, gap) end
        if skin.button(
            imgui,
            group.label .. "##oddq_browser_group_" .. group.id,
            group.id == active_group.id and "active" or "category",
            { group_width, 0.0 }
        ) then
            state.guide_browser_category = group.default_category
            state.guide_browser_page = 1
            state.guide_browser_selected_index = 1
            state.guide_browser_item_id = ""
        end
    end
    local subcategories = active_group.subcategories or {}
    for index, category_id in ipairs(subcategories) do
        local category = category_by_id(category_id)
        if index > 1 then same_line(imgui, gap) end
        local active = category.id == model.category.id
        if skin.button(imgui, category.label .. "##oddq_browser_category_" .. category.id, active and "active" or "category") then
            state.guide_browser_category = category.id
            state.guide_browser_page = 1
            state.guide_browser_selected_index = 1
            state.guide_browser_item_id = ""
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
    local result_x = cursor_screen_x(imgui)
    if result_x ~= nil then
        result_x = result_x + math.max(0.0, tonumber(layout.gutter_width) or 0.0)
    end
    if #model.results == 0 then
        align_cursor_x(imgui, result_x)
        text_line(imgui, model.category.empty_hint or "No results.")
    end
    for index, result in ipairs(model.results) do
        align_cursor_x(imgui, result_x)
        local button_width = math.max(1.0, (tonumber(layout.results_width) or 390.0) - 24.0)
        local label = result_button_label(result.label, button_width)
        local active = index == model.selected_index
        if skin.button(
            imgui,
            label .. "##oddq_browser_result_" .. tostring(index),
            active and "active" or "result",
            { button_width, 0.0 }
        ) then
            state.guide_browser_selected_index = index
        end
        if type(result.ownership) == "table" and #result.ownership > 0 then
            render_ownership(imgui, result.ownership, result_x ~= nil and (result_x + (button_width / 2.0)) or nil)
        elseif result.meta ~= "" then
            muted_line(imgui, result.meta)
        end
    end
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
        local item_result = model.selected.kind == "item"
        local label = item_result and "Open Item##oddq_browser_load" or "Open Guide##oddq_browser_load"
        if skin.button(imgui, label, "primary") then
            if item_result then
                state.guide_browser_item_id = trim((model.selected.item or {}).id)
            else
                dispatch(on_command, model.selected.args)
            end
        end
    end
end

local function render_item_detail(imgui, state, item, layout, on_command)
    if skin.button(imgui, "Back to Item Results##oddq_item_back", "secondary") then
        state.guide_browser_item_id = ""
        return
    end
    if trim(state.item_route_source_id) ~= "" then
        same_line(imgui, 6.0)
        if skin.button(imgui, "Clear Item Pointer##oddq_item_clear_route", "secondary") then
            dispatch(on_command, { "items", "clear-route" })
        end
    end
    if imgui.Separator ~= nil then imgui.Separator() end
    local available_height = math.max(100.0, (tonumber(layout.height) or 420.0) - 38.0)
    local opened, child = begin_child(
        imgui,
        "oddq_item_detail",
        { math.max(1.0, tonumber(layout.results_width) or 550.0), available_height }
    )
    if opened then
        for index, line in ipairs(guide_browser.item_detail_lines(item)) do
            if index == 1 then
                skin.text_colored(imgui, skin.colors.blue_highlight, line, "title")
            elseif index <= 3 then
                skin.text_colored(imgui, skin.colors.white, line, "body")
            else
                text_line(imgui, line)
            end
        end
        for index, source in ipairs(type(item.sources) == "table" and item.sources or {}) do
            if objective_catalog.item_source_route(item, index) ~= nil then
                local label = "Point to " .. trim(source.label)
                if trim(source.label) == "" then label = "Point to source " .. tostring(index) end
                if skin.button(
                    imgui,
                    result_button_label(label, tonumber(layout.results_width) or 550.0)
                        .. "##oddq_item_route_" .. tostring(index),
                    state.item_route_source_id == (trim(item.id) .. ":" .. tostring(index))
                        and "active" or "secondary"
                ) then
                    dispatch(on_command, { "items", "route", trim(item.id), tostring(index) })
                end
            end
        end
    end
    end_child(imgui, child)
end

function guide_browser.render(imgui, state, on_command, options)
    if state == nil then
        return
    end
    ensure_state(state)
    options = type(options) == "table" and options or {}
    local layout = ((skin.layout.main_window or {}).guide_browser or {})
    local custom_pointer_height = options.show_custom_pointer == true
        and (tonumber(layout.custom_pointer_height) or 106.0) or 0.0
    if options.show_custom_pointer == true then
        render_custom_pointer(imgui, state, on_command)
    end
    skin.text_colored(imgui, skin.colors.blue_highlight, "Find a guide", "title")
    text_line(imgui, "Search guides, items, EXP camps, NPC names, and merchant stock.")
    local previous_query = state.guide_browser_query
    if imgui.SetNextItemWidth ~= nil then
        pcall(imgui.SetNextItemWidth, tonumber(layout.search_width) or -1.0)
    end
    state.guide_browser_query = input_text(imgui, "##oddq_guide_browser_search", previous_query)
    if state.guide_browser_query ~= previous_query then
        state.guide_browser_page = 1
        state.guide_browser_selected_index = 1
        state.guide_browser_item_id = ""
    end
    local result_limit = math.max(1, math.floor(tonumber(layout.limit) or 8))
    if imgui ~= nil and imgui.GetWindowHeight ~= nil then
        local window_height = tonumber(imgui.GetWindowHeight()) or 0.0
        local compact_limit = math.max(1, math.floor((window_height - 240.0 - custom_pointer_height) / 48.0))
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
            math.min(
                child_layout.height,
                (tonumber(imgui.GetWindowHeight()) or 0.0) - 168.0 - custom_pointer_height
            )
        )
    end
    render_category_row(imgui, state, model, child_layout)
    if imgui.Separator ~= nil then
        imgui.Separator()
    end
    if model.category.id == "items" and trim(state.guide_browser_item_id) ~= "" then
        local item = objective_catalog.find_item_by_id(state.guide_browser_item_id)
        if item ~= nil then
            render_item_detail(imgui, state, item, child_layout, on_command)
            return
        end
        state.guide_browser_item_id = ""
    end
    render_results_pane(imgui, state, model, on_command, child_layout)
end

return guide_browser
