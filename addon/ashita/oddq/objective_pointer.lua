local objective_pointer = {}

local SANDORIA_3_1_OBJECTIVE_ID = "catseyexi.mission.san_doria_3_1.start"
local SANDORIA_4_1_OBJECTIVE_ID = "catseyexi.mission.san_doria_4_1.start"

local function safe_text(value)
    if type(value) ~= "string" then
        return tostring(value or "")
    end
    return value
end

local function objective_key(objective)
    if type(objective) ~= "table" then
        return ""
    end

    local objective_id = safe_text(objective.objective_id)
    if objective_id ~= "" then
        return objective_id
    end
    local quest_id = safe_text(objective.quest_id)
    if quest_id ~= "" then
        return quest_id
    end
    return safe_text(objective.id):gsub("^objective:", "")
end

local function copy_position(position)
    if type(position) ~= "table" then
        return nil
    end

    local x = tonumber(position.x or position.X)
    local y = tonumber(position.y or position.Y) or 0
    local z = tonumber(position.z or position.Z)
    if x == nil or z == nil then
        return nil
    end

    return {
        x = x,
        y = y,
        z = z,
    }
end

local function location(id, label, zone_id, map_grid, position, radius, target_map_id, target_map_label)
    return {
        id = id,
        label = label,
        zone_id = zone_id,
        map_grid = map_grid or "",
        position = position,
        radius = radius or 8,
        target_map_id = target_map_id,
        target_map_label = target_map_label,
    }
end

local SANDORIA_3_1_LOCATIONS = {
    ambrotien = location(
        "npc:230:ambrotien",
        "Ambrotien gate guard",
        230,
        "K-10",
        { x = 93.419, y = 0.999, z = -57.347 },
        7
    ),
    grilau = location(
        "npc:231:grilau",
        "Grilau gate guard",
        231,
        "D-8",
        { x = -241.987, y = 7.999, z = 57.887 },
        7
    ),
    prince_room = location(
        "npc:233:door_prince_royal_s_rm",
        "Prince Trion / Door: Prince Royal's Rm",
        233,
        "G/H-7",
        { x = -38.0, y = -4.951, z = 75.444 },
        8
    ),
    davoi_entrance = location(
        "object:104:entrance_to_davoi",
        "Entrance to Davoi",
        104,
        "G-12",
        { x = 219.47, y = -4.47, z = 0.038 },
        10
    ),
    quemaricond = location(
        "npc:149:quemaricond",
        "Quemaricond",
        149,
        "H-7",
        { x = 20.629, y = -0.23, z = -22.917 },
        12
    ),
}

local SANDORIA_3_1_STEP_TARGETS = {
    [1] = {
        [230] = SANDORIA_3_1_LOCATIONS.ambrotien,
        [231] = SANDORIA_3_1_LOCATIONS.grilau,
        default = SANDORIA_3_1_LOCATIONS.ambrotien,
    },
    [2] = {
        [233] = SANDORIA_3_1_LOCATIONS.prince_room,
        default = SANDORIA_3_1_LOCATIONS.prince_room,
    },
    [3] = {
        [104] = SANDORIA_3_1_LOCATIONS.davoi_entrance,
        [149] = SANDORIA_3_1_LOCATIONS.quemaricond,
        default = SANDORIA_3_1_LOCATIONS.davoi_entrance,
    },
    [4] = {
        [149] = SANDORIA_3_1_LOCATIONS.quemaricond,
        default = SANDORIA_3_1_LOCATIONS.quemaricond,
    },
    [5] = {
        [233] = SANDORIA_3_1_LOCATIONS.prince_room,
        default = SANDORIA_3_1_LOCATIONS.prince_room,
    },
}

local SANDORIA_3_1_ZONE_TARGETS = {
    [230] = SANDORIA_3_1_LOCATIONS.ambrotien,
    [231] = SANDORIA_3_1_LOCATIONS.grilau,
    [233] = SANDORIA_3_1_LOCATIONS.prince_room,
    [104] = SANDORIA_3_1_LOCATIONS.davoi_entrance,
    [149] = SANDORIA_3_1_LOCATIONS.quemaricond,
}

local SANDORIA_4_1_LOCATIONS = {
    embassy_door = location(
        "npc:243:door_san_dorian_emb",
        "Nelcabrit / Ambassador's office door",
        243,
        "G-9",
        { x = -31.107, y = 7.501, z = -65.061 },
        7
    ),
    audience_chamber = location(
        "npc:243:door_audience_chamber",
        "Door: Audience Chamber",
        243,
        "H-6",
        { x = 0.0, y = -6.748, z = 71.001 },
        7
    ),
    aldo = location(
        "npc:245:aldo",
        "Aldo",
        245,
        "J-8",
        { x = 21.049, y = 3.899, z = -61.53 },
        7
    ),
    paya_sabya = location(
        "npc:244:paya_sabya",
        "Paya-Sabya",
        244,
        "I-8",
        { x = 11.809, y = 1.999, z = 70.987 },
        7
    ),
    muckvix = location(
        "npc:245:muckvix",
        "Muckvix",
        245,
        "H-9",
        { x = -26.824, y = 4.601, z = -137.082 },
        7
    ),
    baudin = location(
        "npc:244:baudin",
        "Baudin",
        244,
        "G-7",
        { x = -76.415, y = -1.199, z = 80.011 },
        7
    ),
    sattal_mansal = location(
        "npc:245:sattal_mansal",
        "Sattal-Mansal",
        245,
        "J-8",
        { x = 41.154, y = 3.899, z = -53.971 },
        7
    ),
    devyu = location(
        "mob:147:de_vyu_headhunter",
        "De'Vyu Headhunter",
        147,
        "I-9",
        { x = 33.747, y = -3.486, z = -130.112 },
        18,
        nil,
        "Beadeaux elevated path"
    ),
    gobhu = location(
        "mob:147:go_bhu_gascon",
        "Go'Bhu Gascon",
        147,
        "F-6",
        { x = -202.0, y = -2.0, z = 110.0 },
        18,
        nil,
        "Beadeaux elevated path"
    ),
    wall_of_dark_arts = location(
        "npc:149:wall_of_dark_arts",
        "Wall of Dark Arts",
        149,
        "G-7",
        { x = -22.924, y = -1.336, z = -69.892 },
        9
    ),
    monastic_entrance = location(
        "object:149:entrance_to_monastic_cavern",
        "Entrance to Monastic Cavern",
        149,
        "G-7",
        { x = -40.076, y = -19.404, z = -100.113 },
        10
    ),
    altar_room_entrance = location(
        "object:151:entrance_to_altar_room",
        "Entrance to Altar Room",
        151,
        "G-10",
        { x = -244.926, y = 10.383, z = -100.0 },
        10,
        2,
        "Map 2"
    ),
    altar_room_magicite = location(
        "object:152:magicite_orastone",
        "Magicite: Orastone",
        152,
        "G-8",
        nil,
        8,
        nil,
        "Altar Room"
    ),
    qulun_dome_entrance = location(
        "object:147:entrance_to_qulun_dome",
        "Entrance to Qulun Dome",
        147,
        "I-7",
        { x = -0.012, y = 20.602, z = 60.009 },
        10,
        2,
        "Map 2"
    ),
    qulun_dome_magicite = location(
        "object:148:magicite_aurastone",
        "Magicite: Aurastone",
        148,
        "F-8",
        nil,
        8,
        nil,
        "Qulun Dome"
    ),
    nelcabrit = location(
        "npc:243:nelcabrit",
        "Nelcabrit",
        243,
        "H-9",
        { x = -35.644, y = 8.999, z = -49.738 },
        7
    ),
}

local SANDORIA_4_1_STEP_TARGETS = {
    [1] = {
        [243] = SANDORIA_4_1_LOCATIONS.embassy_door,
        default = SANDORIA_4_1_LOCATIONS.embassy_door,
    },
    [2] = {
        [243] = SANDORIA_4_1_LOCATIONS.audience_chamber,
        default = SANDORIA_4_1_LOCATIONS.audience_chamber,
    },
    [3] = {
        [245] = SANDORIA_4_1_LOCATIONS.aldo,
        default = SANDORIA_4_1_LOCATIONS.aldo,
    },
    [5] = {
        [147] = { SANDORIA_4_1_LOCATIONS.devyu, SANDORIA_4_1_LOCATIONS.gobhu },
        default = SANDORIA_4_1_LOCATIONS.devyu,
    },
    [6] = {
        [244] = SANDORIA_4_1_LOCATIONS.baudin,
        default = SANDORIA_4_1_LOCATIONS.baudin,
    },
    [7] = {
        [244] = SANDORIA_4_1_LOCATIONS.paya_sabya,
        [245] = SANDORIA_4_1_LOCATIONS.muckvix,
        default = SANDORIA_4_1_LOCATIONS.paya_sabya,
    },
    [8] = {
        [245] = SANDORIA_4_1_LOCATIONS.sattal_mansal,
        default = SANDORIA_4_1_LOCATIONS.sattal_mansal,
    },
    [9] = {
        [149] = SANDORIA_4_1_LOCATIONS.wall_of_dark_arts,
        default = SANDORIA_4_1_LOCATIONS.wall_of_dark_arts,
    },
    [10] = {
        [147] = SANDORIA_4_1_LOCATIONS.qulun_dome_entrance,
        [148] = SANDORIA_4_1_LOCATIONS.qulun_dome_magicite,
        default = SANDORIA_4_1_LOCATIONS.qulun_dome_entrance,
    },
    [11] = {
        [151] = SANDORIA_4_1_LOCATIONS.altar_room_entrance,
        [152] = SANDORIA_4_1_LOCATIONS.altar_room_magicite,
        default = SANDORIA_4_1_LOCATIONS.altar_room_entrance,
    },
    [12] = {
        [243] = SANDORIA_4_1_LOCATIONS.audience_chamber,
        default = SANDORIA_4_1_LOCATIONS.audience_chamber,
    },
    [13] = {
        [243] = SANDORIA_4_1_LOCATIONS.nelcabrit,
        default = SANDORIA_4_1_LOCATIONS.nelcabrit,
    },
}

local SANDORIA_4_1_ZONE_TARGETS = {
    [243] = SANDORIA_4_1_LOCATIONS.embassy_door,
    [244] = SANDORIA_4_1_LOCATIONS.paya_sabya,
    [245] = SANDORIA_4_1_LOCATIONS.aldo,
    [147] = SANDORIA_4_1_LOCATIONS.devyu,
    [149] = SANDORIA_4_1_LOCATIONS.wall_of_dark_arts,
    [151] = SANDORIA_4_1_LOCATIONS.altar_room_entrance,
    [152] = SANDORIA_4_1_LOCATIONS.altar_room_magicite,
}

local function selected_step_index(objective, guidance)
    local selected = tonumber((guidance or {}).guide_step_tab_index)
    if selected == nil or selected <= 0 then
        return nil
    end

    local step_count = 0
    if type((objective or {}).steps) == "table" then
        step_count = #objective.steps
    end
    if step_count > 0 and selected > step_count then
        return nil
    end
    return math.floor(selected)
end

local function current_zone_id(live_context)
    local live = live_context or {}
    return tonumber(live.current_zone_id or live.zone_id or live.zone)
end

local function current_position(live_context)
    return copy_position((live_context or {}).current_position or (live_context or {}).position)
end

local resolve_candidate

local function trim(value)
    return safe_text(value):gsub("^%s+", ""):gsub("%s+$", "")
end

local function first_nonblank(...)
    for _, value in ipairs({ ... }) do
        local text = trim(value)
        if text ~= "" then
            return text
        end
    end
    return ""
end

local function positive_zone_id(value)
    local zone_id = tonumber(value)
    if zone_id ~= nil and zone_id > 0 then
        return zone_id
    end
    return nil
end

local function normalize_text(value)
    local text = safe_text(value):lower():gsub("\\", ""):gsub("'", "")
    text = text:gsub("[^a-z0-9]+", " ")
    return trim(text)
end

local target_index_ready = false
local target_index_by_zone = {}
local target_index_any_zone = {}

local function add_indexed_target(bucket, key, target)
    if key == "" then
        return
    end
    local entries = bucket[key]
    if entries == nil then
        entries = {}
        bucket[key] = entries
    end
    entries[#entries + 1] = target
end

local function ensure_target_index()
    if target_index_ready == true then
        return
    end
    target_index_ready = true

    local loaded, targets = pcall(require, "data/" .. "targets")
    if not loaded or type(targets) ~= "table" then
        return
    end

    for _, target in ipairs(targets) do
        local key = normalize_text(target.name)
        local zone_id = positive_zone_id(target.zone_id)
        add_indexed_target(target_index_any_zone, key, target)
        if zone_id ~= nil then
            local zone_bucket = target_index_by_zone[zone_id]
            if zone_bucket == nil then
                zone_bucket = {}
                target_index_by_zone[zone_id] = zone_bucket
            end
            add_indexed_target(zone_bucket, key, target)
        end
    end
end

local function indexed_targets_for_name(name, zone_id)
    ensure_target_index()
    local key = normalize_text(name)
    if key == "" then
        return nil
    end

    local zone_bucket = zone_id ~= nil and target_index_by_zone[zone_id] or nil
    if zone_bucket ~= nil and zone_bucket[key] ~= nil then
        return zone_bucket[key]
    end
    return target_index_any_zone[key]
end

local function overlay_target(row, step, label)
    if type(row) ~= "table" then
        return nil
    end
    local zone_id = positive_zone_id(row.zone_id) or positive_zone_id((step or {}).zone_id)
    local map_grid = first_nonblank((step or {}).map_grid, row.map_grid)
    return location(
        row.id or ("target:" .. normalize_text(label or row.name)),
        first_nonblank(label, row.name),
        zone_id,
        map_grid,
        row.position,
        tonumber((step or {}).arrival_radius) or 8,
        (step or {}).target_map_id,
        (step or {}).target_map_label
    )
end

local function target_from_index(name, step, zone_id, live_context)
    local live_zone = current_zone_id(live_context)
    local targets = nil
    if zone_id ~= nil then
        targets = indexed_targets_for_name(name, zone_id)
    end
    if targets == nil and live_zone ~= nil then
        targets = indexed_targets_for_name(name, live_zone)
    end
    if targets == nil then
        targets = indexed_targets_for_name(name, nil)
    end

    return overlay_target(resolve_candidate(targets, live_context), step, name)
end

local function checkpoint_from_step(name, step)
    local zone_id = positive_zone_id((step or {}).zone_id)
    local map_grid = first_nonblank((step or {}).map_grid)
    if name == "" or (zone_id == nil and map_grid == "") then
        return nil
    end
    return location(
        "checkpoint:" .. normalize_text(name),
        name,
        zone_id,
        map_grid,
        nil,
        tonumber((step or {}).arrival_radius) or 8,
        (step or {}).target_map_id,
        (step or {}).target_map_label
    )
end

local function split_target_names(value)
    local names = {}
    local text = safe_text(value)
    if text == "" then
        return names
    end
    for part in string.gmatch(text, "[^/]+") do
        local name = trim(part)
        if name ~= "" then
            names[#names + 1] = name
        end
    end
    return names
end

local function step_target_names(step)
    local names = {}
    local fields = { "object_name", "npc_name", "mob_name", "target_name" }
    for _, field in ipairs(fields) do
        for _, name in ipairs(split_target_names((step or {})[field])) do
            names[#names + 1] = name
        end
    end
    return names
end

local function target_from_choice(choice, step, live_context)
    if type(choice) ~= "table" then
        return nil
    end
    local name = first_nonblank(choice.npc_name, choice.object_name, choice.mob_name, choice.target_name)
    local choice_step = {
        zone_id = choice.zone_id,
        map_grid = choice.map_grid,
        target_map_id = step and step.target_map_id,
        target_map_label = step and step.target_map_label,
    }
    return target_from_index(name, choice_step, positive_zone_id(choice.zone_id), live_context)
        or checkpoint_from_step(name, choice_step)
end

local function target_from_choices(step, live_context)
    local choices = (step or {}).choices
    if type(choices) ~= "table" or #choices == 0 then
        return nil
    end

    local live_zone = current_zone_id(live_context)
    if live_zone ~= nil then
        for _, choice in ipairs(choices) do
            if positive_zone_id(choice.zone_id) == live_zone then
                return target_from_choice(choice, step, live_context)
            end
        end
    end
    return target_from_choice(choices[1], step, live_context)
end

local function target_from_step(step, live_context)
    if type(step) ~= "table" then
        return nil
    end

    local choice_target = target_from_choices(step, live_context)
    if choice_target ~= nil then
        return choice_target
    end

    local zone_id = positive_zone_id(step.zone_id)
    for _, name in ipairs(step_target_names(step)) do
        local target = target_from_index(name, step, zone_id, live_context)
        if target ~= nil then
            return target
        end
        target = checkpoint_from_step(name, step)
        if target ~= nil then
            return target
        end
    end
    return nil
end

local function selected_or_nearest_step(objective, guidance, live_context)
    local step_index = selected_step_index(objective, guidance)
    local steps = (objective or {}).steps
    if type(steps) ~= "table" or #steps == 0 then
        return nil
    end
    if step_index ~= nil then
        return steps[step_index], step_index
    end

    local live_zone = current_zone_id(live_context)
    if live_zone ~= nil then
        for index, step in ipairs(steps) do
            if positive_zone_id(step.zone_id) == live_zone then
                return step, index
            end
            for _, choice in ipairs(step.choices or {}) do
                if positive_zone_id(choice.zone_id) == live_zone then
                    return step, index
                end
            end
        end
    end

    for index, step in ipairs(steps) do
        if target_from_step(step, live_context) ~= nil then
            return step, index
        end
    end
    return nil
end

local function distance_sq(position, target)
    local target_position = copy_position((target or {}).position)
    if position == nil or target_position == nil then
        return nil
    end
    local dx = position.x - target_position.x
    local dz = position.z - target_position.z
    return (dx * dx) + (dz * dz)
end

local function nearest_target(live_context, targets)
    if type(targets) ~= "table" or #targets == 0 then
        return nil
    end
    local position = current_position(live_context)
    local best = targets[1]
    local best_distance = distance_sq(position, best)
    for index = 2, #targets do
        local candidate = targets[index]
        local candidate_distance = distance_sq(position, candidate)
        if candidate_distance ~= nil and (best_distance == nil or candidate_distance < best_distance) then
            best = candidate
            best_distance = candidate_distance
        end
    end
    return best
end

function resolve_candidate(candidate, live_context)
    if type(candidate) ~= "table" then
        return nil
    end
    if candidate.id ~= nil then
        return candidate
    end
    return nearest_target(live_context, candidate)
end

local function target_for_step(step_targets, step_index, zone_id, live_context)
    local candidates = step_targets[step_index]
    if type(candidates) ~= "table" then
        return nil
    end
    return resolve_candidate(candidates[zone_id], live_context) or resolve_candidate(candidates.default, live_context)
end

local function target_for_sandoria_3_1(objective, guidance, live_context)
    local zone_id = current_zone_id(live_context)
    local step_index = selected_step_index(objective, guidance)
    if step_index ~= nil then
        return target_for_step(SANDORIA_3_1_STEP_TARGETS, step_index, zone_id, live_context)
    end

    return SANDORIA_3_1_ZONE_TARGETS[zone_id] or SANDORIA_3_1_LOCATIONS.ambrotien
end

local function target_for_sandoria_4_1(objective, guidance, live_context)
    local zone_id = current_zone_id(live_context)
    local step_index = selected_step_index(objective, guidance)
    if step_index ~= nil then
        return target_for_step(SANDORIA_4_1_STEP_TARGETS, step_index, zone_id, live_context)
    end

    return SANDORIA_4_1_ZONE_TARGETS[zone_id] or SANDORIA_4_1_LOCATIONS.embassy_door
end

local function is_sandoria_mission(objective)
    if type(objective) ~= "table" then
        return false
    end
    if objective.mission_line == "San d'Oria Missions" then
        return true
    end
    return objective_key(objective):match("^catseyexi%.mission%.san_doria_%d+_%d+%.start$") ~= nil
end

local function target_for_sandoria_generic(objective, guidance, live_context)
    local step = selected_or_nearest_step(objective, guidance, live_context)
    return target_from_step(step, live_context)
end

local function build_route_for_target(objective, target)
    local position = copy_position((target or {}).position)
    if type(target) ~= "table" then
        return nil
    end

    local key = objective_key(objective)
    local segment = {
        type = "walk",
        zone_id = target.zone_id,
        from = "current_position",
        to = target.id,
        destination_label = target.label,
        map_grid = target.map_grid,
        target_map_id = target.target_map_id,
        target_map_label = target.target_map_label,
        arrival_radius = target.radius,
        source = "static_objective_pointer",
    }
    if position ~= nil then
        segment.target_position = position
    end

    return {
        route_id = "objective_pointer:" .. key .. ":" .. tostring(target.id),
        locked = true,
        pointer = true,
        arrival_radius_floor = 4,
        off_route_distance = 250,
        segments = { segment },
        signature = "local-static-objective-pointer:" .. key,
    }
end

function objective_pointer.supports(objective)
    local key = objective_key(objective)
    return key == SANDORIA_3_1_OBJECTIVE_ID
        or key == SANDORIA_4_1_OBJECTIVE_ID
        or is_sandoria_mission(objective)
end

function objective_pointer.build_route(objective, guidance, live_context)
    if not objective_pointer.supports(objective) then
        return nil
    end

    local key = objective_key(objective)
    if key == SANDORIA_4_1_OBJECTIVE_ID then
        return build_route_for_target(objective, target_for_sandoria_4_1(objective, guidance, live_context))
    end
    if key == SANDORIA_3_1_OBJECTIVE_ID then
        return build_route_for_target(objective, target_for_sandoria_3_1(objective, guidance, live_context))
    end

    return build_route_for_target(objective, target_for_sandoria_generic(objective, guidance, live_context))
end

return objective_pointer
