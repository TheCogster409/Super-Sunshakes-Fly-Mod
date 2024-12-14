dofile( "$GAME_DATA/Scripts/game/AnimationUtil.lua" )
dofile( "$GAME_DATA/Scripts/game/BasePlayer.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

FlyTool = class()
FlyTool.emptyTpRenderables = {}
FlyTool.emptyFpRenderables = {}

local renderables = { "$CONTENT_DATA/Objects/Renderable/FlyShake.rend" }
local renderablesTp = { "$CONTENT_DATA/Animations/char_male_tp_eattool.rend", "$CONTENT_DATA/Animations/char_eattool_tp.rend" }
local renderablesFp = { "$CONTENT_DATA/Animations/char_male_fp_eattool.rend", "$CONTENT_DATA/Animations/char_eattool_fp.rend" }

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

local FoodUuidToRenderable = {
	[tostring( obj_consumable_sunshake )] = SunshakeRenderables,
}

function FlyTool.client_onCreate(self)
	self.tpAnimations = createTpAnimations( self.tool, {} )
	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations( self.tool, {} )
	end

	self.activeItem = sm.uuid.getNil()
	if self.tool:isLocal() then
		self.wasOnGround = true
		self.eatProgress = 0
		self.eatTime = 2.1
		self.munchEffectFp = sm.effect.createEffect( "Eat - MunchFP" )
	else
		self.desiredActiveItem = sm.uuid.getNil()
	end

	self.eating = false
	self.drinkEffectTp = sm.effect.createEffect( "Eat - Drink" )
	self.drinkEffectAudio = sm.effect.createEffect( "Eat - DrinkSound" )
end

function FlyTool.client_onUpdate(self, dt)
	self:loadAnimations()
end

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

function FlyTool.loadAnimations(self)
	self.animationsTp = createTpAnimations(
		self.tool, 
		{
			idle = {"Idle"}, 
			drink = {"Drink"},
			sprint = {"Sprint_fwd"},
			pickup = {"Pickup", {nextAnimation = "idle"}},
			putdown = {"Putdown"}
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
		self.animationsFp = createFpAnimations(
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
	setTpAnimation( self.animationsTp, "idle", 5.0 )
	self.blendTime = 0.2
end

function FlyTool.client_onUpdate(self, dt)
	local isSprinting =  self.tool:isSprinting()
	local isCrouching =  self.tool:isCrouching()
	local isOnGround =  self.tool:isOnGround()

	if self.tool:isLocal() then
		if self.equipped and self.eating == false then
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

	if self.tool:isLocal() then
		local activeItem = sm.localPlayer.getActiveItem()
		if self.activeItem ~= activeItem then
			if sm.item.getEdible( activeItem ) then
				-- Simulate a new equip
				self.activeItem = activeItem
				self:cl_updateEatRenderables()
				self:cl_loadAnimations()
				self.network:sendToServer( "sv_n_updateEatRenderables", self.activeItem )
				self:stopEat()
				self.network:sendToServer( "sv_n_stopEat" )
			end
		end
	end

	for name, animation in pairs( self.animationsTp.animations ) do
		animation.time = animation.time + dt

		if name == self.animationsTp.currentAnimation then
			if animation.time >= animation.info.duration - self.blendTime then
				if name == "pickup" then
					setTpAnimation( self.animationsTp, "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.animationsTp, animation.nextAnimation, 0.001 )
				end
			end
		end
	end


	if self.clicked then
		print("clicked")
		sm.audio.play("Blueprint - Delete")
	end
end

function FlyTool.client_onEquip( self )
	self.wantEquipped = true
	self.jointWeight = 0.0

	currentRenderablesTp = {}
	currentRenderablesFp = {}

	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	self.tool:setTpRenderables( currentRenderablesTp )

	self:loadAnimations()

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )

	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function FlyTool.client_onUnequip( self )
	self.wantEquipped = false
	self.equipped = false
	if sm.exists( self.tool ) then
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.tool:isLocal() then
			if self.fpAnimations.currentAnimation ~= "unequip" then
				print(self.fpAnimations)
				swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
			end
		end
	end
end

function FlyTool.server_startFly(self, character)
	character:setSwimming(not character:isSwimming())

	if character:isSwimming() then
		character.publicData.waterMovementSpeedFraction = 2
	else
		character.publicData.waterMovementSpeedFraction = 1  
	end
end