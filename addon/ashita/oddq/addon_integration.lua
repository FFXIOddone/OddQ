local addon_integration = {}

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function clean_target(value)
    local text = trim(value)
    text = text:gsub("[\r\n\t]", " ")
    text = text:gsub("[/<>|;]", " ")
    text = text:gsub("%s+", " ")
    return trim(text)
end

local function has_blocked_token(command)
    local text = trim(command):lower()
    for _, token in ipairs({
        "/target",
        "/trade",
        "/follow",
        "/attack",
        "/addon",
        "/load",
        "/input",
        "/ma ",
        "packet",
    }) do
        if text:find(token, 1, true) ~= nil then
            return true
        end
    end
    return false
end

function addon_integration.filterscan_command(target_name)
    local target = clean_target(target_name)
    if target == "" then
        return "/filterscan"
    end
    return "/filterscan " .. target
end

function addon_integration.minimap_zoom_command(value)
    local numeric = tonumber(value)
    if numeric == nil or numeric < 0.05 or numeric > 5.0 then
        return nil
    end
    return string.format("/minimap zoom %.2f", numeric)
end

function addon_integration.is_allowed_command(command)
    local text = trim(command):lower()
    if text == "" or has_blocked_token(text) then
        return false
    end
    if text == "/filterscan" then
        return true
    end
    if text:match("^/filterscan [%w%p%s]+$") ~= nil then
        return true
    end
    if text == "/minimap" then
        return true
    end
    if text:match("^/minimap zoom %d+%.?%d*$") ~= nil then
        return true
    end
    if text:match("^/minimap opacity %d+%.?%d*$") ~= nil then
        return true
    end
    if text:match("^/minimap mainopacity %d+%.?%d*$") ~= nil then
        return true
    end
    return false
end

function addon_integration.queue_allowed(command, chat_manager)
    if not addon_integration.is_allowed_command(command) then
        return false, "blocked unsafe helper command"
    end
    if chat_manager == nil or type(chat_manager.QueueCommand) ~= "function" then
        return false, "chat manager unavailable"
    end
    chat_manager:QueueCommand(1, command)
    return true, nil
end

return addon_integration
