SpeedShakePart = class()

function capitalizeFirstLetter(string)
    return string:sub(1, 1):upper() .. string:sub(2)
end

function SpeedShakePart.client_onCreate(self)
	self.factor = sm.item.getFeatureData(self.shape:getShapeUuid())["data"]["Factor"]
	self.shakeType = sm.item.getFeatureData(self.shape:getShapeUuid())["data"]["Type"]
end

function SpeedShakePart.client_onInteract(self, character, state)
	if not state then return end
	local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
	if json["alertTextEnabled"] then
		local messages = sm.json.open("$CONTENT_DATA/Scripts/messages.json")
		if self.factor == character.clientPublicData.waterMovementSpeedShakePartFraction then
			sm.gui.displayAlertText("Nothing happens...", 2)
		else
			sm.gui.displayAlertText(messages[tostring(self.factor > character.clientPublicData.waterMovementSpeedShakePartFraction)][self.shakeType], 2)
		end
	end
	self.network:sendToServer("server_deleteSelf", {character, self.factor})

	if character:isSwimming() then
		character.clientPublicData.waterMovementSpeedShakePartFraction = character * 2
	else
		character.clientPublicData.waterMovementSpeedShakePartFraction = character
	end
end

function SpeedShakePart.client_canInteract( self, character )
    local character = sm.localPlayer.getPlayer().character
    local primaryBind = sm.gui.getKeyBinding("Use", true)
	sm.gui.setInteractionText("", primaryBind, "Drink "..capitalizeFirstLetter(self.shakeType).."Shake™ And Set Speed to "..tostring(self.factor).."x")
	return true
end

function SpeedShakePart.server_deleteSelf(self, data)
	if data[1]:isSwimming() then
		data[1].publicData.waterMovementSpeedShakePartFraction = data[2] * 2
	else
		data[1].publicData.waterMovementSpeedShakePartFraction = data[2]
	end
	self.shape:destroyShape()
end