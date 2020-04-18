local addonName, bsloot = ...
local moduleName = addonName.."_baseline"
local bsloot_baseline = bsloot:NewModule(moduleName, "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

bsloot_baseline.targetBaseline = "20200410.000"

function bsloot_baseline:trigger()
  if (not Baseline or Baseline ~= bsloot_baseline.targetBaseline) then
    bsloot_baseline:forceResetData()
    bsloot:debugPrint("Baseline Data applied: "..Baseline, 1)
  end
end

function bsloot_baseline:forceResetData()
  bsloot:resetAllStoredData(true)
  bsloot_baseline:applyData()
  Baseline = bsloot_baseline.targetBaseline
end

function bsloot_baseline:applyData()

  Baseline = nil
  EPGPCache = {}
    
EPGPTable = {
}
ItemGPCost =  {}
EPGPCache =  {}
CharRoleDB =  {}
SyncEvents =  {}
EPValues =  {}
BisMatrix = {}

  
end