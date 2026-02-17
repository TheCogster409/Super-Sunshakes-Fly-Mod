FlyShakeTool = class()

function FlyShakeTool.client_onEquippedUpdate(self, primary, secondary, forceBuild)
	local character = self.tool:getOwner().character
	local primaryBind = sm.gui.getKeyBinding("Create", true)
	local forceBind = sm.gui.getKeyBinding("ForceBuild", true)
	local rotateBind = sm.gui.getKeyBinding("NextCreateRotation", true)
	local reloadBind = sm.gui.getKeyBinding("Reload", true)

    -- Stop drink animation
    self:clientStopDrinkingAnimation()

	if forceBuild then
		sm.gui.setInteractionText("", primaryBind, "Place")
		return false, false
	end

    sm.gui.setInteractionText("", primaryBind, (character:isSwimming() or character:isDiving()) and "Drink FlyShake™ And Obey Newton " or "Drink FlyShake™ And Defy Gravity ", reloadBind, "Drink And Speedup to 4x")
    sm.gui.setInteractionText("", forceBind, "Force Build ", rotateBind, "Reset Speed")

	if primary == sm.tool.interactState.start and not forceBuild then
		local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		if json.alertTextEnabled then
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

        -- Start drink animation
        self.tool:setBlockSprint(true)
        self.wantDrink = 5
        self.network:sendToServer("server_startFly", character)
    end
    --print(self.equipped, self.wantEquipped)
	return true, false
end

function FlyShakeTool.client_onToggle(self) -- Reset speed upon pressing Q
	local character = self.tool:getOwner().character
	if character:isSwimming() then
		character.clientPublicData.waterMovementSpeedFraction = 2
	else
		character.clientPublicData.waterMovementSpeedFraction = 1
	end

	local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
	if json["alertTextEnabled"] then
		local messages = sm.json.open("$CONTENT_DATA/Scripts/messages.json")
		if self.data["Factor"] == factor then
			sm.gui.displayAlertText("Nothing happens...", 2)
		else
			sm.gui.displayAlertText(messages[tostring(1 > character.clientPublicData.waterMovementSpeedFraction)]["reset"], 2)
		end
	end

	self.network:sendToServer("server_speedup", {character, "1"})
	self.tool:setBlockSprint(true)
	self:client_startDrinkingAnimation()
	return true
end

function FlyShakeTool.client_onReload(self) -- Speedup upon pressing R
	local character = self.tool:getOwner().character
	if character:isSwimming() then
		character.clientPublicData.waterMovementSpeedFraction = 8
	else
		character.clientPublicData.waterMovementSpeedFraction = 4
	end

	local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
	if json["alertTextEnabled"] then
		local messages = sm.json.open("$CONTENT_DATA/Scripts/messages.json")
		if self.data["Factor"] == factor then
			sm.gui.displayAlertText("Nothing happens...", 2)
		else
			sm.gui.displayAlertText(messages[tostring(4 > character.clientPublicData.waterMovementSpeedFraction)]["speed"], 2)
		end
	end

	self.network:sendToServer("server_speedup", {character, "4"})
	self.tool:setBlockSprint(true)
	self:client_startDrinkingAnimation()
	return true
end

function FlyShakeTool.server_speedup(self, data)
	if data[1]:isSwimming() then
		data[1].publicData.waterMovementSpeedFraction = tonumber(data[2]) * 2
	else
		data[1].publicData.waterMovementSpeedFraction = tonumber(data[2])
	end
end

function FlyShakeTool.server_startFly(self, character)
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
end

------------------------------------------------------------------------------------
--  \/ Animations Below \/ (Coded mostly by Retro Dogo, thanks to him!)
------------------------------------------------------------------------------------

dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

local FlyShakeRenderable = { "$MOD_DATA/Objects/Renderable/Tools/FlyShake.rend" }

local RenderablesEattoolTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_eattool.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_eattool/char_eattool_tp.rend" }
local RenderablesEattoolFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_eattool.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_eattool/char_eattool_fp.rend" }

function FlyShakeTool.client_onCreate( self )
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

function FlyShakeTool.client_startDrinkingAnimation(self)
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

function FlyShakeTool.clientStopDrinkingAnimation(self)
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
end

function FlyShakeTool.client_onFixedUpdate(self)
    if self.drinking == true then
        self.drinkProgress = self.drinkProgress + 1
    end
end

function FlyShakeTool.client_onRefresh( self )
	self:cl_updateActiveFood()
end

function FlyShakeTool.client_onClientDataUpdate( self, clientData )
	if not self.tool:isLocal() then
		self.desiredActiveItem = clientData.activeUid
	end
end

function FlyShakeTool.cl_loadAnimations( self )

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


function FlyShakeTool.client_onUpdate( self, dt )
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

function FlyShakeTool.client_onEquip( self, animate )
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

function FlyShakeTool.cl_updateActiveFood( self )
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

function FlyShakeTool.cl_updateEatRenderables( self )
	
	local animationRenderablesTp = RenderablesEattoolTp
	local animationRenderablesFp = RenderablesEattoolFp

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}
	
	for k,v in pairs( animationRenderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( animationRenderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.emptyTpRenderables = shallowcopy( animationRenderablesTp )
	self.emptyFpRenderables = shallowcopy( animationRenderablesFp )

	for k,v in pairs( FlyShakeRenderable ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( FlyShakeRenderable ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	
	self.tool:setTpRenderables(shakeAnimationsEnabled and currentRenderablesTp or self.emptyTpRenderables)
	if self.tool:isLocal() then
		self.tool:setFpRenderables(shakeAnimationsEnabled and currentRenderablesFp or self.emptyFpRenderables)
	end
end

function FlyShakeTool.client_onUnequip( self )
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