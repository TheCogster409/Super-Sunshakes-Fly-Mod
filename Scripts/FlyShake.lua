FlyShakePart = class()

function FlyShakePart.client_onInteract(self, character, state)
	if not state then return end
	local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
	if json["alertTextEnabled"] then
 		if character:isSwimming() then
			sm.gui.displayAlertText("Your inner woc obeys Newton...", 2)
		else
			sm.gui.displayAlertText("Your inner woc defies gravity...", 2)
	  	end
	end
	self.network:sendToServer("server_deleteSelf", character)
end

function FlyShakePart.client_canInteract( self, character )
    local character = sm.localPlayer.getPlayer().character
    local primaryBind = sm.gui.getKeyBinding("Use", true)
	sm.gui.setInteractionText("", primaryBind, (character:isSwimming() or character:isDiving()) and "Drink FlyShake™ And Obey Newton" or "Drink FlyShake™ And Defy Gravity")
	return true
end

function FlyShakePart.server_deleteSelf(self, character)
	local factor = character.publicData.waterMovementSpeedFraction
	if character:isDiving() then
		factor = factor * 0.5
	else
		factor = factor * 2
	end
	character.publicData.waterMovementSpeedFraction = factor
	local settings = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
	if settings["flightMode"] == "normal" then
		character:setDiving(not character:isDiving())
		character:setSwimming(not character:isSwimming())
	elseif settings["flightMode"] == "swim" then
		character:setSwimming(not character:isSwimming())
	else
		character:setDiving(not character:isDiving())
	end
	self.shape:destroyShape()
end