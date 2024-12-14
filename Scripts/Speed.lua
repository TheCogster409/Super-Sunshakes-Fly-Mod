Speed = class()

function Speed.client_onCreate(self)
	self.factor = sm.item.getFeatureData(self.shape:getShapeUuid())["data"]["Factor"]
	self.shakeType = sm.item.getFeatureData(self.shape:getShapeUuid())["data"]["Type"]
end

function Speed.client_onInteract(self, character, state)
	if not state then return end
	local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
	if json["alertTextEnabled"] then
		self.network:sendToServer("server_checkFraction", character)
	end
	self.network:sendToServer("server_deleteSelf", {character, self.factor})
end

function Speed.client_sendText(self, factor)
	print(factor)
	local messages = sm.json.open("$CONTENT_DATA/Scripts/messages.json")
	if self.factor == factor then
		sm.gui.displayAlertText("Nothing happens...", 2)
	else
		sm.gui.displayAlertText(messages[tostring(self.factor > factor)][self.shakeType], 2)
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

function Speed.server_checkFraction(self, character)
	self.network:sendToClient(character:getPlayer(), "client_sendText", character.publicData.waterMovementSpeedFraction)
end