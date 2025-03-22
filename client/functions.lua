function DrawText3D(x, y, z, text, fontSize)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local camCoords = GetGameplayCamCoords()
    local dist = #(camCoords - vector3(x, y, z))
    local scale = math.min((1 / dist) * 2, 1.0) -- Cap scaling to prevent oversize text

    if onScreen then
        SetTextScale(fontSize * scale, fontSize * scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextCentre(true) -- This ensures the text is centered

        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        AddTextComponentString(text)

        DrawText(_x, _y) -- No need for manual _x adjustments
    end
end


function LoadModel(model)
    local propHash = type(model) == "string" and GetHashKey(model) or model
    if propHash == nil then return false, false end
    if not IsModelInCdimage(propHash) then return false, false end
    RequestModel(propHash)
    local ticks = 5
    while not HasModelLoaded(propHash) and ticks > 0 do
        ticks = ticks - 1
        Wait(10)
    end
    return HasModelLoaded(propHash), propHash
end

function CreateProp(propName, position, rotation)
    if propName == nil then return end
    local loaded, propHash = LoadModel(propName)
    if loaded then
        local prop = CreateObject(propHash, position.x, position.y, position.z, false, false, false)
        SetEntityAsMissionEntity(prop, true, true)
        SetEntityCoords(prop, position.x, position.y, position.z)
        SetEntityRotation(prop, rotation.x, rotation.y, rotation.z, 2)
        FreezeEntityPosition(prop, true, true)
        SetModelAsNoLongerNeeded(propHash)
        return prop
    else
        print("UNABLE TO LOAD MODEL ", propName)
    end
    return nil
end