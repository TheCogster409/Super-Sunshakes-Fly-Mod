Silver = class()

function capitalizeFirstLetter(string)
    return string:sub(1, 1):upper() .. string:sub(2)
end

function Silver.client_onCreate(self)
    self.shakeMode = "fly"
    self.factor = 1
    --[[
    Other modes:
    Fly
    Speed
    Slow
    Turbo
    Reset
    ]]
end

function Silver.client_onEquippedUpdate(self, primary, secondary, forceBuild)
    local secretForceBuild = false
	local character = self.tool:getOwner().character

	local primaryBind = sm.gui.getKeyBinding("Create", true)
    local rotateBind = sm.gui.getKeyBinding("NextCreateRotation", true)

	if forceBuild and secretForceBuild then
		sm.gui.setInteractionText("", primaryBind, "Place")
		return false, false
	end

    if self.shakeMode == nil then
        self.shakeMode = "fly"
    end

    if self.shakeMode == "fly" then
        if character:isSwimming() then
            sm.gui.setInteractionText("", primaryBind, "Stop Flying")
        else
            sm.gui.setInteractionText("", primaryBind, "Start Flying")
        end
    elseif self.shakeMode == "speed" then
        sm.gui.setInteractionText("", primaryBind, "Set Speed to 4x Normal Speed")
    elseif self.shakeMode == "slow" then
        sm.gui.setInteractionText("", primaryBind, "Set Speed to 0.5x Normal Speed")
    elseif self.shakeMode == "turbo" then
        sm.gui.setInteractionText("", primaryBind, "Set Speed to 10x Normal Speed")
    elseif self.shakeMode == "reset" then
        sm.gui.setInteractionText("", primaryBind, "Set Speed to 1x Normal Speed")
    end
    sm.gui.setInteractionText("", rotateBind, "Rotate Mode", "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" .. "Current: " .. capitalizeFirstLetter(self.shakeMode) .. "</p>")

    if primary == sm.tool.interactState.start and not forceBuild then
		local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")

		if json.alertTextEnabled then
            if self.shakeMode == "fly" then
                if character:isSwimming() then
                    sm.gui.displayAlertText("Your inner woc obeys Newton...", 2)
                else
                    sm.gui.displayAlertText("Your inner woc defies gravity...", 2)
                end
            else
                local factor = character.clientPublicData.waterMovementSpeedFraction
		        if character:isSwimming() then
		        	factor = factor * 0.5
		        end
                local messages = sm.json.open("$CONTENT_DATA/Scripts/messages.json")
			    if self.factor == factor then
			    	sm.gui.displayAlertText("Nothing happens...", 2)
			    else
			    	sm.gui.displayAlertText(messages[tostring(self.factor > factor)][self.shakeMode], 2)
			    end
            end
		end

        if self.shakeMode == "fly" then
            if character:isSwimming() then
                character.clientPublicData.waterMovementSpeedFraction = character.clientPublicData.waterMovementSpeedFraction * 0.5
            else
                character.clientPublicData.waterMovementSpeedFraction = character.clientPublicData.waterMovementSpeedFraction * 2
            end
        else
            if character:isSwimming() then
                character.clientPublicData.waterMovementSpeedFraction = self.factor * 2
            else
                character.clientPublicData.waterMovementSpeedFraction = self.factor
            end
        end
        local settings = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
        self.network:sendToServer("server_playerInteract", {self.shakeMode, self.factor, character, settings})
	end

	return true, false
end

function Silver.server_playerInteract(self, data)
    local shakeMode = data[1]
    local factor = data[2]
    local character = data[3]
    local settings = data[4]

    if self.shakeMode == "fly" then
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

function Silver.client_onToggle(self)
    if self.shakeMode == "fly" then
        self.shakeMode = "speed"
        self.factor = 4
    elseif self.shakeMode == "speed" then
        self.shakeMode = "slow"
        self.factor = 0.5
    elseif self.shakeMode == "slow" then
        self.shakeMode = "turbo"
        self.factor = 10
    elseif self.shakeMode == "turbo" then
        self.shakeMode = "reset"
        self.factor = 1
    elseif self.shakeMode == "reset" then
        self.shakeMode = "fly"
        self.factor = nil
    end
    return true
end

---------------------------------------------------------------------------
-- retros animation edit

dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

local FlyShakeRenderable = { "$MOD_DATA/Objects/Renderable/SilverShake.rend" }

function Silver.client_onCreate( self )
	self.tpAnimations = createTpAnimations( self.tool, {} )
	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations( self.tool, {} )
	end

	self.activeItem = sm.uuid.getNil()
end

function Silver.client_onRefresh( self )
	self:cl_updateActiveFood()
end

function Silver.client_onClientDataUpdate( self, clientData )
	if not self.tool:isLocal() then
		self.desiredActiveItem = clientData.activeUid
	end
end

function Silver.cl_loadAnimations( self )

	self.tpAnimations = createTpAnimations(
			self.tool,
			{
				idle = { "Idle" },
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


function Silver.client_onUpdate( self, dt )
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
			if not isOnGround and self.wasOnGround and self.fpAnimations.currentAnimation ~= "jump" then
				swapFpAnimation( self.fpAnimations, "land", "jump", 0.02 )
			elseif isOnGround and not self.wasOnGround and self.fpAnimations.currentAnimation ~= "land" then
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

function Silver.client_onEquip( self, animate )
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

function Silver.cl_updateActiveFood( self )
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

function Silver.cl_updateEatRenderables( self )
	
	local animationRenderablesTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_eattool.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_eattool/char_eattool_tp.rend" }
	local animationRenderablesFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_eattool.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_eattool/char_eattool_fp.rend" }

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}
	
	for k,v in pairs( animationRenderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( animationRenderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.emptyTpRenderables = shallowcopy( animationRenderablesTp )
	self.emptyFpRenderables = shallowcopy( animationRenderablesFp )

	for k,v in pairs( FlyShakeRenderable ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( FlyShakeRenderable ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	
	self.tool:setTpRenderables( currentRenderablesTp )
	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
	end
end

function Silver.client_onUnequip( self )
	self.eating = false
	self.activeItem = sm.uuid.getNil()
	if sm.exists( self.tool ) then
		self:cl_updateActiveFood()
		if self.tool:isLocal() then
			self.eatProgress = 0
		end
	end

	self.wantEquipped = false
	self.equipped = false
end