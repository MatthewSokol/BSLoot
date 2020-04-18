local addonName, bsloot = ...
local moduleName = addonName.."_window_bulk_events"
local bsloot_window_bulk_events = bsloot:NewModule(moduleName)
local ST = LibStub("ScrollingTable")
local C = LibStub("LibCrayon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local GUI = LibStub("AceGUI-3.0")
local LW = LibStub("LibWindow-1.1")

local data = {}
local eligibleRollers = {}
local colorHighlight = {r=0, g=0, b=0, a=.9}


function bsloot_window_bulk_events:OnEnable()
 
  local bigContainer = GUI:Create("Window")
  bigContainer:SetTitle(L["Bulk Import Events (csv)"])
  bigContainer:SetWidth(630)
  bigContainer:SetHeight(340)
  bigContainer:EnableResize(false)
  bigContainer:SetLayout("List")
  bigContainer:Hide()
  self._big_container = bigContainer

  local editBox = GUI:Create("MultiLineEditBox")
  editBox:SetWidth(580)
  editBox:SetHeight(260)
  editBox:SetMaxLetters(1000000)
  editBox:SetLabel(L["Bulk CSV Content (max 1000000 characters)"])
  editBox:SetCallback("OnEnterPressed",function()
    bsloot:importEvents(self.editBox:GetText())
    bsloot_window_bulk_events:Hide()
  end)
  bigContainer:AddChild(editBox)
  self.editBox = editBox
  
  bsloot:make_escable(bigContainer,"add")
end

function bsloot_window_bulk_events:Show()
  if not self._big_container.frame:IsShown() then
    self.editBox:SetText("")
    self.editBox:SetFocus()
    self._big_container:Show()
  end
end
function bsloot_window_bulk_events:Hide()
  if self._big_container.frame:IsShown() then
    self._big_container:Hide()
  end
end
function bsloot_window_bulk_events:Toggle()
  if self._big_container.frame:IsShown() then
    self._big_container:Hide()
  else
    bsloot_window_bulk_events:Show()
  end
end
