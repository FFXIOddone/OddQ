local uberwarp_routes = {}

local cache = nil
local cache_index = nil

local function position(row)
    local x = tonumber(row.posx)
    local z = tonumber(row.posy)
    if x == nil or z == nil then return nil end
    return { x = x, y = tonumber(row.posz) or 0, z = z }
end

local function parse(path, method)
    local rows = {}
    local file = io.open(path, "r")
    if file == nil then return rows end
    for line in file:lines() do
        local fields = {}
        for key, value in line:gmatch('(%w+)="([^"]*)"') do fields[key] = value end
        local pos = position(fields)
        if fields.alias ~= nil and tonumber(fields.zone) ~= nil and pos ~= nil then
            rows[#rows + 1] = {
                method = method,
                alias = fields.alias,
                zone_id = tonumber(fields.zone),
                position = pos,
            }
        end
    end
    file:close()
    return rows
end

local function installed_entries()
    if cache ~= nil then return cache end
    cache = {}
    if AshitaCore == nil or AshitaCore.GetInstallPath == nil then return cache end
    local ok, root = pcall(function() return AshitaCore:GetInstallPath() end)
    if not ok or type(root) ~= "string" then return cache end
    root = root:gsub("\\", "/"):gsub("/$", "")
    for _, spec in ipairs({ { "hp", "homepoint.xml" }, { "sg", "survivalguide.xml" } }) do
        local rows = parse(root .. "/resources/ashitahelper/uberwarp/" .. spec[2], spec[1])
        for _, row in ipairs(rows) do cache[#cache + 1] = row end
    end
    return cache
end

local function distance(a, b)
    local dx, dz = b.x - a.x, b.z - a.z
    return math.sqrt((dx * dx) + (dz * dz))
end

local function command_alias(alias)
    return tostring(alias or ""):gsub("(%D)(%d+)$", "%1 %2")
end

local function display_name(row)
    local alias, number = tostring(row.alias):match("^(.-)(%d+)$")
    if row.method == "hp" then
        return (alias or row.alias) .. " HP #" .. (number or "1")
    end
    return tostring(row.alias) .. " Survival Guide"
end

local function route(source, destination, cost)
    return {
        cost = cost,
        source = source,
        destination = destination,
        source_label = display_name(source),
        destination_label = display_name(destination),
        command = "/uw " .. source.method .. " " .. command_alias(destination.alias),
    }
end

local function index_entries(entries)
    local index = { by_zone = {}, by_method = {}, by_method_zone = {} }
    for _, row in ipairs(entries) do
        local zone = tonumber(row.zone_id)
        local method = tostring(row.method or "")
        index.by_zone[zone] = index.by_zone[zone] or {}
        index.by_zone[zone][#index.by_zone[zone] + 1] = row
        index.by_method[method] = index.by_method[method] or {}
        index.by_method[method][#index.by_method[method] + 1] = row
        index.by_method_zone[method] = index.by_method_zone[method] or {}
        index.by_method_zone[method][zone] = index.by_method_zone[method][zone] or {}
        local rows = index.by_method_zone[method][zone]
        rows[#rows + 1] = row
    end
    return index
end

function uberwarp_routes.plan(current_zone, current_position, target_zone, target_position, entries)
    entries = entries or installed_entries()
    current_zone = tonumber(current_zone)
    target_zone = tonumber(target_zone)
    local index = nil
    if entries == cache then
        if cache_index == nil then cache_index = index_entries(entries) end
        index = cache_index
    else
        index = index_entries(entries)
    end

    local direct = nil
    for _, source in ipairs(index.by_zone[current_zone] or {}) do
        local destinations = (index.by_method_zone[source.method] or {})[target_zone] or {}
        for _, destination in ipairs(destinations) do
            local cost = distance(current_position, source.position) + distance(destination.position, target_position)
            if direct == nil or cost < direct.cost then
                direct = route(source, destination, cost)
            end
        end
    end
    if direct ~= nil then return direct end

    -- Uberwarp cannot change service types in one command. When the source zone
    -- only has an HP and the destination only has an SG (or vice versa), route
    -- through a zone that has both and return the first command. The pointer is
    -- rebuilt after every warp, so the next service leg is then selected.
    local bridge = nil
    for _, source in ipairs(index.by_zone[current_zone] or {}) do
        for _, first_destination in ipairs(index.by_method[source.method] or {}) do
            if first_destination ~= source then
                for _, bridge_source in ipairs(index.by_zone[first_destination.zone_id] or {}) do
                    if bridge_source.method ~= source.method then
                        local final_destinations =
                            (index.by_method_zone[bridge_source.method] or {})[target_zone] or {}
                        for _, final_destination in ipairs(final_destinations) do
                            local cost = distance(current_position, source.position)
                                + distance(first_destination.position, bridge_source.position)
                                + distance(final_destination.position, target_position)
                            if bridge == nil or cost < bridge.cost then
                                bridge = route(source, first_destination, cost)
                            end
                        end
                    end
                end
            end
        end
    end
    return bridge
end

return uberwarp_routes
