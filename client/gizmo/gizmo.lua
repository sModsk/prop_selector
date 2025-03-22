-- CREDITS
-- Andyyy7666: https://github.com/overextended/ox_lib/pull/453
-- AvarianKnight: https://forum.cfx.re/t/allow-drawgizmo-to-be-used-outside-of-fxdk/5091845/8?u=demi-automatic
-- DemiAutomatic: https://github.com/DemiAutomatic/object_gizmo

local dataview = GetDataView()
local enableScale = false -- allow scaling mode. doesnt scale collisions and resets when physics are applied it seems

local gizmoEnabled = false
local currentEntity
local startPosition
local startRotation

-- FUNCTIONS

local function normalize(x, y, z)
    local length = math.sqrt(x * x + y * y + z * z)
    if length == 0 then
        return 0, 0, 0
    end
    return x / length, y / length, z / length
end

local function makeEntityMatrix(entity)
    local f, r, u, a = GetEntityMatrix(entity)
    local view = dataview.ArrayBuffer(60)

    view:SetFloat32(0, r[1])
        :SetFloat32(4, r[2])
        :SetFloat32(8, r[3])
        :SetFloat32(12, 0)
        :SetFloat32(16, f[1])
        :SetFloat32(20, f[2])
        :SetFloat32(24, f[3])
        :SetFloat32(28, 0)
        :SetFloat32(32, u[1])
        :SetFloat32(36, u[2])
        :SetFloat32(40, u[3])
        :SetFloat32(44, 0)
        :SetFloat32(48, a[1])
        :SetFloat32(52, a[2])
        :SetFloat32(56, a[3])
        :SetFloat32(60, 1)

    return view
end

local function applyEntityMatrix(entity, view)
    local x1, y1, z1 = view:GetFloat32(16), view:GetFloat32(20), view:GetFloat32(24)
    local x2, y2, z2 = view:GetFloat32(0), view:GetFloat32(4), view:GetFloat32(8)
    local x3, y3, z3 = view:GetFloat32(32), view:GetFloat32(36), view:GetFloat32(40)
    local tx, ty, tz = view:GetFloat32(48), view:GetFloat32(52), view:GetFloat32(56)

    if not enableScale then
        x1, y1, z1 = normalize(x1, y1, z1)
        x2, y2, z2 = normalize(x2, y2, z2)
        x3, y3, z3 = normalize(x3, y3, z3)
    end

    SetEntityMatrix(entity,
        x1, y1, z1,
        x2, y2, z2,
        x3, y3, z3,
        tx, ty, tz
    )
    if IsEntityAPed(entity) then
        SetEntityHeading(entity, GetEntityHeading(entity))
    end
end

local function gizmoLoop(entity)
    if not gizmoEnabled then
        return
    end

    EnterCursorMode()

    if IsEntityAPed(entity) then
        SetEntityAlpha(entity, 200)
    else
        SetEntityDrawOutline(entity, true)
    end

    while gizmoEnabled and DoesEntityExist(entity) do
        Wait(0)

        DisableAllControlActions(0)
        local matrixBuffer = makeEntityMatrix(entity)
        local changed = Citizen.InvokeNative(0xEB2EDCA2, matrixBuffer:Buffer(), 'Editor1',
            Citizen.ReturnResultAnyway())

        if changed then
            applyEntityMatrix(entity, matrixBuffer)
        end
    end

    
    LeaveCursorMode()
 
    if DoesEntityExist(entity) then
        if IsEntityAPed(entity) then SetEntityAlpha(entity, 255) end
        SetEntityDrawOutline(entity, false)
    end

    gizmoEnabled = false
    currentEntity = nil
end

function UseGizmo(entity)
    gizmoEnabled = true
    currentEntity = entity
    gizmoLoop(entity)
    local position = GetEntityCoords(entity)
    local rotation = GetEntityRotation(entity)
    SetEntityCoords(entity, position.x, position.y, position.z, false, false ,false ,false)
    SetEntityRotation(entity, rotation.x, rotation.y, rotation.z, 2, false)
end

function DisableGizmo(entity)
    gizmoEnabled = false
end

function ActivateGizmo(entity)
    if gizmoEnabled or not entity or not DoesEntityExist(entity) then
        if not gizmoEnabled then StopMovingProp() end 
        return false 
    end

    startRotation = GetEntityRotation(entity, 2)
    startPosition = GetEntityCoords(entity)
    return UseGizmo(entity)
end


AddEventHandler("onResourceStop", function(resourceName)
    if (resourceName == GetCurrentResourceName()) then
        if gizmoEnabled then
            LeaveCursorMode()
        end
        gizmoEnabled = false
    end
end)


MapKey({
    command = "_gizmoSelect",
    key = "MOUSE_LEFT",
    mapper = "MOUSE_BUTTON", --"keyboard"
    
    pressed = function()
       if not gizmoEnabled then return end
       ExecuteCommand("+gizmoSelect")
    end,
    released = function()
        if not gizmoEnabled then return end
        ExecuteCommand("-gizmoSelect")
    end
})

MapKey({
    command = '_gizmoTranslation',
    description = 'Sets mode of the gizmo to translation',
    key = 'w',
    mapper = "keyboard",
    pressed = function()
        if not gizmoEnabled then return end
        ExecuteCommand('+gizmoTranslation')
    end,
    released = function ()
        ExecuteCommand('-gizmoTranslation')
    end
})

MapKey({
    command = '_gizmoRotation',
    key = 'r',
    mapper = "keyboard",
    pressed = function()
        if not gizmoEnabled then return end
        ExecuteCommand('+gizmoRotation')
    end,
    released = function ()
        ExecuteCommand('-gizmoRotation')
    end
})


MapKey({
    command = '_gizmoLocal',
    key = 'q',
    mapper = "keyboard",
    pressed = function()
        if not gizmoEnabled then return end
        ExecuteCommand('+gizmoLocal')
    end,
    released = function ()
        ExecuteCommand('-gizmoLocal')
    end
})

MapKey({
    command = '_resetRotation',
    key = 's',
    mapper = "keyboard",
    pressed = function()
        if not gizmoEnabled then return end
        if currentEntity then
            SetEntityRotation(currentEntity, startRotation.x, startRotation.y, startRotation.z, 2, false)
        end
    end
})

MapKey({
    command = '_resetPosition',
    key = 'd',
    mapper = "keyboard",
    pressed = function()
        if not gizmoEnabled then return end
        if currentEntity then
            SetEntityCoords(currentEntity, startPosition.x, startPosition.y, startPosition.z, false, false, false, false)
        end
    end
})

MapKey({
    command = '_placeOnGround',
    key = 'a',
    mapper = "keyboard",
    pressed = function()
        if not gizmoEnabled then return end
        if currentEntity then
            PlaceObjectOnGroundProperly_2(currentEntity)
        end
    end
})


MapKey({
    command = '_rotate-45-',
    key = 'LEFT',
    mapper = "keyboard",
    pressed = function()
        if not gizmoEnabled then return end
        if currentEntity then
            local rotation = GetEntityRotation(currentEntity, 2)
            local heading = rotation.z
            -- Normalize to the nearest 45-degree increment
            local closestHeading = math.floor((heading + 22.5) / 45) * 45
            local newHeading = (closestHeading - 45)
            print("CLosest heading was", closestHeading, "new", newHeading, "Should be", heading - 45)
            -- Apply -45° rotation
            SetEntityRotation(currentEntity, 0, 0, newHeading * 1.0, 2, false)
        end
    end
})

MapKey({
    command = '_rotate+45+',
    key = 'RIGHT',
    mapper = "keyboard",
    pressed = function()
        if not gizmoEnabled then return end
        if currentEntity then
            local rotation = GetEntityRotation(currentEntity, 2)
            local heading = rotation.z
            -- Normalize to the nearest 45-degree increment
            local closestHeading = math.floor((heading + 22.5) / 45) * 45
            local newHeading = (closestHeading + 45)
            print("CLosest heading was", closestHeading, "new", newHeading, "Should be", heading + 45)
            -- Apply +45° rotation
            SetEntityRotation(currentEntity, 0, 0, newHeading * 1.0, 2, false)
        end
    end
})



MapKey({
    command = '_stopGizmos',
    key = 'RETURN',
    mapper = "keyboard",
    pressed = function()
        if not gizmoEnabled then return end
        gizmoEnabled = false
        StopMovingProp()
    end
})

MapKey({
    command = '_stopGizmos',
    key = 'BACK',
    mapper = "keyboard",
    pressed = function()
        if not gizmoEnabled then return end
        gizmoEnabled = false
        StopMovingProp()
    end
})


RegisterCommand("closestHeading", function(s, a)
    local n = tonumber(a[1])

    print(math.floor((n + 22.5) / 45) * 45)
end)