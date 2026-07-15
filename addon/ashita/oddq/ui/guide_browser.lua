local objective_catalog = require("objective_catalog")
local imgui_text = require("ui/imgui_text")
local skin = require("ui/skin")

local guide_browser = {}

local categories = {
    {
        id = "catseye",
        label = "Catseye Quests",
        mode = "quests",
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
        id = "exp",
        label = "EXP Camps",
        mode = "exp",
        empty_hint = "Level-appropriate EXP camp guidance.",
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

local function command_text(args)
    local copied = copy_args(args)
    if #copied == 0 then
        return "/odd"
    end
    return "/odd " .. table.concat(copied, " ")
end

local function category_by_id(id)
    local target = trim(id)
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

local function first_target(entry)
    local step = first_step(entry)
    local target = trim(entry.first_target_name)
    if target == "" then
        target = trim(step.npc_name)
    end
    if target == "" then
        target = trim(step.mob_name)
    end
    if target == "" then
        target = trim(step.object_name)
    end
    if target == "" then
        target = trim(step.target_name)
    end
    return target
end

local function first_grid(entry)
    local step = first_step(entry)
    local grid = trim(entry.first_map_grid)
    if grid == "" then
        grid = trim(step.map_grid)
    end
    return grid
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

local function prerequisite_summary(entry)
    local prerequisites = (entry or {}).prerequisites
    if type(prerequisites) ~= "table" then
        prerequisites = {}
    end
    local parts = {}
    local level = level_label(entry)
    if level ~= "" then
        table.insert(parts, level)
    end
    local job_requirement = trim((entry or {}).job_requirement)
    if job_requirement ~= "" then
        table.insert(parts, "Job: " .. job_requirement)
    end
    local function append_list(label, values)
        if type(values) == "table" and #values > 0 then
            table.insert(parts, label .. ": " .. table.concat(values, ", "))
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

local function guide_meta(entry)
    local parts = {}
    local level = level_label(entry)
    if level ~= "" then
        table.insert(parts, level)
    end
    local target = first_target(entry)
    local grid = first_grid(entry)
    if target ~= "" then
        table.insert(parts, target .. (grid ~= "" and " " .. grid or ""))
    end
    local step_count = tonumber((entry or {}).step_count) or 0
    if step_count <= 0 and type((entry or {}).steps) == "table" then
        step_count = #entry.steps
    end
    if step_count > 0 then
        table.insert(parts, tostring(step_count) .. " steps")
    end
    if (entry or {}).repeatable == true then
        table.insert(parts, "Repeatable")
    end
    return table.concat(parts, " - ")
end

local function result_from_guide(entry)
    return {
        kind = "guide",
        label = trim((entry or {}).name),
        meta = guide_meta(entry),
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
    local rows = objective_catalog.browse(category.mode, query, last_index + 1, category.catalog_group)
    for index = ((page - 1) * max_count) + 1, math.min(last_index, #rows) do
        table.insert(results, result_from_guide(rows[index]))
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

local function append_preview(lines, selected, prefix, include_command)
    prefix = prefix or ""
    if selected == nil then
        table.insert(lines, prefix .. "Preview: none")
        return
    end
    local entry = selected.entry or {}
    local target = first_target(entry)
    local grid = first_grid(entry)
    table.insert(lines, prefix .. "Guide: " .. selected.label)
    table.insert(lines, prefix .. "Type: " .. guide_kind(entry))
    table.insert(lines, prefix .. "Requirements: " .. prerequisite_summary(entry))
    if target ~= "" then
        table.insert(lines, prefix .. "Starts at: " .. target .. (grid ~= "" and " " .. grid or ""))
    end
    local step_count = tonumber(entry.step_count) or (type(entry.steps) == "table" and #entry.steps or 0)
    if step_count > 0 then
        table.insert(lines, prefix .. "Length: " .. tostring(step_count) .. (step_count == 1 and " step" or " steps"))
    end
    if entry.repeatable == true then
        table.insert(lines, prefix .. "Repeatable: Yes")
    end
    if include_command == true then
        table.insert(lines, prefix .. "Open: " .. command_text(selected.args))
    end
end

function guide_browser.render_state(state)
    local model = guide_browser.model(state, 8)
    local counts = objective_catalog.counts()
    local lines = {
        "Guide Browser",
        "Category: " .. model.category.label,
        "Categories: Catseye Quests, All Quests, Missions, Job Unlocks, EXP Camps",
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
    append_preview(lines, model.selected, nil, true)
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

local function title_line(imgui, text)
    if imgui ~= nil and imgui.GetWindowWidth ~= nil then
        local wrap = math.max(1.0, (tonumber(imgui.GetWindowWidth()) or 0.0) - 16.0)
        skin.text_colored_wrapped_at(imgui, skin.colors.blue_highlight, text, wrap, "title")
        return
    end
    skin.text_colored(imgui, skin.colors.blue_highlight, text, "title")
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
        if index > 1 then
            same_line(imgui, tonumber(layout.category_gap) or 6.0)
        end
        local active = category.id == model.category.id
        if skin.button(imgui, category.label .. "##oddq_browser_category_" .. category.id, active and "active" or "secondary") then
            state.guide_browser_category = category.id
            state.guide_browser_query = ""
            state.guide_browser_page = 1
            state.guide_browser_selected_index = 1
        end
    end
end

local function render_results_pane(imgui, state, model, layout)
    local opened, child = begin_child(imgui, "oddq_guide_browser_results", { layout.results_width, layout.height })
    if opened then
        skin.text_colored(imgui, skin.colors.blue_highlight, model.category.label, "section")
        if #model.results == 0 then
            text_line(imgui, model.category.empty_hint or "No results.")
        end
        for index, result in ipairs(model.results) do
            local label = result.label
            local active = index == model.selected_index
            if skin.button(
                imgui,
                label .. "##oddq_browser_result_" .. tostring(index),
                active and "active" or "secondary",
                { math.max(1.0, (tonumber(layout.results_width) or 390.0) - 24.0), 0.0 }
            ) then
                state.guide_browser_selected_index = index
            end
            if result.meta ~= "" then
                muted_line(imgui, result.meta)
            end
        end
        if imgui.Separator ~= nil then
            imgui.Separator()
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
    end
    end_child(imgui, child)
end

local function render_preview_pane(imgui, model, on_command, layout)
    local opened, child = begin_child(imgui, "oddq_guide_browser_preview", { layout.preview_width, layout.height })
    if opened then
        if model.selected == nil then
            skin.text_colored(imgui, skin.colors.blue_highlight, "Choose a guide", "section")
            text_line(imgui, "Select a result to see where it starts and what it requires.")
        else
            local preview_lines = {}
            append_preview(preview_lines, model.selected)
            for index, line in ipairs(preview_lines) do
                if index == 1 then
                    title_line(imgui, line:gsub("^Guide:%s*", ""))
                else
                    text_line(imgui, line)
                end
            end
            if imgui.Separator ~= nil then
                imgui.Separator()
            end
            if skin.button(imgui, "Open Guide##oddq_browser_load", "primary") then
                dispatch(on_command, model.selected.args)
            end
        end
    end
    end_child(imgui, child)
end

function guide_browser.render(imgui, state, on_command)
    if state == nil then
        return
    end
    ensure_state(state)
    local layout = ((skin.layout.main_window or {}).guide_browser or {})
    skin.text_colored(imgui, skin.colors.blue_highlight, "Find a guide", "title")
    text_line(imgui, "Search quests, missions, job unlocks, and EXP camps.")
    local previous_query = state.guide_browser_query
    if imgui.SetNextItemWidth ~= nil then
        pcall(imgui.SetNextItemWidth, tonumber(layout.search_width) or -1.0)
    end
    state.guide_browser_query = input_text(imgui, "##oddq_guide_browser_search", previous_query)
    if state.guide_browser_query ~= previous_query then
        state.guide_browser_page = 1
        state.guide_browser_selected_index = 1
    end
    local model = guide_browser.model(state, layout.limit or 8)

    local child_layout = {
        results_width = tonumber(layout.results_width) or 550.0,
        preview_width = tonumber(layout.preview_width) or 430.0,
        height = tonumber(layout.height) or 420.0,
        category_gap = tonumber(layout.category_gap) or 6.0,
    }
    render_category_row(imgui, state, model, child_layout)
    if imgui.Separator ~= nil then
        imgui.Separator()
    end
    render_results_pane(imgui, state, model, child_layout)
    same_line(imgui, tonumber(layout.column_gap) or 4.0)
    render_preview_pane(imgui, model, on_command, child_layout)
end

return guide_browser
