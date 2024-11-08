ResetTool = class()

function ResetTool.client_onEquippedUpdate(self, primary, secondary, forceBuild)
	local character = self.tool:getOwner().character

	local primaryBind = sm.gui.getKeyBinding("Create", true)
	local forceBind = sm.gui.getKeyBinding("ForceBuild", true)

	if forceBuild then
		sm.gui.setInteractionText("", primaryBind, "Place")
		return false, false
	end

	sm.gui.setInteractionText("", primaryBind, "Return Speed to Normal Speed")
	sm.gui.setInteractionText("", forceBind, "Force Build")

	

	if primary == sm.tool.interactState.start and not forceBuild then
		local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		if json["alertTextEnabled"] then
			sm.gui.displayAlertText("The ResetShake™ your inner Woc to normal levels...", 2)
		end
		self.network:sendToServer("server_speedup", character)
	end
	return true, false
end

function ResetTool.server_speedup(self, character)
	if character:isSwimming() then
		character.publicData.waterMovementSpeedFraction = 2
	else
		character.publicData.waterMovementSpeedFraction = 1
	end
end