Map.focus = {}

local applied = {
    focus = false,
    cursor = false,
    keepInput = false,
}

local function derive()
    local state = Map.state

    if state.fullscreen or (state.pauseMenu and state.pauseMenuSettled) then
        return true, true, false
    end

    if state.inspect then
        return true, true, true
    end

    return false, false, false
end

function Map.focus.apply()
    local focus, cursor, keepInput = derive()

    if focus == applied.focus
        and cursor == applied.cursor
        and keepInput == applied.keepInput
    then
        return
    end

    applied.focus = focus
    applied.cursor = cursor
    applied.keepInput = keepInput

    SetNuiFocus(focus, cursor)
    SetNuiFocusKeepInput(keepInput)

    Map.debug(('focus %s cursor %s keepInput %s'):format(
        tostring(focus),
        tostring(cursor),
        tostring(keepInput)
    ))
end

function Map.focus.release()
    applied.focus = false
    applied.cursor = false
    applied.keepInput = false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end
