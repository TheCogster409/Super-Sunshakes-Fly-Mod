Manager = class()
Manager.instance = nil

-- Credits to elo_melo on discord for writing most of the command code!

function Manager.client_onFixedUpdate(self)
	local character = self.tool:getOwner().character
	if not sm.localPlayer.getCarry():isEmpty() and character:isSwimming() then
		self.network:sendToServer("server_stopFly", character)
		local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		if json["alertTextEnabled"] then
			sm.gui.displayAlertText("Be careful! Picking up containers while flying will get you stuck! \n We have stopped flying for you to keep you safe.", 5)
		end
	end
	return true, false
end

function Manager.client_onCreate(self)
	local character = self.tool:getOwner().character
	local player = self.tool:getOwner()
	self.network:sendToServer("server_stopFly", {character, player})
	if not Manager.instance or Manager.instance ~= self then
        Manager.instance = self
    end
end

function Manager.server_stopFly(self, data)
	self.character = data[1]
	self.player = data[2]
	self.character:setSwimming(false)
end

function Manager.server_Fly(self, params, caller)
	self.network:sendToClient(self.player, "client_Fly", {not self.character:isSwimming()})
    self.character:setSwimming(not self.character:isSwimming())

	if self.character:isSwimming() then
		self.character.publicData.waterMovementSpeedFraction = 2
	else
		self.character.publicData.waterMovementSpeedFraction = 1  
	end
end

function Manager.client_Fly(self, data)
	local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
	if json["alertTextEnabled"] then
		if data[1] then
			sm.gui.displayAlertText("Enabled fly mode.", 2)
		else
			sm.gui.displayAlertText("Disabled fly mode.", 2)
		end
	end
end

function Manager.server_Speed(self, params, caller)
    if self.character:isSwimming() then
		self.character.publicData.waterMovementSpeedFraction = params[2]*2
	else
		self.character.publicData.waterMovementSpeedFraction = params[2]
	end
	self.network:sendToClient(self.player, "client_Speed", params[2])
end

function Manager.client_Speed(self, speed)
    local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
	if json["alertTextEnabled"] then
		sm.gui.displayAlertText("Set speed to " .. speed .. "x", 2)
	end
end

function Manager.server_ToggleAlertText(self, params, caller)
	sm.json.save({["alertTextEnabled"] = params[2]}, "$CONTENT_DATA/Scripts/settings.json")
	self.network:sendToClient(self.player, "client_ToggleAlertText", params[2])
end

function Manager.client_ToggleAlertText(self, enabled)
	if enabled then
		sm.gui.displayAlertText("Alert text like this is now on.")
	else
		sm.gui.displayAlertText("Alert text like this has been disabled.")
	end
end

local BindCommand = BindCommand or sm.game.bindChatCommand

function sm.game.bindChatCommand(command, params, callback, help)
    if not hooked then
        BindCommand("/speed", { { "string", "Speed Multiplier", false } }, "cl_onChatCommand", "Set speed multipler. 1 for normal, 2 for double, 0.5 for half, etc.")
		BindCommand("/fly", {}, "cl_onChatCommand", "Toggle fly mode. Same as FlyShake™")
		BindCommand("/shakeAlertText", { { "bool", "", false } }, "cl_onChatCommand", "Whether or not alert text is shown in the mod. True or false.")
        hooked = true
    end
    
    BindCommand(command, params, callback, help)
end

local oldWorldEvent = oldWorldEvent or sm.event.sendToWorld

function sm.event.sendToWorld(world, callback, params)
    if not params or type(params)=="player" then
        return oldWorldEvent(world, callback, params)
    end

    if params[1] == "/fly" then
        sm.event.sendToTool(Manager.instance.tool, "server_Fly", params)
    elseif params[1] == "/speed" then
		params[2] = tonumber(params[2])
		if params[2] ~= nil then
			params[2] = sm.util.clamp(params[2], -500, 500)
        	sm.event.sendToTool(Manager.instance.tool, "server_Speed", params)
		end
	elseif params[1] == "/shakeAlertText" then
        sm.event.sendToTool(Manager.instance.tool, "server_ToggleAlertText", params)
    else
        oldWorldEvent(world, callback, params)
    end
end