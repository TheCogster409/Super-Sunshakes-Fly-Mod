TurboShake = class()

  function TurboShake.client_onInteract(self, character, state)
    if not state then return end
    local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		if json["alertTextEnabled"] then
      sm.gui.displayAlertText("The TurboShake™ charges up your inner Woc to extreme levels...", 2)
    end
    self.network:sendToServer("server_deleteSelf", character)
  end

  function TurboShake.server_deleteSelf(self, character)
    if character:isSwimming() then
      character.publicData.waterMovementSpeedFraction = 20
    else
      character.publicData.waterMovementSpeedFraction = 10
    end
    self.shape:destroyShape()
  end