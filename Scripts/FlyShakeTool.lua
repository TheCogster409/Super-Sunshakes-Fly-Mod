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
				sm.gui.displayAlertText("Your inner woc obeys Newton...", 2)
			else
				sm.gui.displayAlertText("Your inner woc defies gravity...", 2)
			end
		end
		self.network:sendToServer("server_startFly", character)
	else
		self.clicked = false
	end
	return true, false
end

function FlyTool.server_startFly(self, character)
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
end