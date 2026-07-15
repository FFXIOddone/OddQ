local path_samples = {}

local state = {
    collection_enabled = false,
    manual_enabled = false,
    server_policy_enabled = false,
    session_id = nil,
    samples = {},
    output_path = "config/addons/oddq/path_samples/session.jsonl",
}

local function update_enabled()
    state.collection_enabled = state.manual_enabled or state.server_policy_enabled
    if state.collection_enabled and state.session_id == nil then
        path_samples.rotate_session_id()
    end

    return state.collection_enabled
end

function path_samples.rotate_session_id(now)
    local seed = now or os.time()
    math.randomseed(seed)
    state.session_id = string.format("ps_%d_%04x", seed, math.random(0, 65535))
    state.samples = {}
    return state.session_id
end

function path_samples.set_manual_enabled(enabled)
    state.manual_enabled = enabled == true
    return update_enabled()
end

function path_samples.apply_server_policy(policy)
    state.server_policy_enabled = policy ~= nil and policy.enable_path_samples == true
    return update_enabled()
end

function path_samples.is_enabled()
    return state.collection_enabled
end

function path_samples.current_session_id()
    return state.session_id
end

function path_samples.record_sample(sample)
    if not state.collection_enabled or sample == nil then
        return false
    end

    table.insert(state.samples, {
        t = sample.t,
        x = sample.x,
        y = sample.y,
        z = sample.z,
        speed = sample.speed,
        context = sample.context,
    })

    return true
end

function path_samples.flush_samples(writer)
    if #state.samples == 0 then
        return false
    end

    if writer ~= nil then
        writer(state.session_id, state.samples)
        return true
    end

    local file = io.open(state.output_path, "a")
    if file == nil then
        return false
    end

    file:write(state.session_id .. "\n")
    file:close()
    return true
end

function path_samples.reset()
    state.collection_enabled = false
    state.manual_enabled = false
    state.server_policy_enabled = false
    state.session_id = nil
    state.samples = {}
end

path_samples.state = state

-- ODD_FILE_WRITE: optional local path sample export writes config/addons/oddq/path_samples/session.jsonl only after manual or server-policy enable.
-- ODD_SECURITY_NOTE: path collection is disabled by default, records only position/time samples, and performs no network call or gameplay action.

return path_samples
