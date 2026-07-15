local local_filesystem = {}

local function filesystem_api()
    if ashita == nil or ashita.fs == nil then
        return nil
    end
    if type(ashita.fs.create_directory) ~= "function" then
        return nil
    end
    return ashita.fs
end

function local_filesystem.ensure_directory(path)
    local directory = tostring(path or "")
    if directory == "" or directory:find("\0", 1, true) ~= nil then
        return false, "invalid directory path"
    end

    local fs = filesystem_api()
    if fs == nil then
        return false, "Ashita filesystem API unavailable"
    end

    if type(fs.exists) == "function" then
        local exists_ok, exists = pcall(fs.exists, directory)
        if exists_ok and exists then
            return true, nil
        end
    end

    local create_ok, created = pcall(fs.create_directory, directory)
    if not create_ok or created == false then
        return false, "Ashita could not create directory"
    end
    return true, nil
end

function local_filesystem.ensure_parent(path)
    local directory = tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
    if directory == nil or directory == "" then
        return true, nil
    end
    return local_filesystem.ensure_directory(directory)
end

return local_filesystem
