local inventory_readiness = {}

local function normalize(value)
    return tostring(value or ""):lower():match("^%s*(.-)%s*$")
end

local function requirement_label(entry)
    if type(entry) == "table" then
        return tostring(entry.name or entry.label or entry.item or entry.key_item or "")
    end
    return tostring(entry or "")
end

local function requirement_count(entry)
    if type(entry) == "table" then
        return tonumber(entry.count or entry.quantity) or 1
    end
    return 1
end

local function item_status(label, count, provider)
    local items = type(provider) == "table" and provider.items or nil
    if type(items) ~= "table" then
        return "unknown"
    end
    local have = tonumber(items[normalize(label)])
    if have == nil then
        return "unknown"
    end
    return have >= count and "have" or "missing"
end

local function key_item_status(label, provider)
    local key_items = type(provider) == "table" and provider.key_items or nil
    if type(key_items) ~= "table" then
        return "unknown"
    end
    local have = key_items[normalize(label)]
    if have == nil then
        return "unknown"
    end
    return have == true and "have" or "missing"
end

local function step_at(objective, step_index)
    local steps = type(objective) == "table" and objective.steps or nil
    if type(steps) ~= "table" then
        return {}
    end
    return steps[tonumber(step_index) or 1] or {}
end

function inventory_readiness.for_step(objective, step_index, provider)
    local step = step_at(objective, step_index)
    local rows = {}
    for _, entry in ipairs(step.required_items or {}) do
        local label = requirement_label(entry)
        if label ~= "" then
            local count = requirement_count(entry)
            table.insert(rows, {
                kind = "item",
                label = label,
                count = count,
                status = item_status(label, count, provider),
            })
        end
    end
    for _, entry in ipairs(step.required_key_items or {}) do
        local label = requirement_label(entry)
        if label ~= "" then
            table.insert(rows, {
                kind = "key_item",
                label = label,
                count = 1,
                status = key_item_status(label, provider),
            })
        end
    end
    return rows
end

return inventory_readiness
