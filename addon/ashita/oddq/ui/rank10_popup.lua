local imgui_text = require("ui/imgui_text")
local rank10_milestone = require("rank10_milestone")
local skin = require("ui/skin")
local window_state = require("ui/window_state")

local rank10_popup = {}

function rank10_popup.render_state()
    local lines = {
        "Congratulations - Rank 10!",
        "CatsEyeXI milestone eligibility: ACE and WeW only, Rank 10 in any nation, and at least one job at level 75.",
        "Collect your reward from the Spatial Anomaly in Castle Zvahl Baileys at (J-8).",
        "Review the claim under CatsEyeXI Account Tools > Milestone Rewards.",
        "Choose one reward:",
    }
    for index, reward in ipairs(rank10_milestone.reward_choices) do
        lines[#lines + 1] = tostring(index) .. ". " .. reward.name .. " - " .. reward.detail
    end
    return lines
end

function rank10_popup.render(imgui, state)
    if imgui == nil or imgui.Begin == nil or imgui.End == nil
        or type(state) ~= "table" or state.pending ~= true then
        return
    end

    local layout = skin.layout.rank10_popup or {}
    if imgui.SetNextWindowSize ~= nil then
        imgui.SetNextWindowSize(
            { tonumber(layout.width) or 560.0, tonumber(layout.height) or 410.0 },
            tonumber(ImGuiCond_Always) or 0
        )
    end
    local pushed = skin.push_window(imgui)
    local visible, open = window_state.begin(
        imgui,
        "OddQ Rank 10 Reward",
        true,
        tonumber(ImGuiWindowFlags_NoResize) or 0
    )
    if not open then
        rank10_milestone.dismiss(state)
    end
    if visible then
        local lines = rank10_popup.render_state()
        skin.text_colored(imgui, skin.colors.blue_highlight, lines[1], "title")
        imgui_text.wrapped(imgui, lines[2])
        skin.section_header(imgui, "Where to collect")
        imgui_text.wrapped(imgui, lines[3])
        imgui_text.wrapped(imgui, lines[4])
        skin.section_header(imgui, lines[5])
        for index = 6, #lines do
            imgui_text.wrapped(imgui, lines[index])
        end
        if skin.button(imgui, "Got it##oddq_rank10_reward_dismiss", "primary", { 120.0, 0.0 }) then
            rank10_milestone.dismiss(state)
        end
    end
    imgui.End()
    skin.pop(imgui, pushed)
end

return rank10_popup
