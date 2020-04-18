local addonName, bsloot = ...
local moduleName = addonName.."_loot"
local bsloot_loot = bsloot:NewModule(moduleName,"AceEvent-3.0","AceHook-3.0","AceTimer-3.0")
local ST = LibStub("ScrollingTable")
local LD = LibStub("LibDialog-1.0")
local LDD = LibStub("LibDropdown-1.0")
local C = LibStub("LibCrayon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local GUI = LibStub("AceGUI-3.0")
local G = LibStub("LibGratuity-3.0")
local DF = LibStub("LibDeformat-3.0")

local data = { }

function bsloot_loot:tradeLootCallback(tradeTarget,itemColor,itemString,itemName,itemID,itemLink)
end

function bsloot_loot:raidLootAdmin()
  return (bsloot:GroupStatus()=="RAID" and bsloot:lootMaster() and bsloot:isAdmin())
end

function bsloot_loot:tradeLoot()
  --Can listen to "traded to" events?
end


