FantWarn = class()
dofile("$CONTENT_40639a2c-bb9f-4d4f-b88c-41bfe264ffa8/Scripts/ModDatabase.lua")

-- Tool to warn users who have fant's advanced tools mod installed

function FantWarn.client_onCreate(self)
	if self.tool:isLocal() then
        print("hi")
        ModDatabase.loadDescriptions()
        ModDatabase.loadShapesets()
        ModDatabase.loadToolsets()
        local loadedMods = ModDatabase.getAllLoadedMods() -- Returns an array of localIds (UUIDs, strings)
        for i, localId in ipairs(loadedMods) do
            if ModDatabase.databases.descriptions[localId].fileId == 2851449097 then
                print("Super SunShakes™ Fly Mod Error:    00Fant's 'Advanced' Tools mod detected! Please remove it for Super SunShakes™ to work properly. I cannot fix the issues it creates and he will not fix them for me either.")
            self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/FantWarn.layout", false, {
                isHud = false,
                isInteractive = false,
                needsCursor = true,
                hidesHotbar = false,
                isOverlapped = false,
                backgroundAlpha = 0.0,
            })
            self.gui:open()
                break
            end
        end
        ModDatabase.unloadDescriptions()
        ModDatabase.unloadShapesets()
        ModDatabase.unloadToolsets()
    end
end