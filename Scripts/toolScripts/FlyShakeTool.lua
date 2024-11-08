FlyTool = class()

function FlyTool.client_onEquippedUpdate(self, primary, secondary, forceBuild)
	local character = self.tool:getOwner().character

	self.clicked = false

	local primaryBind = sm.gui.getKeyBinding("Create", true)
	local forceBind = sm.gui.getKeyBinding("ForceBuild", true)

	if forceBuild then
		sm.gui.setInteractionText("", primaryBind, "Place")
		return false, false
	end

	if character:isSwimming() then
		sm.gui.setInteractionText("", primaryBind, "Stop Flying")
		sm.gui.setInteractionText("", forceBind, "Force Build")
	else
		sm.gui.setInteractionText("", primaryBind, "Start Flying")
		sm.gui.setInteractionText("", forceBind, "Force Build")
	end
	

	if primary == sm.tool.interactState.start and not forceBuild then
		self.clicked = true
		local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		if json["alertTextEnabled"] then
			if character:isSwimming() then
				sm.gui.displayAlertText("Disabled fly mode.", 2)
			else
				sm.gui.displayAlertText("Enabled fly mode.", 2)
			end
		end
		self.network:sendToServer("server_startFly", character)
	else
		self.clicked = false
	end
	return true, false
end

function FlyTool.server_startFly(self, character)
	character:setSwimming(not character:isSwimming())

	if character:isSwimming() then
		character.publicData.waterMovementSpeedFraction = 2
	else
		character.publicData.waterMovementSpeedFraction = 1  
	end
end