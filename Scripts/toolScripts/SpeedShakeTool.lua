SpeedTool = class()

function SpeedTool.client_onEquippedUpdate(self, primary, secondary, forceBuild)
	local character = self.tool:getOwner().character

	local primaryBind = sm.gui.getKeyBinding("Create", true)
	local forceBind = sm.gui.getKeyBinding("ForceBuild", true)

	if forceBuild then
		sm.gui.setInteractionText("", primaryBind, "Place")
		return false, false
	end

	sm.gui.setInteractionText("", primaryBind, "Set Speed to 4x Normal Speed")
	sm.gui.setInteractionText("", forceBind, "Force Build")

	

	if primary == sm.tool.interactState.start and not forceBuild then
		local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		if json["alertTextEnabled"] then
			sm.gui.displayAlertText("The SpeedShake™ charges up your inner Woc inside you...", 2)
		end
		self.network:sendToServer("server_speedup", character)
	end
	return true, false
end

function SpeedTool.server_speedup(self, character)
	if character:isSwimming() then
		character.publicData.waterMovementSpeedFraction = 8
	else
		character.publicData.waterMovementSpeedFraction = 4  
	end
end