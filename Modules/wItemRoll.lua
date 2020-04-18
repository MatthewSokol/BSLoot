local addonName, bsloot = ...
local moduleName = addonName.."_window_roll_present"
local bsloot_window_roll_present = bsloot:NewModule(moduleName)
local ST = LibStub("ScrollingTable")
local C = LibStub("LibCrayon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local GUI = LibStub("AceGUI-3.0")
local LW = LibStub("LibWindow-1.1")

local PLATE, MAIL, LEATHER, CLOTH = 4,3,2,1
local DPS, CASTER, HEALER, TANK = 4,3,2,1
local class_to_armor = {
  PALADIN = PLATE,
  WARRIOR = PLATE,
  HUNTER = MAIL,
  SHAMAN = MAIL,
  DRUID = LEATHER,
  ROGUE = LEATHER,
  MAGE = CLOTH,
  PRIEST = CLOTH,
  WARLOCK = CLOTH,
}
local armor_text = {
  [CLOTH] = L["CLOTH"],
  [LEATHER] = L["LEATHER"],
  [MAIL] = L["MAIL"],
  [PLATE] = L["PLATE"],
}
local class_to_role = {
  PALADIN = {HEALER,DPS,TANK,CASTER},
  PRIEST = {HEALER,CASTER},
  DRUID = {HEALER,TANK,DPS,CASTER},
  SHAMAN = {HEALER,DPS,CASTER},
  MAGE = {CASTER},
  WARLOCK = {CASTER},
  ROGUE = {DPS},
  HUNTER = {DPS},
  WARRIOR = {TANK,DPS},
}
local role_text = {
  [TANK] = L["TANK"],
  [HEALER] = L["HEALER"],
  [CASTER] = L["CASTER"],
  [DPS] = L["PHYS DPS"],
}
local data = {}
local eligibleRollers = {}
local colorHighlight = {r=0, g=0, b=0, a=.9}

local function st_sorter_numeric(st,rowa,rowb,col)
  local cella = st.data[rowa].cols[col].value
  local cellb = st.data[rowb].cols[col].value
  local sort = st.cols[col].sort or st.cols[col].defaultsort
  if bsloot.db.char.classgroup then
    local classa = st.data[rowa].cols[5].value
    local classb = st.data[rowb].cols[5].value
    if classa == classb then
      if cella == cellb then
        local sortnext = st.cols[col].sortnext
        if sortnext then
          return st.data[rowa].cols[sortnext].value < st.data[rowb].cols[sortnext].value
        end
      else
        return tonumber(cella) > tonumber(cellb)
      end      
    else
      if sort == ST.SORT_DSC then
        return classa < classb
      else
        return classa > classb
      end
    end
  else
    if cella == cellb then
      local sortnext = st.cols[col].sortnext
      if sortnext then
        return st.data[rowa].cols[sortnext].value < st.data[rowb].cols[sortnext].value
      end
    else
      if sort == ST.SORT_DSC then
        return tonumber(cella) > tonumber(cellb)
      else
        return tonumber(cella) < tonumber(cellb)
      end
    end
  end
end

function bsloot_window_roll_present:OnEnable()
 
  bsloot_prices = bsloot:GetModule(addonName.."_prices")

  local smallContainer = GUI:Create("Window")
  smallContainer:SetTitle(L["Item To Roll On"])
  smallContainer:SetWidth(130)
  smallContainer:SetHeight(140)
  smallContainer:EnableResize(false)
  smallContainer:SetLayout("List")
  smallContainer:Hide()

  local bigContainer = GUI:Create("Window")
  bigContainer:SetTitle(L["Item To Roll On"])
  bigContainer:SetWidth(755)
  bigContainer:SetHeight(340)
  bigContainer:EnableResize(false)
  bigContainer:SetLayout("List")
  bigContainer:Hide()
  self._big_container = bigContainer

  self._itemLabel = GUI:Create("InteractiveLabel")
  --[[
    
  SetImageSize(width, height) - Set the size of the image.
  ]]--
  if(self.item) then
    self._itemLabel:SetText(self.item)
  end
  self._big_container:AddChild(self._itemLabel)
  self._currentEquippedItemLabel = GUI:Create("InteractiveLabel")
  self._big_container:AddChild(self._currentEquippedItemLabel)

  
  self._playerEpLabel = GUI:Create("Label")
  self._big_container:AddChild(self._playerEpLabel)
  self._playerGpLabel = GUI:Create("Label")
  self._big_container:AddChild(self._playerGpLabel)
  self._playerPrLabel = GUI:Create("Label")
  self._big_container:AddChild(self._playerPrLabel)
  self._blankLabel = GUI:Create("Label")
  self._big_container:AddChild(self._blankLabel)

  self._itemGpLabel = GUI:Create("Label")
  self._big_container:AddChild(self._itemGpLabel)
  self._previewPrLabel = GUI:Create("Label")
  self._big_container:AddChild(self._previewPrLabel)
  
  local needButton = GUI:Create("Button")
    needButton:SetAutoWidth(true)
    needButton:SetText(L["Need"])
    needButton:SetCallback("OnClick",function()
    bsloot:broadcast("!need "..self._itemId, self.sender)
  end)
  bigContainer:AddChild(needButton)
  self._needButton = needButton
  
  local passButton = GUI:Create("Button")
    passButton:SetAutoWidth(true)
    passButton:SetText(L["Pass"])
    passButton:SetCallback("OnClick",function()
    bsloot:broadcast("!pass "..self._itemId, self.sender)
  end)
  bigContainer:AddChild(passButton)

  local announceButton = GUI:Create("Button")
  announceButton:SetAutoWidth(true)
  announceButton:SetText(L["Announce"])
  announceButton:SetCallback("OnClick",function()
    if(bsloot_window_roll_present.announced) then
      return
    end
    bsloot:SendChat("LAST CALL for: "..self.item, bsloot.db.profile.chat.presentItemToRollOn);
    bsloot_window_roll_present.announced = true
    -- DBM:CreatePizzaTimer(10, "LAST CALL")
    DBM:CreatePizzaTimer(10, "LAST CALL for "..self.item, true)
    C_Timer.After(10, function()
      local winners = {}
      local highestRoll = nil
        for _,roll in pairs(rollsByChar) do
          local effPr = tonumber(roll.effectivePr)
          if(highestRoll == nil or effPr > highestRoll) then
            bsloot:debugPrint(roll.charName .. " beats current max bid of ".. bsloot:tableToString(highestRoll) .. " with " .. roll.effectivePr )
            winners = {}
            highestRoll = effPr
            table.insert(winners, roll.charName)
          elseif(effPr == highestRoll) then
            table.insert(winners, roll.charName)
          end
        end
          
        if(#winners ~= 0) then
          if(#winners == 1) then
            --1 winner
            local gpValue = bsloot_prices:GetPrice(self.item, winners[1])
            bsloot:SendChat("Winner for "..self.item.." is "..winners[1].." (".. gpValue.." GP)", bsloot.db.profile.chat.lootResult, winners);
            
            local winnerMsg = "itemWinner "..winners[1].." "..self.item
            bsloot:broadcast(winnerMsg, bsloot.test_mode_vars.channel)
            bsloot_window_roll_present:TakeScreenShotThenDo(function()
              bsloot:broadcast("clearLoot")
            end)
          else
            -- It's a tie
            local winnersList = ""
            local winnersListDiv = ""
            for _,p in ipairs(winners) do
              winnersList = winnersList .. winnersListDiv .. p
              winnersListDiv = ", "
            end
            bsloot:SendChat("Winners for "..self.item.." are "..winnersList..". Roll for the tie", bsloot.db.profile.chat.lootResult, winners);
            self._resolveTieButton:SetDisabled(false)
          end
        else
          --No rolls
          bsloot:SendChat("No rolls for "..self.item..", it will be sharded", bsloot.db.profile.chat.lootResult);
          bsloot_window_roll_present:TakeScreenShotThenDo(function()
            bsloot:broadcast("clearLoot")
          end)
        end

    end)
  end)
  announceButton:SetDisabled(true)
  self._announceButton = announceButton
  bigContainer:AddChild(announceButton)

  local resolveTieButton = GUI:Create("Button")
  resolveTieButton:SetAutoWidth(true)
  resolveTieButton:SetText(L["Resolve Tie"])
  resolveTieButton:SetCallback("OnClick",function()
    
    if(bsloot_window_roll_present.announced) then
      return
    end
    bsloot_window_roll_present.announced = true
    local selected = self._standings_table:GetSelection()
    if(selected and selected ~= nil and selected > 0) then
      local selectedRow = self._standings_table:GetRow(selected)
      bsloot:debugPrint("Selected row: "..bsloot:tableToString(selectedRow), 7)
      local winningName = selectedRow.cols[1].value
      local gpValue = bsloot_prices:GetPrice(self.item, winningName)
      bsloot:SendChat("Winner for "..self.item.." is "..winningName .." (".. gpValue.." GP)", bsloot.db.profile.chat.lootResult, winningName)
      bsloot:chargeGpForItem(self._itemId, winningName)
      local winnerMsg = "itemWinner "..winningName.." "..self.item
      bsloot:broadcast(winnerMsg, bsloot.test_mode_vars.channel)
      bsloot_window_roll_present:TakeScreenShotThenDo(function()
        bsloot:broadcast("clearLoot")
      end)
    else
      message("You must select the row which has the winning roll")
    end
  end)
  resolveTieButton:SetDisabled(true)
  self._resolveTieButton = resolveTieButton
  bigContainer:AddChild(resolveTieButton)
    
  self._standingsFrame = GUI:Create("SimpleGroup")
  self._standingsFrame:SetWidth(525)
  self._standingsFrame:SetHeight(300)
  self._standingsFrame:SetPoint("TOPRIGHT",self._big_container.frame,"TOPRIGHT", -10, -45)
  bigContainer:AddChild(self._standingsFrame)

  self._missingRolls = GUI:Create("SimpleGroup")
  self._missingRolls:SetWidth(40)
  self._missingRolls:SetHeight(150)
  self._missingRolls:SetPoint("TOPRIGHT",self._big_container.frame,"TOPRIGHT", -590, -300)
  bigContainer:AddChild(self._missingRolls)

  bsloot:make_escable(bigContainer,"add")
end
function bsloot_window_roll_present:getCurrentItem()
  return self._itemId, self.item
end

function bsloot_window_roll_present:presentItem(sender, item, inEligibleRollers, rollType, shouldShow)
  bsloot:doWithItemInfo(item, function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
  itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
  isCraftingReagent, itemId)
  bsloot:removePrint("DOING WITH INFO(item) ("..bsloot:tableToString(itemId)..")= "..bsloot:tableToString(itemName)..", "..bsloot:tableToString(itemLink)..", "..bsloot:tableToString(itemRarity)..", "..bsloot:tableToString(itemLevel)..", "..bsloot:tableToString(itemMinLevel)..", "..bsloot:tableToString(itemType)..", "..bsloot:tableToString(itemSubType)..", "..bsloot:tableToString(itemStackCount)..", "..bsloot:tableToString(itemEquipLoc)..", "..bsloot:tableToString(itemIcon)..", "..bsloot:tableToString(itemSellPrice)..", "..bsloot:tableToString(itemClassID)..", "..bsloot:tableToString(itemSubClassID)..", "..bsloot:tableToString(bindType)..", "..bsloot:tableToString(expacID)..", "..bsloot:tableToString(itemSetID)..", "..bsloot:tableToString(isCraftingReagent))
  bsloot:removePrint("itemLink: "..bsloot:tableToString(itemLink))
  self._itemScreenshotted = false
  self.sender = sender
  self.eligibleRollers = inEligibleRollers
  self.item = itemLink
  local tempItemId = GetItemInfoInstant(itemLink)
  if(tempItemId ~= nil) then
    self._itemId = tempItemId
    if(rollType and rollType ~= nil and rollType == -3) then
      self._needButton:SetDisabled(true)
    else
      self._needButton:SetDisabled(false)
    end
    if(self._itemLabel) then
      self._itemLabel:SetText(self.item)
      self._itemLabel:SetImage(itemIcon)
      
      self._itemLabel:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(self._big_container.frame,"ANCHOR_TOP")
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
      
      end)
      self._itemLabel:SetCallback("OnLeave", function(widget)
        if GameTooltip:IsOwned(self._big_container.frame) then
          GameTooltip_Hide()
        end
      end)
      -- TODO implement see https://wow.gamepedia.com/ItemEquipLoc consider tokens, 2h vs 1h + oh, etc
      -- local itemSlotId, _ = GetInventorySlotInfo(itemEquipLoc)
      -- equpippedItem = GetInventoryItemLink("player", itemSlotId)
      -- bsloot:doWithItemInfo(equpippedItem, function(itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
      -- itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
      -- isCraftingReagent, itemId)
      -- bsloot:removePrint("Gear in slot is: "..equpippedItem..". "..equpippedItemName)
      -- self._currentEquippedItemLabel:SetText("Currently Equipped: "..equpippedItemLink)
      -- self._currentEquippedItemLabel:SetImage(equpippedItemIcon)
      --   end)
      
      self._currentEquippedItemLabel:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(self._big_container.frame,"ANCHOR_TOP")
        GameTooltip:SetHyperlink(equpippedItemLink)
        GameTooltip:Show()
      
      end)
      self._currentEquippedItemLabel:SetCallback("OnLeave", function(widget)
        if GameTooltip:IsOwned(self._big_container.frame) then
          GameTooltip_Hide()
        end
      end)
   
      local gpValue, baseGpVal = bsloot_prices:GetPrice(self._itemId, bsloot._playerName)
      self._itemGpLabel:SetText("Item GP (for you): " .. gpValue .. "\nItem GP (base value): "..baseGpVal)
   
      local epGpSummary =  bsloot:getEpGpSummary(bsloot._playerName)
      self._playerEpLabel:SetText("Your EP: " .. epGpSummary.EP)
      self._playerGpLabel:SetText("Your GP: " .. epGpSummary.GP)
      self._playerPrLabel:SetText("Your Base PR: " .. epGpSummary.PR)
   
      self._previewPrLabel:SetText("Preview Base PR (if you win): " .. bsloot:calcPr(epGpSummary.EP, epGpSummary.GP+gpValue))
   end
  bsloot_window_roll_present:PopulateMissingRolls()

  bsloot_window_roll_present:ResetRolls()
  self._big_container.SetStatusText(itemLink)

  self._resolveTieButton:SetDisabled(true)
  if(bsloot:isSourceOfTrue("loot")) then
    self._announceButton:SetDisabled(false)
  else
    self._announceButton:SetDisabled(true)
  end
    if(shouldShow == nil or shouldShow) then
      bsloot_window_roll_present:Show()
    end
  end
end)

end
local missingRollsData = { }
function bsloot_window_roll_present:PopulateMissingRolls()

  table.wipe(missingRollsData)

  --Standings
  local headers = {
    {["name"]=C:Orange(_G.NAME),["width"]=100}
  }
  if(not self._missingRolls_table) then
    self._missingRolls_table = ST:CreateST(headers,5,nil,colorHighlight,self._missingRolls.frame) -- cols, numRows, rowHeight, highlight, parent
  end
  
  for name, info in pairs(self.eligibleRollers) do
    if((not rollsByChar[name] or rollsByChar[name] == nil) and (not passesByChar[name] or passesByChar[name] == nil)) then
      
      local color = RAID_CLASS_COLORS[1]
      if(info and info ~= nil) then
        local eClass, class, hexclass = bsloot:getClassData(info.class)
        color = RAID_CLASS_COLORS[eClass]
      end
      table.insert(missingRollsData,{["cols"]={
        {["value"]=name,["color"]=color},
      }})
      bsloot:debugPrint("Adding "..name.." as awaiting a roll", 7)
    else
      bsloot:debugPrint(name.." has already rolled", 8)
    end
  end

  self._missingRolls_table:SetData(missingRollsData)  
  if self._missingRolls_table and self._missingRolls_table.showing then
    self._missingRolls_table:SortData()
  end
  
  self._big_container:SetCallback("OnShow", function() 
    if(self._missingRolls_table) then
      self._missingRolls_table:Show() 
    end
  end)
  self._big_container:SetCallback("OnClose", function() 
    if(self._missingRolls_table) then
      self._missingRolls_table:Hide() 
    end
  end)
  
  self._missingRolls_table.frame:SetPoint("BOTTOMLEFT",self._big_container.frame,"BOTTOMLEFT", 10, 10)
end

function bsloot_window_roll_present:ResetRolls()
  rollsByChar = {}
  rollsByPr = {}
  passesByChar = {}
end

function bsloot_window_roll_present:updateRolls(itemId, charName, ep, gp, pr, modifier, effectivePr)
  if(self._itemId ~= nil and itemId == ""..self._itemId) then
    bsloot_window_roll_present:removePreviousRollType(charName)
    rollsByChar[charName] = {}
    rollsByChar[charName].itemLink = itemLink
    rollsByChar[charName].charName = charName
    rollsByChar[charName].ep = ep
    rollsByChar[charName].gp = gp
    rollsByChar[charName].pr = pr
    rollsByChar[charName].modifier = modifier
    rollsByChar[charName].effectivePr = effectivePr

    missingRollsData[charName] = nil

    bsloot_window_roll_present:Refresh()
  else
    bsloot:debugPrint("Unexpected item roll types: "..type(itemId).." vs "..type(self._itemId), 5)
    bsloot:debugPrint("Unexpected item roll values: "..itemId.." vs "..bsloot:tableToString(self._itemId)..";", 5)
  end
  --TODO what if bid received for wrong one
end

function bsloot_window_roll_present:updatePass(charName)
  bsloot_window_roll_present:removePreviousRollType(charName)
  passesByChar[charName] = true
  bsloot_window_roll_present:Refresh()

end
function bsloot_window_roll_present:Show()
  if self._itemId and self._itemId ~= nil then
    if not self._big_container.frame:IsShown() then
      self._big_container:Show()
    end
    self:Refresh()
  else
    bsloot:debugPrint("Attempt to view Item Rolls with no item prepared, requesting refresh", 1)
    bsloot:broadcast("requestItemWindowRefresh")
  end
end
function bsloot_window_roll_present:TakeScreenShotThenDo(func)
  if(not self._itemScreenshotted) then
    bsloot_window_roll_present:Show()
    Screenshot()
    self._itemScreenshotted = true
    C_Timer.After(3, func)
  else
    func()
  end
end
function bsloot_window_roll_present:Clear(ssOnAnnounce)
  if(ssOnAnnounce and ssOnAnnounce ~= nil) then
    bsloot_window_roll_present:TakeScreenShotThenDo(function()
      bsloot_window_roll_present:Hide()
    end)
  else
      bsloot_window_roll_present:Hide()
  end
  bsloot_window_roll_present.announced = false
  bsloot_window_roll_present._itemScreenshotted = false
  self._itemId = nil
end
function bsloot_window_roll_present:Hide()
  if self._big_container.frame:IsShown() then
    self._big_container:Hide()
  end
end
function bsloot_window_roll_present:Toggle()
  if self._big_container.frame:IsShown() then
    self._big_container:Hide()
    self:Refresh()
  else
    bsloot_window_roll_present:Show()
  end
end

function bsloot_window_roll_present:removePreviousRollType(charName) 
  if(rollsByChar[charName]) then
    rollsByChar[charName] = nil
    passesByChar[charName] = nil
  end
end

rollsByChar = {}
passesByChar = {}

function bsloot_window_roll_present:Refresh()
  bsloot:debugPrint("Refresshing roll tables", 8)
  table.wipe(data)
  
  --Standings
  local headers = {
    {["name"]=C:Orange(_G.NAME),["width"]=100}, 
    {["name"]=C:Orange(L["Effective PR"]),["width"]=75,["comparesort"]=st_sorter_numeric,["sortnext"]=1,["sort"]=ST.SORT_DSC}, --effectivePr
    {["name"]=C:Orange(L["ep"]:upper()),["width"]=75,["comparesort"]=st_sorter_numeric}, --ep
    {["name"]=C:Orange(L["gp"]:upper()),["width"]=75,["comparesort"]=st_sorter_numeric}, --gp
    {["name"]=C:Orange(L["pr"]:upper()),["width"]=75,["comparesort"]=st_sorter_numeric}, --pr
    {["name"]=C:Orange(L["mod"]:upper()),["width"]=75,["comparesort"]=st_sorter_numeric}, --modifier
  }
  if(not self._standings_table) then
    self._standings_table = ST:CreateST(headers,5,nil,colorHighlight,self._standingsFrame.frame) -- cols, numRows, rowHeight, highlight, parent
    self._standings_table:EnableSelection(true)
  end
  for charName,roll in pairs(rollsByChar) do
    bsloot:debugPrint("Adding entry for " .. charName .. "'s roll", 6)
    local ep = roll.ep
    local gp = roll.gp
    local pr = roll.pr
    local raidRosterInfo = self.eligibleRollers[roll.charName]
    local color = RAID_CLASS_COLORS[1]
    if(raidRosterInfo and raidRosterInfo ~= nil) then
      local eClass, class, hexclass = bsloot:getClassData(raidRosterInfo.class)
      color = RAID_CLASS_COLORS[eClass]
    end
    -- local armor_class = armor_text[class_to_armor[eClass]]
    table.insert(data,{["cols"]={
      {["value"]=roll.charName,["color"]=color},
      {["value"]=string.format("%.4f", roll.effectivePr),["color"]={r=1.0,g=215/255,b=0,a=1.0}},
      {["value"]=string.format("%.4f", roll.ep)},
      {["value"]=string.format("%.4f", roll.gp)},
      {["value"]=string.format("%.4f", roll.pr)},
      {["value"]=roll.modifier},
    }})
  end

  self._standings_table:SetData(data)  
  if self._standings_table and self._standings_table.showing then
    self._standings_table:SortData()
  end
  
  self._big_container:SetCallback("OnShow", function() 
    if(self._standings_table) then
      self._standings_table:Show() 
    end
  end)
  self._big_container:SetCallback("OnClose", function() 
    if(self._standings_table) then
      self._standings_table:Hide() 
    end
  end)

  self._standings_table:SetDisplayRows(18, 15)
  self._standings_table.frame:SetPoint("TOPRIGHT",self._big_container.frame,"TOPRIGHT", -10, -45)

  bsloot_window_roll_present:PopulateMissingRolls()
end

function bsloot_window_roll_present:GetBasiccData()
  return self.item, rollsByChar, passesByChar
end

function bsloot_window_roll_present:SendAsChat(toPerson) 
  local chatTo = {}
  chatTo.WHISPER = true
  local msg = ""
  local _, basePrice = bsloot_prices:GetPrice(self._itemId, bsloot._playerName)
  msg = "Item: " .. self.item .. ", baseGp: " .. basePrice
  bsloot:SendChat(msg, chatTo, toPerson)
  local header = {"Character", "EffectivePR", "Modifiers", "Base PR", "EP", "GP"}

  local maxLengths = {}
  maxLengths.charName = string.len(header[1])
  maxLengths.effectivePr = string.len(header[2])
  maxLengths.modifier = string.len(header[3])
  maxLengths.pr = string.len(header[4])
  maxLengths.ep = string.len(header[5])
  maxLengths.gp = string.len(header[6])
  for _, roll in pairs(rollsByChar) do
    maxLengths.charName = math.max(maxLengths.charName, string.len(roll.charName))
    maxLengths.effectivePr = math.max(maxLengths.effectivePr, string.len(string.format("%.4f", roll.effectivePr)))
    maxLengths.modifier = math.max(maxLengths.modifier, string.len(roll.modifier))
    maxLengths.pr = math.max(maxLengths.pr, string.len(string.format("%.4f", roll.pr)))
    maxLengths.ep = math.max(maxLengths.ep, string.len(string.format("%.4f", roll.ep)))
    maxLengths.gp = math.max(maxLengths.gp, string.len(string.format("%.4f", roll.gp)))
  end

  local spacesBetweenCol = 2
  msg = header[1] .. string.rep(" ", maxLengths.charName + spacesBetweenCol - string.len(header[1]))
    .. header[2] .. string.rep(" ", maxLengths.charName + spacesBetweenCol - string.len(header[2]))
    .. header[3] .. string.rep(" ", maxLengths.charName + spacesBetweenCol - string.len(header[3]))
    .. header[4] .. string.rep(" ", maxLengths.charName + spacesBetweenCol - string.len(header[4]))
    .. header[5] .. string.rep(" ", maxLengths.charName + spacesBetweenCol - string.len(header[5]))
    .. header[6] .. string.rep(" ", maxLengths.charName + spacesBetweenCol - string.len(header[6]))
  bsloot:SendChat(msg, chatTo, toPerson)
  for char, roll in pairs(rollsByChar) do
    local effPrStr, prStr, epStr, gpStr = string.format("%.4f", roll.effectivePr), string.format("%.4f", roll.pr), string.format("%.4f", roll.ep), string.format("%.4f", roll.gp)
    msg = roll.charName .. string.rep(" ", maxLengths.charName + spacesBetweenCol - string.len(roll.charName))
    .. effPrStr .. string.rep(" ", maxLengths.effectivePr + spacesBetweenCol - string.len(effPrStr))
    .. roll.modifier .. string.rep(" ", maxLengths.modifier + spacesBetweenCol - string.len(roll.modifier))
    .. prStr .. string.rep(" ", maxLengths.pr + spacesBetweenCol - string.len(prStr))
    .. epStr .. string.rep(" ", maxLengths.ep + spacesBetweenCol - string.len(epStr))
    .. gpStr .. string.rep(" ", maxLengths.gp + spacesBetweenCol - string.len(gpStr))
    bsloot:SendChat(msg, chatTo, toPerson)
  end
  
  
  local passesStr = ""
  local passesStrDiv = ""
  for char, _ in pairs(passesByChar) do
    passesStr = passesStr ..passesStrDiv .. char
    passesStrDiv = ","
  end
  msg = "Passes: "..passesStr
  bsloot:SendChat(msg, chatTo, toPerson)
  
  local missingRollsStr = ""
  local missingRollsStrDiv = ""
  for name, info in pairs(self.eligibleRollers) do
    if((not rollsByChar[name] or rollsByChar[name] == nil) and (not passesByChar[name] or passesByChar[name] == nil)) then
      missingRollsStr = missingRollsStr ..missingRollsStrDiv .. name
      missingRollsStrDiv = ","
    end
  end
  msg = "Missing rolls from: "..missingRollsStr
  bsloot:SendChat(msg, chatTo, toPerson)
end