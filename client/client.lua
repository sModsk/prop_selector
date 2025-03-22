-- TODO get a life --

local callback = nil
local propRequest = nil
local fontSize = 1.5

function CreatePropSelector()
    local self = {
        props = {},
        cam = nil,
        currentIndexInCategory = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
        category = 1,
        currentCategory = {},
        maxOnScreen = 8,
        active = false,
        spin = false,
        camPassed = false,
        orginalProp = false,
        spawnData = false,
    }

    self.currentIndex = function()
        return self.currentIndexInCategory[self.category]
    end

    self.setCurrentIndex = function(index)
        self.currentIndexInCategory[self.category] = index
    end

    self.toggleCursorMode = function(value)
        if value then
            SetNuiFocus(true, true)
            Wait(10)

            if not self.camPassed then
                local player = PlayerPedId()
                SetEntityVisible(player, false, 0)
                self.toggleCamera(true)
            end

        else       
            SetNuiFocus(false, false)
            if not self.camPassed then
                local player = PlayerPedId()
                SetEntityVisible(player, true, 0)
                self.toggleCamera(false)
            end
        end
    end

    self.flush = function()
        for k,v in pairs(self.props) do
            DeleteEntity(v.prop)
        end
        self.props = {}
    end

    self.init = function(categories, furniture, blocked, reset)
        self.categories = categories
        self.furniture = furniture
        self.blocked = blocked
        SendNuiMessage(json.encode({action = "init", data = categories}))
    end

    self.disable = function(destroyTarget, temp)
        if not self.active then return end
        self.active = false
        self.toggleCursorMode(false)

        for k,v in pairs(self.props) do
            DeleteEntity(v.prop)
        end

        if not temp then
            if destroyTarget and self.lastTarget then
                if self.lastTarget.prop ~= self.orginalProp then
                    DeleteEntity(self.lastTarget.prop)
                end
            end

            self.lastTarget = nil
        end
    end

    self.enable = function (data, atStart)
        SendNuiMessage(json.encode({
            action = "show",
        }))

        if atStart then
            local cam = GetRenderingCam() 
            self.spin = false
            self.cam = cam ~= -1 and cam or nil
            self.camPassed = self.cam ~= nil
            self.orginalProp = data.prop
            self.spawnData = self.orginalProp ~= nil and {
                position = GetEntityCoords(self.orginalProp),
                rotation = GetEntityRotation(self.orginalProp),
            } or false

            if self.orginalProp then self.setProp(self.orginalProp, nil, nil, nil, true) end
        end

        self.swapCategory()
        self.toggleCursorMode(true)

        self.setProps()
        Wait(10) self.setProps()
        self.loop()
    end

    self.getOriginToBottomDistance = function(model)
        local minDim, maxDim = GetModelDimensions(GetEntityModel(model))
        local bottomZ = math.min(minDim.z, maxDim.z)
        local x, y, z = table.unpack(GetEntityCoords(model))
        local distance = self.vectorMagnitude({x = x, y = y, z = z - bottomZ})
        return distance
    end

    self.vectorMagnitude = function(vector)
        local magnitude = math.sqrt(vector.x^2 + vector.y^2 + vector.z^2)
        return tonumber(string.format("%.5f", magnitude))
    end

    self.toggleCamera = function (enable)
        if enable then
            if not self.cam then
                local camCoord = GetGameplayCamCoord()
                local camRot = GetGameplayCamRot(2)
                local camFov = GetGameplayCamFov()
    
                self.cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                SetCamCoord(self.cam, camCoord.x, camCoord.y, camCoord.z)
                SetCamRot(self.cam, camRot.x, camRot.y, camRot.z, 2)
                SetCamFov(self.cam, camFov)
                SetCamActive(self.cam, true)
                RenderScriptCams(true, true, 0, true, true)
            end
        else
            if self.cam then
                DestroyCam(self.cam, false)
                RenderScriptCams(false, true, 0, true, true)
                self.cam = nil
            end
        end
    end

    self.setPropData = function(modelData)
        local model = (type(modelData) == "string" or type(modelData) == "number") and modelData or modelData.model
        model = self.blocked[model] and "prop_cs_protest_sign_02b" or model

        local prop = CreateProp(model, vec3(0, 0, 0), vec3(0, 0, 0))
        if not prop or prop == 0 then prop = CreateProp("m24_1_prop_m41_outofordersign_01a", vec3(0, 0, 0), vec3(0, 0, 0)) end

        local minDim, maxDim = GetModelDimensions(GetEntityModel(prop))
        SetEntityCollision(prop, false, false)
        SetEntityAlwaysPrerender(prop, true)
        local sizeDifference = self.vectorMagnitude({x = maxDim.x - minDim.x, y = maxDim.y - minDim.y, z = maxDim.z - minDim.z})
        local sizeDifferenceClamped =  sizeDifference
        if sizeDifference < .5 then sizeDifferenceClamped = .5 end
        if sizeDifference > 2.5 then sizeDifferenceClamped = 2.5 end
        
        return {
            model = model,
            text = type(modelData) == "table" and modelData.text,
            prop = prop,
            minDim = minDim,
            maxDim = maxDim,
            originalSize = sizeDifferenceClamped,
            orginalSizeNotClamped = sizeDifference,
            originDistance = self.getOriginToBottomDistance(prop)
        }
    end

    self.resetData = function()
        self.category = 1
        for i= 1,#self.currentIndexInCategory do self.currentIndexInCategory[i] = 1 end
    end

    self.swapCategory = function()
        self.flush()

        if not self.categories[self.category] then self.resetData() end

        self.currentCategory = self.furniture[self.categories[self.category].name]
        if #self.currentCategory.models < 8 then self.maxOnScreen = #self.currentCategory.models else self.maxOnScreen = 8 end

        local currentIndex = self.currentIndex()
        local count = self.maxOnScreen

        for i=currentIndex, #self.currentCategory.models do
            local model = self.currentCategory.models[i]
            table.insert(self.props, self.setPropData(model))
            
            count -= 1
            if count == 0 then break end
        end

        if count > 0 then
            for i=1, count do
                local model = self.currentCategory.models[i]
                table.insert(self.props, self.setPropData(model))
            end
        end
    end
    
    self.nextProp = function()
        local currentIndex = self.currentIndex()
        currentIndex += 1
        if currentIndex > #self.currentCategory.models then
            currentIndex = 1
        end
        self.setCurrentIndex(currentIndex)

        local realIndex = currentIndex + self.maxOnScreen - 1
        if realIndex > #self.currentCategory.models then
            realIndex = realIndex - #self.currentCategory.models
        end
    
        local item = table.remove(self.props, 1)
        DeleteEntity(item.prop)
        table.insert(self.props, self.setPropData(self.currentCategory.models[realIndex]))
    end
    
    self.lastProp = function()

        local currentIndex = self.currentIndex()
        currentIndex -= 1
        if currentIndex < 1 then
            currentIndex = #self.currentCategory.models
        end
        self.setCurrentIndex(currentIndex)

        local item = table.remove(self.props)
        DeleteEntity(item.prop)
        table.insert(self.props, 1, self.setPropData(self.currentCategory.models[currentIndex]))
    end
    
    self.selectPropDataUnderCursor = function()
        local x, y = GetNuiCursorPosition()
        local xRes, yRes = GetActualScreenResolution()
        x = x / xRes
        y = y / yRes
    
        local closestProp = nil
        local closestDistance = math.huge
    
        for i=1, #self.props do
            local propData = self.props[i]
            if i <= self.maxOnScreen then
                local _x = (i - .5) / self.maxOnScreen
                local _y = self.getScreenY(i)
                local distance = math.sqrt((x - _x)^2 + (y - _y)^2)
    
                if distance < 0.05 then
                    if distance < closestDistance then
                        closestProp = propData
                        closestDistance = distance
                    end
                end
            else
                break
            end
        end
    
        return closestProp
    end

    self.placeOnGround = function(prop, coords)

        local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1, false)
        if found then
            if math.abs(coords.z - groundZ) < 1.5 then
                PlaceObjectOnGroundProperly_2(prop)
            end
        end
    end

    self.setProp = function(prop, propData, coords, rotation, dontPlaceOnGround)
        if prop and DoesEntityExist(prop) then
            if self.spawnData then
                SetEntityCoords(prop, self.spawnData.position.x, self.spawnData.position.y, self.spawnData.position.z, false, false, false, false)
                SetEntityRotation(prop, self.spawnData.rotation.x, self.spawnData.rotation.y, self.spawnData.rotation.z, 2, false)

                if not dontPlaceOnGround then
                    self.placeOnGround(prop, self.spawnData.position)
                end
            else
                SetEntityCoords(prop, coords.x, coords.y, coords.z, false, false, false, false)
                SetEntityRotation(prop, rotation.x, rotation.y, rotation.z, 2, false)

                if not dontPlaceOnGround then
                    self.placeOnGround(prop, coords)
                end
            end
            
            self.lastTarget = {
                target = propData,
                prop = prop
            }

            if propData then
                SetEntityDrawOutline(propData.prop, true) 
            end
        end
    end

    self.getSpawnPosition = function()
        local camCoords = GetCamCoord(self.cam)
        local forward, right, up = GetCamMatrix(self.cam)
        local startCoords = camCoords
        local maxDistance = 10.0
        local endCoords = startCoords + (right * maxDistance) - up
    
        local rayHandle = StartShapeTestRay(startCoords.x, startCoords.y, startCoords.z, endCoords.x, endCoords.y, endCoords.z, -1, PlayerPedId(), 0)
        local _, hit, hitCoords, normal, entity = GetShapeTestResult(rayHandle)
        
        if hit == 1 then
            return hitCoords
        else
            return endCoords
        end
    end
    
    self.setSelectedProp = function(propData)
        local coords
        local rotation

        if self.lastTarget  then
            if self.lastTarget.target then
                SetEntityDrawOutline(self.lastTarget.target.prop, false)
            end

            coords = GetEntityCoords(self.lastTarget.prop)
            rotation = GetEntityRotation(self.lastTarget.prop, 2)

            if self.lastTarget.prop ~= self.orginalProp then
                DeleteEntity(self.lastTarget.prop)
            else
                -- Hide original prop
                if self.orginalProp then 
                    SetEntityCoords(self.orginalProp, 0.0, 0.0, 0.0, false, false, false, false)
                end
            end

            self.lastTarget = nil
        end
        

        local position = GetCamCoord(self.cam)
        local dontPlaceOnGround = coords ~= nil
        coords = coords or self.getSpawnPosition()

        local prop = CreateProp(GetEntityModel(propData.prop), coords, vector3(0.0, 0.0, 0.0))
        local direction = (coords - position)
        local heading = math.atan2(direction.y, direction.x) * (180 / math.pi) - 90

        rotation = rotation or vec3(0, 0, heading)

        self.setProp(prop, propData, coords, rotation, dontPlaceOnGround)
    end

    self.getEntityUnderCursor = function()
        if not self.cam then return end
        local propData = self.selectPropDataUnderCursor()
        if propData then
            self.setSelectedProp(propData)
        end
    end

    self.centerEntity = function()
        if not self.cam then return end
        local index = math.floor(#self.props / 2)
        self.setSelectedProp(self.props[index])
    end


    self.getScreenY = function(i)
        local baseY = 0.95
        local peak = 0.15
        local progress = (i - 0.5) / self.maxOnScreen
        return baseY - (peak * math.sin(progress * math.pi))
    end

    self.setProps = function()
        local targetSize = .025
        local baseMargin = self.currentCategory.margin / self.maxOnScreen
        for i=1, #self.props do
            local propData = self.props[i]
            if i <= self.maxOnScreen then
                local x = (i - .5) / self.maxOnScreen
                local y = self.getScreenY(i)
                local worldVector, normalVector = GetWorldCoordFromScreenCoord(x, y)
                local marginAdjustment = baseMargin * (propData.originalSize or 1) / 3
                local propPos = worldVector + normalVector * marginAdjustment
                self.setEntityOffsetPosition(propData, propPos, targetSize)
            end
        end
    end

    self.setEntityOffsetPosition = function(propData, position, targetSize)
        local entity = propData.prop
    
        local camRot = GetFinalRenderedCamRot(2)
    
        SetEntityRotation(entity, camRot.x , camRot.y, camRot.z, 2, false)
        local forwardVector, rightVector, upVector, _position = GetEntityMatrix(entity)

        local scale = targetSize / propData.originalSize
    
        forwardVector = forwardVector * scale
        rightVector = rightVector * scale
        upVector = upVector * scale
        
        -- Set the entity matrix
        SetEntityMatrix(entity, 
            forwardVector.x, forwardVector.y, forwardVector.z,
            rightVector.x, rightVector.y, rightVector.z,
            upVector.x, upVector.y, upVector.z,
            position.x, position.y, position.z
        )
    
        position = position + upVector * propData.originDistance 
        SetEntityCoordsNoOffset(entity, position.x, position.y, position.z) 
    end

    self.loop = function()
        self.active = true
        CreateThread(function()
            while self.active do
                Wait(0)
    
                local baseMargin = self.currentCategory.margin / self.maxOnScreen
                for i=1, #self.props do
                    local propData = self.props[i]
                    if i <= self.maxOnScreen then
                        local x = (i - .5) / self.maxOnScreen
                        local y = self.getScreenY(i)
                        local worldVector, normalVector = GetWorldCoordFromScreenCoord(x, y)
                        local marginAdjustment = baseMargin * (propData.originalSize or 1) / 3
                        local lightMarginAdjustment = marginAdjustment * 0.25
                        local lightPos = worldVector + normalVector * lightMarginAdjustment
                        DrawLightWithRange(lightPos.x, lightPos.y, lightPos.z, 255, 255, 255, 0.5, .1)
                    end
                end

                if self.lastTarget and self.lastTarget.target then
                    if self.lastTarget.target.text then
                        local coords = GetEntityCoords(self.lastTarget.prop)
                        DrawText3D(coords.x, coords.y, coords.z, self.lastTarget.target.text, fontSize)
                    end
                end
            end

            
        end)
    end

    return self
end

local PropSelector = CreatePropSelector()

local function openSelector(data, cb)
    local data = data or {}

    local categories = data.categories or Categories
    local furniture = data.furniture or Furniture
    local blocked = data.blocked or {}

    fontSize = data.fontSize or 1.5

    PropSelector.init(categories, furniture, blocked)
    PropSelector.enable(data, true)

    propRequest = {
        waiting = true
    }

    if not cb then
        while propRequest.waiting do
            Wait(1)
        end

        return propRequest.prop
    else
        callback = cb
    end
end

function StopMovingProp()
    SendNuiMessage(json.encode({
        action = "gizmo",
        activated = false
    }))

    if propRequest and propRequest.waiting then
        SetNuiFocus(true, true)
    end
end

RegisterNUICallback('search', function(data, cb)
    local keyWord = data.keyWord
    local models = {}
    if PropSelector.furniture then
        for j=1, #PropSelector.categories - 1 do
            local v = PropSelector.furniture[PropSelector.categories[j].name]
            if v and v.models then
                for i = 1, #v.models do
                    local model = type(v.models[i]) == "string" and v.models[i] or v.models[i].model
                    if keyWord and string.find(string.lower(model), string.lower(keyWord), 1, true) then
                        table.insert(models, model)
                    end
                end
            end
        end   
    end

    if #models <= 0 then
        return
    end

    -- Lazy implementation --
    -- Nope, not gonna rework position calculations.. let's just fill space with last model -- 
    if #models < 8 then
        local offset = 8 - #models
        for i=1, offset do
            table.insert(models, models[#models])
        end
    end
    ----------------------

    PropSelector.furniture["Search"] = {
        margin = 1.0,
        models = models
    }

    if not PropSelector then return end
    PropSelector.currentIndexInCategory[#PropSelector.categories] = 1
    PropSelector.category = #PropSelector.categories
    PropSelector.swapCategory()
    PropSelector.setProps()
end)

RegisterNUICallback('move', function(data, cb)
    Wait(10)
    if not IsNuiFocused() then return end
    if not propRequest or not propRequest.waiting then return end
    if not PropSelector then return end
    if PropSelector.lastTarget and PropSelector.lastTarget.prop then
        SetNuiFocus(false, false)
        SendNuiMessage(json.encode({
            action = "gizmo",
            activated = true
        }))

        local data = ActivateGizmo(PropSelector.lastTarget.prop)
    end
end)

RegisterNUICallback('centerEntity', function(data, cb)
    if not PropSelector then return end
    PropSelector.centerEntity() 
end)

RegisterNUICallback('clicked', function(data, cb)
    if not PropSelector then return end
    PropSelector.getEntityUnderCursor() 
end)

RegisterNUICallback('released', function(data, cb)
    if not PropSelector then return end
end)

RegisterNUICallback('category', function(data, cb)
    if not PropSelector then return end
    local index = tonumber(data.index)
    PropSelector.category = index
    PropSelector.swapCategory()
    PropSelector.setProps()
end)

RegisterNUICallback('next', function(data, cb)
    if not PropSelector then return end
    PropSelector.nextProp()
    PropSelector.setProps()
end)

RegisterNUICallback('prev', function(data, cb)
    if not PropSelector then return end
    PropSelector.lastProp()
    PropSelector.setProps()
end)

RegisterNUICallback('spin', function(data, cb)
    if not PropSelector then return end
    PropSelector.spin = not PropSelector.spin 
end)

RegisterNUICallback('close', function(data, cb)
    SendNuiMessage(json.encode({
        action = "close"
    }))

    if not PropSelector then return end

    PropSelector.disable(true)

    if PropSelector.orginalProp then
        local position = PropSelector.spawnData.position
        local rotation = PropSelector.spawnData.rotation

        SetEntityCoords(PropSelector.orginalProp, position.x, position.y, position.z, false ,false, false, false)
        SetEntityRotation(PropSelector.orginalProp, rotation.x, rotation.y, rotation.z, 2, false)
    end

    if callback then callback(nil) end
    callback = nil

    if propRequest then
        propRequest.waiting = false
    end
end)

RegisterNUICallback('select', function(data, cb)
    SendNuiMessage(json.encode({
        action = "close"
    }))

    if not PropSelector then return end
    local prop = PropSelector?.lastTarget?.prop
    PropSelector.disable(false)
    if callback then callback(prop) end
    callback = nil

    if propRequest then
        propRequest.waiting = false
        propRequest.prop = prop
    end
end)

-- Hides the menu temporarily so we can change the camera angle
RegisterNUICallback('tempDisable', function(data, cb)
    Wait(10)
    if not IsNuiFocused() then return end
    SetNuiFocus(false, false)
    SendNuiMessage(json.encode({
        action = "tempClose"
    }))

    local prop = PropSelector?.lastTarget?.prop
    PropSelector.disable(false, true)
    
    while not IsDisabledControlJustPressed(0, 25) do
        DisableControlAction(0, 25, true)
        Wait(1)
    end

    PropSelector.enable(data, false)
    SetNuiFocus(true, true)

end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if not PropSelector then return end
        PropSelector.disable(true)
    end
end)



RegisterCommand("propSelector", function()
    local prop = openSelector({})
end)



local function isOpen()
    return propRequest and propRequest.waiting
end

exports("Open", openSelector)
exports("IsOpen", isOpen)
