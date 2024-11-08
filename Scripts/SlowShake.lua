SlowShake = class()

  function SlowShake.client_onInteract(self, character, state)
    if not state then return end
    local json = sm.json.open("$CONTENT_DATA/Scripts/settings.json")
		if json["alertTextEnabled"] then
      sm.gui.displayAlertText("The SlowShake™ discharges your inner Woc beyond comprehension...", 2)
    end
    self.network:sendToServer("server_deleteSelf", character)
  end

  function SlowShake.server_deleteSelf(self, character)
    if character:isSwimming() then
      character.publicData.waterMovementSpeedFraction = 1
    else
      character.publicData.waterMovementSpeedFraction = 0.5 
    end
    self.shape:destroyShape()
  end
