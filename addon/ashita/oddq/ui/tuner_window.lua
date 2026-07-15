local imgui_text = require("ui/imgui_text")
local skin = require("ui/skin")
local window_state = require("ui/window_state")

local tuner_window = {}

local layout_control_groups = {
    {
        key = "guide_notes",
        title = "Guide Notes Window",
        target = skin.layout.guide_notes,
        controls = {
            { key = "width", label = "Guide Width", min = 240.0, max = 900.0, step = 5.0 },
            { key = "height", label = "Guide Height", min = 160.0, max = 720.0, step = 5.0 },
            { key = "padding_x", label = "Guide Padding X", min = 0.0, max = 80.0, step = 1.0 },
            { key = "padding_y", label = "Guide Padding Y", min = 0.0, max = 80.0, step = 1.0 },
            { key = "content_top_gap", label = "Guide Top Gap", min = 0.0, max = 80.0, step = 0.5 },
            { key = "content_bottom_gap", label = "Guide Bottom Gap", min = 0.0, max = 80.0, step = 0.5 },
        },
    },
    {
        key = "objective_cluster",
        title = "Objective Box",
        target = skin.layout.objective_cluster,
        controls = {
            { key = "width", label = "Objective Width", min = 80.0, max = 900.0, step = 2.0 },
            { key = "min_height", label = "Minimum Height", min = 40.0, max = 500.0, step = 2.0 },
            { key = "loaded_min_height", label = "Loaded Minimum Height", min = 40.0, max = 620.0, step = 2.0 },
            { key = "padding_x", label = "Padding X", min = 0.0, max = 48.0, step = 1.0 },
            { key = "padding_y", label = "Padding Y", min = 0.0, max = 48.0, step = 1.0 },
            { key = "gap", label = "Gap", min = 0.0, max = 32.0, step = 1.0 },
            { key = "radius", label = "Radius", min = 0.0, max = 24.0, step = 1.0 },
            { key = "progress_height", label = "Progress Height", min = 1.0, max = 18.0, step = 1.0 },
            { key = "button_height", label = "Button Height", min = 12.0, max = 48.0, step = 1.0 },
            { key = "window_margin_x", label = "Window Margin X", min = 0.0, max = 240.0, step = 1.0 },
            { key = "min_width", label = "Minimum Width", min = 60.0, max = 520.0, step = 2.0 },
            { key = "title_indent_x", label = "Title Indent", min = 0.0, max = 48.0, step = 0.5 },
            { key = "subtitle_indent_x", label = "Subtitle Indent", min = 0.0, max = 48.0, step = 0.5 },
            { key = "text_right_inset", label = "Text Right Inset", min = 0.0, max = 80.0, step = 1.0 },
            { key = "title_subtitle_gap", label = "Title Subtitle Gap", min = 0.0, max = 24.0, step = 0.5 },
            { key = "instruction_gap", label = "Instruction Gap", min = 0.0, max = 36.0, step = 1.0 },
            { key = "instruction_indent_x", label = "Instruction Indent", min = 0.0, max = 48.0, step = 1.0 },
            { key = "instruction_line_y_offset", label = "Instruction Line Y", min = -12.0, max = 24.0, step = 0.5 },
            { key = "instruction_line_height", label = "Instruction Line Height", min = 0.0, max = 80.0, step = 1.0 },
            { key = "instruction_line_thickness", label = "Instruction Line Thickness", min = 0.0, max = 8.0, step = 0.25, precision = 2 },
            { key = "bottom_gap", label = "Bottom Gap", min = 0.0, max = 40.0, step = 1.0 },
        },
    },
    {
        key = "detailed_information",
        title = "Detailed Information",
        target = skin.layout.detailed_information,
        controls = {
            { key = "width", label = "Detailed Width", min = 320.0, max = 1200.0, step = 5.0 },
            { key = "height", label = "Detailed Height", min = 180.0, max = 900.0, step = 5.0 },
            { key = "padding_x", label = "Detail Padding X", min = 0.0, max = 80.0, step = 1.0 },
            { key = "padding_y", label = "Detail Padding Y", min = 0.0, max = 80.0, step = 1.0 },
            { key = "gap", label = "Detailed Gap", min = 0.0, max = 36.0, step = 1.0 },
            { key = "wrap_inset", label = "Detailed Wrap Inset", min = 0.0, max = 80.0, step = 1.0 },
            { key = "section_gap", label = "Detail Section Gap", min = 0.0, max = 36.0, step = 0.5 },
            { key = "section_top_gap", label = "Section Top Gap", min = 0.0, max = 36.0, step = 0.5 },
            { key = "section_bottom_gap", label = "Section Bottom Gap", min = 0.0, max = 36.0, step = 0.5 },
            { key = "tab_button_gap", label = "Tab Button Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "tab_row_gap", label = "Tab Row Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "tab_max_buttons_per_row", label = "Tabs Per Row", min = 1.0, max = 8.0, step = 1.0 },
            { key = "tab_button_height", label = "Tab Button Height", min = 0.0, max = 48.0, step = 1.0 },
            { key = "tab_button_min_width", label = "Tab Button Min Width", min = 0.0, max = 240.0, step = 1.0 },
            { key = "nav_button_gap", label = "Nav Button Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "nav_button_height", label = "Nav Button Height", min = 0.0, max = 48.0, step = 1.0 },
            { key = "nav_top_gap", label = "Nav Top Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "nav_bottom_gap", label = "Nav Bottom Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "summary_gap", label = "Summary Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "step_body_gap", label = "Step Body Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "note_gap", label = "Note Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "title_indent_x", label = "Detail Title Indent", min = 0.0, max = 80.0, step = 1.0 },
            { key = "body_indent_x", label = "Detail Body Indent", min = 0.0, max = 200.0, step = 1.0 },
            { key = "note_indent_x", label = "Detail Note Indent", min = 0.0, max = 200.0, step = 1.0 },
            { key = "content_top_gap", label = "Content Top Gap", min = 0.0, max = 80.0, step = 0.5 },
            { key = "content_bottom_gap", label = "Content Bottom Gap", min = 0.0, max = 80.0, step = 0.5 },
        },
    },
    {
        key = "main_window",
        title = "Main Window",
        target = skin.layout.main_window,
        controls = {
            { key = "width", label = "Main Width", min = 320.0, max = 1200.0, step = 5.0 },
            { key = "height", label = "Main Height", min = 240.0, max = 900.0, step = 5.0 },
            { key = "section_gap", label = "Main Section Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "mode_button_gap", label = "Mode Button Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "nav_button_gap", label = "Navigation Button Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "control_gap", label = "Control Gap", min = 0.0, max = 48.0, step = 0.5 },
        },
    },
    {
        key = "direction_cue",
        title = "Direction Cue",
        target = skin.layout.direction_cue,
        controls = {
            { key = "width", label = "Direction Width", min = 160.0, max = 720.0, step = 5.0 },
            { key = "height", label = "Direction Height", min = 100.0, max = 520.0, step = 5.0 },
            { key = "alpha", label = "Direction Alpha", min = 0.0, max = 1.0, step = 0.02, precision = 2 },
            { key = "arrow_size", label = "Arrow Size", min = 24.0, max = 160.0, step = 1.0 },
            { key = "arrow_gap", label = "Arrow Gap", min = 0.0, max = 80.0, step = 1.0 },
            { key = "label_gap", label = "Arrow Label Gap", min = 0.0, max = 80.0, step = 0.5 },
            { key = "body_gap", label = "Direction Body Gap", min = 0.0, max = 48.0, step = 0.5 },
        },
    },
    {
        key = "map_pin",
        title = "Map Pin",
        target = skin.layout.map_pin,
        controls = {
            { key = "width", label = "Map Pin Width", min = 160.0, max = 720.0, step = 5.0 },
            { key = "height", label = "Map Pin Height", min = 80.0, max = 420.0, step = 5.0 },
            { key = "alpha", label = "Map Pin Alpha", min = 0.0, max = 1.0, step = 0.02, precision = 2 },
            { key = "body_gap", label = "Map Pin Body Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "direction_gap", label = "Map Pin Direction Gap", min = 0.0, max = 48.0, step = 0.5 },
        },
    },
    {
        key = "tuner_window",
        title = "Tuner Window",
        target = skin.layout.tuner_window,
        controls = {
            { key = "width", label = "Tuner Width", min = 360.0, max = 1400.0, step = 5.0 },
            { key = "height", label = "Tuner Height", min = 320.0, max = 1100.0, step = 5.0 },
            { key = "group_gap", label = "Tuner Group Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "control_gap", label = "Tuner Control Gap", min = 0.0, max = 48.0, step = 0.5 },
            { key = "button_gap", label = "Tuner Button Gap", min = 0.0, max = 48.0, step = 0.5 },
        },
    },
    {
        key = "window",
        title = "Window Skin",
        target = skin.layout.window,
        controls = {
            { key = "alpha", label = "Window Alpha", min = 0.20, max = 1.00, step = 0.02, precision = 2 },
            { key = "rounding", label = "Window Rounding", min = 0.0, max = 24.0, step = 1.0 },
            { key = "frame_rounding", label = "Frame Rounding", min = 0.0, max = 18.0, step = 1.0 },
            { key = "scrollbar_rounding", label = "Scrollbar Rounding", min = 0.0, max = 18.0, step = 1.0 },
            { key = "border_size", label = "Border Size", min = 0.0, max = 4.0, step = 0.25, precision = 2 },
            { key = "item_spacing_x", label = "Item Spacing X", min = 0.0, max = 40.0, step = 0.5 },
            { key = "item_spacing_y", label = "Item Spacing Y", min = 0.0, max = 40.0, step = 0.5 },
            { key = "item_inner_spacing_x", label = "Inner Spacing X", min = 0.0, max = 40.0, step = 0.5 },
            { key = "item_inner_spacing_y", label = "Inner Spacing Y", min = 0.0, max = 40.0, step = 0.5 },
            { key = "frame_padding_x", label = "Frame Padding X", min = 0.0, max = 40.0, step = 0.5 },
            { key = "frame_padding_y", label = "Frame Padding Y", min = 0.0, max = 40.0, step = 0.5 },
            { key = "indent_spacing", label = "Indent Spacing", min = 0.0, max = 80.0, step = 1.0 },
            { key = "scrollbar_size", label = "Scrollbar Size", min = 0.0, max = 40.0, step = 1.0 },
        },
    },
    {
        key = "text",
        title = "Text",
        target = skin.layout.text,
        controls = {
            { key = "wrap_inset", label = "Generic Wrap Inset", min = 0.0, max = 120.0, step = 1.0 },
            { key = "title_scale", label = "Title Text Scale", min = 0.50, max = 2.50, step = 0.05, precision = 2 },
            { key = "subtitle_scale", label = "Subtitle Text Scale", min = 0.50, max = 2.50, step = 0.05, precision = 2 },
            { key = "body_scale", label = "Body Text Scale", min = 0.50, max = 2.50, step = 0.05, precision = 2 },
            { key = "instruction_scale", label = "Instruction Text Scale", min = 0.50, max = 2.50, step = 0.05, precision = 2 },
            { key = "section_scale", label = "Section Text Scale", min = 0.50, max = 2.50, step = 0.05, precision = 2 },
            { key = "label_scale", label = "Label Text Scale", min = 0.50, max = 2.50, step = 0.05, precision = 2 },
            { key = "value_scale", label = "Value Text Scale", min = 0.50, max = 2.50, step = 0.05, precision = 2 },
            { key = "body_line_gap", label = "Body Line Gap", min = 0.0, max = 24.0, step = 0.5 },
            { key = "section_gap", label = "Section Gap", min = 0.0, max = 24.0, step = 0.5 },
        },
    },
}

local color_controls = {
    { color_key = "bg", channel = 4, label = "Background Alpha", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "panel", channel = 4, label = "Panel Alpha", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "panel_soft", channel = 4, label = "Soft Panel Alpha", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "blue_border", channel = 4, label = "Border Alpha", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "blue_button", channel = 4, label = "Button Alpha", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "line", channel = 4, label = "Divider Alpha", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "scrollbar_grab", channel = 4, label = "Scrollbar Alpha", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "text", channel = 1, label = "Text Red", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "text", channel = 2, label = "Text Green", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "text", channel = 3, label = "Text Blue", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "text", channel = 4, label = "Text Alpha", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "muted", channel = 1, label = "Muted Red", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "muted", channel = 2, label = "Muted Green", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "muted", channel = 3, label = "Muted Blue", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "muted", channel = 4, label = "Muted Alpha", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "blue", channel = 1, label = "Accent Red", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "blue", channel = 2, label = "Accent Green", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "blue", channel = 3, label = "Accent Blue", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "blue_highlight", channel = 1, label = "Highlight Red", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "blue_highlight", channel = 2, label = "Highlight Green", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "blue_highlight", channel = 3, label = "Highlight Blue", min = 0.0, max = 1.0, step = 0.02 },
    { color_key = "blue_highlight", channel = 4, label = "Highlight Alpha", min = 0.0, max = 1.0, step = 0.02 },
}

local default_layout = {}
for _, group in ipairs(layout_control_groups) do
    default_layout[group.key] = {}
    for _, control in ipairs(group.controls) do
        default_layout[group.key][control.key] = group.target[control.key]
    end
end

local default_colors = {}
for _, control in ipairs(color_controls) do
    local color = skin.colors[control.color_key]
    default_colors[control.color_key] = default_colors[control.color_key] or {}
    default_colors[control.color_key][control.channel] = color[control.channel]
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function format_lua_number(value, precision)
    value = tonumber(value) or 0.0
    precision = precision or 2
    local text = string.format("%." .. tostring(precision) .. "f", value)
    text = text:gsub("0+$", ""):gsub("%.$", ".0")
    return text
end

local function same_line(imgui, spacing)
    if imgui == nil or imgui.SameLine == nil then
        return
    end
    if spacing == nil then
        imgui.SameLine()
        return
    end
    local ok = pcall(imgui.SameLine, 0.0, spacing)
    if not ok then
        imgui.SameLine()
    end
end

local function vertical_gap(imgui, amount)
    if imgui ~= nil and imgui.Dummy ~= nil and amount ~= nil and amount > 0 then
        imgui.Dummy({ 1.0, amount })
    end
end

local function input_format(control)
    if control.precision ~= nil then
        return "%." .. tostring(control.precision) .. "f"
    end
    if (tonumber(control.step) or 1.0) < 1.0 then
        return "%.2f"
    end
    return "%.1f"
end

local function input_float(imgui, label, current, control)
    if imgui == nil or imgui.InputFloat == nil then
        return nil
    end

    local step = control.step or 1.0
    local value = { tonumber(current) or 0.0 }
    local ok, changed, returned = pcall(function()
        return imgui.InputFloat(label, value, step, step * 5.0, input_format(control))
    end)
    if not ok then
        ok, changed, returned = pcall(function()
            return imgui.InputFloat(label, value)
        end)
    end
    if not ok then
        return nil
    end

    if type(returned) == "number" then
        return returned
    end
    if type(changed) == "number" then
        return changed
    end
    if changed == true or returned == true or value[1] ~= current then
        return tonumber(value[1])
    end
    return nil
end

local function set_table_value(target, control, value)
    target[control.key] = clamp(value, control.min, control.max)
end

local function table_number_control(imgui, group, control)
    local current = tonumber(group.target[control.key]) or 0.0
    local input_label = control.label .. "##oddq_ui_tuner_" .. group.key .. "_" .. control.key
    local changed_value = input_float(imgui, input_label, current, control)
    if changed_value ~= nil then
        set_table_value(group.target, control, changed_value)
        current = tonumber(group.target[control.key]) or current
    elseif imgui == nil or imgui.InputFloat == nil then
        imgui_text.wrapped(imgui, control.label .. ": " .. format_lua_number(current, control.precision))
    end

    if skin.button(imgui, "-##oddq_ui_tuner_dec_" .. group.key .. "_" .. control.key, "secondary") then
        set_table_value(group.target, control, current - control.step)
        current = tonumber(group.target[control.key]) or current
    end
    same_line(imgui)
    if skin.button(imgui, "+##oddq_ui_tuner_inc_" .. group.key .. "_" .. control.key, "secondary") then
        set_table_value(group.target, control, current + control.step)
    end
end

local function color_control_id(control)
    return control.color_key .. "_" .. tostring(control.channel)
end

local function set_color_value(control, value)
    local color = skin.colors[control.color_key]
    color[control.channel] = clamp(value, control.min, control.max)
end

local function color_number_control(imgui, control)
    local color = skin.colors[control.color_key]
    local current = tonumber(color[control.channel]) or 0.0
    local input_label = control.label .. "##oddq_ui_tuner_color_" .. color_control_id(control)
    local changed_value = input_float(imgui, input_label, current, control)
    if changed_value ~= nil then
        set_color_value(control, changed_value)
        current = tonumber(color[control.channel]) or current
    elseif imgui == nil or imgui.InputFloat == nil then
        imgui_text.wrapped(imgui, control.label .. ": " .. format_lua_number(current, 2))
    end

    if skin.button(imgui, "-##oddq_ui_tuner_dec_color_" .. color_control_id(control), "secondary") then
        set_color_value(control, current - control.step)
        current = tonumber(color[control.channel]) or current
    end
    same_line(imgui)
    if skin.button(imgui, "+##oddq_ui_tuner_inc_color_" .. color_control_id(control), "secondary") then
        set_color_value(control, current + control.step)
    end
end

local function render_layout_group(imgui, group, index)
    if index > 1 and imgui.Separator ~= nil then
        imgui.Separator()
    end
    vertical_gap(imgui, (skin.layout.tuner_window or {}).group_gap or 0.0)
    imgui_text.colored(imgui, skin.colors.blue_highlight, group.title)
    for _, control in ipairs(group.controls) do
        table_number_control(imgui, group, control)
        vertical_gap(imgui, (skin.layout.tuner_window or {}).control_gap or 0.0)
    end
end

local function render_color_group(imgui)
    if imgui.Separator ~= nil then
        imgui.Separator()
    end
    imgui_text.colored(imgui, skin.colors.blue_highlight, "Color Channels")
    for _, control in ipairs(color_controls) do
        color_number_control(imgui, control)
    end
end

local function append_layout_snippet(lines)
    table.insert(lines, "layout = {")
    for _, group in ipairs(layout_control_groups) do
        table.insert(lines, "    " .. group.key .. " = {")
        for _, control in ipairs(group.controls) do
            table.insert(
                lines,
                "        " .. control.key .. " = " .. format_lua_number(group.target[control.key], control.precision) .. ","
            )
        end
        table.insert(lines, "    },")
    end
    table.insert(lines, "},")
end

local function append_color_snippet(lines)
    local emitted = {}
    table.insert(lines, "")
    table.insert(lines, "colors = {")
    for _, control in ipairs(color_controls) do
        if emitted[control.color_key] ~= true then
            local color = skin.colors[control.color_key]
            table.insert(
                lines,
                "    " .. control.color_key .. " = { "
                    .. format_lua_number(color[1], 3) .. ", "
                    .. format_lua_number(color[2], 3) .. ", "
                    .. format_lua_number(color[3], 3) .. ", "
                    .. format_lua_number(color[4], 3) .. " },"
            )
            emitted[control.color_key] = true
        end
    end
    table.insert(lines, "},")
end

function tuner_window.reset()
    for _, group in ipairs(layout_control_groups) do
        for key, value in pairs(default_layout[group.key]) do
            group.target[key] = value
        end
    end
    for color_key, channels in pairs(default_colors) do
        local color = skin.colors[color_key]
        for channel, value in pairs(channels) do
            color[channel] = value
        end
    end
end

function tuner_window.layout_snippet()
    local lines = {}
    append_layout_snippet(lines)
    append_color_snippet(lines)
    return table.concat(lines, "\n")
end

function tuner_window.render(imgui, state)
    if imgui == nil or imgui.Begin == nil or imgui.End == nil then
        return
    end
    if state == nil or state.ui_tuner_open ~= true then
        return
    end

    if imgui.SetNextWindowSize ~= nil then
        local layout = skin.layout.tuner_window or { width = 520.0, height = 720.0 }
        imgui.SetNextWindowSize({ layout.width or 520.0, layout.height or 720.0 }, ImGuiCond_FirstUseEver)
    end
    local pushed = skin.push_window(imgui)
    local visible, open = window_state.begin(imgui, "OddQ UI Tuner", true, 0)
    state.ui_tuner_open = open
    if visible then
        imgui_text.wrapped(imgui, "Live edits update the current runtime. Use /odd ui save when the values look right.")
        for index, group in ipairs(layout_control_groups) do
            render_layout_group(imgui, group, index)
        end
        render_color_group(imgui)
        if imgui.Separator ~= nil then
            imgui.Separator()
        end
        if skin.button(imgui, "Reset##oddq_ui_tuner_reset", "secondary") then
            tuner_window.reset()
        end
        same_line(imgui, (skin.layout.tuner_window or {}).button_gap or nil)
        if skin.button(imgui, "Print Constants##oddq_ui_tuner_print", "primary") then
            state.ui_tuner_last_snippet = tuner_window.layout_snippet()
        end
        same_line(imgui, (skin.layout.tuner_window or {}).button_gap or nil)
        if skin.button(imgui, "Save File##oddq_ui_tuner_save", "primary") then
            state.ui_tuner_last_snippet = tuner_window.layout_snippet()
            state.ui_tuner_save_requested = true
        end
        if state.ui_tuner_last_snippet ~= nil and state.ui_tuner_last_snippet ~= "" then
            imgui_text.wrapped(imgui, state.ui_tuner_last_snippet)
        end
    end
    imgui.End()
    skin.pop(imgui, pushed)
end

return tuner_window
