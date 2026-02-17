VendingMachine = class()

-- I "borrowed" some code from DPP's Dat Pixel Pack vending machine to make this.

-- Button callbacks
function VendingMachine.client_flyShakeButtonPressed(self)
    print("fly shake order")
    self.gui:close()
end

function VendingMachine.client_speedShakeButtonPressed(self)
    print("speed shake order")
    self.gui:close()
end

function VendingMachine.client_slowShakeButtonPressed(self)
    print("slow shake order")
    self.gui:close()
end

function VendingMachine.client_turboShakeButtonPressed(self)
    print("turbo shake order")
    self.gui:close()
end

function VendingMachine.client_resetShakeButtonPressed(self)
    print("reset shake order")
    self.gui:close()
end

function VendingMachine.client_onCreate(self) 

    -- GUI Stuff
    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/VendingMachine.layout", false, {
        isHud = false,
        isInteractive = true,
        needsCursor = true,
        hidesHotbar = false,
        isOverlapped = false,
        backgroundAlpha = 0.0,
    })
    self.gui:setImage("FlyShakeIcon", "$CONTENT_DATA/Gui/Icons/FlyShake.png")
    self.gui:setImage("SpeedShakeIcon", "$CONTENT_DATA/Gui/Icons/SpeedShake.png")
    self.gui:setImage("SlowShakeIcon", "$CONTENT_DATA/Gui/Icons/SlowShake.png")
    self.gui:setImage("TurboShakeIcon", "$CONTENT_DATA/Gui/Icons/TurboShake.png")
    self.gui:setImage("ResetShakeIcon", "$CONTENT_DATA/Gui/Icons/ResetShake.png")
    
    self.gui:setData("DescriptionText", "Super Sunshakes™ allow you to speed up, slow down, and FLY!\nCreations Of Greatness Incorporated, LLC is not responsible for any harm done to the consumer. Contains minimal lead,\ntime juice, and [ S I N G U L A R I T Y ].")

    self.gui:setButtonCallback("FlyShakeButton", "client_flyShakeButtonPressed")
    self.gui:setButtonCallback("SpeedShakeButton", "client_speedShakeButtonPressed")
    self.gui:setButtonCallback("SlowShakeButton", "client_slowShakeButtonPressed")
    self.gui:setButtonCallback("TurboShakeButton", "client_turboShakeButtonPressed")
    self.gui:setButtonCallback("ResetShakeButton", "client_resetShakeButtonPressed")

    -- Sunshakes inside the machine
    self.shakeRenderables = {
        sm.uuid.new("631b46aa-5a7d-4fe9-9294-ec431058d6c7"),
        sm.uuid.new("f0f57ae4-e8f4-4d3b-af28-e0a8c752a0aa"),
        sm.uuid.new("9393f6af-a473-4833-b34e-b6482c70aa09"),
        sm.uuid.new("1ad2874b-0f5c-4f9f-bafc-dd60ffe9a532"),
        sm.uuid.new("f4f4c787-2fb7-4c05-b6fd-f088400c3b1d"),
        sm.uuid.new("211a771b-6aa5-40c7-bf65-d743946656fe")
    }

    self.sunshakes = {}
    i = 1
    for x=0.2,-0.3451, -0.2725 do
        for y=0.3, -0.251, -0.275 do
            for z=0.45, 0.1749, -0.275 do
                local sunshakeEffect = sm.effect.createEffect("ShapeRenderable", self.interactable)
                sunshakeEffect:setParameter("uuid", self.shakeRenderables[math.ceil(i*0.333333)])
                sunshakeEffect:setParameter("uuid", self.shakeRenderables["fly"])
                sunshakeEffect:setParameter("color", sm.color.new(0,0,0))
                sunshakeEffect:setScale(sm.vec3.one()*0.25)
                sunshakeEffect:setOffsetPosition(sm.vec3.new(x,y,z))
                sunshakeEffect:setOffsetRotation(sm.quat.new(0, 0.7071068, 0, 0.7071068))
                sunshakeEffect:start()
                self.sunshakes[#self.sunshakes+1] = sunshakeEffect
                i = i + 1
            end
        end
    end
    --X: 0.2, -0.0725, -0.345   -0.2725
    --Y: 0.3, 0.025, -0.25      -0.275
    --Z: 0.45, 0
end

function VendingMachine.client_canInteract( self, character )
    local primaryBind = sm.gui.getKeyBinding("Use", true)
	sm.gui.setInteractionText("", primaryBind, "Buy a Super SunShake™")
	return true
end

function VendingMachine.client_onInteract(self)
    self.gui:open()
end

function VendingMachine.client_onDestroy( self )
    for i, effect in pairs(self.sunshakes) do
        effect:destroy()
    end
end