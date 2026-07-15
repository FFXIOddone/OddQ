local progression_ledger = {}
local local_filesystem = require("local_filesystem")
local entry_cache = {}

progression_ledger.default_path = "config/addons/oddq/progression/completed.txt"

local function normalize_id(id)
    local value = tostring(id or ""):gsub("^%s+", ""):gsub("%s+$", "")
    value = value:gsub("^[Oo][Bb][Jj][Ee][Cc][Tt][Ii][Vv][Ee]:", "")
    value = value:gsub("%.[Ss][Tt][Aa][Rr][Tt]$", "")
    return value
end

local function ensure_parent_dir(path)
    local ok = local_filesystem.ensure_parent(path)
    return ok == true
end

local function read_entries(path)
    local entries = {}
    local file = io.open(path, "r")
    if file == nil then
        return entries
    end
    for line in file:lines() do
        local kind, id = line:match("^([^|]+)|(.+)$")
        id = normalize_id(id)
        if (kind == "mission" or kind == "quest") and id ~= "" then
            entries[kind .. "|" .. id] = { kind = kind, id = id }
        end
    end
    file:close()
    return entries
end

local function write_entries(path, entries)
    local file = io.open(path, "w")
    if file == nil then
        if not ensure_parent_dir(path) then
            return false
        end
        file = io.open(path, "w")
        if file == nil then
            return false
        end
    end
    local rows = {}
    for _, entry in pairs(entries) do
        table.insert(rows, entry.kind .. "|" .. entry.id)
    end
    table.sort(rows)
    for _, row in ipairs(rows) do
        file:write(row .. "\n")
    end
    file:close()
    return true
end

local function copy_entries(entries)
    local copied = {}
    for key, entry in pairs(entries or {}) do
        copied[key] = { kind = entry.kind, id = entry.id }
    end
    return copied
end

local function cached_entries(path)
    local key = tostring(path or progression_ledger.default_path)
    if entry_cache[key] == nil then
        entry_cache[key] = read_entries(key)
    end
    return entry_cache[key], key
end

function progression_ledger.record(path, kind, id)
    path = path or progression_ledger.default_path
    if kind ~= "mission" and kind ~= "quest" then
        return false
    end
    id = normalize_id(id)
    if id == "" then
        return false
    end
    local cached, key = cached_entries(path)
    local entries = copy_entries(cached)
    entries[kind .. "|" .. id] = { kind = kind, id = id }
    if not write_entries(path, entries) then
        return false
    end
    entry_cache[key] = entries
    return true
end

function progression_ledger.remove(path, kind, id)
    path = path or progression_ledger.default_path
    if kind ~= "mission" and kind ~= "quest" then
        return false
    end
    id = normalize_id(id)
    if id == "" then
        return false
    end
    local cached, key = cached_entries(path)
    local entries = copy_entries(cached)
    entries[tostring(kind) .. "|" .. id] = nil
    if not write_entries(path, entries) then
        return false
    end
    entry_cache[key] = entries
    return true
end

function progression_ledger.completed_lists(path)
    path = path or progression_ledger.default_path
    local lists = {
        completed_missions = {},
        completed_quests = {},
    }
    local entries = cached_entries(path)
    for _, entry in pairs(entries) do
        if entry.kind == "mission" then
            table.insert(lists.completed_missions, entry.id)
        elseif entry.kind == "quest" then
            table.insert(lists.completed_quests, entry.id)
        end
    end
    table.sort(lists.completed_missions)
    table.sort(lists.completed_quests)
    return lists
end

function progression_ledger.invalidate(path)
    entry_cache[tostring(path or progression_ledger.default_path)] = nil
end

-- ODD_FILE_WRITE: local manual guidance completion state only, under config/addons/oddq/progression/completed.txt.
-- ODD_SECURITY_NOTE: no movement, targeting, trading, packet mutation, outbound packet creation, or chat reading.
return progression_ledger
