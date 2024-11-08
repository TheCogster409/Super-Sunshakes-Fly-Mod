SpeedShake = class()

  function SpeedShake.client_onInteract(self, character, state)
    if not state then return end
    local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		if json["alertTextEnabled"] then
      sm.gui.displayAlertText("The SpeedShake™ charges up your inner Woc inside you...", 2)
    end
    self.network:sendToServer("server_deleteSelf", character)
  end

  function SpeedShake.server_deleteSelf(self, character)
    if character:isSwimming() then
      character.publicData.waterMovementSpeedFraction = 8
    else
      character.publicData.waterMovementSpeedFraction = 4  
    end
    self.shape:destroyShape()
  end
