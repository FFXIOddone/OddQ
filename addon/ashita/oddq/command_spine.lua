local command_spine = {}

local DEFINITIONS = {
    { name = "open", handler = "open", aliases = { "open", "menu", "welcome" }, usage = "/odd", summary = "open the guide browser" },
    { name = "close", handler = "close", aliases = { "close" }, usage = "/odd close", summary = "Close OddQ." },
    { name = "cancel", handler = "cancel", aliases = { "cancel" }, usage = "/odd cancel", summary = "Cancel the active guide or temporary pointer and clear saved guide state." },
    { name = "back", handler = "back", aliases = { "back" }, usage = "/odd back", summary = "Return from the Guide display to the Browser." },
    { name = "status", handler = "status", aliases = { "status", "where", "current" }, usage = "/odd status", summary = "Print the current guide step." },
    { name = "next", handler = "next", aliases = { "next" }, usage = "/odd next", summary = "Advance one guide step or mission." },
    { name = "previous", handler = "previous", aliases = { "previous", "prev" }, usage = "/odd previous", summary = "Return one guide step or mission." },
    { name = "route", handler = "route", aliases = { "route", "route-mode" }, usage = "/odd route warp|no-warp", summary = "Choose guidance for the player's teleport unlocks." },
    { name = "pointer", handler = "pointer", aliases = { "pointer", "position", "pos", "coordinates", "coords", "xy", "grid" }, usage = "/odd pointer <X,Y|GRID>|clear", summary = "Set a temporary pointer to coordinates or a verified grid like (E-5) in the current zone." },
    { name = "warp-home", handler = "warp_home", aliases = { "warp-home" }, usage = "/odd warp-home", summary = "Use the recommended available Warp Home item." },
    { name = "help", handler = "help", aliases = { "help" }, usage = "/odd help", summary = "List durable OddQ text commands." },
    { name = "plan", handler = "plan", aliases = { "plan" }, usage = "/odd plan [category] [search]", summary = "Browse or load a guide with an optional category." },
    { name = "browse", handler = "browse", aliases = { "browse", "list", "catalog" }, usage = "/odd browse [category] [search]", summary = "Open a filtered guide catalog." },
    { name = "find", handler = "find", aliases = { "find", "search", "load", "go" }, usage = "/odd find <search>", summary = "Load the best matching local guide." },
    { name = "catseye", handler = "category", aliases = { "catseye" }, usage = "/odd catseye [search]", summary = "Browse CatsEyeXI quests.", category = "catseye", mode = "quests" },
    { name = "missions", handler = "category", aliases = { "missions", "mission", "m" }, usage = "/odd missions [search]", summary = "Browse or search missions.", category = "missions", mode = "missions" },
    { name = "jobs", handler = "category", aliases = { "jobs", "job", "j" }, usage = "/odd jobs [search]", summary = "Browse or search job-unlock guides.", category = "jobs", mode = "jobs" },
    { name = "quests", handler = "category", aliases = { "quests", "quest", "q" }, usage = "/odd quests [search]", summary = "Browse or search quests.", category = "quests", mode = "quests" },
    { name = "solo", handler = "category", aliases = { "solo", "exp", "camp", "camps", "trust", "trusts" }, usage = "/odd solo [search]", summary = "Browse solo and Trust EXP camps.", category = "exp_solo", mode = "exp" },
    { name = "6man", handler = "category", aliases = { "6man", "sixman", "party" }, usage = "/odd 6man [search]", summary = "Browse six-player EXP camps.", category = "exp_6man", mode = "exp" },
    { name = "mageburn", handler = "category", aliases = { "mageburn", "manaburn" }, usage = "/odd mageburn [search]", summary = "Browse mage-burn EXP camps.", category = "exp_mageburn", mode = "exp" },
    { name = "meleeburn", handler = "category", aliases = { "meleeburn", "petburn" }, usage = "/odd meleeburn [search]", summary = "Browse melee-burn EXP camps.", category = "exp_meleeburn", mode = "exp" },
    { name = "npcs", handler = "category", aliases = { "npcs", "npc", "finder" }, usage = "/odd npcs [search]", summary = "Browse or search NPC locations.", category = "npcs", mode = "npcs" },
    { name = "items", handler = "category", aliases = { "items", "item" }, usage = "/odd items [query]", summary = "Search source-backed item acquisition by name or numeric item ID.", category = "items", mode = "items" },
}

local BY_ALIAS = {}
for _, definition in ipairs(DEFINITIONS) do
    for _, alias in ipairs(definition.aliases) do
        if BY_ALIAS[alias] ~= nil then
            error("duplicate OddQ command alias: " .. alias)
        end
        BY_ALIAS[alias] = definition
    end
end

local function copy_values(values, start_index)
    local copied = {}
    for index = start_index or 1, #(values or {}) do
        copied[#copied + 1] = values[index]
    end
    return copied
end

function command_spine.commands()
    local copied = {}
    for index, definition in ipairs(DEFINITIONS) do
        copied[index] = definition
    end
    return copied
end

function command_spine.resolve(args)
    args = type(args) == "table" and args or {}
    local raw = tostring(args[1] or "")
    local command = raw:lower()
    local definition = command == "" and DEFINITIONS[1] or BY_ALIAS[command]
    if definition == nil then
        return {
            name = "search",
            handler = "search",
            args = copy_values(args, 1),
        }
    end
    return {
        name = definition.name,
        handler = definition.handler,
        args = copy_values(args, 2),
        category = definition.category,
        mode = definition.mode,
        usage = definition.usage,
        summary = definition.summary,
    }
end

function command_spine.help_lines()
    local lines = {
        "OddQ help",
        "/odd <search> - load the best matching local guide",
    }
    for _, definition in ipairs(DEFINITIONS) do
        lines[#lines + 1] = definition.usage .. " - " .. definition.summary
    end
    return lines
end

return command_spine
