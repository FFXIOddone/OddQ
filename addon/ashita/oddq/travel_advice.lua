local travel_advice = {}

local zone_names_loaded, zone_names = pcall(require, "data/zone_names")
if not zone_names_loaded then
    zone_names = {}
end

local pretty_zone_names = {
    [205] = "Ifrit's Cauldron",
    [243] = "Ru'Lude Gardens",
    [230] = "Southern San d'Oria",
    [231] = "Northern San d'Oria",
}

local fastest_paths = {
    [104] = "Warp Jeuno > HP to Ru'Lude Gardens > SG to Jugner Forest",
    [147] = "Warp Jeuno > HP to Ru'Lude Gardens > SG to Beadeaux",
    [149] = "Warp Jeuno > HP to Ru'Lude Gardens > SG to Davoi",
    [151] = "Warp Jeuno > HP to Ru'Lude Gardens > SG to Castle Oztroja",
    [152] = "Warp Jeuno > HP to Ru'Lude Gardens > SG to Castle Oztroja > zone to Altar Room",
    [205] = "Warp Jeuno > HP to Ru'Lude Gardens > SG to Ifrit's Cauldron",
    [230] = "Warp San d'Oria > HP to Southern San d'Oria",
    [231] = "Warp San d'Oria > HP to Northern San d'Oria",
    [243] = "Warp Jeuno > HP to Ru'Lude Gardens",
    [244] = "Warp Jeuno > HP to Upper Jeuno",
    [245] = "Warp Jeuno > HP to Lower Jeuno",
}

local function has_text(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

local function first_nonblank(...)
    for _, value in ipairs({ ... }) do
        if has_text(value) then
            return tostring(value)
        end
    end
    return ""
end

local function clean_zone_name(value)
    local text = tostring(value or "")
    text = text:gsub("dOria", "d'Oria")
    text = text:gsub("Ifrits", "Ifrit's")
    text = text:gsub("RuLude", "Ru'Lude")
    return text
end

function travel_advice.zone_name(zone_id)
    local normalized = tonumber(zone_id)
    if normalized ~= nil then
        return pretty_zone_names[normalized] or clean_zone_name(zone_names[normalized])
    end
    return clean_zone_name(zone_id)
end

local function target_zone_id(source)
    if type(source) ~= "table" then
        return nil
    end
    return tonumber(source.zone_id or source.destination_zone_id or source.target_zone_id)
end

local function target_map_label(source)
    if type(source) ~= "table" then
        return ""
    end
    return first_nonblank(
        source.target_map_label,
        source.target_map_name,
        source.destination_map_label,
        source.destination_map_name,
        source.map_label,
        source.map_name,
        source.map_floor
    )
end

local function map_grid(source)
    if type(source) ~= "table" then
        return ""
    end
    return first_nonblank(source.map_grid, source.destination_map_grid)
end

function travel_advice.path(source)
    local zone_id = target_zone_id(source)
    if zone_id ~= nil and fastest_paths[zone_id] ~= nil then
        return fastest_paths[zone_id]
    end

    local zone = travel_advice.zone_name(zone_id)
    if has_text(zone) then
        return "Use your fastest Home Point or Survival Guide to " .. zone
    end
    return ""
end

function travel_advice.summary(source)
    local path = travel_advice.path(source)
    if path == "" then
        return nil
    end

    local details = {}
    local zone = travel_advice.zone_name(target_zone_id(source))
    if has_text(zone) then
        table.insert(details, zone)
    end
    local map_label = target_map_label(source)
    if map_label ~= "" then
        table.insert(details, map_label)
    end
    local grid = map_grid(source)
    if grid ~= "" then
        table.insert(details, grid)
    end

    if #details > 0 then
        return "Travel: " .. path .. " (" .. table.concat(details, ", ") .. ")"
    end
    return "Travel: " .. path
end

return travel_advice
