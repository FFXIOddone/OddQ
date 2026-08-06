local warp_home = {}

local SERVER_TIMESTAMP_OFFSET = 1009792800
local INVENTORY_CONTAINER = 0

local choices = {
    { names = { "Instant Warp", "Scroll of Instant Warp" }, command_name = "Instant Warp", consumable = true },
    { names = { "Warp Ring" }, command_name = "Warp Ring", equip_delay = 10 },
    { names = { "Dcl.Grd. Ring", "Ducal Guard's ring" }, command_name = "Dcl.Grd. Ring", equip_delay = 30 },
}

local function safe_call(callback)
    local ok, value = pcall(callback)
    return ok and value or nil
end

local function text(value)
    return tostring(value or "")
end

local function item_name(resource)
    return text(resource and (resource.Name or resource.name or resource.LogName or resource.log_name))
end

local function little_u32(extra, first)
    if extra == nil then return nil end
    local function byte(index)
        if type(extra) == "string" then return extra:byte(index) end
        return tonumber(extra[index])
    end
    local a, b, c, d = byte(first), byte(first + 1), byte(first + 2), byte(first + 3)
    if a == nil or b == nil or c == nil or d == nil then return nil end
    return a + (b * 256) + (c * 65536) + (d * 16777216)
end

local function seconds_remaining(item, now)
    local extra = item and (item.Extra or item.extra)
    local next_use = little_u32(extra, 5)
    if next_use == nil then return nil end
    return math.max(0, (next_use + SERVER_TIMESTAMP_OFFSET) - now)
end

local function inventory_rows()
    local memory = AshitaCore ~= nil and AshitaCore.GetMemoryManager ~= nil
        and safe_call(function() return AshitaCore:GetMemoryManager() end) or nil
    local inventory = memory ~= nil and memory.GetInventory ~= nil
        and safe_call(function() return memory:GetInventory() end) or nil
    local resources = AshitaCore ~= nil and AshitaCore.GetResourceManager ~= nil
        and safe_call(function() return AshitaCore:GetResourceManager() end) or nil
    if inventory == nil or resources == nil then return {} end
    local maximum = tonumber(safe_call(function()
        return inventory:GetContainerCountMax(INVENTORY_CONTAINER)
    end)) or 0
    local rows = {}
    for index = 1, maximum do
        local item = safe_call(function()
            return inventory:GetContainerItem(INVENTORY_CONTAINER, index)
        end)
        local item_id = tonumber(item and (item.Id or item.id)) or 0
        if item_id > 0 then
            local resource = safe_call(function() return resources:GetItemById(item_id) end)
            rows[#rows + 1] = { item = item, name = item_name(resource) }
        end
    end
    return rows
end

local function matching_row(rows, names)
    for _, row in ipairs(rows) do
        local normalized_row = row.name:lower():gsub("[^%w]", "")
        for _, wanted in ipairs(names) do
            if normalized_row == wanted:lower():gsub("[^%w]", "") then return row end
        end
    end
    return nil
end

function warp_home.select(rows, now)
    rows = rows or inventory_rows()
    now = tonumber(now) or os.time()
    for _, choice in ipairs(choices) do
        local row = matching_row(rows, choice.names)
        if row ~= nil then
            if choice.consumable then
                return {
                    label = "Instant Warp",
                    commands = { '/item "' .. choice.command_name .. '" <me>' },
                }
            end
            local remaining = seconds_remaining(row.item, now)
            if remaining ~= nil and remaining <= choice.equip_delay then
                return {
                    label = choice.command_name == "Warp Ring" and "Warp Ring" or "Ducal Warp",
                    commands = {
                        '/equip ring2 "' .. choice.command_name .. '"',
                        '/wait ' .. tostring(choice.equip_delay),
                        '/item "' .. choice.command_name .. '" <me>',
                    },
                }
            end
        end
    end
    return nil
end

function warp_home.current_action()
    return warp_home.select()
end

return warp_home
