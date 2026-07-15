local guide_browser = require("ui/guide_browser")
local route_window = require("ui/route_window")
local assist_ui = require("ui/assist_hub")
local imgui_text = require("ui/imgui_text")
local skin = require("ui/skin")
local window_state = require("ui/window_state")

local main_window = {}

local placeholder_ids = {
    ["mission.next"] = true,
    ["quest.next"] = true,
    ["job_unlock.next"] = true,
    ["exp.next"] = true,
    ["none"] = true,
}

local function copy_args(args)
    local copied = {}
    for index, value in ipairs(args or {}) do
        copied[index] = tostring(value or "")
    end
    return copied
end

local function dispatch_command(on_command, args)
    if type(on_command) == "function" then
        on_command(copy_args(args))
    end
end

local function safe_text(value)
    if value == nil or type(value) == "table" then
        return ""
    end
    return tostring(value)
end

local function has_loaded_guide(objective)
    if type(objective) ~= "table" or placeholder_ids[safe_text(objective.objective_id)] == true then
        return false
    end
    local objective_id = safe_text(objective.objective_id)
    return objective_id ~= "" and objective_id ~= "none"
end

local function guide_title(objective)
    if type(objective) ~= "table" then
        return ""
    end
    return safe_text(objective.quest_name or objective.title or objective.name or objective.objective_id)
end

local function normalized_view(state, objective)
    if safe_text((state or {}).main_view) == "guide" and has_loaded_guide(objective) then
        return "guide"
    end
    return "browse"
end

local function route_state(state, route, objective, active_segment_index)
    return {
        guidance = state,
        objective = objective,
        route = route,
        active_segment_index = active_segment_index,
    }
end

function main_window.render_state(state, objective, route, active_segment_index)
    state = state or {}
    local view = normalized_view(state, objective)
    local lines = {
        "OddQ Guides",
        "View: " .. view,
    }
    if view == "guide" then
        table.insert(lines, "Back to Guides")
        for line in route_window.render_state(route_state(state, route, objective, active_segment_index)):gmatch("[^\n]+") do
            if line ~= "OddQ" then
                table.insert(lines, line)
            end
        end
    else
        if has_loaded_guide(objective) then
            table.insert(lines, "Resume: " .. guide_title(objective))
        end
        for line in guide_browser.render_state(state):gmatch("[^\n]+") do
            table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n")
end

local function same_line(imgui, gap)
    if imgui == nil or imgui.SameLine == nil then
        return
    end
    local ok = pcall(imgui.SameLine, 0.0, tonumber(gap) or 8.0)
    if not ok then
        imgui.SameLine()
    end
end

local function render_resume_strip(imgui, state, objective)
    if not has_loaded_guide(objective) then
        return
    end
    skin.text_colored(imgui, skin.colors.blue_highlight, "Current guide", "section")
    imgui_text.wrapped(imgui, guide_title(objective))
    if skin.button(imgui, "Resume Guide##oddq_resume_guide", "secondary") then
        state.main_view = "guide"
    end
    if imgui.Separator ~= nil then
        imgui.Separator()
    end
end

local function render_browser(imgui, state, objective, on_command)
    render_resume_strip(imgui, state, objective)
    guide_browser.render(imgui, state, on_command)
end

local function render_guide(imgui, state, objective, route, active_segment_index, on_command, assist_state, on_assist_action)
    if skin.button(imgui, "Back to Guides##oddq_back_to_guides", "secondary") then
        state.main_view = "browse"
        return
    end
    skin.text_wrapped(imgui, guide_title(objective), "title")
    if imgui.Separator ~= nil then
        imgui.Separator()
    end
    route_window.render(imgui, route_state(state, route, objective, active_segment_index), on_command)
    assist_ui.render_inline(imgui, assist_state, on_assist_action)
end

function main_window.render(
    imgui,
    state,
    objective,
    route,
    active_segment_index,
    guided_menu_text,
    on_command,
    assist_state,
    on_assist_action
)
    if imgui == nil or imgui.Begin == nil or imgui.End == nil then
        return
    end
    if state == nil or state.main_window_open ~= true then
        return
    end

    local layout = skin.layout.main_window or {}
    imgui.SetNextWindowSize({ layout.width or 1040.0, layout.height or 620.0 }, ImGuiCond_FirstUseEver)
    local pushed = skin.push_window(imgui)
    local visible, open = window_state.begin(imgui, "OddQ Guides", true, 0)
    if not open then
        state.main_window_open = false
        dispatch_command(on_command, { "close" })
    end
    if visible then
        local view = normalized_view(state, objective)
        state.main_view = view
        if view == "guide" then
            render_guide(imgui, state, objective, route, active_segment_index, on_command, assist_state, on_assist_action)
        else
            render_browser(imgui, state, objective, on_command)
        end
    end
    imgui.End()
    skin.pop(imgui, pushed)
end

return main_window
