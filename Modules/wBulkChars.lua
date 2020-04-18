local addonName, bsloot = ...
local moduleName = addonName.."_window_bulk_chars"
local bsloot_window_bulk_chars = bsloot:NewModule(moduleName)
local ST = LibStub("ScrollingTable")
local C = LibStub("LibCrayon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local GUI = LibStub("AceGUI-3.0")
local LW = LibStub("LibWindow-1.1")

local data = {}
local eligibleRollers = {}
local colorHighlight = {r=0, g=0, b=0, a=.9}


function bsloot_window_bulk_chars:OnEnable()
 
  local bigContainer = GUI:Create("Window")
  bigContainer:SetTitle(L["Bulk Import Chars (csv)"])
  bigContainer:SetWidth(630)
  bigContainer:SetHeight(340)
  bigContainer:EnableResize(false)
  bigContainer:SetLayout("List")
  bigContainer:Hide()
  self._big_container = bigContainer

  local overwriteFlag = GUI:Create("CheckBox")
  overwriteFlag:SetLabel(L["Overwrite Existing Chars"])
  bigContainer:AddChild(overwriteFlag)
  self.overwriteFlag = overwriteFlag

  local editBox = GUI:Create("MultiLineEditBox")
  editBox:SetWidth(580)
  editBox:SetHeight(260)
  editBox:SetMaxLetters(1000000)
  editBox:SetLabel(L["Bulk CSV Content (max 1000000 characters)"])
  editBox:SetCallback("OnEnterPressed",function()
    bsloot:importCharRoles(self.editBox:GetText(), self.overwriteFlag:GetValue())
    bsloot_window_bulk_chars:Hide()
  end)
  bigContainer:AddChild(editBox)
  self.editBox = editBox

  bsloot:make_escable(bigContainer,"add")
end

function bsloot_window_bulk_chars:Show()
  if not self._big_container.frame:IsShown() then
    self.editBox:SetText("")
    self.editBox:SetFocus()
    self._big_container:Show()
  end
end
function bsloot_window_bulk_chars:Hide()
  if self._big_container.frame:IsShown() then
    self._big_container:Hide()
  end
end
function bsloot_window_bulk_chars:Toggle()
  if self._big_container.frame:IsShown() then
    self._big_container:Hide()
  else
    bsloot_window_bulk_chars:Show()
  end
end
