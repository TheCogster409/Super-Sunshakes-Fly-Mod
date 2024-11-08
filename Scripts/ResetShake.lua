ResetShake = class()

  function ResetShake.client_onInteract(self, character, state)
    if not state then return end
    local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		if json["alertTextEnabled"] then
      sm.gui.displayAlertText("The ResetShake™ your inner Woc to normal levels...", 2)
    end
    self.network:sendToServer("server_deleteSelf", character)
  end

  function ResetShake.server_deleteSelf(self, character)
    if character:isSwimming() then
      character.publicData.waterMovementSpeedFraction = 2
    else
      character.publicData.waterMovementSpeedFraction = 1  
    end
    self.shape:destroyShape()
  end
