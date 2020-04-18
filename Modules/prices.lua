local addonName, bsloot = ...
local moduleName = addonName.."_prices"
local bsloot_prices = bsloot:NewModule(moduleName, "AceEvent-3.0")
local ST = LibStub("ScrollingTable")
local name_version = "BSLootFixed-1.0"

function bsloot_prices:OnEnable()
  local mzt,_,_,_,reason = GetAddOnInfo("MizusRaidTracker")
  if not (reason == "ADDON_MISSING" or reason == "ADDON_DISABLED") then
    local loaded, finished = IsAddOnLoaded("MizusRaidTracker")
    if loaded then
      self:ADDON_LOADED("ADDON_LOADED","MizusRaidTracker")
    else
      self:RegisterEvent("ADDON_LOADED")
    end
  end
end

function bsloot_prices:GetPrice(item, charName, rollType)
  if not (type(item)=="number" or type(item)=="string") then return end
  local price,itemId,data
  itemId = GetItemInfoInstant(item)
  if (itemId) then
    --Conjured 45 food or 55 water to demo
    if(itemId == 8076 or itemId == 8079) then
      return 0, 0
    end
    local itemKey = bsloot:buildEpGpEventReasonKey(bsloot.statics.eventType.GP_VAL, bsloot.statics.EPGP.LOOT, itemId)
    data = ItemGPCost[itemKey]
    if (data) then
      price = data.gp
    else
      bsloot:doWithItemInfo(itemId, 
        function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
          itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
          isCraftingReagent, itemId)
          price = (bsloot_prices:GetItemValue(itemLevel, itemRarity)^2) * 0.04 * bsloot_prices:GetItemValue(itemEquipLoc)
          bsloot:debugPrint("Ad hoc price calc("..bsloot:tableToString(itemName).."): " .. bsloot:tableToString(itemLevel) .. ", ".. bsloot:tableToString(itemRarity) .. ", "..bsloot:tableToString(itemEquipLoc) ..", "..bsloot:tableToString(price), 6)
        end)
    end
  end
  
  if(not rollType or rollType == nil and charName and charName ~= nil) then
    rollType = bsloot:getRollType(charName, itemId)
  end
  local basePrice = price
  if(rollType and rollType ~= nil) then
    if(rollType == -2) then
      price = price * 0.1
    elseif(rollType == -1) then
      price = price * 0.25
    end
  end
  price = bsloot:num_round(price)
  basePrice = bsloot:num_round(basePrice)
  return price, basePrice
end

function bsloot_prices:GetItemValue(ilvl, iQuality)
  local itemValue = 0
  if(iQuality == 5) then --Legendary
    itemValue = (ilvl - 1.1) / 1.1
  elseif(iQuality == 4) then --Epic
    itemValue = (ilvl - 1.3) / 1.3
  elseif(iQuality == 3) then --Blue/Rare
    itemValue = (ilvl - 1.84) / 1.6
  elseif(iQuality == 2) then --Green/Uncommon
    itemValue = (ilvl - 4) / 2
  end

end

function bsloot_prices:GetItemValue(iSlot) 
  local slotVal = 1
  if(iSlot == "" or iSlot == nil) then
    slotVal = 0.1
  elseif(iSlot == "INVTYPE_FINGER") then
    slotVal = 0.55
  elseif(iSlot == "INVTYPE_WEAPONMAINHAND") then
    slotVal = 0.7
  elseif(iSlot == "INVTYPE_RANGED" or iSlot == "INVTYPE_RANGEDRIGHT") then
    slotVal = 0.5
  elseif(iSlot == "INVTYPE_HEAD") then
    slotVal = 1
  elseif(iSlot == "INVTYPE_ROBE" or iSlot == "INVTYPE_CHEST") then 
    slotVal = 1
  elseif(iSlot == "INVTYPE_SHOULDER") then
    slotVal = 0.777
  elseif(iSlot == "INVTYPE_LEGS") then
    slotVal = 1
  elseif(iSlot == "INVTYPE_FEET") then
    slotVal = 0.777
  elseif(iSlot == "INVTYPE_2HWEAPON") then
    slotVal = 1.5
  elseif(iSlot == "INVTYPE_WRIST") then
    slotVal = 0.55
  elseif(iSlot == "INVTYPE_WEAPON") then
    slotVal = 0.7
  elseif(iSlot == "INVTYPE_SHIELD") then
    slotVal = 0.55
  elseif(iSlot == "INVTYPE_WAIST") then
    slotVal = 0.777
  elseif(iSlot == "INVTYPE_NECK") then
    slotVal = 0.55
  elseif(iSlot == "INVTYPE_HAND") then
    slotVal = 0.777
  elseif(iSlot == "INVTYPE_TRINKET") then
    slotVal = 0.7
  elseif(iSlot == "INVTYPE_HOLDABLE") then
    slotVal = 0.55
  elseif(iSlot == "INVTYPE_CLOAK") then
    slotVal = 0.55
  else
      --bsloot:debugPrint("Ad hoc price calc("..itemName.."): " .. itemLevel .. ", ".. itemRarity .. ", "..itemEquipLoc ..", "..price, 3)
  end
  -- bsloot:debugPrint("slot " .. iSlot .. " has mod value of ".. slotVal, 6)
  return slotVal
--[[
Off-hand	0.75
Wand	0.42

]]
end

function bsloot_prices:ADDON_LOADED(event,...)
  if ... == "MizusRaidTracker" then
    self:UnregisterEvent("ADDON_LOADED")
    local MRT_ItemCost = function(mrt_data)
      local itemstring = mrt_data.ItemString
      local dkpValue = self:GetPrice(itemstring, bsloot._playerName)
      local itemNote
      if not dkpValue then
        dkpValue = 0
        itemNote = ""
      else
        local dkpValue2 = math.floor(dkpValue*bsloot.db.profile.discount)
        itemNote = string.format("%d or %d", dkpValue, dkpValue2)
      end
      return dkpValue, mrt_data.Looter, itemNote, "", true
    end
    if MRT_RegisterItemCostHandlerCore then
      MRT_RegisterItemCostHandlerCore(MRT_ItemCost, addonName)
    end
  end
end

bsloot_prices._prices = prices

