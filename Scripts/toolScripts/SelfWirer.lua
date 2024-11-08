dofile( "$GAME_DATA/Scripts/game/AnimationUtil.lua" )
dofile( "$GAME_DATA/Scripts/game/BasePlayer.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
selfWirer = class()

BasePlayer.onReload = BasePlayer.onReload or function(self) return true end

local renderables = {
	"$CONTENT_DATA/Animations/Char_Tools/Char_connecttool/char_connecttool.rend"
}

local renderablesTp = {
	"$CONTENT_DATA/Animations/Char_Male/Animations/char_male_tp_connecttool.rend",
	"$CONTENT_DATA/Animations/Char_Tools/Char_connecttool/char_connecttool_tp_animlist.rend"
}
local renderablesFp = {
	"$CONTENT_DATA/Animations/Char_Tools/Char_connecttool/char_connecttool_fp_animlist.rend"
}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

function selfWirer.client_onUpdate( self )
	self:loadAnimations()
end

function selfWirer.loadAnimations( self )

	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "connecttool_idle" },
			pickup = { "connecttool_pickup", { nextAnimation = "idle" } },
			putdown = { "connecttool_putdown" },
		}
	)
	local movementAnimations = {
		idle = "connecttool_idle",
		idleRelaxed = "connecttool_idle_relaxed",

		sprint = "connecttool_sprint",
		runFwd = "connecttool_run_fwd",
		runBwd = "connecttool_run_bwd",

		jump = "connecttool_jump",
		jumpUp = "connecttool_jump_up",
		jumpDown = "connecttool_jump_down",

		land = "connecttool_jump_land",
		landFwd = "connecttool_jump_land_fwd",
		landBwd = "connecttool_jump_land_bwd",

		crouchIdle = "connecttool_crouch_idle",
		crouchFwd = "connecttool_crouch_fwd",
		crouchBwd = "connecttool_crouch_bwd"
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	setTpAnimation( self.tpAnimations, "idle", 5.0 )

	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "connecttool_pickup", { nextAnimation = "idle" } },
				unequip = { "connecttool_putdown" },

				idle = { "connecttool_idle", { looping = true } },
				idleFlip = { "connecttool_idle_flip", { nextAnimation = "idle", blendNext = 0.5 } },
				idleUse = { "connecttool_use_idle" },

				sprintInto = { "connecttool_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 5.0 } },
				sprintExit = { "connecttool_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },
				sprintIdle = { "connecttool_sprint_idle", { looping = true } },
			}
		)
	end
	self.blendTime = 0.2
end

function selfWirer.client_onUpdate( self, dt )

	local isSprinting =  self.tool:isSprinting()
	local isCrouching =  self.tool:isCrouching()

	if self.tool:isLocal() then
		if self.equipped then
			if self.fpAnimations.currentAnimation ~= "idleFlip" then
				if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
					swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
				elseif not self.tool:isSprinting() and ( self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto" ) then
					swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
				end
			end
		end
		updateFpAnimations( self.fpAnimations, self.equipped, dt )
	end

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end

	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			if animation.time >= animation.info.duration - self.blendTime then
				if name == "pickup" then
					setTpAnimation( self.tpAnimations, "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
				end
			end
		end
	end
end

function selfWirer.client_onEquip( self )

	sm.audio.play("ConnectTool - Equip")
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

function selfWirer.client_onUnequip( self )

	sm.audio.play("ConnectTool - Unequip")
	self.wantEquipped = false
	self.equipped = false
	if sm.exists( self.tool ) then
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.tool:isLocal() then
			if self.fpAnimations.currentAnimation ~= "unequip" then
				swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
			end
		end
	end
end

local gateConnect = sm.gui.getKeyBinding("Create", true)
local gateDisconnect = sm.gui.getKeyBinding("Attack", true)

function selfWirer.client_onEquippedUpdate(self, primaryState, secondaryState)
	local hit, result = sm.localPlayer.getRaycast(7.5)
	local Interactable
	if result.type == "body" then
		self.resultShape = result:getShape()
		Interactable = self.resultShape:getInteractable()
		local uuid = tostring(self.resultShape.uuid)
		print(tostring(self.resultShape.uuid))
		if uuid == "9f0f56e8-2c31-4d83-996c-d00a9b296c3f" or uuid == "bc336a10-675a-4942-94ce-e83ecb4b501a" then
			local parents = Interactable:getParents()
			if #parents == 0 then
				self.toggle = false
			else
				for i, parent in pairs(parents) do 
					if parent == Interactable then
						self.toggle = true
					else
						self.toggle = false
					end
				end
			end
			
			self.target = true
			if not self.toggle then
				sm.gui.setInteractionText(string.format("<strong><p textShadow='true' bg='gui_keybinds_bg' color='#ffffff' spacing='5'>Press%sto selfwire this logic gate</p></strong>", gateConnect))
			else
				sm.gui.setInteractionText(string.format("<strong><p textShadow='true' bg='gui_keybinds_bg' color='#ffffff' spacing='5'>Press%sto unselfwire this logic gate</p></strong>", gateDisconnect))
			end
		else
			self.target = false
		end 
	else
		self.target = false
	end
	
	if self.target then
		self.pos = self.resultShape:getWorldPosition()
		if primaryState == 2 then
			self.network:sendToServer("sv_conWire", Interactable)
		elseif secondaryState == 2 then
			self.network:sendToServer("sv_disConWire", Interactable)
		end
	end

    return true, true
end

function selfWirer.sv_conWire(self, Interactable, c)
	self.connect = Interactable:connect(Interactable)
    if self.connect then
		self.network:sendToClient(c, "cl_userCon")
    end
end

function selfWirer.sv_disConWire(self, Interactable, c)
    self.disconnect = Interactable:disconnect(Interactable)
    if self.disconnect then
        self.network:sendToClient(c, "cl_userDis")
    end
end

function selfWirer.cl_userCon(self)
    sm.gui.displayAlertText("Selfwire made")
    sm.audio.play("WeldTool - Sparks", self.pos)
	setFpAnimation(self.fpAnimations, "idleFlip", 0.2)
end

function selfWirer.cl_userDis(self)
    sm.gui.displayAlertText("Reset")
    sm.audio.play("WeldTool - Error", self.pos)
end