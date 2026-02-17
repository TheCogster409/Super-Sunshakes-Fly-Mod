SilverShakeTool = class()

function capitalizeFirstLetter(string)
    return string:sub(1, 1):upper() .. string:sub(2)
end

function lowercaseFirstLetter(string)
    return string:sub(1, 1):lower() .. string:sub(2)
end

function SilverShakeTool.client_onCreate(self)
    self.wantDrink = 0
    self.shakeMode = "speed"
    self.factor = 4
    self.lastForeBuild = false
    --[[
    Other modes:
    Speed
    Slow
    Turbo

    Fly mode is a seprate thing for right click, Reset has been removed
    ]]
end

function SilverShakeTool.client_onEquippedUpdate(self, primary, secondary, forceBuild)
    -- get some important stuff
	local character = self.tool:getOwner().character

    local settings = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
    local messages = sm.json.open("$CONTENT_DATA/Scripts/messages.json")

	local primaryBind = sm.gui.getKeyBinding("Create", true)
    local reloadBind = sm.gui.getKeyBinding("Reload", true)
    local forceBind = sm.gui.getKeyBinding("ForceBuild", true)
    local rotateBind = sm.gui.getKeyBinding("NextCreateRotation", true)

    if self.shakeMode == nil then -- nil check
        self.shakeMode = "speed"
        self.factor = 4
    end

    -- Knowing if we are already at our desired speed is important, as if so, speed will simply be reset back to normal
    local speedWontChange = self.factor == ((not (character:isSwimming() or character:isDiving())) and character.clientPublicData.waterMovementSpeedFraction or character.clientPublicData.waterMovementSpeedFraction * 0.5)

    -- Set interaction text for the set speed and set fly (speed checks for speedWontChange, fly checks for diving or swimming)
    if self.shakeMode == "speed" then
        sm.gui.setInteractionText("", primaryBind, speedWontChange and "Drink ResetShake™    " or "Drink SpeedShake™    ", reloadBind, "Open Mod Settings")
    elseif self.shakeMode == "slow" then
        sm.gui.setInteractionText("", primaryBind, speedWontChange and "Drink ResetShake™    " or "Drink SlowShake™    ", reloadBind, "Open Mod Settings")
    elseif self.shakeMode == "turbo" then
        sm.gui.setInteractionText("", primaryBind, speedWontChange and "Drink ResetShake™    " or "Drink TurboShake™    ", reloadBind, "Open Mod Settings")
    end
    -- set the mode swap interaction text and fly mode interaction text
    sm.gui.setInteractionText("", rotateBind, "Change Super SunShake™ ".. "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" .. "Current: " .. capitalizeFirstLetter(self.shakeMode) .. "</p>    ", forceBind, (character:isSwimming() or character:isDiving()) and "Drink FlyShake™ And Obey Newton" or "Drink FlyShake™ And Defy Gravity")

    -- Stop drink animation
    if self.drinkProgress == nil then
        self.drinkProgress = 0
    elseif self.drinkProgress >= 20 then
        self.tool:setBlockSprint(false)
        self.drinkProgress = 0
        self.drinking = false
		self.drinkEffectAudio:stop()
        self.drinkEffectTp:stop()

        if self.tool:isLocal() then
            setFpAnimation( self.fpAnimations, "idle", 0.25 )
        end
        setTpAnimation( self.tpAnimations, "idle", 10.0 )
    end

    ---- Fly Stuff ----
    if forceBuild ~= self.lastForceBuild then
        if forceBuild then
            if settings.alertTextEnabled then
                if character:isSwimming() then
                    sm.gui.displayAlertText("Your inner woc obeys Newton...", 2)
                else
                    sm.gui.displayAlertText("Your inner woc defies gravity...", 2)
                end
            end
            if character:isSwimming() then
                character.clientPublicData.waterMovementSpeedFraction = character.clientPublicData.waterMovementSpeedFraction * 0.5
            else
                character.clientPublicData.waterMovementSpeedFraction = character.clientPublicData.waterMovementSpeedFraction * 2
            end
            self.tool:setBlockSprint(true) -- Make sure to block sprinting!
            self.wantDrink = 5
            self.network:sendToServer("server_playerInteract", {true, 1, character, settings})
        end

        self.lastForceBuild = forceBuild
    end

    ---- Speed stuff ----

    if primary == sm.tool.interactState.start then
        if settings.alertTextEnabled then
            local factor = character.clientPublicData.waterMovementSpeedFraction
            if character:isSwimming() then
                factor = factor * 0.5
            end
            if speedWontChange then
                sm.gui.displayAlertText(messages[tostring(1 > factor)]["reset"], 2) -- Display reset text if we are already at desire desired speed
            else
                sm.gui.displayAlertText(messages[tostring(self.factor > factor)][self.shakeMode], 2)
            end
		end

        if character:isSwimming() then -- Make sure to set speed to normal if we are resetting speed!
            character.clientPublicData.waterMovementSpeedFraction = speedWontChange and 2 or self.factor * 2
        else
            character.clientPublicData.waterMovementSpeedFraction = speedWontChange and 1 or self.factor
        end
        
        self.network:sendToServer("server_playerInteract", {false, speedWontChange and 1 or self.factor, character, settings})
        self.tool:setBlockSprint(true) -- Make sure to block sprinting!
        self:client_startDrinkingAnimation()
    end

	return true, true
end

-- Server side set speed stuff
function SilverShakeTool.server_playerInteract(self, data)
    local speedOrFly = data[1]
    local factor = data[2]
    local character = data[3]
    local settings = data[4]

    if speedOrFly then -- Whether or not the server needs to set flight or speed
        if character:isSwimming() then
            character.publicData.waterMovementSpeedFraction = character.publicData.waterMovementSpeedFraction * 0.5
        else
            character.publicData.waterMovementSpeedFraction = character.publicData.waterMovementSpeedFraction * 2
        end

	    if settings["flightMode"] == "normal" then
	    	character:setDiving(not character:isDiving())
	    	character:setSwimming(not character:isSwimming())
	    elseif settings["flightMode"] == "swim" then
	    	character:setSwimming(not character:isSwimming())
	    else
	    	character:setDiving(not character:isDiving())
	    end
    else
        if character:isSwimming() then
            character.publicData.waterMovementSpeedFraction = factor * 2
        else
            character.publicData.waterMovementSpeedFraction = factor
        end
    end
end

function SilverShakeTool.client_onToggle(self) -- Rotate between speedshakes™, dont if force building
    if not self.forceBuild then
        if self.shakeMode == "speed" then
            self.shakeMode = "slow"
            self.factor = 0.5
        elseif self.shakeMode == "slow" then
            self.shakeMode = "turbo"
            self.factor = 10
        elseif self.shakeMode == "turbo" then
            self.shakeMode = "speed"
            self.factor = 4
        end
        return true
    else
        return false
    end
end

------------------------------------------------------------------------------------
-- GUI
------------------------------------------------------------------------------------
function SilverShakeTool.client_onReload(self)
    if self.settingsGUI == nil then
        self.settingsGUI = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/SettingsMenu.layout", false, {
            isHud = false,
            isInteractive = true,
            needsCursor = true,
            hidesHotbar = false,
            isOverlapped = false,
            backgroundAlpha = 0.0,
        })
        self.settingsGUI:setButtonCallback("ShakeAnimations", "client_settingsToggleChanged")
        self.settingsGUI:setButtonCallback("ShakeAlertText", "client_settingsToggleChanged")
        self.settingsGUI:createDropDown("FlightMode", "client_settingsFlightMode", {"Normal", "Swim", "Dive"})

        local settings = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
        self.guiSettings = {
            shakeAnimations = false,
            shakeAlertText = not settings["alertTextEnabled"]}
        self:client_settingsToggleChanged("ShakeAnimations", false)
        self:client_settingsToggleChanged("ShakeAlertText", false)
        self:client_settingsFlightMode(capitalizeFirstLetter(settings["flightMode"]))
    end
    self.settingsGUI:open()
	return true
end

function SilverShakeTool.client_settingsToggleChanged(self, button, actuallyToggle)
    if actuallyToggle == nil then actuallyToggle = true end
    if button == "ShakeAnimations" then
        self.guiSettings.shakeAnimations = not self.guiSettings.shakeAnimations
        self.settingsGUI:setText("ShakeAnimations", "Shakes In Hand    -    "..(self.guiSettings.shakeAnimations and "Enabled" or "Disabled"))
        if actuallyToggle then shakeAnimationsEnabled = self.guiSettings.shakeAnimations end
        
    elseif button == "ShakeAlertText" then
        self.guiSettings.shakeAlertText = not self.guiSettings.shakeAlertText
        self.settingsGUI:setText("ShakeAlertText", "Shake Alert Text    -    "..(self.guiSettings.shakeAlertText and "Enabled" or "Disabled"))

        if actuallyToggle then
            local settings = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
            settings["alertTextEnabled"] = self.guiSettings.shakeAlertText
            sm.json.save(settings, "$CONTENT_DATA/Scripts/settings.json")
        end
        if actuallyToggle then
            if self.guiSettings.shakeAlertText then
                sm.gui.displayAlertText("Alert text like this is now on.")
            else
                sm.gui.displayAlertText("Alert text like this has been disabled.")
            end
        end
    end
end

function SilverShakeTool.client_settingsFlightMode(self, option)
    local character = self.tool:getOwner().character
	if option == "Normal" or option == "Swim" or option == "Dive" then
        local settings = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		settings["flightMode"] = lowercaseFirstLetter(option)
		sm.json.save(settings, "$CONTENT_DATA/Scripts/settings.json")
		self.network:sendToServer("server_settingsFlightMode", {option, character})
	end

    if option == "Normal" then
        self.settingsGUI:setText("FlightModeDescriptionBox", "Functional but has visual bubbles.\nUse most of the time.")
        self.settingsGUI:setSelectedDropDownItem("FlightMode", "Normal")
    elseif option == "Swim" then
        self.settingsGUI:setText("FlightModeDescriptionBox", "No bubbles, but no extra speed upward.\nUse for recording and screenshots.")
        self.settingsGUI:setSelectedDropDownItem("FlightMode", "Swim")
    elseif option == "Dive" then
        self.settingsGUI:setText("FlightModeDescriptionBox", "Buggy, don't use.")
        self.settingsGUI:setSelectedDropDownItem("FlightMode", "Dive")
    end
end

function SilverShakeTool.server_settingsFlightMode(self, data)
	if data[1] == "Normal" then
		data[2]:setDiving(data[2]:isSwimming())
		data[2]:setSwimming(data[2]:isDiving())
	elseif data[1] == "Swim" then
		data[2]:setSwimming(data[2]:isDiving())
		data[2]:setDiving(false)
    elseif data[1] == "Dive" then
		data[2]:setDiving(data[2]:isSwimming())
		data[2]:setSwimming(false)
	end
end

------------------------------------------------------------------------------------
--  \/ Animations Below \/ (Coded mostly by Retro Dogo, thanks to him!)
------------------------------------------------------------------------------------

dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

local SilverShakeRenderable = { "$MOD_DATA/Objects/Renderable/Tools/SilverShake.rend" }

local RenderablesEattoolTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_eattool.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_eattool/char_eattool_tp.rend" }
local RenderablesEattoolFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_eattool.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_eattool/char_eattool_fp.rend" }

function SilverShakeTool.client_onCreate( self )
	self.tpAnimations = createTpAnimations( self.tool, {} )
	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations( self.tool, {} )
	end

	self.activeItem = sm.uuid.getNil()
    self.drinkEffectTp = sm.effect.createEffect( "Eat - Drink" )
    self.drinkEffectTp:setPosition( self.tool:getTpBonePos( "jnt_head" ) )
	self.drinkEffectTp:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.tool:getTpBoneDir( "jnt_head" ) ) )
    self.drinkEffectAudio = sm.effect.createEffect( "Eat - DrinkSound" )
    self.drinkEffectAudio:setPosition( self.tool:getTpBonePos( "jnt_head" ) )
    self.drinking = false
end

function SilverShakeTool.client_startDrinkingAnimation(self)
    if shakeAnimationsEnabled and not self.drinking then
        self.drinking = true
        self.drinkProgress = 0
        self.drinkEffectAudio:start()
    
        if self.tool:isLocal() then
            setFpAnimation( self.fpAnimations, "drink", 0.25 )
        end
        setTpAnimation( self.tpAnimations, "drink", 10.0 )
        if not self.tool:isInFirstPersonView() then
            self.drinkEffectTp:start()
            self.drinkEffectTp:setPosition( self.tool:getTpBonePos( "jnt_head" ) )
            self.drinkEffectTp:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.tool:getTpBoneDir( "jnt_head" ) ) )
        end
    end
end

function SilverShakeTool.client_onFixedUpdate(self)
    if self.drinking == true then
        self.drinkProgress = self.drinkProgress + 1
    end
end

function SilverShakeTool.client_onRefresh( self )
	self:cl_updateActiveFood()
end

function SilverShakeTool.client_onClientDataUpdate( self, clientData )
	if not self.tool:isLocal() then
		self.desiredActiveItem = clientData.activeUid
	end
end

function SilverShakeTool.cl_loadAnimations( self )

	self.tpAnimations = createTpAnimations(
			self.tool,
			{
				idle = { "Idle" },
                drink = { "Drink" },
				sprint = { "Sprint_fwd" },
				pickup = { "Pickup", { nextAnimation = "idle" } },
				putdown = { "Putdown" }
			
			}
		)
		local movementAnimations = {

			idle = "Idle",
			
			runFwd = "Run_fwd",
			runBwd = "Run_bwd",
			
			sprint = "Sprint_fwd",
			
			jump = "Jump",
			jumpUp = "Jump_up",
			jumpDown = "Jump_down",

			land = "Jump_land",
			landFwd = "Jump_land_fwd",
			landBwd = "Jump_land_bwd",

			crouchIdle = "Crouch_idle",
			crouchFwd = "Crouch_fwd",
			crouchBwd = "Crouch_bwd"
		}
		
		for name, animation in pairs( movementAnimations ) do
			self.tool:setMovementAnimation( name, animation )
		end
		
		if self.tool:isLocal() then
			self.fpAnimations = createFpAnimations(
				self.tool,
				{
					idle = { "Idle", { looping = true } },
					
                    drink = { "Drink" },

					sprintInto = { "Sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
					sprintIdle = { "Sprint_idle", { looping = true } },
					sprintExit = { "Sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },
					
					jump = { "Jump", { nextAnimation = "idle" } },
					land = { "Jump_land", { nextAnimation = "idle" } },
					
					equip = { "Pickup", { nextAnimation = "idle" } },
					unequip = { "Putdown" }
				}
			)
		end
		setTpAnimation( self.tpAnimations, "idle", 5.0 )
		self.blendTime = 0.2
end


function SilverShakeTool.client_onUpdate( self, dt )
    if self.lastShakeAnimationState ~= shakeAnimationsEnabled then
        self.lastShakeAnimationState = shakeAnimationsEnabled
        self:cl_updateActiveFood()
    end
    
    if not shakeAnimationsEnabled then
        self.equipped = false
        self.wantEquipped = false
        return
    end

    if self.wantDrink ~= nil and self.wantDrink > 0 then -- We need to wait 5 frames to play drinking animation when toggling fly mode, otherwise it doesnt play
        self.wantDrink = self.wantDrink - 1
        if self.wantDrink == 0 then
            self:client_startDrinkingAnimation()
        end
    end

    if not self.equipped then
        self.tool:setBlockSprint(false)
    end

	-- First person animation
	local isSprinting =  self.tool:isSprinting()
	local isCrouching =  self.tool:isCrouching()
	local isOnGround =  self.tool:isOnGround()
	
	if self.tool:isLocal() then
		if self.equipped then
			if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not self.tool:isSprinting() and ( self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto" ) then
				swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end
			if not isOnGround and self.wasOnGround and self.fpAnimations.currentAnimation ~= "jump" and not self.drinking then
				swapFpAnimation( self.fpAnimations, "land", "jump", 0.02 )
			elseif isOnGround and not self.wasOnGround and self.fpAnimations.currentAnimation ~= "land" and not self.drinking then
				swapFpAnimation( self.fpAnimations, "jump", "land", 0.02 )
            end
		end

		updateFpAnimations( self.fpAnimations, self.equipped, dt )

		self.wasOnGround = isOnGround
	end

	-- Update the equipped item for the clients that do not own the tool
	if not self.tool:isLocal() and self.activeItem ~= self.desiredActiveItem and self.tool:isEquipped() then
		self.activeItem = self.desiredActiveItem
		self:cl_updateActiveFood()
	end

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end
	
	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight 
	local totalWeight = 0.0
	
	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt
	
		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )
			
			if animation.time >= animation.info.duration - self.blendTime then
				if ( name == "eat" ) then
					setTpAnimation( self.tpAnimations, "pickup",  10.05 )
				elseif name == "drink" then
						setTpAnimation( self.tpAnimations, "pickup", 10.05 )
				elseif name == "pickup" then
					setTpAnimation( self.tpAnimations, "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
				end 
				
			end
		else
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
		end
	
		totalWeight = totalWeight + animation.weight
	end
	
	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( self.tpAnimations.animations ) do
		
		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			self.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end
	
end

function SilverShakeTool.client_onEquip( self, animate )
	if self.tool:isLocal() then
		self.activeItem = sm.localPlayer.getActiveItem()
		self:cl_updateActiveFood()
	else
		if not animate then
			-- reload renderable
			self.activeItem = sm.uuid.getNil()
		end
	end

	self.wantEquipped = true
end

function SilverShakeTool.cl_updateActiveFood( self )
	self:cl_updateEatRenderables()
	self:cl_loadAnimations()
	if self.activeItem == nil or self.activeItem == sm.uuid.getNil() then
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
		end
	else
		setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
		if self.tool:isLocal() then
			swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
		end
	end
end

function SilverShakeTool.cl_updateEatRenderables( self )
	
	local animationRenderablesTp = RenderablesEattoolTp
	local animationRenderablesFp = RenderablesEattoolFp

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}
	
	for k,v in pairs( animationRenderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( animationRenderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.emptyTpRenderables = shallowcopy( animationRenderablesTp )
	self.emptyFpRenderables = shallowcopy( animationRenderablesFp )

	for k,v in pairs( SilverShakeRenderable ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( SilverShakeRenderable ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	
	self.tool:setTpRenderables(shakeAnimationsEnabled and currentRenderablesTp or self.emptyTpRenderables)
	if self.tool:isLocal() then
		self.tool:setFpRenderables(shakeAnimationsEnabled and currentRenderablesFp or self.emptyFpRenderables)
	end
end

function SilverShakeTool.client_onUnequip( self )
	self.drinking = false
	self.activeItem = sm.uuid.getNil()
	if sm.exists( self.tool ) then
		self:cl_updateActiveFood()
		if self.tool:isLocal() then
			self.drinkProgress = 0
		end
	end

	self.wantEquipped = false
	self.equipped = false
end