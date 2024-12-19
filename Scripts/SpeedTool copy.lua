SpeedTool = class()

function SpeedTool.client_onEquippedUpdate(self, primary, secondary, forceBuild)
	local character = self.tool:getOwner().character
	local primaryBind = sm.gui.getKeyBinding("Create", true)
	local forceBind = sm.gui.getKeyBinding("ForceBuild", true)

	if forceBuild then
		sm.gui.setInteractionText("", primaryBind, "Place")
		return false, false
	end

	sm.gui.setInteractionText("", primaryBind, "Set Speed to "..tostring(self.data["Factor"]).."x Normal Speed")
	sm.gui.setInteractionText("", forceBind, "Force Build")

	

	if primary == sm.tool.interactState.start and not forceBuild then
		local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		if json["alertTextEnabled"] then
			self.network:sendToServer("server_checkFraction", character)
		end
		self.network:sendToServer("server_speedup", {character, tostring(self.data["Factor"])})
	end
	return true, false
end

function SpeedTool.client_sendText(self, factor)
	local character = self.tool:getOwner().character
	local messages = sm.json.open("$CONTENT_DATA/Scripts/messages.json")
	if self.data["Factor"] == factor then
		sm.gui.displayAlertText("Nothing happens...", 2)
	else
		sm.gui.displayAlertText(messages[tostring(self.data["Factor"] > factor)][self.data["Type"]], 2)
	end

	if character:isSwimming() then
		character.clientPublicData.waterMovementSpeedFraction = character.clientPublicData.waterMovementSpeedFraction * 2
	else
		character.clientPublicData.waterMovementSpeedFraction = character.clientPublicData.waterMovementSpeedFraction * 0.5
	end
end

function SpeedTool.server_speedup(self, data)
	if data[1]:isSwimming() then
		data[1].publicData.waterMovementSpeedFraction = tonumber(data[2]) * 2
	else
		data[1].publicData.waterMovementSpeedFraction = tonumber(data[2])
	end
end

function SpeedTool.server_checkFraction(self, character)
	local factor = character.publicData.waterMovementSpeedFraction
	if character:isSwimming() then
		factor = factor * 0.5
	end
	self.network:sendToClient(character:getPlayer(), "client_sendText", factor)
end