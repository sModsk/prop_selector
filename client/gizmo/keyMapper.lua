function MapKey(data)
    RegisterCommand('+'..data.command, function()
        if data.pressed then data.pressed() end
    end, true)
    RegisterCommand('-'..data.command, function()
        if data.released then data.released() end
    end, true)

    RegisterKeyMapping('~!+'..data.command, '', data.mapper, data.key)
end