local update_checker = {}

local LATEST_RELEASE_API = "https://api.github.com/repos/FFXIOddone/OddQ/releases/latest"
local RELEASES_URL = "https://github.com/FFXIOddone/OddQ/releases/latest"
local REQUEST_TIMEOUT_SECONDS = 4

local function parse_version(value)
    local major, minor, patch = tostring(value or ""):match("^oddq%-v(%d+)%.(%d+)%.(%d+)$")
    if major == nil then
        major, minor, patch = tostring(value or ""):match("^v?(%d+)%.(%d+)%.(%d+)$")
    end
    if major == nil then return nil end
    return { tonumber(major), tonumber(minor), tonumber(patch) }
end

local function version_text(parts)
    return table.concat(parts, ".")
end

local function is_newer(candidate, current)
    for index = 1, 3 do
        if candidate[index] ~= current[index] then
            return candidate[index] > current[index]
        end
    end
    return false
end

local function default_request()
    local https_ok, https = pcall(require, "socket.ssl.https")
    local ltn12_ok, ltn12 = pcall(require, "socket.ltn12")
    if not https_ok or not ltn12_ok then
        return nil, nil, "https dependencies unavailable"
    end

    local chunks = {}
    local previous_timeout = https.TIMEOUT
    https.TIMEOUT = REQUEST_TIMEOUT_SECONDS
    -- ODD_NETWORK_CALL: one read-only HTTPS GET to the fixed public OddQ release endpoint.
    local called, ok, code = pcall(https.request, {
        url = LATEST_RELEASE_API,
        method = "GET",
        headers = {
            ["Accept"] = "application/vnd.github+json",
            ["User-Agent"] = "OddQ-update-checker",
            ["X-GitHub-Api-Version"] = "2022-11-28",
        },
        sink = ltn12.sink.table(chunks),
    })
    https.TIMEOUT = previous_timeout
    if not called or not ok then
        return nil, nil, tostring(code or ok)
    end
    return table.concat(chunks), tonumber(code), nil
end

local function default_decode(body)
    return {
        tag_name = tostring(body or ""):match('"tag_name"%s*:%s*"([^"]+)"'),
        html_url = tostring(body or ""):match('"html_url"%s*:%s*"([^"]+)"'),
    }
end

local function default_notify(message)
    print("[OddQ] " .. message)
end

function update_checker.new_state()
    return { checked = false }
end

function update_checker.check(state, current_version, dependencies)
    state = state or update_checker.new_state()
    if state.checked then return { status = "already_checked" } end
    state.checked = true

    dependencies = dependencies or {}
    local request = dependencies.request or default_request
    local decode = dependencies.decode or default_decode
    local notify = dependencies.notify or default_notify
    local request_ok, body, status_code = pcall(request)
    if not request_ok or body == nil or status_code ~= 200 then
        return { status = "unavailable" }
    end

    local decode_ok, release = pcall(decode, body)
    if not decode_ok or type(release) ~= "table" then
        return { status = "invalid_response" }
    end
    local current = parse_version(current_version)
    local latest = parse_version(release.tag_name)
    if current == nil or latest == nil then
        return { status = "invalid_release" }
    end
    if not is_newer(latest, current) then
        return { status = "current", latest_version = version_text(latest) }
    end

    local release_url = tostring(release.html_url or "")
    if not release_url:match("^https://github%.com/FFXIOddone/OddQ/releases/") then
        release_url = RELEASES_URL
    end
    local latest_text = version_text(latest)
    notify("OddQ " .. latest_text .. " is available; you have " .. version_text(current) .. ".")
    notify("Run /addon link oddq to open the verified GitHub release page: " .. release_url)
    return {
        status = "update_available",
        latest_version = latest_text,
        release_url = release_url,
    }
end

return update_checker
