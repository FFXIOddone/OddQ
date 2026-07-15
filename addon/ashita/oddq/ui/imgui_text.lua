local imgui_text = {}

local MAX_TEXT_CHUNK_BYTES = 180

local function literal(value)
    return tostring(value or "")
end

function imgui_text.format(value)
    return tostring(value or ""):gsub("%%", "%%%%")
end

local function split_long_line(line)
    line = tostring(line or "")
    local chunks = {}
    while #line > MAX_TEXT_CHUNK_BYTES do
        local prefix = line:sub(1, MAX_TEXT_CHUNK_BYTES)
        local cut = nil
        for index = #prefix, 1, -1 do
            local byte = prefix:byte(index)
            if byte == 32 or byte == 9 then
                cut = index - 1
                break
            end
        end
        if cut == nil or cut < 32 then
            cut = MAX_TEXT_CHUNK_BYTES
        end

        local chunk = line:sub(1, cut):gsub("%s+$", "")
        if chunk ~= "" then
            table.insert(chunks, chunk)
        end
        line = line:sub(cut + 1):gsub("^%s+", "")
    end
    if line ~= "" or #chunks == 0 then
        table.insert(chunks, line)
    end
    return chunks
end

local function safe_chunks(value)
    local chunks = {}
    for line in (literal(value) .. "\n"):gmatch("(.-)\n") do
        for _, chunk in ipairs(split_long_line(line)) do
            table.insert(chunks, chunk)
        end
    end
    return chunks
end

local function push_text_wrap(imgui)
    if imgui == nil or imgui.PushTextWrapPos == nil then
        return false
    end

    local wrap_position = 0
    if imgui.GetWindowWidth ~= nil then
        wrap_position = math.max(0, (tonumber(imgui.GetWindowWidth()) or 0) - 16)
    end
    imgui.PushTextWrapPos(wrap_position)
    return true
end

local function push_text_wrap_at(imgui, wrap_position)
    if imgui == nil or imgui.PushTextWrapPos == nil then
        return false
    end

    local position = tonumber(wrap_position)
    if position == nil then
        return push_text_wrap(imgui)
    end

    imgui.PushTextWrapPos(math.max(0, position))
    return true
end

function imgui_text.text(imgui, value)
    if imgui == nil then
        return
    end
    local chunks = safe_chunks(value)
    if imgui.TextUnformatted ~= nil then
        for _, chunk in ipairs(chunks) do
            imgui.TextUnformatted(chunk)
        end
    elseif imgui.Text ~= nil then
        for _, chunk in ipairs(chunks) do
            imgui.Text(imgui_text.format(chunk))
        end
    end
end

function imgui_text.wrapped(imgui, value)
    if imgui == nil then
        return
    end

    local chunks = safe_chunks(value)
    if imgui.TextUnformatted ~= nil then
        local wrapped = push_text_wrap(imgui)
        for _, chunk in ipairs(chunks) do
            imgui.TextUnformatted(chunk)
        end
        if wrapped and imgui.PopTextWrapPos ~= nil then
            imgui.PopTextWrapPos()
        end
    elseif imgui.TextWrapped ~= nil then
        for _, chunk in ipairs(chunks) do
            imgui.TextWrapped(imgui_text.format(chunk))
        end
    elseif imgui.Text ~= nil then
        for _, chunk in ipairs(chunks) do
            imgui.Text(imgui_text.format(chunk))
        end
    end
end

function imgui_text.wrapped_at(imgui, value, wrap_position)
    if imgui == nil then
        return
    end

    local chunks = safe_chunks(value)
    if imgui.TextUnformatted ~= nil then
        local wrapped = push_text_wrap_at(imgui, wrap_position)
        for _, chunk in ipairs(chunks) do
            imgui.TextUnformatted(chunk)
        end
        if wrapped and imgui.PopTextWrapPos ~= nil then
            imgui.PopTextWrapPos()
        end
    elseif imgui.TextWrapped ~= nil then
        for _, chunk in ipairs(chunks) do
            imgui.TextWrapped(imgui_text.format(chunk))
        end
    elseif imgui.Text ~= nil then
        for _, chunk in ipairs(chunks) do
            imgui.Text(imgui_text.format(chunk))
        end
    end
end

function imgui_text.colored(imgui, color, value)
    if imgui == nil then
        return
    end

    local chunks = safe_chunks(value)
    if imgui.TextUnformatted ~= nil
        and imgui.PushStyleColor ~= nil
        and imgui.PopStyleColor ~= nil
        and ImGuiCol_Text ~= nil then
        imgui.PushStyleColor(ImGuiCol_Text, color)
        for _, chunk in ipairs(chunks) do
            imgui.TextUnformatted(chunk)
        end
        imgui.PopStyleColor()
    elseif imgui.TextColored ~= nil then
        for _, chunk in ipairs(chunks) do
            imgui.TextColored(color, imgui_text.format(chunk))
        end
    elseif imgui.Text ~= nil then
        for _, chunk in ipairs(chunks) do
            imgui.Text(imgui_text.format(chunk))
        end
    end
end

function imgui_text.colored_wrapped_at(imgui, color, value, wrap_position)
    if imgui == nil then
        return
    end

    if imgui.PushStyleColor ~= nil
        and imgui.PopStyleColor ~= nil
        and ImGuiCol_Text ~= nil then
        imgui.PushStyleColor(ImGuiCol_Text, color)
        imgui_text.wrapped_at(imgui, value, wrap_position)
        imgui.PopStyleColor()
        return
    end

    imgui_text.wrapped_at(imgui, value, wrap_position)
end

return imgui_text
