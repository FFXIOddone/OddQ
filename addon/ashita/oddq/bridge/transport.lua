local transport = {}

local function load_dependency(name)
    local ok, value = pcall(require, name)
    if not ok then
        return nil, value
    end
    return value, nil
end

function transport.post_json(url, request)
    local http, http_err = load_dependency("socket.http")
    if http == nil then
        return nil, "bridge transport dependency unavailable: " .. tostring(http_err)
    end

    local ltn12, ltn_err = load_dependency("socket.ltn12")
    if ltn12 == nil then
        return nil, "bridge transport dependency unavailable: " .. tostring(ltn_err)
    end

    local json, json_err = load_dependency("json")
    if json == nil then
        return nil, "bridge transport dependency unavailable: " .. tostring(json_err)
    end

    local encoded_ok, body = pcall(json.encode, request)
    if not encoded_ok then
        return nil, "bridge request encode failed: " .. tostring(body)
    end

    local chunks = {}
    local previous_timeout = http.TIMEOUT
    http.TIMEOUT = 5

    -- ODD_NETWORK_CALL: localhost bridge JSON POST only; no external endpoint policy in Lua.
    local ok, code = http.request({
        url = url,
        method = "POST",
        source = ltn12.source.string(body),
        headers = {
            ["Accept"] = "application/json",
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#body),
        },
        sink = ltn12.sink.table(chunks),
    })

    http.TIMEOUT = previous_timeout

    if not ok then
        return nil, "bridge request failed: " .. tostring(code)
    end

    local status_code = tonumber(code)
    if status_code ~= 200 then
        return nil, "bridge request failed with status " .. tostring(code)
    end

    local response_body = table.concat(chunks)
    local decoded_ok, response = pcall(json.decode, response_body)
    if not decoded_ok then
        return nil, "bridge response decode failed: " .. tostring(response)
    end

    return response, nil
end

return transport
