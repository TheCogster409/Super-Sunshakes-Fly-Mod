FlyShake = class()

  function FlyShake.client_onInteract(self, character, state)
    if not state then return end
    local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		if json["alertTextEnabled"] then
      if character:isSwimming() then
        sm.gui.displayAlertText("Disabled fly mode.", 2)
      else
        sm.gui.displayAlertText("Enabled fly mode.", 2)
      end
    end
    self.network:sendToServer("server_deleteSelf", character)
  end

  function FlyShake.server_deleteSelf(self, character)
    character:setSwimming(not character:isSwimming())

    if character:isSwimming() then
      character.publicData.waterMovementSpeedFraction = 2
    else
      character.publicData.waterMovementSpeedFraction = 1  
    end

    self.shape:destroyShape()
  end
