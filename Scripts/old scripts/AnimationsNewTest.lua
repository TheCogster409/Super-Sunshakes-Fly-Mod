ShakeTool = class()

function capitalizeFirstLetter(string)
    return string:sub(1, 1):upper() .. string:sub(2)
end

local ShakeRenderable = { "$MOD_DATA/Objects/Renderable/Tools/"}--..capitalizeFirstLetter(self.data["Type"]).."Shake.rend" }
local RenderablesEattoolTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_eattool.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_eattool/char_eattool_tp.rend" }
local RenderablesEattoolFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_eattool.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_eattool/char_eattool_fp.rend" }
sm.tool.preloadRenderables(ShakeRenderable)
sm.tool.preloadRenderables(RenderablesEattoolTp)
sm.tool.preloadRenderables(RenderablesEattoolFp)

function ShakeTool.client_onRefresh( self )
	self:client_updateEatRenderables()
end

function ShakeTool.client_loadAnimations(self)

    -- Use AnimationUtil.lua to auto-create animation stuff
    self.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "Idle" },
			sprint = { "Sprint_fwd" },
			pickup = { "Pickup", { nextAnimation = "idle" } },
			putdown = { "Putdown" }
		}
	)
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
end

function ShakeTool.client_onCreate( self )
    self.drinkEffectAudio = sm.effect.createEffect( "Eat - DrinkSound" )
    self:client_loadAnimations()
end

function ShakeTool.client_onUpdate(self, dt)

    -- logic to swap between animations
    local isSprinting =  self.tool:isSprinting()
	local isCrouching =  self.tool:isCrouching()
	local isOnGround =  self.tool:isOnGround()

    if self.tool:isLocal() then
        --self.tool:updateFpAnimation("Idle", self.animProgress, 1.0, true)
        if self.equipped then
			if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
				--print("sprint")
                self.tool:updateFpAnimation("Sprint_idle", self.animProgress, 1, true)
                swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not self.tool:isSprinting() and ( self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto" ) then
				--print("walk")
                swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end
			if not isOnGround and self.wasOnGround and self.fpAnimations.currentAnimation ~= "jump" then
				--print("jump")
                swapFpAnimation( self.fpAnimations, "land", "jump", 0.02 )
			elseif isOnGround and not self.wasOnGround and self.fpAnimations.currentAnimation ~= "land" then
				--print("land")
                swapFpAnimation( self.fpAnimations, "jump", "land", 0.02 )
			end
		end

        -- Temporary code to only play idle animation as I cant figure it out right now
        if not self.animProgress then self.animProgress = 0 end
        self.animProgress = self.animProgress + dt
        self.tool:updateFpAnimation("Idle", self.animProgress, 1, true)
        
        --updateFpAnimations( self.fpAnimations, self.equipped, dt )

        self.wasOnGround = isOnGround
    else
        self:client_updateEatRenderables()
    end
end

-- Equip/dequip stuff
function ShakeTool.client_onEquip(self)
    self:client_updateEatRenderables()
	self.equipped = true
end
function ShakeTool.client_onUnequip(self)
	self.equipped = false
end

-- Get the models and renderables working
function ShakeTool.client_updateEatRenderables(self)
	local currentRenderablesTp = {}
	local currentRenderablesFp = {}
	
	for i, renderable in pairs(RenderablesEattoolTp) do currentRenderablesTp[#currentRenderablesTp+1] = renderable end
	for i, renderable in pairs(RenderablesEattoolFp) do currentRenderablesFp[#currentRenderablesFp+1] = renderable end

	for i, renderable in pairs(ShakeRenderable) do currentRenderablesTp[#currentRenderablesTp+1] = renderable end
	for i, renderable in pairs(ShakeRenderable) do currentRenderablesFp[#currentRenderablesFp+1] = renderable end
	
	self.tool:setTpRenderables(currentRenderablesTp)
	if self.tool:isLocal() then
		self.tool:setFpRenderables(currentRenderablesFp)
	end
end