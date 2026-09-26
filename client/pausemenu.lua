Map.pauseMenu = {}

local CONTROL_PAUSE = 200

local NATIVE_MENU = 'FE_MENU_VERSION_LANDING_MENU'

local LOOK_CONTROLS = {
    1,
    2,
}

local NATIVE_MENU_GIVE_UP_MS = 2000

local NATIVE_MENU_POLL_MS = 100

local nativeMenuGeneration = 0

local reopenAfterNativeMenu = false

local function isNativeMenuUp()
    return IsPauseMenuActive() or GetPauseMenuState() ~= 0
end

local function holdMinimapForNativeMenu()
    nativeMenuGeneration = nativeMenuGeneration + 1

    local generation = nativeMenuGeneration

    Map.surface.setNativeMenuActive(true)

    CreateThread(function()
        local startedAt = GetGameTimer()
        local seenUp = false

        while nativeMenuGeneration == generation do
            Wait(NATIVE_MENU_POLL_MS)

            if isNativeMenuUp() then
                seenUp = true
            elseif seenUp
                or GetGameTimer() - startedAt >= NATIVE_MENU_GIVE_UP_MS
            then
                break
            end
        end

        if nativeMenuGeneration == generation then
            if reopenAfterNativeMenu then
                reopenAfterNativeMenu = false

                Map.pauseMenu.open()
            end

            Map.surface.setNativeMenuActive(false)
        end
    end)
end

local openGeneration = 0

local function armFocusFallback(generation)
    CreateThread(function()
        Wait(Map.config.pauseMenuFocusTimeoutMs)

        if generation ~= openGeneration
            or not Map.state.pauseMenu
            or Map.state.pauseMenuSettled
        then
            return
        end

        Map.log(('the page did not report the pause menu settling within ' ..
            '%d ms; taking focus anyway'):format(
                Map.config.pauseMenuFocusTimeoutMs
            ))

        Map.setState('pauseMenuSettled', true)
    end)
end

RegisterNUICallback('map:pauseMenuSettled', function(_, cb)
    if Map.state.pauseMenu then
        Map.setState('pauseMenuSettled', true)
    end

    cb({})
end)

local function setOpen(open)
    if Map.state.pauseMenu == open then
        return
    end

    openGeneration = openGeneration + 1

    if open then
        Map.setState('pauseMenuSettled', false)

        Map.player.sendNow()
    end

    Map.setState('pauseMenu', open)

    if open then
        armFocusFallback(openGeneration)
    end

    Map.send({
        type = 'map:pauseMenu',
        open = open,
    })
end

function Map.pauseMenu.open()
    if not Map.state.playerLoaded then
        return
    end

    setOpen(true)
end

function Map.pauseMenu.close()
    setOpen(false)
end

function Map.pauseMenu.toggle()
    setOpen(not Map.state.pauseMenu)
end

Map.onReplay(function()
    Map.send({
        type = 'map:pauseMenu',
        open = Map.state.pauseMenu,
    })
end)

RegisterNUICallback('map:settingsRequested', function(_, cb)
    reopenAfterNativeMenu = true

    holdMinimapForNativeMenu()

    Map.pauseMenu.close()

    Wait(0)

    ActivateFrontendMenu(GetHashKey(NATIVE_MENU), false, -1)

    cb({})
end)

RegisterNUICallback('map:quitRequested', function(data, cb)
    local action = type(data) == 'table' and data.action or nil

    cb({})

    if action == 'leaveServer' then
        Map.log('leaving the server at the player\'s request')
        ExecuteCommand('disconnect')
    else
        Map.debug(('map:quitRequested ignored: unknown action %s')
            :format(tostring(action)))
    end
end)

CreateThread(function()
    while true do
        if Map.state.ready and Map.state.playerLoaded then
            if not Map.state.nativeMenu and isNativeMenuUp() then
                holdMinimapForNativeMenu()
            end

            if not Map.state.nativeMenu then
                DisableFrontendThisFrame()

                if not Map.state.pauseMenu
                    and IsControlJustPressed(0, CONTROL_PAUSE)
                then
                    Map.pauseMenu.open()
                end
            end

            if Map.state.pauseMenu and not Map.state.pauseMenuSettled then
                for index = 1, #LOOK_CONTROLS do
                    DisableControlAction(0, LOOK_CONTROLS[index], true)
                end
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)
