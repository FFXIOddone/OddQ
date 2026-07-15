local imgui_text = require("ui/imgui_text")

local skin = {}

skin.colors = {
    bg = { 0.063, 0.067, 0.067, 1.00 },
    panel = { 0.094, 0.102, 0.102, 0.00 },
    panel_soft = { 0.039, 0.043, 0.043, 0.50 },
    blue = { 0.059, 0.541, 0.862, 1.00 },
    blue_border = { 0.059, 0.541, 0.862, 0.72 },
    blue_button = { 0.114, 0.110, 0.086, 0.88 },
    blue_highlight = { 0.098, 0.858, 1.000, 1.00 },
    scrollbar_bg = { 0.039, 0.043, 0.043, 0.82 },
    scrollbar_grab = { 0.059, 0.541, 0.862, 0.40 },
    scrollbar_grab_hovered = { 0.059, 0.541, 0.862, 0.68 },
    scrollbar_grab_active = { 0.098, 0.858, 1.000, 0.84 },
    text = { 0.933, 0.914, 0.863, 1.00 },
    muted = { 0.700, 0.745, 0.745, 1.00 },
    line = { 0.933, 0.914, 0.863, 0.30 },
}

skin.layout = {
    guide_notes = {
        width = 585.0,
        height = 230.0,
        padding_x = 0.0,
        padding_y = 0.0,
        content_top_gap = 0.0,
        content_bottom_gap = 0.0,
    },
    objective_cluster = {
        width = 180.0,
        min_height = 90.0,
        loaded_min_height = 100.0,
        padding_x = 0.0,
        padding_y = 4.0,
        gap = 5.0,
        radius = 8.0,
        progress_height = 9.0,
        button_height = 25.0,
        window_margin_x = 96.0,
        min_width = 120.0,
        title_indent_x = 6.0,
        subtitle_indent_x = 10.0,
        text_right_inset = 5.0,
        title_subtitle_gap = 0.0,
        instruction_gap = 5.0,
        instruction_indent_x = 15.0,
        instruction_line_y_offset = 0.0,
        instruction_line_height = 18.0,
        instruction_line_thickness = 2.0,
        bottom_gap = 0.0,
    },
    detailed_information = {
        width = 685.0,
        height = 607.0,
        padding_x = 0.0,
        padding_y = 0.0,
        gap = 7.0,
        wrap_inset = 8.0,
        section_gap = 0.0,
        section_top_gap = 0.0,
        section_bottom_gap = 0.0,
        tab_button_gap = 6.0,
        tab_row_gap = 6.0,
        tab_max_buttons_per_row = 8.0,
        tab_min_overlap_pct = 0.0,
        tab_max_overlap_pct = 0.0,
        tab_button_height = 32.0,
        tab_button_min_width = 78.0,
        nav_button_gap = 7.0,
        nav_button_width = 132.0,
        nav_button_height = 0.0,
        nav_top_gap = 4.0,
        nav_bottom_gap = 4.0,
        summary_gap = 5.0,
        step_body_gap = 4.0,
        note_gap = 2.0,
        title_indent_x = 0.0,
        body_indent_x = 45.0,
        note_indent_x = 80.0,
        content_top_gap = 0.0,
        content_bottom_gap = 0.0,
    },
    main_window = {
        width = 1040.0,
        height = 620.0,
        section_gap = 0.0,
        mode_button_gap = 0.0,
        nav_button_gap = 0.0,
        control_gap = 0.0,
        guide_browser = {
            results_width = 550.0,
            preview_width = 430.0,
            height = 420.0,
            column_gap = 8.0,
            category_gap = 6.0,
            search_width = -1.0,
            limit = 8.0,
        },
    },
    assist_hub = {
        width = 360.0,
        height = 320.0,
    },
    direction_cue = {
        width = 320.0,
        height = 178.0,
        alpha = 0.35,
        arrow_size = 58.0,
        arrow_gap = 18.0,
        label_gap = 0.0,
        body_gap = 0.0,
    },
    map_pin = {
        width = 260.0,
        height = 118.0,
        alpha = 0.30,
        body_gap = 0.0,
        direction_gap = 0.0,
    },
    tuner_window = {
        width = 520.0,
        height = 720.0,
        group_gap = 0.0,
        control_gap = 0.0,
        button_gap = 0.0,
    },
    window = {
        alpha = 0.93,
        rounding = 10.0,
        frame_rounding = 5.0,
        scrollbar_rounding = 3.0,
        border_size = 0.0,
        item_spacing_x = 8.0,
        item_spacing_y = 6.0,
        item_inner_spacing_x = 4.0,
        item_inner_spacing_y = 4.0,
        frame_padding_x = 4.0,
        frame_padding_y = 5.0,
        indent_spacing = 21.0,
        scrollbar_size = 14.0,
    },
    text = {
        wrap_inset = 16.0,
        title_scale = 1.0,
        subtitle_scale = 1.0,
        body_scale = 1.0,
        instruction_scale = 1.0,
        section_scale = 1.0,
        label_scale = 1.0,
        value_scale = 1.0,
        body_line_gap = 0.0,
        section_gap = 0.0,
    },
}

local function global(name)
    return _G ~= nil and _G[name] or nil
end

local function push_color(imgui, slot_name, color, pushed)
    local slot = global(slot_name)
    if imgui ~= nil and imgui.PushStyleColor ~= nil and slot ~= nil then
        imgui.PushStyleColor(slot, color)
        pushed.colors = pushed.colors + 1
    end
end

local function push_var(imgui, slot_name, value, pushed)
    local slot = global(slot_name)
    if imgui ~= nil and imgui.PushStyleVar ~= nil and slot ~= nil then
        imgui.PushStyleVar(slot, value)
        pushed.vars = pushed.vars + 1
    end
end

local function pop_style(imgui, pushed)
    pushed = pushed or { colors = 0, vars = 0 }
    if imgui ~= nil and imgui.PopStyleVar ~= nil and pushed.vars > 0 then
        imgui.PopStyleVar(pushed.vars)
    end
    if imgui ~= nil and imgui.PopStyleColor ~= nil and pushed.colors > 0 then
        imgui.PopStyleColor(pushed.colors)
    end
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

local function text_layout()
    return skin.layout.text or {}
end

local function text_scale(role)
    local layout = text_layout()
    if role == "title" then
        return tonumber(layout.title_scale) or 1.0
    elseif role == "subtitle" then
        return tonumber(layout.subtitle_scale) or 1.0
    elseif role == "instruction" then
        return tonumber(layout.instruction_scale) or 1.0
    elseif role == "section" then
        return tonumber(layout.section_scale) or 1.0
    elseif role == "label" then
        return tonumber(layout.label_scale) or 1.0
    elseif role == "value" then
        return tonumber(layout.value_scale) or 1.0
    end
    return tonumber(layout.body_scale) or 1.0
end

local function with_text_scale(imgui, role, render)
    local scale = text_scale(role)
    local scaled = false
    if imgui ~= nil and imgui.SetWindowFontScale ~= nil and math.abs(scale - 1.0) > 0.001 then
        imgui.SetWindowFontScale(scale)
        scaled = true
    end
    render()
    if scaled then
        imgui.SetWindowFontScale(1.0)
    end
end

local function fallback_wrap_x(imgui)
    if imgui ~= nil and imgui.GetWindowWidth ~= nil then
        return math.max(0.0, (tonumber(imgui.GetWindowWidth()) or 0.0) - (text_layout().wrap_inset or 16.0))
    end
    return nil
end

local function role_gap(imgui, role)
    if role == "body" then
        vertical_gap(imgui, text_layout().body_line_gap or 0.0)
    end
end

function skin.text_wrapped(imgui, value, role)
    role = role or "body"
    with_text_scale(imgui, role, function()
        local wrap_x = fallback_wrap_x(imgui)
        if wrap_x ~= nil then
            imgui_text.wrapped_at(imgui, value, wrap_x)
        else
            imgui_text.wrapped(imgui, value)
        end
    end)
    role_gap(imgui, role)
end

function skin.text_wrapped_at(imgui, value, wrap_position, role)
    role = role or "body"
    with_text_scale(imgui, role, function()
        imgui_text.wrapped_at(imgui, value, wrap_position)
    end)
    role_gap(imgui, role)
end

function skin.text_colored(imgui, color, value, role)
    role = role or "body"
    with_text_scale(imgui, role, function()
        imgui_text.colored(imgui, color, value)
    end)
    role_gap(imgui, role)
end

function skin.text_colored_wrapped_at(imgui, color, value, wrap_position, role)
    role = role or "body"
    with_text_scale(imgui, role, function()
        imgui_text.colored_wrapped_at(imgui, color, value, wrap_position)
    end)
    role_gap(imgui, role)
end

local function color_u32(imgui, color)
    if imgui ~= nil and imgui.GetColorU32 ~= nil then
        return imgui.GetColorU32(color)
    end
    return color
end

function skin.push_window(imgui, alpha)
    local pushed = { colors = 0, vars = 0 }
    local window_layout = skin.layout.window or {}
    if imgui ~= nil and imgui.SetNextWindowBgAlpha ~= nil then
        imgui.SetNextWindowBgAlpha(alpha or window_layout.alpha or 0.80)
    end

    push_color(imgui, "ImGuiCol_Text", skin.colors.text, pushed)
    push_color(imgui, "ImGuiCol_WindowBg", skin.colors.bg, pushed)
    push_color(imgui, "ImGuiCol_Border", skin.colors.blue_border, pushed)
    push_color(imgui, "ImGuiCol_TitleBg", skin.colors.panel, pushed)
    push_color(imgui, "ImGuiCol_TitleBgActive", skin.colors.panel, pushed)
    push_color(imgui, "ImGuiCol_TitleBgCollapsed", skin.colors.panel, pushed)
    push_color(imgui, "ImGuiCol_Button", skin.colors.blue_button, pushed)
    push_color(imgui, "ImGuiCol_ButtonHovered", { 0.059, 0.541, 0.862, 0.62 }, pushed)
    push_color(imgui, "ImGuiCol_ButtonActive", { 0.098, 0.858, 1.000, 0.72 }, pushed)
    push_color(imgui, "ImGuiCol_FrameBg", { 0.059, 0.063, 0.063, 0.90 }, pushed)
    push_color(imgui, "ImGuiCol_ScrollbarBg", skin.colors.scrollbar_bg, pushed)
    push_color(imgui, "ImGuiCol_ScrollbarGrab", skin.colors.scrollbar_grab, pushed)
    push_color(imgui, "ImGuiCol_ScrollbarGrabHovered", skin.colors.scrollbar_grab_hovered, pushed)
    push_color(imgui, "ImGuiCol_ScrollbarGrabActive", skin.colors.scrollbar_grab_active, pushed)

    push_var(imgui, "ImGuiStyleVar_WindowRounding", window_layout.rounding or 8.0, pushed)
    push_var(imgui, "ImGuiStyleVar_FrameRounding", window_layout.frame_rounding or 4.0, pushed)
    push_var(imgui, "ImGuiStyleVar_ScrollbarRounding", window_layout.scrollbar_rounding or 4.0, pushed)
    push_var(imgui, "ImGuiStyleVar_WindowBorderSize", window_layout.border_size or 1.0, pushed)
    push_var(imgui, "ImGuiStyleVar_ItemSpacing", { window_layout.item_spacing_x or 8.0, window_layout.item_spacing_y or 4.0 }, pushed)
    push_var(
        imgui,
        "ImGuiStyleVar_ItemInnerSpacing",
        { window_layout.item_inner_spacing_x or 4.0, window_layout.item_inner_spacing_y or 4.0 },
        pushed
    )
    push_var(imgui, "ImGuiStyleVar_FramePadding", { window_layout.frame_padding_x or 4.0, window_layout.frame_padding_y or 3.0 }, pushed)
    push_var(imgui, "ImGuiStyleVar_IndentSpacing", window_layout.indent_spacing or 21.0, pushed)
    push_var(imgui, "ImGuiStyleVar_ScrollbarSize", window_layout.scrollbar_size or 14.0, pushed)
    return pushed
end

function skin.pop(imgui, pushed)
    pop_style(imgui, pushed)
end

function skin.section_header(imgui, label)
    if imgui ~= nil and imgui.Separator ~= nil then
        imgui.Separator()
    end
    vertical_gap(imgui, text_layout().section_gap or 0.0)
    skin.text_colored(imgui, skin.colors.blue_highlight, tostring(label or ""), "section")
end

function skin.label_value(imgui, label, value)
    skin.text_colored(imgui, skin.colors.blue_highlight, tostring(label or ""), "label")
    if imgui ~= nil and imgui.SameLine ~= nil then
        imgui.SameLine()
    end
    skin.text_wrapped(imgui, tostring(value or ""), "value")
end

local function push_button_style(imgui, variant)
    local pushed = { colors = 0, vars = 0 }
    local color = skin.colors.blue_button
    local hovered = { 0.098, 0.858, 1.000, 0.58 }
    local active = { 0.098, 0.858, 1.000, 0.80 }
    if variant == "primary" then
        color = { 0.059, 0.541, 0.862, 0.62 }
    elseif variant == "active" then
        color = { 0.098, 0.858, 1.000, 0.38 }
    elseif variant == "toggle" then
        color = { 0.059, 0.541, 0.862, 0.46 }
    elseif variant == "disabled" then
        color = { 0.20, 0.23, 0.27, 0.45 }
        hovered = { 0.20, 0.23, 0.27, 0.45 }
        active = { 0.20, 0.23, 0.27, 0.45 }
    end
    push_color(imgui, "ImGuiCol_Button", color, pushed)
    push_color(imgui, "ImGuiCol_ButtonHovered", hovered, pushed)
    push_color(imgui, "ImGuiCol_ButtonActive", active, pushed)
    push_var(imgui, "ImGuiStyleVar_FrameRounding", 4.0, pushed)
    return pushed
end

function skin.disabled_checkbox(imgui, label, checked)
    if imgui == nil then
        return
    end
    if imgui.BeginDisabled ~= nil and imgui.EndDisabled ~= nil and imgui.Checkbox ~= nil then
        skin.disabled(imgui, function()
            imgui.Checkbox(label, { checked == true })
        end)
        return
    end
    local text = tostring(label or ""):gsub("##.*$", "")
        .. (checked == true and ": On" or ": Off")
    if imgui.TextDisabled ~= nil then
        imgui.TextDisabled(text)
    elseif imgui.Text ~= nil then
        imgui.Text(text)
    end
end

function skin.disabled(imgui, render)
    if type(render) ~= "function" then
        return
    end
    local used = imgui ~= nil and imgui.BeginDisabled ~= nil and imgui.EndDisabled ~= nil
    if used then
        imgui.BeginDisabled(true)
    end
    render()
    if used then
        imgui.EndDisabled()
    end
end

function skin.button(imgui, label, variant, size)
    if imgui == nil or imgui.Button == nil then
        return false
    end
    local disabled = variant == "disabled"
    local pushed = push_button_style(imgui, variant)
    local clicked
    local function render_button()
        if size ~= nil then
            local ok, value = pcall(imgui.Button, tostring(label or ""), size)
            if ok then
                clicked = value
            else
                clicked = imgui.Button(tostring(label or ""))
            end
        else
            clicked = imgui.Button(tostring(label or ""))
        end
    end
    if disabled then
        skin.disabled(imgui, render_button)
    else
        render_button()
    end
    pop_style(imgui, pushed)
    return not disabled and clicked == true
end

function skin.toggle_button(imgui, label, active)
    return skin.button(imgui, label, active and "toggle" or "secondary")
end

function skin.progress_bar(imgui, fraction, label, max_width, height)
    fraction = tonumber(fraction) or 0
    if fraction < 0 then
        fraction = 0
    elseif fraction > 1 then
        fraction = 1
    end

    if imgui == nil
        or imgui.GetWindowDrawList == nil
        or imgui.GetCursorScreenPos == nil
        or imgui.Dummy == nil then
        skin.text_wrapped(imgui, tostring(label or ""))
        return
    end

    local draw = imgui.GetWindowDrawList()
    if draw == nil or draw.AddRectFilled == nil then
        skin.text_wrapped(imgui, tostring(label or ""))
        return
    end

    local width = tonumber(max_width) or 220.0
    if max_width == nil and imgui.GetWindowWidth ~= nil then
        width = math.max(160.0, math.min(320.0, imgui.GetWindowWidth() - 32.0))
    end
    local x, y = imgui.GetCursorScreenPos()
    local h = tonumber(height) or 5.0
    draw:AddRectFilled({ x, y }, { x + width, y + h }, color_u32(imgui, skin.colors.line), 999.0)
    draw:AddRectFilled({ x, y }, { x + (width * fraction), y + h }, color_u32(imgui, skin.colors.blue_highlight), 999.0)
    imgui.Dummy({ width, h + 4.0 })
    if label ~= nil and label ~= "" then
        skin.text_colored(imgui, skin.colors.muted, tostring(label), "body")
    end
end

local function set_cursor_screen_pos(imgui, x, y)
    if imgui ~= nil and imgui.SetCursorScreenPos ~= nil then
        imgui.SetCursorScreenPos({ x, y })
        return true
    end
    return false
end

local function cursor_pos_x(imgui)
    if imgui == nil then
        return nil
    end
    if imgui.GetCursorPosX ~= nil then
        return tonumber(imgui.GetCursorPosX())
    end
    if imgui.GetCursorPos ~= nil then
        local x = imgui.GetCursorPos()
        return tonumber(x)
    end
    return nil
end

local function calc_text_line_size(imgui, value, role)
    if imgui == nil or imgui.CalcTextSize == nil then
        return nil, nil
    end

    local ok, width, height = pcall(imgui.CalcTextSize, tostring(value or ""))
    if not ok then
        return nil, nil
    end

    local measured_width = nil
    local measured_height = nil
    if type(width) == "number" then
        measured_width = width
        measured_height = tonumber(height)
    elseif type(width) == "table" then
        measured_width = tonumber(width[1] or width.x)
        measured_height = tonumber(width[2] or width.y)
    end
    if measured_width == nil then
        return nil, nil
    end
    local scale = text_scale(role)
    return measured_width * scale, measured_height ~= nil and measured_height * scale or nil
end

local function calc_text_line_width(imgui, value, role)
    local width = calc_text_line_size(imgui, value, role)
    return width
end

local function estimated_text_line_width(value, role)
    return #tostring(value or "") * 8.0 * text_scale(role)
end

local function measured_or_estimated_text_line_width(imgui, value, role)
    return calc_text_line_width(imgui, value, role)
        or estimated_text_line_width(value, role)
end

local function text_width(imgui, value, role)
    local text = tostring(value or "")
    local widest = 0.0
    local measured = false
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local width = calc_text_line_width(imgui, line, role)
        if width == nil then
            return nil
        end
        widest = math.max(widest, width)
        measured = true
    end
    return measured and widest or nil
end

local function fallback_text_line_height(role)
    return 17.0 * text_scale(role)
end

local function text_line_height(imgui, role)
    local _, measured_height = calc_text_line_size(imgui, "Ag", role)
    return math.max(measured_height or 0.0, fallback_text_line_height(role))
end

local function wrap_text_lines(imgui, value, role, available_width)
    local text = tostring(value or "")
    local width = tonumber(available_width)
    local lines = {}
    for raw_line in (text .. "\n"):gmatch("(.-)\n") do
        if raw_line == "" then
            table.insert(lines, "")
        elseif width == nil or width <= 0 then
            table.insert(lines, raw_line)
        else
            local current = ""
            for word in raw_line:gmatch("%S+") do
                local candidate = current == "" and word or (current .. " " .. word)
                if current == "" or measured_or_estimated_text_line_width(imgui, candidate, role) <= width then
                    current = candidate
                else
                    table.insert(lines, current)
                    current = word
                end
            end
            if current ~= "" then
                table.insert(lines, current)
            end
        end
    end
    if #lines == 0 then
        table.insert(lines, "")
    end
    return lines
end

local function fit_text_to_width(imgui, value, role, available_width)
    local text = tostring(value or ""):gsub("%s+$", "")
    local width = tonumber(available_width)
    if width == nil or width <= 0 then
        return text
    end
    local suffix = "..."
    if measured_or_estimated_text_line_width(imgui, text, role) <= width then
        return text
    end
    while text ~= "" and measured_or_estimated_text_line_width(imgui, text .. suffix, role) > width do
        text = text:sub(1, -2):gsub("%s+$", "")
    end
    if text == "" then
        return suffix
    end
    return text .. suffix
end

local function clamp_text_to_wrapped_lines(imgui, value, role, available_width, max_lines)
    local limit = math.floor(tonumber(max_lines) or 0)
    if limit <= 0 then
        return tostring(value or "")
    end
    local lines = wrap_text_lines(imgui, value, role, available_width)
    if #lines <= limit then
        return table.concat(lines, "\n")
    end
    local limited = {}
    for index = 1, limit do
        limited[index] = lines[index]
    end
    limited[limit] = fit_text_to_width(imgui, limited[limit], role, available_width)
    return table.concat(limited, "\n")
end

local function wrapped_text_height(imgui, value, role, available_width)
    return #wrap_text_lines(imgui, value, role, available_width) * text_line_height(imgui, role)
end

local function objective_cluster_text_width(imgui, model, layout)
    local title_width = text_width(imgui, model.title or "OddQ", "title")
    if title_width == nil then
        return nil
    end

    local content_width = (layout.title_indent_x or 0.0) + title_width
    if model.subtitle ~= nil and model.subtitle ~= "" then
        local subtitle_width = text_width(imgui, model.subtitle, "subtitle")
        if subtitle_width == nil then
            return nil
        end
        content_width = math.max(content_width, (layout.subtitle_indent_x or 0.0) + subtitle_width)
    end

    return (layout.padding_x or 0.0) + content_width + (layout.text_right_inset or 0.0)
end

local function objective_cluster_title_height(imgui, model, layout, panel_width)
    local title_available_width = (tonumber(panel_width) or layout.width)
        - (layout.padding_x or 0.0)
        - (layout.title_indent_x or 0.0)
        - (layout.text_right_inset or 0.0)
    local title_height = wrapped_text_height(imgui, model.title or "OddQ", "title", title_available_width)
    if title_height == nil then
        return nil
    end

    local content_height = title_height
    if model.subtitle ~= nil and model.subtitle ~= "" then
        local subtitle_available_width = (tonumber(panel_width) or layout.width)
            - (layout.padding_x or 0.0)
            - (layout.subtitle_indent_x or 0.0)
            - (layout.text_right_inset or 0.0)
        local subtitle_height = wrapped_text_height(imgui, model.subtitle, "subtitle", subtitle_available_width)
        if subtitle_height == nil then
            return nil
        end
        content_height = content_height + (layout.title_subtitle_gap or 0.0) + subtitle_height
    end

    return ((layout.padding_y or 0.0) * 2.0) + content_height
end

function skin.objective_cluster(imgui, model, handlers)
    model = model or {}
    handlers = handlers or {}

    local layout = skin.layout.objective_cluster
    local panel_x = nil
    local panel_y = nil
    local panel_width = layout.width
    local panel_height = layout.min_height
    local panel_local_x = nil
    local card_wrap_x = nil
    local positioned = false
    local title_indented = false
    local title_outline_only = false
    if model ~= nil and (model.progress ~= nil or model.show_controls ~= false) then
        panel_height = math.max(panel_height, layout.loaded_min_height or panel_height)
    end

    if imgui ~= nil
        and imgui.GetWindowDrawList ~= nil
        and imgui.GetCursorScreenPos ~= nil then
        local draw = imgui.GetWindowDrawList()
        if draw ~= nil and draw.AddRectFilled ~= nil then
            panel_local_x = cursor_pos_x(imgui)
            panel_x, panel_y = imgui.GetCursorScreenPos()
            local measured_width = objective_cluster_text_width(imgui, model, layout)
            if imgui.GetWindowWidth ~= nil then
                local available_width = (tonumber(imgui.GetWindowWidth()) or 0.0) - layout.window_margin_x
                if measured_width ~= nil and available_width > 0.0 then
                    panel_width = math.min(math.max(layout.min_width, measured_width), available_width)
                elseif available_width > 0.0 then
                    panel_width = math.max(layout.min_width, available_width)
                end
            elseif measured_width ~= nil then
                panel_width = math.max(layout.min_width, measured_width)
            end
            local measured_height = objective_cluster_title_height(imgui, model, layout, panel_width)
            if measured_height ~= nil then
                panel_height = math.max(1.0, measured_height)
                title_outline_only = true
            end
            draw:AddRectFilled({ panel_x, panel_y }, { panel_x + panel_width, panel_y + panel_height }, color_u32(imgui, skin.colors.panel), layout.radius)
            if draw.AddRect ~= nil then
                draw:AddRect({ panel_x, panel_y }, { panel_x + panel_width, panel_y + panel_height }, color_u32(imgui, skin.colors.blue_border), layout.radius)
            end
            card_wrap_x = (panel_local_x or 0.0) + panel_width - layout.padding_x - (layout.text_right_inset or 0.0)
            positioned = set_cursor_screen_pos(
                imgui,
                panel_x + layout.padding_x + (layout.title_indent_x or 0.0),
                panel_y + layout.padding_y
            )
            title_indented = positioned and (layout.title_indent_x or 0.0) ~= 0.0
        end
    end

    if card_wrap_x ~= nil then
        skin.text_colored_wrapped_at(imgui, skin.colors.blue_highlight, tostring(model.title or "OddQ"), card_wrap_x, "title")
    else
        skin.text_colored(imgui, skin.colors.blue_highlight, tostring(model.title or "OddQ"), "title")
    end
    vertical_gap(imgui, layout.title_subtitle_gap or 0.0)
    if model.subtitle ~= nil and model.subtitle ~= "" then
        if positioned and panel_x ~= nil and imgui ~= nil and imgui.GetCursorScreenPos ~= nil then
            local _, cursor_y = imgui.GetCursorScreenPos()
            set_cursor_screen_pos(imgui, panel_x + layout.padding_x + (layout.subtitle_indent_x or 0.0), cursor_y)
        end
        if card_wrap_x ~= nil then
            skin.text_colored_wrapped_at(imgui, skin.colors.muted, tostring(model.subtitle), card_wrap_x, "subtitle")
        else
            skin.text_colored(imgui, skin.colors.muted, tostring(model.subtitle), "subtitle")
        end
    end
    if title_indented
        and imgui ~= nil
        and imgui.GetCursorScreenPos ~= nil
        and panel_x ~= nil then
        local _, cursor_y = imgui.GetCursorScreenPos()
        set_cursor_screen_pos(imgui, panel_x + layout.padding_x, cursor_y)
    end
    if title_outline_only
        and positioned
        and imgui ~= nil
        and panel_x ~= nil
        and panel_y ~= nil then
        set_cursor_screen_pos(imgui, panel_x + layout.padding_x, panel_y + panel_height)
    end
    if model.progress ~= nil then
        vertical_gap(imgui, layout.gap)
        skin.progress_bar(imgui, model.progress, model.progress_label, panel_width - (layout.padding_x * 2.0), layout.progress_height)
    end

    if model.show_controls ~= false then
        vertical_gap(imgui, layout.gap)
        local rendered_control = false
        if type(handlers.on_guide) == "function" then
            if skin.button(imgui, "Guide##oddq_objective_cluster_guide", "secondary") then
                handlers.on_guide()
            end
            rendered_control = true
        end
        if type(handlers.on_previous) == "function" then
            if rendered_control then
                same_line(imgui, layout.gap)
            end
            if skin.button(imgui, "Previous##oddq_objective_cluster_previous", "secondary") then
                handlers.on_previous()
            end
            rendered_control = true
        end
        if type(handlers.on_next) == "function" then
            if rendered_control then
                same_line(imgui, layout.gap)
            end
            if skin.button(imgui, "Next##oddq_objective_cluster_next", "primary") then
                handlers.on_next()
            end
        end
    end

    if model.instruction ~= nil and model.instruction ~= "" then
        vertical_gap(imgui, layout.instruction_gap or layout.gap)
        if imgui ~= nil and imgui.GetWindowDrawList ~= nil and imgui.GetCursorScreenPos ~= nil then
            local draw = imgui.GetWindowDrawList()
            if draw ~= nil and draw.AddLine ~= nil then
                local x, y = imgui.GetCursorScreenPos()
                local line_offset = layout.instruction_line_y_offset or 2.0
                local line_height = layout.instruction_line_height or 32.0
                draw:AddLine(
                    { x, y + line_offset },
                    { x, y + line_offset + line_height },
                    color_u32(imgui, skin.colors.blue_highlight),
                    layout.instruction_line_thickness or 2.0
                )
                set_cursor_screen_pos(imgui, x + (layout.instruction_indent_x or 9.0), y)
            end
        end
        local instruction = tostring(model.instruction)
        if card_wrap_x ~= nil then
            local instruction_width = panel_width
                - (layout.padding_x or 0.0)
                - (layout.instruction_indent_x or 9.0)
                - (layout.text_right_inset or 0.0)
            instruction = clamp_text_to_wrapped_lines(
                imgui,
                instruction,
                "instruction",
                instruction_width,
                layout.instruction_max_lines or 2
            )
            skin.text_wrapped_at(imgui, instruction, card_wrap_x, "instruction")
        else
            skin.text_wrapped(imgui, instruction, "instruction")
        end
    end

    if positioned and panel_x ~= nil and panel_y ~= nil then
        if title_outline_only and imgui ~= nil and imgui.GetCursorScreenPos ~= nil then
            local _, cursor_y = imgui.GetCursorScreenPos()
            set_cursor_screen_pos(imgui, panel_x, math.max(cursor_y or panel_y, panel_y + panel_height) + (layout.bottom_gap or 8.0))
        else
            set_cursor_screen_pos(imgui, panel_x, panel_y + panel_height + (layout.bottom_gap or 8.0))
        end
    elseif imgui ~= nil and imgui.Dummy ~= nil then
        imgui.Dummy({ panel_width, layout.bottom_gap or 6.0 })
    end
end

return skin
