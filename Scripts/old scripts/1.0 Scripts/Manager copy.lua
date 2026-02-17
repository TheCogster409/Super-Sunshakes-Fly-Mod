Manager = class()
Manager.instance = nil

-- Credits to elo_melo on discord for writing most of the command code!

function Manager.client_onRefresh(self)
	Manager.instance = self
	self.tick = 0
end

function Manager.client_onFixedUpdate(self)
	local character = self.tool:getOwner().character
	if not sm.localPlayer.getCarry():isEmpty() and character:isSwimming() then
		self.network:sendToServer("server_stopFly", {character, self.tool:getOwner()})
		if self.settings["alertTextEnabled"] then
			sm.gui.displayAlertText("Picking up containers while flying will get you stuck! You aren't flying now.", 5)
		end
	end

	self.tick = self.tick + 1
	if self.tick == 80 then
		self.tick = 0
		self.network:sendToServer("server_saveData", {character, self.settings["playerUUID"]})
	end
	
	return true, false
end

function Manager.client_onCreate(self)
	self.tick = 0
	self.settings = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
	local character = self.tool:getOwner().character
	local player = self.tool:getOwner()
	self.network:sendToServer("server_stopFly", {character, player, true})
	if not Manager.instance or Manager.instance ~= self then
        Manager.instance = self
    end

	if self.settings["playerUUID"] == nil then
		self.settings["playerUUID"] = tostring(sm.uuid.new())
		sm.json.save(self.settings, "$CONTENT_DATA/Scripts/settings.json")
	end

	local stateData = sm.storage.load("stateData"..self.settings["playerUUID"])
	if stateData ~= nil then
		self.network:sendToServer("server_initState", {character, stateData})
	end
end

function Manager.server_saveData(self, data)
	sm.storage.save("stateData"..data[2], {data[1]:isSwimming(), data[1]:isDiving(), data[1].publicData.waterMovementSpeedFraction})
end

function Manager.server_initState(self, data)
	data[1]:setSwimming(data[2][1])
	data[1]:setDiving(data[2][2])
	data[1].publicData.waterMovementSpeedFraction = data[2][3]
end

function Manager.server_stopFly(self, data)
	if data[3] then
		data[1].publicData.waterMovementSpeedFraction = 1
	end
	data[1]:setSwimming(false)
	data[1]:setDiving(false)
	data[1].publicData.waterMovementSpeedFraction = data[1].publicData.waterMovementSpeedFraction * 0.5
end

function Manager.server_Fly(self, params, caller)
	local character = params["player"]:getCharacter()
	self.network:sendToClient(params["player"], "client_Fly", {character:isSwimming()})
    local factor = character.publicData.waterMovementSpeedFraction
	if character:isDiving() then
		factor = factor * 0.5	
	else
		factor = factor * 2
	end
	character:setDiving(not character:isDiving())
	character:setSwimming(not character:isSwimming())
	character.publicData.waterMovementSpeedFraction = factor
end

function Manager.client_FlightMode(self, params, caller)
	local character = params["player"]:getCharacter()
	if params[2] == "normal" or params[2] == "swim" or params[2] == "dive" then
		self.settings["flightMode"] = params[2]
		sm.json.save(self.settings, "$CONTENT_DATA/Scripts/settings.json")
		if self.settings["flightMode"] == "normal" then
			character:setDiving(character:isSwimming())
			character:setSwimming(character:isDiving())
		elseif self.settings["flightMode"] == "swim" then
			character:setSwimming(character:isDiving())
			character:setDiving(false)
		else
			character:setDiving(character:isSwimming())
			character:setSwimming(false)
		end
	end
end

function Manager.client_Fly(self, data)
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
	self.network:sendToClient(params["player"], "client_Speed", params[2])
end

function Manager.client_Speed(self, speed)
	if self.settings["alertTextEnabled"] then
		sm.gui.displayAlertText("Set speed to " .. speed .. "x", 2)
	end
end

function Manager.client_ToggleAlertText(self, params, caller)
	if params[2] == true or params[2] == false then
		self.settings["alertTextEnabled"] = params[2]
		print(self.settings)
		sm.json.save(self.settings, "$CONTENT_DATA/Scripts/settings.json")
		
		sm.gui.displayAlertText("Test")

		if params[2] then
			sm.gui.displayAlertText("Alert text like this is now on.")
		else
			sm.gui.displayAlertText("Alert text like this has been disabled.")
		end
	end
end

local BindCommand = BindCommand or sm.game.bindChatCommand

function sm.game.bindChatCommand(command, params, callback, help)
    if not hooked then
        BindCommand("/speed", { { "string", " Speed Multiplier", false } }, "cl_onChatCommand", "Set speed multipler. 1 for normal, 2 for double, 0.5 for half, etc.")
		BindCommand("/flightMode", { { "string", " Mode", false } }, "cl_onChatCommand", "Changes flight mode.\nNormal for, well, normal.\nSwim for swimming only. (up/down speed isn't applied but particles are gone.)\nDive for diving. Kind of useless.")
		BindCommand("/fly", {}, "cl_onChatCommand", "Toggle fly mode. Same as FlyShake™")
		BindCommand("/shakeAlertText", { { "bool", "", false } }, "cl_onChatCommand", "Whether or not alert text is shown in the mod. True or false.")
        hooked = true
    end
    
    BindCommand(command, params, callback, help)
end

-- Need to replace below because its bad but still works in meantime
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
        sm.event.sendToTool(Manager.instance.tool, "client_ToggleAlertText", params)
    elseif params[1] == "/flightMode" then
        sm.event.sendToTool(Manager.instance.tool, "client_FlightMode", params)
    else
        oldWorldEvent(world, callback, params)
    end
end