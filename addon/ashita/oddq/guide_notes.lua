local guide_notes = {}

local loaded, generated_notes = pcall(function()
    return require("data/guide_notes")
end)

guide_notes.notes = loaded and generated_notes or {}

local function list_contains(values, needle)
    if type(values) ~= "table" then
        return false
    end
    for _, value in ipairs(values) do
        if tostring(value) == tostring(needle) then
            return true
        end
    end
    return false
end

local function note_applies_to_state(note, state, zone_id)
    if type(note) ~= "table" then
        return false
    end

    if type(note.zone_ids) == "table" and #note.zone_ids > 0 and not list_contains(note.zone_ids, tonumber(zone_id)) then
        return false
    end

    if type(note.modes) ~= "table" or #note.modes == 0 then
        return true
    end
    if state == nil or type(state.modes) ~= "table" then
        return true
    end

    for _, mode in ipairs(note.modes) do
        if state.modes[mode] == true then
            return true
        end
    end
    return false
end

function guide_notes.for_state(state, zone_id, limit)
    local results = {}
    for _, note in ipairs(guide_notes.notes) do
        if note_applies_to_state(note, state, zone_id) then
            table.insert(results, note)
        end
    end
    table.sort(results, function(left, right)
        local left_priority = tonumber(left.priority) or 100
        local right_priority = tonumber(right.priority) or 100
        if left_priority == right_priority then
            return tostring(left.id or "") < tostring(right.id or "")
        end
        return left_priority < right_priority
    end)

    if limit ~= nil and #results > tonumber(limit) then
        local trimmed = {}
        for index = 1, tonumber(limit) do
            table.insert(trimmed, results[index])
        end
        return trimmed
    end
    return results
end

return guide_notes
