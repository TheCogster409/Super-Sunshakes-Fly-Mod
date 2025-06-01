Manager = class()
Manager.instance = nil

-- Credits to elo_melo on discord for writing most of the command code!

function Manager.client_onRefresh(self)
	Manager.instance = self
	self.tick = 0
end

function Manager.client_onFixedUpdate(self)
    if shakeAnimationsEnabled == nil then shakeAnimationsEnabled = true end

	if self.tool:isLocal() then
		local character = self.tool:getOwner().character
		if not sm.localPlayer.getCarry():isEmpty() and character:isSwimming() then
			character.clientPublicData.waterMovementSpeedFraction = character.clientPublicData.waterMovementSpeedFraction * 0.5
			self.network:sendToServer("server_stopFly", character)
			if self.settings["alertTextEnabled"] then
				sm.gui.displayAlertText("Picking up containers while flying will get you stuck!\nYour inner woc obeys Newton...", 5)
			end
		end

		self.tick = self.tick + 1
		if self.tick == 80 then
			self.tick = 0
			self.network:sendToServer("server_saveData", {character, self.settings["playerUUID"]})
		end
	end
	return true, false
end

function Manager.client_onCreate(self)
	if self.tool:isLocal() then
		self.tick = 0
		self.settings = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		local character = self.tool:getOwner().character
		local player = self.tool:getOwner()
		if not Manager.instance or Manager.instance ~= self then
    	    Manager.instance = self
    	end

        if character.clientPublicData.waterMovementSpeedFraction == nil then
            character.clientPublicData.waterMovementSpeedFraction = 1
        end

		if self.settings["playerUUID"] == nil then
			self.settings["playerUUID"] = tostring(sm.uuid.new())
			sm.json.save(self.settings, "$CONTENT_DATA/Scripts/settings.json")
		end
		self.network:sendToServer("server_initState", {player, self.settings["playerUUID"], false})
	end
end

function Manager.server_saveData(self, data)
	sm.storage.save("stateData"..data[2], {data[1]:isSwimming(), data[1]:isDiving(), data[1].publicData.waterMovementSpeedFraction})
end

function Manager.server_initState(self, data)
	local character = data[1].character
	local stateData = sm.storage.load("stateData"..data[2])
	if stateData == nil then
		stateData = {false, false, 1}
	end
	self.network:sendToClient(data[1], "client_initState", stateData[3])
	character:setSwimming(stateData[1])
	character:setDiving(stateData[2])
	character.publicData.waterMovementSpeedFraction = stateData[3]
end

function Manager.client_initState(self, fraction)
	local character = self.tool:getOwner().character
	character.clientPublicData.waterMovementSpeedFraction = fraction
end

function Manager.server_stopFly(self, character)
	character:setSwimming(false)
	character:setDiving(false)
	character.publicData.waterMovementSpeedFraction = character.publicData.waterMovementSpeedFraction * 0.5
end

function Manager.server_Fly(self, params, caller)
	local character = params["player"]:getCharacter()
	local settings = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
	if settings["flightMode"] == "normal" then
		character:setDiving(not character:isDiving())
		character:setSwimming(not character:isSwimming())
	elseif settings["flightMode"] == "swim" then
		character:setSwimming(not character:isSwimming())
	else
		character:setDiving(not character:isDiving())
	end
	if character:isSwimming() then
		character.publicData.waterMovementSpeedFraction = character.publicData.waterMovementSpeedFraction * 2
	else
		character.publicData.waterMovementSpeedFraction = character.publicData.waterMovementSpeedFraction * 0.5
	end

	self.network:sendToClient(params["player"], "client_Fly", {character:isSwimming()})
end

function Manager.client_Fly(self, data)
	local character = self.tool:getOwner().character
	if character:isSwimming() then
		character.clientPublicData.waterMovementSpeedFraction = character.clientPublicData.waterMovementSpeedFraction * 2
	else
		character.clientPublicData.waterMovementSpeedFraction = character.clientPublicData.waterMovementSpeedFraction * 0.5
	end

	if self.settings["alertTextEnabled"] then
		if data[1] then
			sm.gui.displayAlertText("Your inner woc obeys Newton...", 2)
		else
			sm.gui.displayAlertText("Your inner woc defies gravity...", 2)
		end
	end
end

function Manager.server_Speed(self, params, caller)
	local character = params["player"]:getCharacter()
    if character:isSwimming() then
		character.publicData.waterMovementSpeedFraction = params[2]*2
	else
		character.publicData.waterMovementSpeedFraction = params[2]
	end
	self.network:sendToClient(params["player"], "client_Speed", params)
end

function Manager.client_Speed(self, params)
	local character = params["player"]:getCharacter()
    if character:isSwimming() then
		character.clientPublicData.waterMovementSpeedFraction = params[2]*2
	else
		character.clientPublicData.waterMovementSpeedFraction = params[2]
	end
	if self.settings["alertTextEnabled"] then
		sm.gui.displayAlertText("Set speed to " .. params[2] .. "x", 2)
	end
end

local BindCommand = BindCommand or sm.game.bindChatCommand

function sm.game.bindChatCommand(command, params, callback, help)
    if not hooked then
        BindCommand("/speed", { { "string", " Speed Multiplier", false } }, "cl_onChatCommand", "Set speed multiplier. 1 for normal, 2 for double, 0.5 for half, etc.")
		BindCommand("/fly", {}, "cl_onChatCommand", "Toggle fly mode. Same as drinking a FlyShake™")
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
    else
        oldWorldEvent(world, callback, params)
    end
end