local skin = require("ui/skin")
local window_state = require("ui/window_state")

local assist_ui = {}

local inline_card_ids = {
    travel = true,
    target = true,
    readiness = true,
    filterscan = true,
    minimap = true,
}

local function inline_body(card)
    local body = tostring((card or {}).body or "")
    if card.id == "travel" then
        return body:gsub("^Travel:%s*", "")
    end
    if card.id == "target" then
        body = body:gsub("^Target helper:%s*", "")
        return body:gsub("^Target confirmed:%s*", "")
    end
    return body
end

function assist_ui.render_state(assist_state)
    if assist_state == nil or assist_state.visible == false then
        return "OddQ Assist Hub\nHidden"
    end
    local lines = { "OddQ Assist Hub" }
    for _, card in ipairs(assist_state.cards or {}) do
        table.insert(lines, tostring(card.title or card.id or "Card") .. ": " .. tostring(card.body or ""))
    end
    return table.concat(lines, "\n")
end

local function window_size_condition(state)
    if state ~= nil and state.ui_tuner_open == true and ImGuiCond_Always ~= nil then
        return ImGuiCond_Always
    end
    return ImGuiCond_FirstUseEver
end

function assist_ui.render(imgui, state, assist_state, on_action)
    if imgui == nil or state == nil or state.assist_hub_open ~= true then
        return
    end

    local layout = (skin.layout and skin.layout.assist_hub) or { width = 360.0, height = 320.0 }
    imgui.SetNextWindowSize({ layout.width or 360.0, layout.height or 320.0 }, window_size_condition(state))
    local pushed = skin.push_window(imgui)
    local visible, open = window_state.begin(imgui, "OddQ Assist Hub", true, 0)
    state.assist_hub_open = open
    if visible then
        for _, card in ipairs((assist_state or {}).cards or {}) do
            imgui.Text(tostring(card.title or card.id or "Card"))
            if imgui.TextWrapped ~= nil then
                imgui.TextWrapped(tostring(card.body or ""))
            else
                imgui.Text(tostring(card.body or ""))
            end
            if card.action ~= nil and type(on_action) == "function" and imgui.Button ~= nil then
                if skin.button(imgui, "Run##oddq_assist_action_" .. tostring(card.id or card.title), "secondary") then
                    on_action(card.action)
                end
            end
            if imgui.Separator ~= nil then
                imgui.Separator()
            end
        end
    end
    imgui.End()
    skin.pop(imgui, pushed)
end

function assist_ui.render_inline(imgui, assist_state, on_action)
    if imgui == nil or assist_state == nil or assist_state.visible == false then
        return
    end
    local rendered_header = false
    for _, card in ipairs(assist_state.cards or {}) do
        local card_id = tostring(card.id or "")
        local permission_action = card_id ~= "filterscan" and card_id ~= "minimap" or card.action ~= nil
        local body = inline_body(card)
        if inline_card_ids[card_id] == true and permission_action and body:match("%S") ~= nil then
            if not rendered_header then
                skin.section_header(imgui, "For this step")
                rendered_header = true
            end
            skin.label_value(imgui, tostring(card.title or "Guide"), body)
            if card.action ~= nil and type(on_action) == "function" then
                local label = card.id == "filterscan" and "Run FilterScan" or "Apply MiniMap View"
                if skin.button(imgui, label .. "##oddq_inline_action_" .. tostring(card.id), "secondary") then
                    on_action(card.action)
                end
            end
        end
    end
end

return assist_ui
