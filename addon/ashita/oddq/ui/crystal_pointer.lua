local crystal_pointer = {}

local mesh = require("data/hp_crystal_model")

local MODEL_SCALE = 24.0
local CAMERA_DISTANCE = 120.0
local MAX_DEPTH_TILT = 0.94
local LIGHT = { x = -0.34, y = -0.46, z = 0.82 }

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function cross(a, b)
    return {
        x = (a.y * b.z) - (a.z * b.y),
        y = (a.z * b.x) - (a.x * b.z),
        z = (a.x * b.y) - (a.y * b.x),
    }
end

local function subtract(a, b)
    return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

local function normalized(value)
    local length = math.sqrt((value.x * value.x) + (value.y * value.y) + (value.z * value.z))
    if length <= 0.000001 then return { x = 0, y = 0, z = 1 } end
    return { x = value.x / length, y = value.y / length, z = value.z / length }
end

local function mix(left, right, amount)
    return left + ((right - left) * amount)
end

local function face_color(normal, refracted)
    local diffuse = math.max(0, (normal.x * LIGHT.x) + (normal.y * LIGHT.y) + (normal.z * LIGHT.z))
    local facing = math.abs(normal.z)
    local bend = clamp(math.abs((normal.x * 0.79) + (normal.y * 0.61)), 0, 1)
    if refracted then
        return {
            0.05 + (bend * 0.10),
            0.62 + (bend * 0.24),
            0.92 + (facing * 0.08),
            0.26 + (facing * 0.12),
        }
    end
    local response = clamp((diffuse * 0.55) + (facing * 0.25) + (bend * 0.20), 0, 1)
    local hue = 0.12 + (response * 0.76)
    local specular = diffuse ^ 8
    return {
        clamp(mix(0.03, 0.34, hue) + (specular * 0.55), 0, 1),
        clamp(mix(0.42, 0.94, hue) + (specular * 0.18), 0, 1),
        clamp(mix(0.82, 1.00, hue) + (specular * 0.08), 0, 1),
        0.72 + (facing * 0.16),
    }
end

local function destination_direction(cue)
    local source = (cue or {}).pointer_vector_3d
    if type(source) ~= "table" then
        local screen = (cue or {}).pointer_vector or { x = 0, y = -1 }
        source = { x = screen.x, y = 0, z = -screen.y }
    end

    -- Cue Y is positive for a target above the player, while projected screen
    -- Y is positive downward. Camera Z is positive toward the viewer: an
    -- ahead target therefore brings the crystal's bottom tip toward us.
    local direction = normalized({
        x = tonumber(source.x) or 0,
        y = -(tonumber(source.y) or 0),
        z = tonumber(source.z) or 0,
    })
    local vertical = clamp(direction.y, -MAX_DEPTH_TILT, MAX_DEPTH_TILT)
    local horizontal_length = math.sqrt((direction.x * direction.x) + (direction.z * direction.z))
    local horizontal_scale = math.sqrt(math.max(0, 1 - (vertical * vertical)))
    if horizontal_length <= 0.000001 then
        return { x = 0, y = vertical, z = horizontal_scale }
    end
    return {
        x = (direction.x / horizontal_length) * horizontal_scale,
        y = vertical,
        z = (direction.z / horizontal_length) * horizontal_scale,
    }
end

local function direction_basis(cue)
    local destination = destination_direction(cue)
    local camera_up = { x = 0, y = -1, z = 0 }
    local right = cross(destination, camera_up)
    local right_length = math.sqrt((right.x * right.x) + (right.y * right.y) + (right.z * right.z))
    if right_length <= 0.000001 then
        right = { x = 1, y = 0, z = 0 }
    else
        right = normalized(right)
    end

    -- The model's long bottom point is local -Y. Map -Y to the full
    -- camera-space destination vector, then derive the remaining orthonormal
    -- axes so rotation never stretches or mirrors the crystal.
    local axis = { x = -destination.x, y = -destination.y, z = -destination.z }
    local depth = normalized(cross(right, axis))
    return right, axis, depth
end

function crystal_pointer.project(cue, center)
    center = center or { 34, 34 }
    local right, axis, depth = direction_basis(cue)
    local transformed = {}
    local projected = {}
    local vertex_depths = {}
    local minimum_depth, maximum_depth = nil, nil
    for index, vertex in ipairs(mesh.vertices) do
        local point = {
            x = ((vertex.x * right.x) + (vertex.y * axis.x) + (vertex.z * depth.x)) * MODEL_SCALE,
            y = ((vertex.x * right.y) + (vertex.y * axis.y) + (vertex.z * depth.y)) * MODEL_SCALE,
            z = ((vertex.x * right.z) + (vertex.y * axis.z) + (vertex.z * depth.z)) * MODEL_SCALE,
        }
        transformed[index] = point
        vertex_depths[index] = point.z
        minimum_depth = minimum_depth == nil and point.z or math.min(minimum_depth, point.z)
        maximum_depth = maximum_depth == nil and point.z or math.max(maximum_depth, point.z)
        local perspective = CAMERA_DISTANCE / math.max(24.0, CAMERA_DISTANCE - point.z)
        projected[index] = {
            center[1] + (point.x * perspective),
            center[2] + (point.y * perspective),
        }
    end

    local faces = {}
    for face_index, face in ipairs(mesh.faces) do
        local a, b, c = transformed[face[1]], transformed[face[2]], transformed[face[3]]
        -- Screen Y points downward, so reverse the cross-product order to
        -- recover the mesh's outward camera-space normal for optical shading.
        local normal = normalized(cross(subtract(c, a), subtract(b, a)))
        local refracted = normal.z <= 0.000001
        faces[#faces + 1] = {
            points = { projected[face[1]], projected[face[2]], projected[face[3]] },
            color = face_color(normal, refracted),
            depth = (a.z + b.z + c.z) / 3,
            source_index = face_index,
            refracted = refracted,
        }
    end
    table.sort(faces, function(left, right_face)
        if left.depth == right_face.depth then
            return left.source_index < right_face.source_index
        end
        return left.depth < right_face.depth
    end)
    return {
        faces = faces,
        vertices = projected,
        camera_vertices = transformed,
        vertex_depths = vertex_depths,
        tip = projected[#projected],
        tail = projected[1],
        minimum_depth = minimum_depth or 0,
        maximum_depth = maximum_depth or 0,
    }
end

function crystal_pointer.draw(imgui, draw, center, cue)
    if draw == nil or draw.AddTriangleFilled == nil then return false end
    local state = crystal_pointer.project(cue, center)
    for _, face in ipairs(state.faces) do
        draw:AddTriangleFilled(
            face.points[1],
            face.points[2],
            face.points[3],
            imgui.GetColorU32 and imgui.GetColorU32(face.color) or face.color
        )
    end
    return true
end

return crystal_pointer
