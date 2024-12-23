CPPHook = class()

sm.CarryPlusPlus = {}
sm.CarryPlusPlus.heldData = {}
sm.CarryPlusPlus.hooked = false
sm.CarryPlusPlus.hookedWorld = false
sm.CarryPlusPlus.currentInteractableColor = nil
sm.CarryPlusPlus.currentInteractableOriginalColor = nil
sm.CarryPlusPlus.carryPlacedById = 0
sm.CarryPlusPlus.deleteCarriedItems = false

local oldBindCommand = sm.game.bindChatCommand

local function bindCommandHook(command, params, callback, help)
    if not sm.CarryPlusPlus.hooked then
        dofile("$CONTENT_f8df5c4b-a095-469b-9369-c7eb593f6f52/Scripts/dofiler.lua")
        print("Hooking Carry++")
        sm.CarryPlusPlus.hooked = true
        if sm.isHost then
            oldBindCommand("/deleteCarriedItems", {{ "bool", "enable", true }}, "cl_onChatCommand", "Automatically deletes any items that enter your carry tool. (Unlimited inventory only)")
        end
    else
        print("Unhooking Carry++")
        sm.game.bindChatCommand = oldBindCommand
    end
    oldBindCommand(command, params, callback, help)
end
sm.game.bindChatCommand = bindCommandHook

local oldWorldEvent = sm.event.sendToWorld

local function worldEventHook(world, callback, params)
    if not params then
        oldWorldEvent(world, callback, params)
        return
    end

    if params[1] == "/deleteCarriedItems" then
        local deleteCarryItems = not sm.CarryPlusPlus.deleteCarriedItems
        if type( params[2] ) == "boolean" then
        deleteCarryItems = params[2]
    end
    sm.CarryPlusPlus.deleteCarriedItems = deleteCarryItems
    if sm.CarryPlusPlus.deleteCarriedItems and sm.game.getLimitedInventory() then
    sm.CarryPlusPlus.deleteCarriedItems = false
    sm.gui.chatMessage( "Carried Item Deletion only available in Unlimited inventory!" )
    return
end
sm.gui.chatMessage( "Carried Item Deleting is " .. ( sm.CarryPlusPlus.deleteCarriedItems and "Enabled" or "Disabled" ) )
    else
        oldWorldEvent(world, callback, params)
    end
end

sm.event.sendToWorld = worldEventHook