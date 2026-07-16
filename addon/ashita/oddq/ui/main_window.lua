local guide_browser = require("ui/guide_browser")
local route_window = require("ui/route_window")
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

local function route_state(state, objective)
    return {
        guidance = state,
        objective = objective,
    }
end

function main_window.render_state(state, objective)
    state = state or {}
    local view = normalized_view(state, objective)
    local lines = {
        "OddQ",
        "View: " .. view,
    }
    if view == "guide" then
        table.insert(lines, "Back to Guides")
        for line in route_window.render_state(route_state(state, objective)):gmatch("[^\n]+") do
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

local function render_guide(imgui, state, objective, on_command)
    if skin.button(imgui, "Back to Guides##oddq_back_to_guides", "secondary") then
        state.main_view = "browse"
        return
    end
    if imgui.Separator ~= nil then
        imgui.Separator()
    end
    route_window.render(imgui, route_state(state, objective), on_command)
end

function main_window.render(imgui, state, objective, on_command)
    if imgui == nil or imgui.Begin == nil or imgui.End == nil then
        return
    end
    if state == nil or state.main_window_open ~= true then
        return
    end

    local layout = skin.layout.main_window or {}
    local width = tonumber(layout.width) or 820.0
    local height = tonumber(layout.height) or 560.0
    local min_width = math.min(tonumber(layout.min_width) or 480.0, width)
    local min_height = math.min(tonumber(layout.min_height) or 320.0, height)
    local max_width = math.max(min_width, tonumber(layout.max_width) or width)
    local max_height = math.max(min_height, tonumber(layout.max_height) or height)
    if imgui.SetNextWindowSize ~= nil then
        imgui.SetNextWindowSize({ width, height }, ImGuiCond_FirstUseEver)
    end
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints(
            { min_width, min_height },
            { max_width, max_height }
        )
    end
    local pushed = skin.push_window(imgui)
    local visible, open = window_state.begin(imgui, "OddQ", true, 0)
    if not open then
        state.main_window_open = false
        dispatch_command(on_command, { "close" })
    end
    if visible then
        local view = normalized_view(state, objective)
        state.main_view = view
        if view == "guide" then
            render_guide(imgui, state, objective, on_command)
        else
            render_browser(imgui, state, objective, on_command)
        end
    end
    imgui.End()
    skin.pop(imgui, pushed)
end

return main_window
