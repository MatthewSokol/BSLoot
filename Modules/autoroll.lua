local addonName, bsloot = ...
local moduleName = addonName.."_autoroll"
local bsloot_autoroll = bsloot:NewModule(moduleName, "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

actions = {
  0, --default, use the window manually
  1, --wishlist item, roll
  2, --bis roll
  3, --blacklisted, pass
  4, --have it, pass
}

function bsloot_autoroll:getAction(itemID,action)
  --[[check is enabled
  register for event of item presented
  react according to config
  ]]-- 
end

