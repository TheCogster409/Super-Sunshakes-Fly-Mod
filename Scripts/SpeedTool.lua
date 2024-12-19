SpeedTool = class()

function SpeedTool.client_onEquippedUpdate(self, primary, secondary, forceBuild)
	local character = self.tool:getOwner().character
	print(character.clientPublicData.waterMovementSpeedFraction)
	local primaryBind = sm.gui.getKeyBinding("Create", true)
	local forceBind = sm.gui.getKeyBinding("ForceBuild", true)

	if forceBuild then
		sm.gui.setInteractionText("", primaryBind, "Place")
		return false, false
	end

	sm.gui.setInteractionText("", primaryBind, "Set Speed to "..tostring(self.data["Factor"]).."x Normal Speed")
	sm.gui.setInteractionText("", forceBind, "Force Build")

	

	if primary == sm.tool.interactState.start and not forceBuild then
		self.network:sendToServer("server_speedup", {character, tostring(self.data["Factor"])})
		local factor = character.clientPublicData.waterMovementSpeedFraction
		if character:isSwimming() then
			factor = factor * 0.5
		end
		local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		print(factor)
		if character:isSwimming() then
			character.clientPublicData.waterMovementSpeedFraction = self.data["Factor"] * 2
		else
			character.clientPublicData.waterMovementSpeedFraction = self.data["Factor"]
		end

		if json["alertTextEnabled"] then
			local messages = sm.json.open("$CONTENT_DATA/Scripts/messages.json")
			if self.data["Factor"] == factor then
				sm.gui.displayAlertText("Nothing happens...", 2)
			else
				sm.gui.displayAlertText(messages[tostring(self.data["Factor"] > factor)][self.data["Type"]], 2)
			end
		end
	end
	return true, false
end

function SpeedTool.server_speedup(self, data)
	if data[1]:isSwimming() then
		data[1].publicData.waterMovementSpeedFraction = tonumber(data[2]) * 2
	else
		data[1].publicData.waterMovementSpeedFraction = tonumber(data[2])
	end
end

---------------------------------------------------------------------------
-- retros animation edit

dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

local SpeedShakeRenderable = { "$MOD_DATA/Objects/Renderable/SpeedShake.rend" }
local SlowShakeRenderable = { "$MOD_DATA/Objects/Renderable/SlowShake.rend" }
local TurboShakeRenderable = { "$MOD_DATA/Objects/Renderable/TurboShake.rend" }
local ResetShakeRenderable = { "$MOD_DATA/Objects/Renderable/ResetShake.rend" }

local typeToShake = {
	["speed"] = SpeedShakeRenderable,
	["slow"] = SlowShakeRenderable,
	["turbo"] = TurboShakeRenderable,
	["reset"] = ResetShakeRenderable
}

local RenderablesEattoolTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_eattool.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_eattool/char_eattool_tp.rend" }
local RenderablesEattoolFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_eattool.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_eattool/char_eattool_fp.rend" }

function SpeedTool.client_onCreate( self )
	self.tpAnimations = createTpAnimations( self.tool, {} )
	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations( self.tool, {} )
	end

	self.activeItem = sm.uuid.getNil()
end

function SpeedTool.client_onRefresh( self )
	self:cl_updateActiveFood()
end

function SpeedTool.client_onClientDataUpdate( self, clientData )
	if not self.tool:isLocal() then
		self.desiredActiveItem = clientData.activeUid
	end
end

function SpeedTool.cl_loadAnimations( self )

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


function SpeedTool.client_onUpdate( self, dt )
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

function SpeedTool.client_onEquip( self, animate )
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

function SpeedTool.cl_updateActiveFood( self )
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

function SpeedTool.cl_updateEatRenderables( self )
	
	local animationRenderablesTp = RenderablesEattoolTp
	local animationRenderablesFp = RenderablesEattoolFp

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}
	
	for k,v in pairs( animationRenderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( animationRenderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.emptyTpRenderables = shallowcopy( animationRenderablesTp )
	self.emptyFpRenderables = shallowcopy( animationRenderablesFp )

	for k,v in pairs( typeToShake[self.data["Type"]] ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( typeToShake[self.data["Type"]] ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	
	self.tool:setTpRenderables( currentRenderablesTp )
	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
	end
end

function SpeedTool.client_onUnequip( self )
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