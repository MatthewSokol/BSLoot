local addonName, bsloot = ...
local moduleName = addonName.."_standby"
local bsloot_standby = bsloot:NewModule(moduleName, "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
local C = LibStub("LibCrayon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local LD = LibStub("LibDialog-1.0")
local DF = LibStub("LibDeformat-3.0")
local T = LibStub("LibQTip-1.0")

bsloot_standby.roster = {}

function bsloot_standby:checkReady(name)
  --check if the player is still at computer/ready
end

--heartbeat to standby players
--call up by role (awarding spot to first to answer)
--call specific player
--UI popup to respond
--will need to manually add alts for some