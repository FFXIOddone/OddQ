local window_state = {}

function window_state.begin(imgui, title, is_open, flags)
    local open = { is_open == true }
    local visible = imgui.Begin(title, open, flags or 0)
    return visible == true, open[1] == true
end

return window_state
