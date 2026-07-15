local pilot_recorder = {}
local local_filesystem = require("local_filesystem")

local state = {
    active = false,
    session_id = nil,
    output_path = "config/addons/oddq/pilot/session.jsonl",
    route_attempt_index = 0,
}

local function apply_generation_metadata(event, metadata)
    metadata = metadata or {}
    if metadata.source ~= nil then
        event.source = metadata.source
    end

    if metadata.evidence_type == "route_generation_transport" then
        event.evidence_type = "route_generation_transport"
        event.manual_result_claimed = false
        event.route_quality_claimed = false
    end

    return event
end

local function encode_string(value)
    local escaped = value:gsub('[%z\1-\31\\"]', function(char)
        if char == "\\" then
            return "\\\\"
        end
        if char == '"' then
            return '\\"'
        end
        if char == "\b" then
            return "\\b"
        end
        if char == "\f" then
            return "\\f"
        end
        if char == "\n" then
            return "\\n"
        end
        if char == "\r" then
            return "\\r"
        end
        if char == "\t" then
            return "\\t"
        end
        return string.format("\\u%04x", char:byte())
    end)
    return '"' .. escaped .. '"'
end

local function encode_json(value)
    local value_type = type(value)
    if value_type == "string" then
        return encode_string(value)
    end
    if value_type == "number" then
        return tostring(value)
    end
    if value_type == "boolean" then
        return tostring(value)
    end
    if value_type ~= "table" then
        return "null"
    end

    local is_array = true
    local count = 0
    for key, _ in pairs(value) do
        count = count + 1
        if type(key) ~= "number" then
            is_array = false
        end
    end

    local parts = {}
    if is_array then
        for index = 1, count do
            table.insert(parts, encode_json(value[index]))
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    for key, child in pairs(value) do
        table.insert(parts, encode_json(tostring(key)) .. ":" .. encode_json(child))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function new_session_id(now)
    return string.format("pilot_%d_%04x", now or os.time(), math.random(0, 65535))
end

local function is_absolute_path(path)
    return path:match("^%a:[/\\]") ~= nil or path:match("^[/\\]") ~= nil
end

local function ashita_install_path()
    if AshitaCore == nil then
        return nil
    end

    local ok, path = pcall(function()
        return AshitaCore:GetInstallPath()
    end)
    if ok and type(path) == "string" and path ~= "" then
        return path
    end

    return nil
end

local function resolve_output_path(path)
    if is_absolute_path(path) then
        return path
    end

    local install_path = ashita_install_path()
    if install_path == nil then
        return path
    end

    local separator = ""
    if install_path:sub(-1) ~= "\\" and install_path:sub(-1) ~= "/" then
        separator = "\\"
    end

    return install_path .. separator .. path
end

local function ensure_parent_directory(path)
    return local_filesystem.ensure_parent(path)
end

local function append_event(event)
    local output_path = resolve_output_path(state.output_path)
    local file, err = io.open(output_path, "a")
    if file == nil then
        local directory_ok, directory_err = ensure_parent_directory(output_path)
        if not directory_ok then
            return false, directory_err
        end
        file, err = io.open(output_path, "a")
        if file == nil then
            return false, err or ("could not open " .. output_path)
        end
    end

    event.timestamp_utc = os.date("!%Y-%m-%dT%H:%M:%SZ")
    event.session_id = state.session_id
    file:write(encode_json(event) .. "\n")
    file:close()
    return true
end

function pilot_recorder.is_active()
    return state.active
end

function pilot_recorder.start_session(label)
    if state.active then
        return state.session_id
    end

    math.randomseed(os.time())
    state.active = true
    state.session_id = new_session_id(os.time())
    state.route_attempt_index = 0
    local ok, err = append_event({
        event = "session_start",
        label = label or "",
        lua_memory_kb = collectgarbage("count"),
    })
    if not ok then
        state.active = false
        state.session_id = nil
        state.route_attempt_index = 0
        return nil, "pilot recorder could not write " .. resolve_output_path(state.output_path) .. ": " .. tostring(err)
    end
    return state.session_id
end

function pilot_recorder.stop_session(note)
    if not state.active then
        return false
    end

    append_event({
        event = "session_stop",
        note = note or "",
        lua_memory_kb = collectgarbage("count"),
    })
    state.active = false
    return true
end

function pilot_recorder.record_batch_start(count, delay_seconds)
    if not state.active then
        return false
    end

    return append_event({
        event = "batch_start",
        count = count or 0,
        delay_seconds = delay_seconds or 0,
        evidence_type = "route_generation_transport",
        manual_result_claimed = false,
        route_quality_claimed = false,
        note = "route-generation/transport evidence only; no manual arrival claimed",
    })
end

function pilot_recorder.record_batch_stop(attempts_completed, note)
    if not state.active then
        return false
    end

    return append_event({
        event = "batch_stop",
        attempts_completed = attempts_completed or 0,
        evidence_type = "route_generation_transport",
        manual_result_claimed = false,
        route_quality_claimed = false,
        note = note or "batch complete",
        lua_memory_kb = collectgarbage("count"),
    })
end

function pilot_recorder.next_route_attempt(route_request, metadata)
    if not state.active then
        return nil
    end

    route_request = route_request or {}
    state.route_attempt_index = state.route_attempt_index + 1
    local attempt_id = string.format("%s_route_%03d", state.session_id, state.route_attempt_index)
    append_event(apply_generation_metadata({
        event = "route_attempt",
        attempt_id = attempt_id,
        server_profile = route_request.server_profile,
        game_mode = route_request.game_mode,
        start_zone_id = route_request.current_zone_id,
        target_objective_id = route_request.target_objective_id,
    }, metadata))
    return attempt_id
end

function pilot_recorder.record_route_result(attempt_id, result)
    if not state.active or attempt_id == nil then
        return false
    end

    result = result or {}
    local metadata = {
        source = result.source,
        evidence_type = result.evidence_type,
    }
    local event = {
        event = "route_result",
        attempt_id = attempt_id,
        success = result.success == true,
        fallback_used = result.fallback_used == true,
        cache_hit = result.cache_hit == true,
        payload_bytes = result.payload_bytes or 0,
        solve_time_ms = result.solve_time_ms or 0,
        error = result.error or "",
        note = result.note or "",
    }
    apply_generation_metadata(event, metadata)
    if event.evidence_type == "route_generation_transport" and event.note == "" then
        event.note = "batch route-generation/transport evidence only; no manual arrival claimed"
    end
    return append_event(event)
end

function pilot_recorder.record_manual_result(success, note)
    if not state.active then
        return false
    end

    return append_event({
        event = "manual_result",
        success = success == true,
        note = note or "",
    })
end

function pilot_recorder.record_point_verification(success, note)
    if not state.active then
        return false
    end

    return append_event({
        event = "point_verification",
        success = success == true,
        verification_status = success == true and "gm_verified" or "bad_landing",
        route_quality_claimed = false,
        note = note or "",
    })
end

function pilot_recorder.record_route_quality(success, note)
    if not state.active then
        return false
    end

    return append_event({
        event = "route_quality",
        success = success == true,
        manual_result_claimed = true,
        route_quality_claimed = true,
        note = note or "",
    })
end

function pilot_recorder.record_route_test_event(event)
    if not state.active then
        return false
    end
    if type(event) ~= "table" or event.event == nil then
        return false
    end

    event.evidence_type = "route_test_progress"
    event.manual_result_claimed = false
    event.route_quality_claimed = false
    return append_event(event)
end

function pilot_recorder.record_progress_event(event)
    if not state.active then
        return false
    end
    if type(event) ~= "table" or event.event == nil then
        return false
    end

    event.evidence_type = "objective_progress_recon"
    event.manual_result_claimed = false
    event.route_quality_claimed = false
    return append_event(event)
end

function pilot_recorder.record_frame_sample(route_id, ui_open_seconds, metadata)
    if not state.active then
        return false
    end

    metadata = metadata or {}
    local event = {
        event = "frame_sample",
        route_id = route_id or "",
        ui_open_seconds = ui_open_seconds or 0,
        lua_memory_kb = collectgarbage("count"),
    }

    local frame_cost_ms = tonumber(metadata.frame_cost_ms)
    if frame_cost_ms ~= nil then
        event.frame_cost_ms = frame_cost_ms
        event.timing_source = metadata.timing_source or "manual_frame_sample"
    else
        event.frame_cost_ms = 0
        event.note = metadata.note or "timing pending"
    end

    local frame_delta_ms = tonumber(metadata.frame_delta_ms)
    if frame_delta_ms ~= nil then
        event.frame_delta_ms = frame_delta_ms
    end
    if metadata.route_visible ~= nil then
        event.route_visible = metadata.route_visible == true
    end

    return append_event(apply_generation_metadata(event, metadata))
end

function pilot_recorder.record_note(note)
    if not state.active then
        return false
    end

    return append_event({
        event = "note",
        note = note or "",
    })
end

function pilot_recorder.status()
    if not state.active then
        return "pilot recorder inactive"
    end

    return "pilot recorder active: " .. tostring(state.session_id)
end

pilot_recorder.state = state

-- ODD_FILE_WRITE: live pilot evidence writes config/addons/oddq/pilot/session.jsonl only after /odd pilot start.
-- ODD_SECURITY_NOTE: recorder stores route metrics, notes, frame samples, and Lua memory only; no chat logs, credentials, raw packet dumps, movement, targeting, trading, or packet mutation.

return pilot_recorder
