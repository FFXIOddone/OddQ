local objective_catalog = {}

local loaded, objective_rows = pcall(require, "data/objectives")
if not loaded or type(objective_rows) ~= "table" then
    objective_rows = {}
end

local loaded_exp_camps, exp_camp_rows = pcall(require, "data/exp_camps")
if not loaded_exp_camps or type(exp_camp_rows) ~= "table" then
    exp_camp_rows = {}
end

local catalog_rows = {}
local runtime_objective_cache = setmetatable({}, { __mode = "k" })

local mode_for_kind = {
    mission = "missions",
    job_unlock = "jobs",
    quest = "quests",
    exp_camp = "exp",
}

local short_kind = {
    mission = "mission",
    job_unlock = "job",
    quest = "quest",
    exp_camp = "exp",
}

local advanced_job_aliases = {
    { name = "paladin", alias = "pld" },
    { name = "dark knight", alias = "drk" },
    { name = "beastmaster", alias = "bst" },
    { name = "bard", alias = "brd" },
    { name = "ranger", alias = "rng" },
    { name = "samurai", alias = "sam" },
    { name = "ninja", alias = "nin" },
    { name = "dragoon", alias = "drg" },
    { name = "summoner", alias = "smn" },
    { name = "blue mage", alias = "blu" },
    { name = "corsair", alias = "cor" },
    { name = "puppetmaster", alias = "pup" },
    { name = "dancer", alias = "dnc" },
    { name = "scholar", alias = "sch" },
    { name = "geomancer", alias = "geo" },
    { name = "rune fencer", alias = "run" },
}

local mission_line_aliases = {
    { alias = "rov", canonical = "rhapsodies", name_terms = { "rhapsodies" }, chaptered = true },
    { alias = "cop", canonical = "promathia", name_terms = { "promathia" }, chaptered = true },
    { alias = "pm", canonical = "promathia", name_terms = { "promathia" }, chaptered = true },
    { alias = "toau", canonical = "aht urhgan", name_terms = { "aht", "urhgan" }, chaptered = false },
    { alias = "wotg", canonical = "wings goddess", name_terms = { "wings", "goddess" }, chaptered = false },
    { alias = "zm", canonical = "zilart", name_terms = { "zilart" }, chaptered = false },
}

local nation_mission_aliases = {
    { canonical = "san doria", name_terms = { "san", "oria" } },
    { canonical = "bastok", name_terms = { "bastok" } },
    { canonical = "windurst", name_terms = { "windurst" } },
}

local function safe_text(value)
    if value == nil or type(value) == "function" or type(value) == "thread" or type(value) == "userdata" or type(value) == "table" then
        return ""
    end
    return tostring(value)
end

local function normalize_mode(mode)
    local text = safe_text(mode):lower()
    if text == "" or text == "all" or text == "catalog" then
        return nil
    end
    if text == "mission" then
        return "missions"
    end
    if text == "job" or text == "job_unlock" or text == "advanced_job" or text == "advanced_jobs" then
        return "jobs"
    end
    if text == "quest" then
        return "quests"
    end
    if text == "exp_camp" or text == "camp" or text == "camps" then
        return "exp"
    end
    return text
end

local function matches_mode(entry, mode)
    local normalized = normalize_mode(mode)
    if normalized == nil then
        return true
    end
    return mode_for_kind[safe_text(entry.kind)] == normalized
end

local function level_label(entry)
    if (entry or {}).level_requirement_unknown == true then
        return "Level: Unknown"
    end
    local level_min = tonumber(entry.level_min) or 0
    local level_max = tonumber(entry.level_max) or 0
    if safe_text((entry or {}).kind) == "mission" and level_min <= 1 and level_max <= 0 then
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

local function first_stop_label(entry)
    local parts = {}
    local target = safe_text(entry.first_target_name)
    local map_grid = safe_text(entry.first_map_grid)
    if target ~= "" then
        table.insert(parts, target)
    end
    if map_grid ~= "" then
        table.insert(parts, map_grid)
    end
    return table.concat(parts, " ")
end

local function copy_list(values)
    local rows = {}
    if type(values) ~= "table" then
        return rows
    end
    for _, value in ipairs(values) do
        local text = safe_text(value)
        if text ~= "" then
            table.insert(rows, text)
        end
    end
    return rows
end

local function copy_position(position)
    if type(position) ~= "table" then
        return nil
    end
    local x = tonumber(position.x)
    local y = tonumber(position.y)
    local z = tonumber(position.z)
    if x == nil or y == nil or z == nil then
        return nil
    end
    return { x = x, y = y, z = z }
end

local function copy_prerequisites(entry)
    entry = entry or {}
    local source = entry.prerequisites
    if type(source) ~= "table" then
        source = {}
    end
    return {
        fame = copy_list(source.fame),
        quests_completed = copy_list(source.quests_completed),
        missions_completed = copy_list(source.missions_completed),
        level_min = tonumber(source.level_min or entry.level_min) or 0,
        level_max = tonumber(source.level_max or entry.level_max) or 0,
        transport_unlocks = copy_list(source.transport_unlocks),
    }
end

local exp_category_priority = {
    parties = 900,
    solo_trusts = 700,
    duo_trusts = 690,
    manaburns = 680,
    pet_parties = 670,
}

local function exp_display_priority(camp)
    local base = exp_category_priority[safe_text(camp.category_key)] or 650
    local level_min = tonumber(camp.level_min) or 0
    return base - level_min
end

local function exp_instruction(camp)
    local name = safe_text(camp.name)
    if name == "" then
        name = "EXP camp"
    end
    local parts = {
        "Travel to " .. name .. ".",
    }
    local range = safe_text(camp.level_range)
    if range ~= "" then
        table.insert(parts, "Recommended range: Lv." .. range .. ".")
    end
    local note = safe_text(camp.note)
    if note ~= "" then
        table.insert(parts, note)
    end
    return table.concat(parts, " ")
end

local function exp_notes(camp)
    local note = safe_text(camp.note)
    if note == "" then
        return {}
    end
    return { note }
end

local function to_exp_entry(camp)
    camp = camp or {}
    local objective_id = safe_text(camp.objective_id)
    if objective_id == "" then
        objective_id = "catseyexi.exp." .. safe_text(camp.id)
    end
    local zone_id = tonumber(camp.zone_id) or 0
    local position = copy_position({
        x = camp.x,
        y = camp.y,
        z = camp.z,
    }) or {}
    local name = safe_text(camp.name)
    if name == "" then
        name = objective_id
    end

    return {
        id = "objective:" .. objective_id,
        objective_id = objective_id,
        quest_id = objective_id,
        kind = "exp_camp",
        name = name,
        category_key = safe_text(camp.category_key),
        category = safe_text(camp.category),
        display_priority = exp_display_priority(camp),
        level_min = tonumber(camp.level_min) or 0,
        level_max = tonumber(camp.level_max) or 0,
        level_range = safe_text(camp.level_range),
        prerequisites = {
            fame = {},
            level_min = tonumber(camp.level_min) or 0,
            level_max = tonumber(camp.level_max) or 0,
            missions_completed = {},
            quests_completed = {},
            transport_unlocks = {},
        },
        step_count = 1,
        first_step_id = "camp",
        first_step_kind = "exp_camp",
        first_zone_id = zone_id,
        first_target_name = safe_text(camp.category),
        first_map_grid = "",
        verification_status = "draft",
        steps = {
            {
                step_id = "camp",
                step_kind = "exp_camp",
                zone_id = zone_id,
                npc_name = safe_text(camp.category),
                map_grid = "",
                position = position,
                instruction = exp_instruction(camp),
                required_items = {},
                required_key_items = {},
                notes = exp_notes(camp),
            },
        },
    }
end

local function build_catalog_rows()
    local rows = {}
    local seen = {}
    for _, entry in ipairs(objective_rows) do
        table.insert(rows, entry)
        local objective_id = safe_text(entry.objective_id)
        if objective_id ~= "" then
            seen[objective_id] = true
        end
    end
    for _, camp in ipairs(exp_camp_rows) do
        local objective_id = safe_text(camp.objective_id)
        if objective_id ~= "" and seen[objective_id] ~= true then
            table.insert(rows, to_exp_entry(camp))
            seen[objective_id] = true
        end
    end
    return rows
end

catalog_rows = build_catalog_rows()

local function append_prerequisite_list(parts, label, values)
    if type(values) == "table" and #values > 0 then
        table.insert(parts, label .. ": " .. table.concat(values, ", "))
    end
end

local function prerequisite_detail_label(entry)
    local prerequisites = copy_prerequisites(entry)
    local parts = {}
    append_prerequisite_list(parts, "Fame", prerequisites.fame)
    append_prerequisite_list(parts, "Quests", prerequisites.quests_completed)
    append_prerequisite_list(parts, "Missions", prerequisites.missions_completed)
    append_prerequisite_list(parts, "Transport", prerequisites.transport_unlocks)
    return table.concat(parts, "; ")
end

local function matches_catalog_group(entry, catalog_group)
    local expected = safe_text(catalog_group)
    if expected == "" then
        return true
    end
    return safe_text((entry or {}).catalog_group) == expected
end

local function step_target_name(step)
    step = type(step) == "table" and step or {}
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

local function steps_search_blob(entry)
    local parts = {}
    if type(entry.steps) ~= "table" then
        return ""
    end
    for _, step in ipairs(entry.steps) do
        if type(step) == "table" then
            table.insert(parts, safe_text(step.instruction))
            table.insert(parts, step_target_name(step))
            table.insert(parts, safe_text(step.map_grid))
            for _, note in ipairs(copy_list(step.notes)) do
                table.insert(parts, note)
            end
            for _, item in ipairs(copy_list(step.required_items)) do
                table.insert(parts, item)
            end
            for _, key_item in ipairs(copy_list(step.required_key_items)) do
                table.insert(parts, key_item)
            end
        end
    end
    return table.concat(parts, " ")
end

local function copy_steps(entry)
    local rows = {}
    if type(entry.steps) ~= "table" then
        return rows
    end
    for _, step in ipairs(entry.steps) do
        if type(step) == "table" then
            table.insert(rows, {
                step_id = safe_text(step.step_id),
                step_kind = safe_text(step.step_kind),
                zone_id = tonumber(step.zone_id) or 0,
                npc_name = safe_text(step.npc_name),
                mob_name = safe_text(step.mob_name),
                object_name = safe_text(step.object_name),
                target_name = safe_text(step.target_name),
                map_grid = safe_text(step.map_grid),
                position = copy_position(step.position),
                instruction = safe_text(step.instruction),
                required_items = copy_list(step.required_items),
                required_key_items = copy_list(step.required_key_items),
                notes = copy_list(step.notes),
            })
        end
    end
    return rows
end

local function search_blob(entry)
    return table.concat({
        safe_text(entry.name),
        safe_text(entry.objective_id),
        safe_text(entry.quest_id),
        safe_text(entry.kind),
        safe_text(entry.category),
        safe_text(entry.category_key),
        safe_text(entry.catalog_group),
        safe_text(entry.job_requirement),
        safe_text(entry.level_range),
        safe_text(entry.first_target_name),
        safe_text(entry.first_map_grid),
        safe_text(entry.verification_status),
        prerequisite_detail_label(entry),
        steps_search_blob(entry),
    }, " "):lower()
end

local function normalize_search_text(value)
    local text = safe_text(value):lower()
    text = text:gsub("'s", "")
    text = text:gsub("[^%w]+", " ")
    text = text:gsub("%f[%w]sandy%f[%W]", "san doria")
    text = text:gsub("%f[%w]basty%f[%W]", "bastok")
    text = text:gsub("%f[%w]windy%f[%W]", "windurst")
    text = text:gsub("%f[%w]m(%d+)%s+(%d+)%f[%W]", "mission %1 %2")
    text = text:gsub("%f[%w]rank%s+(%d+)%s+mission%s+(%d+)%f[%W]", "mission %1 %2")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function normalized_contains(value, query)
    local text = normalize_search_text(value)
    local normalized_query = normalize_search_text(query)
    if text == "" or normalized_query == "" then
        return false
    end
    if text:find(normalized_query, 1, true) ~= nil then
        return true
    end

    local compact_text = text:gsub("%s+", "")
    local compact_query = normalized_query:gsub("%s+", "")
    if compact_query == "" then
        return false
    end
    return compact_text:find(compact_query, 1, true) ~= nil
end

local function normalized_contains_terms(value, query)
    local text = normalize_search_text(value)
    local normalized_query = normalize_search_text(query)
    if text == "" or normalized_query == "" then
        return false
    end

    for word in normalized_query:gmatch("%S+") do
        if text:find(word, 1, true) == nil then
            return false
        end
    end
    return true
end

local function normalized_has_word(value, word)
    local text = " " .. normalize_search_text(value) .. " "
    local target = " " .. normalize_search_text(word) .. " "
    if target == "  " then
        return false
    end
    return text:find(target, 1, true) ~= nil
end

local generic_service_queries = {
    ["home point"] = true,
    homepoint = true,
    hp = true,
    ["survival guide"] = true,
    ["survival guides"] = true,
    sg = true,
    telepoint = true,
    ["teleport mea"] = true,
    ["teleport holla"] = true,
    ["teleport dem"] = true,
    ["teleport altep"] = true,
    ["teleport yhoat"] = true,
    ["teleport vahzl"] = true,
}

local function is_generic_service_query(query)
    return generic_service_queries[normalize_search_text(query)] == true
end

local function clean_normalized(value)
    local text = safe_text(value)
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function remove_normalized_word(value, word)
    local text = " " .. clean_normalized(value) .. " "
    text = text:gsub(" " .. safe_text(word) .. " ", " ")
    return clean_normalized(text)
end

local function query_number_tokens(query)
    local numbers = {}
    for number in normalize_search_text(query):gmatch("%d+") do
        table.insert(numbers, number)
    end
    return numbers
end

local function mission_number_matches(entry_name, query, chaptered)
    local numbers = query_number_tokens(query)
    if #numbers == 0 then
        return true
    end

    local name = normalize_search_text(entry_name)
    if chaptered == true then
        if #numbers >= 2 then
            return name:find("%f[%w]mission%s+" .. numbers[1] .. "%s+" .. numbers[2] .. "%f[%W]") ~= nil
        end
        return name:find("%f[%w]mission%s+" .. numbers[1] .. "%s+%d+%f[%W]") ~= nil
    end

    return name:find("%f[%w]mission%s+" .. numbers[1] .. "%f[%W]") ~= nil
end

local function mission_line_alias_score(entry, query)
    if safe_text(entry.kind) ~= "mission" then
        return nil
    end

    local normalized_query = normalize_search_text(query)
    if normalized_query == "" then
        return nil
    end

    for _, alias in ipairs(mission_line_aliases) do
        if normalized_has_word(normalized_query, alias.alias) then
            local name = safe_text(entry.name)
            for _, term in ipairs(alias.name_terms) do
                if not normalized_has_word(name, term) then
                    return nil
                end
            end
            if not mission_number_matches(name, normalized_query, alias.chaptered) then
                return nil
            end

            local remainder = remove_normalized_word(normalized_query, alias.alias)
            for _, word in ipairs({ "mission", "missions", "chapter" }) do
                remainder = remove_normalized_word(remainder, word)
            end
            local canonical_query = alias.canonical
            if remainder ~= "" then
                canonical_query = canonical_query .. " " .. remainder
            end
            if normalized_contains_terms(name, canonical_query) then
                if #query_number_tokens(normalized_query) > 0 then
                    return 0.25
                end
                return 0.75
            end
        end
    end
    return nil
end

local function nation_mission_number_matches(entry_name, query)
    local numbers = query_number_tokens(query)
    if #numbers == 0 then
        return true
    end

    local name = normalize_search_text(entry_name)
    if #numbers >= 2 then
        return name:find("%f[%w]mission%s+" .. numbers[1] .. "%s+" .. numbers[2] .. "%f[%W]") ~= nil
    end
    return name:find("%f[%w]mission%s+" .. numbers[1] .. "%s+%d+%f[%W]") ~= nil
end

local function nation_mission_alias_score(entry, query)
    if safe_text(entry.kind) ~= "mission" then
        return nil
    end

    local normalized_query = normalize_search_text(query)
    if normalized_query == "" then
        return nil
    end

    local name = safe_text(entry.name)
    for _, alias in ipairs(nation_mission_aliases) do
        if normalized_contains_terms(normalized_query, alias.canonical) then
            for _, term in ipairs(alias.name_terms) do
                if not normalized_has_word(name, term) then
                    return nil
                end
            end
            if not nation_mission_number_matches(name, normalized_query) then
                return nil
            end
            if #query_number_tokens(normalized_query) >= 2 then
                return 0.1
            end
            if #query_number_tokens(normalized_query) == 1 then
                return 0.5
            end
            return 0.9
        end
    end
    return nil
end

local function job_alias_score(entry, query)
    if safe_text(entry.kind) ~= "job_unlock" then
        return nil
    end

    local name = safe_text(entry.name):lower()
    for _, alias in ipairs(advanced_job_aliases) do
        if query == alias.alias and name:find(alias.name, 1, true) ~= nil then
            return 0
        end
    end
    return nil
end

local function job_labeled_quest_alias_score(entry, query)
    if safe_text(entry.kind) ~= "quest" then
        return nil
    end

    local name = safe_text(entry.name):lower()
    for _, alias in ipairs(advanced_job_aliases) do
        local has_query_job = normalized_has_word(query, alias.alias)
            or normalized_contains_terms(query, alias.name)
        local has_entry_job = name:find("%(" .. alias.alias .. "%)") ~= nil
            or name:find(alias.name, 1, true) ~= nil
        if has_query_job and has_entry_job then
            return 0
        end
    end
    return nil
end

local function entry_limit_break_number(entry)
    local name = normalize_search_text((entry or {}).name)
    local number = name:match("^limit break%s+(%d+)")
    return tonumber(number)
end

local function query_limit_break_number(query)
    local text = normalize_search_text(query)
    local compact = text:gsub("%s+", "")
    local number = compact:match("^lb([1-5])$")
        or compact:match("^limitbreak([1-5])$")
        or text:match("^limit break%s+([1-5])$")
        or text:match("^genkai%s+([1-5])$")
    return tonumber(number)
end

local function limit_break_alias_score(entry, query)
    if safe_text(entry.kind) ~= "quest" then
        return nil
    end

    local name = normalize_search_text(entry.name)
    local text = normalize_search_text(query)
    if text == "maat" or text == "maat fight" then
        if name == "limit break 5 shattering stars" then
            return 0
        end
        return nil
    end

    local number = query_limit_break_number(query)
    if number == nil or entry_limit_break_number(entry) ~= number then
        return nil
    end
    if number == 5 and name ~= "limit break 5 shattering stars" then
        return 0.65
    end
    return 0
end

local function support_job_alias_score(entry, query)
    if safe_text(entry.kind) ~= "quest" then
        return nil
    end

    local text = normalize_search_text(query)
    if text ~= "sj" then
        return nil
    end

    local name = normalize_search_text(entry.name)
    if name == "unlock support job subjob elder memories" then
        return 0
    end
    if name:find("^unlock support job subjob", 1, true) ~= nil then
        return 0.5
    end
    return nil
end

local function travel_unlock_alias_score(entry, query)
    if safe_text(entry.kind) ~= "quest" then
        return nil
    end

    local text = normalize_search_text(query)
    if text ~= "mount" and text ~= "mount quest" and text ~= "chocobo license" then
        return nil
    end

    if normalize_search_text(entry.name) == "chocobo wounds" then
        return 0
    end
    return nil
end

local function content_unlock_title(entry)
    local objective_id = safe_text((entry or {}).objective_id)
    local name = safe_text((entry or {}).name)
    if objective_id:find("catseyexi.content_unlock.", 1, true) ~= 1 then
        return ""
    end
    return name:gsub("^Unlock%s+Catseye%s+Content:%s*", "")
end

local function content_unlock_alias_score(entry, query)
    if safe_text(entry.kind) ~= "quest" then
        return nil
    end

    local title = content_unlock_title(entry)
    if title == "" then
        return nil
    end

    local text = normalize_search_text(query)
    if text == "" then
        return nil
    end
    local has_unlock_intent = normalized_has_word(text, "unlock")
        or normalized_has_word(text, "guide")
        or normalized_has_word(text, "access")
        or text:find("^how%s+to%s+", 1, false) ~= nil
    if has_unlock_intent ~= true then
        return nil
    end

    local reduced = text
    for _, word in ipairs({ "how", "to", "unlock", "guide", "catseye", "content", "access" }) do
        reduced = remove_normalized_word(reduced, word)
    end
    if reduced == "" then
        return nil
    end

    if normalized_contains_terms(title, reduced) or normalized_contains_terms(entry.name, reduced) then
        return 0.35
    end
    return nil
end

local roman_numbers = {
    i = 1,
    ii = 2,
    iii = 3,
    iv = 4,
    v = 5,
    vi = 6,
    vii = 7,
    viii = 8,
    ix = 9,
    x = 10,
}

local function gobbiebag_part_number(entry)
    local part = normalize_search_text((entry or {}).name):match("^the gobbiebag part%s+([ivx]+)$")
    return roman_numbers[part]
end

local function query_gobbiebag_part_number(query)
    local text = normalize_search_text(query)
    if text == "" then
        return nil
    end
    if
        not normalized_has_word(text, "gobbiebag")
        and not normalized_has_word(text, "bag")
        and not normalized_has_word(text, "inventory")
    then
        return nil
    end

    local number = tonumber(text:match("%f[%d](%d+)%f[%D]"))
    if number ~= nil and number >= 1 and number <= 10 then
        return number
    end
    for word in text:gmatch("%S+") do
        number = roman_numbers[word]
        if number ~= nil then
            return number
        end
    end
    return nil
end

local function gobbiebag_alias_score(entry, query)
    if safe_text(entry.kind) ~= "quest" then
        return nil
    end
    local target_part = query_gobbiebag_part_number(query)
    if target_part == nil then
        return nil
    end
    if gobbiebag_part_number(entry) == target_part then
        return 0
    end
    return nil
end

local function item_route_score(entry, query)
    if safe_text(entry.kind) ~= "quest" or not normalized_has_word(entry.name, "route") then
        return nil
    end

    local normalized_query = normalize_search_text(query)
    if normalized_query == "" or type(entry.steps) ~= "table" then
        return nil
    end

    for _, step in ipairs(entry.steps) do
        if type(step) == "table" then
            for _, item in ipairs(copy_list(step.required_items)) do
                if normalize_search_text(item) == normalized_query then
                    return 2.5
                end
            end
        end
    end
    return nil
end

local function required_key_item_score(entry, query)
    local normalized_query = normalize_search_text(query)
    if normalized_query == "" or type(entry.steps) ~= "table" then
        return nil
    end

    for _, step in ipairs(entry.steps) do
        if type(step) == "table" then
            for _, key_item in ipairs(copy_list(step.required_key_items)) do
                local normalized_key_item = normalize_search_text(key_item)
                if normalized_key_item == normalized_query then
                    return 2.25
                end
                if #normalized_query >= 4 and normalized_contains(key_item, query) then
                    return 2.75
                end
            end
        end
    end
    return nil
end

local function exp_level_score(entry, query)
    if safe_text(entry.kind) ~= "exp_camp" then
        return nil
    end
    local normalized_query = normalize_search_text(query)
    local level_text = normalized_query:match("^level%s+(%d+)$")
        or normalized_query:match("^lv%s+(%d+)$")
        or normalized_query:match("^(%d+)$")
    if level_text == nil then
        return nil
    end

    local level = tonumber(level_text)
    local level_min = tonumber(entry.level_min) or 0
    local level_max = tonumber(entry.level_max) or 0
    if level == nil or level_min <= 0 or level < level_min then
        return nil
    end
    if level_max > 0 and level > level_max then
        return nil
    end
    if safe_text(entry.category_key) == "parties" then
        return 0.5
    end
    return 0.75
end

local function search_score(entry, query)
    local name = safe_text(entry.name):lower()
    local objective_id = safe_text(entry.objective_id):lower()
    local target = safe_text(entry.first_target_name):lower()
    local alias_score = job_alias_score(entry, query)
    if alias_score ~= nil then
        return alias_score
    end
    alias_score = job_labeled_quest_alias_score(entry, query)
    if alias_score ~= nil then
        return alias_score
    end
    alias_score = limit_break_alias_score(entry, query)
    if alias_score ~= nil then
        return alias_score
    end
    alias_score = support_job_alias_score(entry, query)
    if alias_score ~= nil then
        return alias_score
    end
    alias_score = travel_unlock_alias_score(entry, query)
    if alias_score ~= nil then
        return alias_score
    end
    alias_score = content_unlock_alias_score(entry, query)
    if alias_score ~= nil then
        return alias_score
    end
    alias_score = nation_mission_alias_score(entry, query)
    if alias_score ~= nil then
        return alias_score
    end
    alias_score = gobbiebag_alias_score(entry, query)
    if alias_score ~= nil then
        return alias_score
    end
    alias_score = mission_line_alias_score(entry, query)
    if alias_score ~= nil then
        return alias_score
    end
    local route_score = item_route_score(entry, query)
    if route_score ~= nil then
        return route_score
    end
    local key_item_score = required_key_item_score(entry, query)
    if key_item_score ~= nil then
        return key_item_score
    end
    local level_score = exp_level_score(entry, query)
    if level_score ~= nil then
        return level_score
    end
    if name:find(query, 1, true) ~= nil then
        return 1
    end
    if objective_id:find(query, 1, true) ~= nil then
        return 2
    end
    if target:find(query, 1, true) ~= nil then
        return 3
    end
    if search_blob(entry):find(query, 1, true) ~= nil then
        return 4
    end
    if normalized_contains(entry.name, query) then
        return 5
    end
    if normalized_contains(search_blob(entry), query) then
        return 6
    end
    if normalized_contains_terms(search_blob(entry), query) then
        return 7
    end
    return nil
end

local function sorted_entries(entries)
    table.sort(entries, function(left, right)
        local left_priority = tonumber(left.display_priority) or 0
        local right_priority = tonumber(right.display_priority) or 0
        if left_priority ~= right_priority then
            return left_priority > right_priority
        end
        return safe_text(left.name):lower() < safe_text(right.name):lower()
    end)
    return entries
end

local function sorted_insert(results, item)
    table.insert(results, item)
    table.sort(results, function(left, right)
        if left.score ~= right.score then
            return left.score < right.score
        end
        local left_name = safe_text(left.entry.name):lower()
        local right_name = safe_text(right.entry.name):lower()
        if left_name == right_name then
            local left_is_start = safe_text(left.entry.objective_id):lower():find("%.start$") ~= nil
            local right_is_start = safe_text(right.entry.objective_id):lower():find("%.start$") ~= nil
            if left_is_start ~= right_is_start then
                return left_is_start
            end
        end
        local left_priority = tonumber((left.entry or {}).display_priority) or 0
        local right_priority = tonumber((right.entry or {}).display_priority) or 0
        if left_priority ~= right_priority then
            return left_priority > right_priority
        end
        return left_name < right_name
    end)
end

function objective_catalog.normalize_mode(mode)
    return normalize_mode(mode)
end

function objective_catalog.mode_for_entry(entry)
    return mode_for_kind[safe_text((entry or {}).kind)]
end

function objective_catalog.counts()
    local result = {
        all = 0,
        missions = 0,
        jobs = 0,
        quests = 0,
        exp = 0,
    }
    for _, entry in ipairs(catalog_rows) do
        local mode = mode_for_kind[safe_text(entry.kind)]
        result.all = result.all + 1
        if mode ~= nil then
            result[mode] = result[mode] + 1
        end
    end
    return result
end

function objective_catalog.list(mode, limit, catalog_group)
    local normalized = normalize_mode(mode)
    local max_count = tonumber(limit) or 12
    local results = {}
    for _, entry in ipairs(catalog_rows) do
        if matches_mode(entry, normalized) and matches_catalog_group(entry, catalog_group) then
            table.insert(results, entry)
        end
    end
    sorted_entries(results)
    local limited = {}
    for index, entry in ipairs(results) do
        if index > max_count then
            break
        end
        table.insert(limited, entry)
    end
    return limited
end

function objective_catalog.search(query, mode, limit, catalog_group)
    local text = safe_text(query):lower()
    local max_count = tonumber(limit) or 12
    local scored = {}
    if text == "" then
        return {}
    end
    if is_generic_service_query(text) then
        return {}
    end
    for _, entry in ipairs(catalog_rows) do
        if matches_mode(entry, mode) and matches_catalog_group(entry, catalog_group) then
            local score = search_score(entry, text)
            if score ~= nil then
                sorted_insert(scored, {
                    score = score,
                    entry = entry,
                })
            end
        end
    end
    local results = {}
    for index, item in ipairs(scored) do
        if index > max_count then
            break
        end
        table.insert(results, item.entry)
    end
    return results
end

function objective_catalog.browse(mode, query, limit, catalog_group)
    if normalize_search_text(query) == "" then
        return objective_catalog.list(mode, limit, catalog_group)
    end
    return objective_catalog.search(query, mode, limit, catalog_group)
end

local function normalize_suggestion_filters(filters)
    if type(filters) ~= "table" then
        return {
            missions = true,
            jobs = true,
            quests = true,
            exp = true,
        }
    end

    local source = filters
    if type(filters.modes) == "table" then
        source = filters.modes
    end

    local has_explicit_filter = false
    for _, mode in ipairs({ "missions", "jobs", "quests", "exp" }) do
        if source[mode] ~= nil then
            has_explicit_filter = true
            break
        end
    end

    if not has_explicit_filter then
        return {
            missions = true,
            jobs = true,
            quests = true,
            exp = true,
        }
    end

    return {
        missions = source.missions == true,
        jobs = source.jobs == true,
        quests = source.quests == true,
        exp = source.exp == true,
    }
end

local function suggestion_filter_allows(entry, filters)
    local mode = mode_for_kind[safe_text((entry or {}).kind)]
    if mode == nil then
        return false
    end
    return filters[mode] == true
end

local function mission_completion(entry)
    local name = safe_text((entry or {}).name)
    local rank, mission = name:match("^San d'Oria Mission%s+(%d+)%-(%d+)")
    if rank ~= nil then
        return "sandy " .. rank .. "-" .. mission
    end
    rank, mission = name:match("^Bastok Mission%s+(%d+)%-(%d+)")
    if rank ~= nil then
        return "bastok " .. rank .. "-" .. mission
    end
    rank, mission = name:match("^Windurst Mission%s+(%d+)%-(%d+)")
    if rank ~= nil then
        return "windy " .. rank .. "-" .. mission
    end
    rank, mission = name:match("^Promathia Mission%s+(%d+)%-(%d+)")
    if rank ~= nil then
        return "cop " .. rank .. "-" .. mission
    end
    rank, mission = name:match("^Rhapsodies of Vana'diel Mission%s+(%d+)%-(%d+)")
    if rank ~= nil then
        return "rov " .. rank .. "-" .. mission
    end
    local number = name:match("^Aht Urhgan Mission%s+(%d+)")
    if number ~= nil then
        return "toau " .. number
    end
    number = name:match("^Wings of the Goddess Mission%s+(%d+)")
    if number ~= nil then
        return "wotg " .. number
    end
    number = name:match("^Zilart Mission%s+(%d+)")
    if number ~= nil then
        return "zm " .. number
    end
    return nil
end

local function simple_name_completion(entry)
    local name = normalize_search_text((entry or {}).name)
    if name == "" then
        return safe_text((entry or {}).objective_id)
    end
    return name
end

local function entry_completion(entry)
    local kind = safe_text((entry or {}).kind)
    if kind == "mission" then
        return mission_completion(entry) or simple_name_completion(entry)
    end
    if kind == "job_unlock" then
        local job = safe_text((entry or {}).name):match("^Unlock%s+([^:]+)")
        if job ~= nil then
            return job:lower()
        end
    end
    if kind == "exp_camp" then
        local level_min = tonumber((entry or {}).level_min) or 0
        if level_min > 0 then
            return "exp " .. tostring(level_min)
        end
    end
    return simple_name_completion(entry)
end

local function suggestion_for_entry(entry)
    local mode = mode_for_kind[safe_text((entry or {}).kind)]
    if mode == nil then
        return nil
    end
    local objective_id = safe_text(entry.objective_id)
    if objective_id == "" then
        return nil
    end
    local completion = entry_completion(entry)
    local args = {
        "plan",
        mode,
        objective_id,
    }
    return {
        label = safe_text(entry.name),
        mode = mode,
        objective_id = objective_id,
        completion = completion,
        command_text = "/odd " .. completion,
        args = args,
        entry = entry,
    }
end

function objective_catalog.suggest(query, filters, limit)
    local max_count = tonumber(limit) or 5
    local allowed = normalize_suggestion_filters(filters)
    local text = safe_text(query)
    local entries
    if normalize_search_text(text) == "" then
        entries = objective_catalog.list(nil, max_count * 6)
    else
        entries = objective_catalog.search(text, nil, max_count * 8)
    end

    local suggestions = {}
    local seen = {}
    for _, entry in ipairs(entries) do
        if suggestion_filter_allows(entry, allowed) then
            local objective_id = safe_text(entry.objective_id)
            if objective_id ~= "" and seen[objective_id] ~= true then
                local suggestion = suggestion_for_entry(entry)
                if suggestion ~= nil then
                    table.insert(suggestions, suggestion)
                    seen[objective_id] = true
                end
            end
        end
        if #suggestions >= max_count then
            break
        end
    end
    return suggestions
end

local function mission_sequence_key(entry)
    if safe_text((entry or {}).kind) ~= "mission" then
        return nil
    end
    local name = safe_text(entry.name)
    local rank, mission = name:match("^San d'Oria Mission%s+(%d+)%-(%d+)")
    if rank ~= nil then
        return { family = "san_doria", major = tonumber(rank) or 0, minor = tonumber(mission) or 0 }
    end
    rank, mission = name:match("^Bastok Mission%s+(%d+)%-(%d+)")
    if rank ~= nil then
        return { family = "bastok", major = tonumber(rank) or 0, minor = tonumber(mission) or 0 }
    end
    rank, mission = name:match("^Windurst Mission%s+(%d+)%-(%d+)")
    if rank ~= nil then
        return { family = "windurst", major = tonumber(rank) or 0, minor = tonumber(mission) or 0 }
    end
    rank, mission = name:match("^Promathia Mission%s+(%d+)%-(%d+)")
    if rank ~= nil then
        return { family = "promathia", major = tonumber(rank) or 0, minor = tonumber(mission) or 0 }
    end
    rank, mission = name:match("^Rhapsodies of Vana'diel Mission%s+(%d+)%-(%d+)")
    if rank ~= nil then
        return { family = "rhapsodies", major = tonumber(rank) or 0, minor = tonumber(mission) or 0 }
    end
    local number = name:match("^Aht Urhgan Mission%s+(%d+)")
    if number ~= nil then
        return { family = "aht_urhgan", major = tonumber(number) or 0, minor = 0 }
    end
    number = name:match("^Wings of the Goddess Mission%s+(%d+)")
    if number ~= nil then
        return { family = "wings", major = tonumber(number) or 0, minor = 0 }
    end
    number = name:match("^Zilart Mission%s+(%d+)")
    if number ~= nil then
        return { family = "zilart", major = tonumber(number) or 0, minor = 0 }
    end
    return nil
end

local function resolve_catalog_entry(value)
    if type(value) ~= "table" then
        return nil
    end
    local objective_id = safe_text(value.objective_id)
    if objective_id ~= "" then
        local entry = objective_catalog.find_by_objective_id(objective_id)
        if entry ~= nil then
            return entry
        end
    end
    objective_id = safe_text(value.quest_id)
    if objective_id ~= "" then
        local entry = objective_catalog.find_by_objective_id(objective_id)
        if entry ~= nil then
            return entry
        end
    end
    local name = safe_text(value.name)
    if name == "" then
        name = safe_text(value.quest_name)
    end
    if name ~= "" then
        for _, entry in ipairs(catalog_rows) do
            if safe_text(entry.name) == name then
                return entry
            end
        end
    end
    if value.kind ~= nil then
        return value
    end
    return nil
end

function objective_catalog.mission_neighbor(objective_or_entry, delta)
    local current = resolve_catalog_entry(objective_or_entry)
    local current_key = mission_sequence_key(current)
    if current == nil or current_key == nil then
        return nil, "not_mission"
    end

    local sequence = {}
    for _, entry in ipairs(catalog_rows) do
        local key = mission_sequence_key(entry)
        if key ~= nil and key.family == current_key.family then
            table.insert(sequence, {
                entry = entry,
                key = key,
            })
        end
    end

    table.sort(sequence, function(left, right)
        if left.key.major ~= right.key.major then
            return left.key.major < right.key.major
        end
        if left.key.minor ~= right.key.minor then
            return left.key.minor < right.key.minor
        end
        return safe_text(left.entry.name):lower() < safe_text(right.entry.name):lower()
    end)

    local current_id = safe_text(current.objective_id)
    local current_index = nil
    for index, item in ipairs(sequence) do
        if safe_text(item.entry.objective_id) == current_id then
            current_index = index
            break
        end
    end
    if current_index == nil then
        return nil, "not_mission"
    end

    local next_index = current_index + (tonumber(delta) or 0)
    if next_index < 1 then
        return nil, "start"
    end
    if next_index > #sequence then
        return nil, "end"
    end
    return sequence[next_index].entry, nil
end

function objective_catalog.find_by_objective_id(objective_id)
    local target = safe_text(objective_id)
    if target == "" then
        return nil
    end
    local unprefixed = target:gsub("^objective:", "")
    for _, entry in ipairs(catalog_rows) do
        if safe_text(entry.objective_id) == target
            or safe_text(entry.objective_id) == unprefixed
            or safe_text(entry.id) == target then
            return entry
        end
    end
    return nil
end

local transport_flag_list_keys = {
    "home_points",
    "survival_guides",
    "outposts",
    "teleport_crystals",
    "exp_guides",
    "city_teleporters",
    "spells",
    "items",
}

local function contract_position(position)
    return copy_position(position) or { x = 0, y = 0, z = 0 }
end

local function contract_steps(steps)
    local rows = {}
    for _, step in ipairs(steps or {}) do
        table.insert(rows, {
            step_id = safe_text(step.step_id),
            step_kind = safe_text(step.step_kind),
            zone_id = tonumber(step.zone_id) or 0,
            npc_name = step_target_name(step),
            map_grid = safe_text(step.map_grid),
            instruction = safe_text(step.instruction),
            required_items = copy_list(step.required_items),
            required_key_items = copy_list(step.required_key_items),
        })
    end
    return rows
end

local function contract_transport_flags(flags)
    flags = type(flags) == "table" and flags or {}
    local result = {}
    for _, key in ipairs(transport_flag_list_keys) do
        result[key] = copy_list(flags[key])
    end

    local cooldowns = type(flags.cooldowns) == "table" and flags.cooldowns or {}
    result.cooldowns = {
        warp_ring_seconds_remaining = math.floor(tonumber(cooldowns.warp_ring_seconds_remaining) or 0),
        instant_warp_scroll_count = math.floor(tonumber(cooldowns.instant_warp_scroll_count) or 0),
    }
    return result
end

function objective_catalog.to_runtime_objective(objective, entry)
    if type(objective) ~= "table" then
        return nil
    end

    if entry == nil and runtime_objective_cache[objective] ~= nil then
        return runtime_objective_cache[objective]
    end
    if entry == nil then
        entry = objective_catalog.find_by_objective_id(objective.objective_id)
    end

    local runtime = {}
    for key, value in pairs(objective) do
        runtime[key] = value
    end
    if type(entry) == "table" and safe_text(entry.objective_id) == safe_text(objective.objective_id) then
        runtime.prerequisites = copy_prerequisites(entry)
        runtime.steps = copy_steps(entry)
    end
    runtime_objective_cache[objective] = runtime
    return runtime
end

function objective_catalog.to_objective_plan(entry, state)
    if type(entry) ~= "table" then
        return nil
    end
    state = state or {}
    local objective_id = safe_text(entry.objective_id)
    if objective_id == "" then
        return nil
    end

    local guide_steps = copy_steps(entry)
    local first_step = guide_steps[1] or {}
    local first_target_name = step_target_name(first_step)
    if first_target_name == "" then
        first_target_name = safe_text(entry.first_target_name)
    end
    local kind = safe_text(entry.kind)
    local mode = short_kind[kind]
    if mode == "" or mode == nil then
        mode = kind
    end

    return {
        schema = "objective_plan.v1",
        selection_note = "targeted OddQ local guide",
        actions = {
            {
                mode = mode,
                reason = "local_catalog_match",
                objective = {
                    objective_id = objective_id,
                    quest_id = safe_text(entry.quest_id),
                    quest_name = safe_text(entry.name),
                    objective_kind = kind,
                    step_id = safe_text(first_step.step_id or entry.first_step_id),
                    step_kind = safe_text(first_step.step_kind or entry.first_step_kind),
                    zone_id = tonumber(first_step.zone_id or entry.first_zone_id) or 0,
                    position = contract_position(first_step.position),
                    npc_name = first_target_name,
                    map_grid = safe_text(first_step.map_grid or entry.first_map_grid),
                    instruction = safe_text(first_step.instruction),
                    level_min = tonumber(entry.level_min) or 0,
                    level_max = tonumber(entry.level_max) or 0,
                    exp_category_key = safe_text(entry.category_key),
                    exp_category_label = safe_text(entry.category),
                    job_requirement = safe_text(entry.job_requirement),
                    level_requirement_unknown = entry.level_requirement_unknown == true,
                    repeatable = entry.repeatable == true,
                    steps = contract_steps(guide_steps),
                    evidence = {
                        source = safe_text(entry.source_url) ~= "" and safe_text(entry.source_url) or "odddb_local_catalog",
                        run_id = "odddb-lua-export",
                        validated = safe_text(entry.verification_status) == "script_verified",
                        status = safe_text(entry.verification_status),
                    },
                    route_request_hint = {
                        server_profile = safe_text(state.server_profile),
                        game_mode = safe_text(state.game_mode),
                        current_zone_id = tonumber(state.current_zone_id) or 0,
                        current_position = contract_position(state.current_position),
                        target_objective_id = objective_id,
                        key_items = copy_list(state.key_items),
                        known_unlocks_hash = safe_text(state.known_unlocks_hash),
                        known_transport_flags = contract_transport_flags(state.known_transport_flags),
                    },
                },
            },
        },
        blockers = {},
    }
end

function objective_catalog.result_line(entry, index)
    local kind = short_kind[safe_text(entry.kind)] or safe_text(entry.kind)
    if kind == "" then
        kind = "entry"
    end
    local parts = {
        tostring(index) .. ". [" .. kind .. "] " .. safe_text(entry.name),
    }
    local level = level_label(entry)
    if level ~= "" then
        table.insert(parts, level)
    end
    local prerequisites = prerequisite_detail_label(entry)
    if prerequisites ~= "" then
        table.insert(parts, prerequisites)
    end
    local first_stop = first_stop_label(entry)
    if first_stop ~= "" then
        table.insert(parts, first_stop)
    end
    local step_count = tonumber(entry.step_count) or 0
    if step_count > 0 then
        table.insert(parts, tostring(step_count) .. " steps")
    end
    return table.concat(parts, " - ")
end

function objective_catalog.render_results(entries, options)
    entries = entries or {}
    options = options or {}
    local title = safe_text(options.title)
    if title == "" then
        title = "odd list"
    end

    local lines = {
        title .. ":",
    }
    if #entries == 0 then
        table.insert(lines, "No matching OddQ entries.")
        table.insert(lines, "Try /odd list jobs or /odd find ranger.")
        return table.concat(lines, "\n")
    end

    for index, entry in ipairs(entries) do
        table.insert(lines, objective_catalog.result_line(entry, index))
    end

    table.insert(lines, "Use /odd open <number> or /odd <number> to load a result; /odd jobs ranger or /odd jobs drg also load job guides.")
    return table.concat(lines, "\n")
end

return objective_catalog
