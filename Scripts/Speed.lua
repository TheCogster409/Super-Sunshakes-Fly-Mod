Speed = class()

function Speed.client_onCreate(self)
	self.factor = sm.item.getFeatureData(self.shape:getShapeUuid())["data"]["Factor"]
	self.shakeType = sm.item.getFeatureData(self.shape:getShapeUuid())["data"]["Type"]
end

function Speed.client_onInteract(self, character, state)
	if not state then return end
	local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
	if json["alertTextEnabled"] then
		local messages = sm.json.open("$CONTENT_DATA/Scripts/messages.json")
		if self.factor == character.clientPublicData.waterMovementSpeedFraction then
			sm.gui.displayAlertText("Nothing happens...", 2)
		else
			sm.gui.displayAlertText(messages[tostring(self.factor > character.clientPublicData.waterMovementSpeedFraction)][self.shakeType], 2)
		end
	end
	self.network:sendToServer("server_deleteSelf", {character, self.factor})

	if character:isSwimming() then
		character.clientPublicData.waterMovementSpeedFraction = character * 2
	else
		character.clientPublicData.waterMovementSpeedFraction = character
	end
end

function Speed.server_deleteSelf(self, data)
	if data[1]:isSwimming() then
		data[1].publicData.waterMovementSpeedFraction = data[2] * 2
	else
		data[1].publicData.waterMovementSpeedFraction = data[2]
	end
	self.shape:destroyShape()
end