local addonName, bsloot = ...
local moduleName = addonName.."_sync"
local bsloot_sync = bsloot:NewModule(moduleName, "AceEvent-3.0")

bsloot_sync.queueTimerFrequency = 10
bsloot_sync.syncQueue = {first = 0, last = -1}
bsloot_sync.scheduled = {}
bsloot.syncMinGuildRank = 3 --higher = lower rank, 1 is GM
SyncEvents = SyncEvents or {}
bsloot_sync.maxSyncResponseWaitTimeMins = 10


bsloot_sync.enabled = false
bsloot_sync.syncOnlyCritical = true
function bsloot_sync:OnEnable()
  bsloot_sync.enabled = false or bsloot.db.char.syncEnabled
  bsloot_sync.syncOnlyCritical = false or bsloot.db.char.syncOnlyCritical
  bsloot_sync.queueTimerFrequency = 10 or bsloot.db.char.syncQueueFrequency
  bsloot_sync:startQueueTimer()
  bsloot_sync:syncAll()
end

function bsloot_sync:isCriticalType(eventType) 
--   return eventType == nil or string.find(eventType, "ItemVal_") == 1 or string.find(eventType, "CharRole_") == 1 
return true
end

function bsloot_sync:SetEnabled(flag)
  if(flag and not bsloot_sync.enabled) then
    bsloot_sync.enabled = flag
    bsloot_sync:syncAll()
  else
    bsloot_sync.enabled = flag
    bsloot_sync.syncQueue = {first = 0, last = -1}
  end
end

function bsloot_sync:IsEnabled()
  return bsloot_sync.enabled
  -- return false
end
function bsloot_sync:IsSyncOnlyCritical()
  return bsloot_sync.syncOnlyCritical
end
function bsloot_sync:SetSyncOnlyCritical(flag)
  bsloot_sync.syncOnlyCritical = flag
end
function bsloot_sync:SetSyncQueueFrequency(frequencyInSeconds)
  bsloot_sync.queueTimerFrequency = flag
end

function bsloot_sync:startQueueTimer()

  C_Timer.After(bsloot_sync.queueTimerFrequency, function()
    if(bsloot_sync:IsEnabled()) then
      bsloot:debugPrint("Processing sync queue", 9)
      local success, err = pcall(function()
        bsloot_sync:readQueue()
      end)
      if(not success) then
        bsloot:debugPrint("Encountered error while reading queue, ignoring record: "..bsloot:tableToString(err), 3)
      end
    else
      bsloot:debugPrint("NOT Processing sync queue", 9)
    end      
    bsloot_sync:startQueueTimer()
  end)
end

function bsloot_sync:syncAllOut(requester)
  if(bsloot_sync:IsEnabled()) then
    local rank = C_GuildInfo.GetGuildRankOrder(UnitGUID("player"))
    if(rank <= bsloot.syncMinGuildRank) then
      bsloot_sync:sendAllData(requester)
    else
      bsloot:debugPrint("skipping broadcast, too low rank", 5)
    end
  end
end

bsloot_sync.offerBatchSize = 50
function bsloot_sync:offerSyncEvents(toPlayer)
  if(bsloot_sync:IsEnabled()) then
      local myProfile = bsloot_sync:getDataProfile()
      local dataProfileStr = myProfile.mostRecent .. "|" .. myProfile.numEvents
      if(toPlayer and toPlayer ~= nil) then
        bsloot:broadcast("syncOffer "..dataProfileStr, "WHISPER", toPlayer)
      else
        bsloot:broadcast("syncOffer "..dataProfileStr)
      end
  end
end

function bsloot_sync:sendAllData(toPlayer)
  for eventId, eventData in pairs(SyncEvents) do
    local eventIdStr = eventId .. ":" .. eventData.type
    local qRec = bsloot_sync:buildOutboundQrec("outbound", eventIdStr, toPlayer)
    bsloot_sync:processEventDataRequest(qRec)
  end
end

function bsloot_sync:syncRecentEvent(eventId)
  if(bsloot_sync:IsEnabled()) then
    local eventData = SyncEvents[eventId]
    if(eventData and eventData ~= nil) then
      local eventIdStr = eventId .. ":" .. eventData.type
      local qRec = bsloot_sync:buildOutboundQrec("outbound", eventIdStr)
      bsloot_sync:processEventDataRequest(qRec)
    else
      bsloot:errorPrint("Recent Sync Event not found: "..eventId)
    end
  end
end

function bsloot_sync:checkSyncOffer(dataProfileStr, sender)
 -- bsloot:debugPrint("checkSyncOffer("..bsloot:tableToString(events)..", "..sender..")", 7)
  if(bsloot_sync:IsEnabled()) then
    local dataProfile = bsloot:split(dataProfileStr, "|")
    local numOffered = tonumber(dataProfile[2])
    local myProfile = bsloot_sync:getDataProfile()
    if(dataProfile[1] > myProfile.mostRecent) then
      bsloot_sync:requestAllData(myProfile.mostRecent, sender)
    elseif(numOffered > myProfile.numEvents) then
      local numMissing = myProfile.numEvents - numOffered
      bsloot:warnPrint("Getting all events from "..sender.." because they have "..numMissing.." you do not. These are not most recent a full data rebuild may be necessary", 1)
        bsloot_sync:requestAllData(nil, sender)
    end
  end
end

function bsloot_sync:getDataProfile()
  local dataProfile = {}
  dataProfile.numEvents = #SyncEvents
  _, dataProfile.mostRecent = bsloot_sync.getMostRecentEvent()
  return dataProfile
end

function bsloot_sync.getMostRecentEvent()
  local mostRecentTs = 0
  local mostRecentEvent = ""
  for eventId, event in pairs(SyncEvents) do
    if(event.epochSeconds >= mostRecentTs) then
      mostRecentTs = event.epochSeconds
      mostRecentEvent = eventId
    end
  end
  return SyncEvents[mostRecentEvent], mostRecentTs
end

function bsloot_sync:receiveInboundEvent(eventData, sender)
  
  if(bsloot_sync:IsEnabled()) then
    -- bsloot_sync:enqueue("inbound", eventData, sender)
    local qRec = bsloot_sync:buildInboundQrec("inbound", eventData, sender)
    
    --TODO remove, or adjust to allow minor variance; if adjusting apply elsewhere
    if(not bsloot_sync:checkVersion(qRec.header, requester)) then
      bsloot:debugPrint("Rejecting inbound sync from "..requester .. " they are on version: "..header.senderVersion, 3)
      return
    end
    bsloot_sync:processInboundEvent(qRec)
    bsloot_sync.lastInboundEventSec, _ = bsloot:getServerTime()
    bsloot_sync.awaitingResponse = false
  end
end


function bsloot_sync:processInboundEvent(qRec)
  if(bsloot_sync:IsEnabled()) then
    local eventData = qRec.data
    local header = qRec.header
    local eventId = header.eventId
    local eventType = header.type
    local eventTs = header.epochSeconds
    local eventVersion = header.eventVersion
    if(not bsloot_sync.syncOnlyCritical or bsloot_sync:isCriticalType(eventType)) then

      --bsloot:debugPrint("receiveInboundEvent("..bsloot:tableToString(eventData)..", "..sender..")", 9)

      if(not SyncEvents[eventId] or SyncEvents[eventId] == nil) then --skips events we already have
        bsloot:receiveEvent(eventType, eventData, eventId, eventVersion, eventTs)
      end
    end
  end
end

function bsloot_sync:enqueue(type, eventData, requester)
  if(bsloot_sync:IsEnabled()) then
    if(type == "inbound") then
      local qRec = bsloot_sync:buildInboundQrec(type, eventData, requester)
      
      if(not bsloot_sync:checkVersion(qRec.header, requester)) then
        bsloot:debugPrint("Rejecting inbound sync from "..requester .. " they are on version: "..header.senderVersion, 3)
        return
      end


      -- if(not bsloot_sync.syncOnlyCritical or bsloot_sync:isCriticalType(qRec.eventType)) then
        bsloot_sync:qAdd(bsloot_sync.syncQueue, qRec)
      -- end
    elseif(type == "outbound") then
      
      local qRec = bsloot_sync:buildOutboundQrec(type, eventData, requester)
      
      -- if(not bsloot_sync.syncOnlyCritical or bsloot_sync:isCriticalType(qRec.eventType)) then
        local addedAt = nil
        addedAt = bsloot_sync:qAdd(bsloot_sync.syncQueue, qRec)
        
      -- end
    end
  end
end
function bsloot_sync:buildOutboundQrec(type, eventIdStr, toPlayer)
  
  local qRec = {}
  qRec.type = type
  qRec.data = eventData
  qRec.requesters = {}
  if(toPlayer and toPlayer ~= nil) then
    table.insert(qRec.requesters, toPlayer)
  end
  local eventIdArray = bsloot:split(eventIdStr, ":")
  qRec.eventId = eventIdArray[1]
  qRec.eventType = eventIdArray[2]
  return qRec
end
function bsloot_sync:buildInboundQrec(type, eventData, requester)
  local qRec = {}
  qRec.type = type
  qRec.data = eventData
  local dataArray = bsloot:split(eventData, "\n")
  local headerArray = bsloot:split(dataArray[1], " ")
  local startData = string.find(eventData, "\n")
  qRec.data = strsub(eventData, startData+1)
  local header = {}
  header.senderVersion = headerArray[1]
  header.eventId = headerArray[2]
  header.type = headerArray[3]
  header.epochSeconds = tonumber(headerArray[4])
  header.eventVersion = headerArray[5]
  qRec.header = header
  qRec.eventId = headerArray[2]
  qRec.eventType = headerArray[3]
  return qRec
end
function bsloot_sync:receiveEventDataRequest(eventId, sender)
  if(bsloot_sync:IsEnabled()) then
    --bsloot:debugPrint("processEventDataRequest("..bsloot:tableToString(eventId)..", "..sender..")", 8)
    local qRec = bsloot_sync:buildOutboundQrec("outbound", eventId)
    qRec.requesters = {}
    table.insert(qRec.requesters, sender)
    bsloot_sync:processEventDataRequest(qRec)
  end
end
function bsloot_sync:receiveDataSinceRequest(since, sender)
  since = tonumber(since)
  for eventId, event in pairs(SyncEvents) do
    if(event.epochSeconds > since) then
      local qRec = bsloot_sync:buildOutboundQrec("outbound", eventId)
      qRec.requesters = {}
      table.insert(qRec.requesters, sender)
      bsloot_sync:processEventDataRequest(qRec)
    end
  end
end

function bsloot_sync:processEventDataRequest(qRec)
  if(bsloot_sync:IsEnabled()) then
    local eventId = qRec.eventId
    local requesters = qRec.requesters
    local eventType = qRec.eventType
    if(not bsloot_sync.syncOnlyCritical or bsloot_sync:isCriticalType(eventType)) then
      local event = SyncEvents[eventId]
      if(event and event ~= nil) then
        local eventData = bsloot._versionString .. " " .. eventId .. " " .. event.type .. " " .. event.epochSeconds .. " " .. event.version .. "\n" .. event.dataString
        if(qRec.requesters and qRec.requesters ~= nil and #qRec.requesters > 0) then
          for _, c in ipairs(qRec.requesters) do
            bsloot:broadcastSync("syncGive "..eventData, c)
          end
        else
          bsloot:broadcastSync("syncGive "..eventData)
        end
      else
        bsloot:warnPrint("Requested Event not found: "..eventId)
      end
    end
  end
end
-- Helper functions

function bsloot_sync:readQueue()
  if(not bsloot_sync:isQEmpty(bsloot_sync.syncQueue)) then
    local qRec = bsloot_sync:qPop(bsloot_sync.syncQueue)
    local qDepth = bsloot_sync:getQDepth(bsloot_sync.syncQueue)
    bsloot:debugPrint("Reading sync queue (qdepth="..qDepth.."): " .. bsloot:tableToString(qRec), 5)
    if(qRec and qRec ~= nil) then
      if(qRec.type == "inbound") then
        bsloot_sync:processInboundEvent(qRec)
      elseif(qRec.type == "outbound") then
        bsloot_sync:processEventDataRequest(qRec)
      else
        bsloot:debugPrint("Unrecognized QueueRecord type", 6)
      end
    else
      bsloot:debugPrint("race condition, try again", 6)
    end
    if(qDepth == 0) then
      bsloot:debugPrint("Processed all Queued Sync activities", 1)
    end
  end
end
function bsloot_sync:getQDepth(q)
  return q.last-q.first+1
end
function bsloot_sync:isQEmpty(q)
  return q.first > q.last
end
function bsloot_sync:qAdd(q, value)
  local last = q.last + 1
  q.last = last
  q[last] = value
  return last
end
function bsloot_sync:qPop(q)
  local first = q.first
  if(first > q.last) then 
    return
  end
  local value = q[first]
  q[first] = nil
  q.first = first + 1
  return value
end

function bsloot_sync:syncAll()
  
  if(bsloot_sync:IsEnabled()) then
    bsloot_sync:offerSyncEvents()
    local profile = bsloot_sync:getDataProfile()
    bsloot_sync:getAllData(profile.mostRecent)
  end
end

function bsloot_sync:getAllData(since)
  local rankSorted = {}
  local numGuildMembers = GetNumGuildMembers(true)
  for i = 1, numGuildMembers do
    local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, 
    achievementPoints, achievementRank, isMobile, isSoREligible, standingID = GetGuildRosterInfo(i)
    local member_name = Ambiguate(name,"short")
    
    if(level > bsloot.VARS.minlevel) then
      if(online and member_name ~= bsloot._playerName) then 
        if(not rankSorted[rankIndex] or rankSorted[rankIndex] == nil) then
          rankSorted[rankIndex] = {}
        end
        table.insert(rankSorted[rankIndex], member_name)
      end
    end
  end

  local orderedSources = {}
  for rankIndex = 1, bsloot.syncMinGuildRank do
    if(rankSorted[rankIndex] and rankSorted[rankIndex] ~= nil) then
      table.sort(rankSorted[rankIndex])
      for _, c in ipairs(rankSorted[rankIndex]) do
        table.insert(orderedSources, c)
      end
    end
  end

  bsloot_sync:checkWithNextSourceForNewData(orderedSources, 1)
  
end

function bsloot_sync:checkWithNextSourceForNewData(orderedSources, index, startedWaiting)
  if(index <= #orderedSources) then
    local source = orderedSources[index]
    if(not startedWaiting or startedWaiting == nil) then
      bsloot:removePrint("Processing source "..source)
      bsloot_sync.lastInboundEventSec = 0
      local myProfile = bsloot_sync:getDataProfile()
      bsloot_sync.awaitingResponse = true
      local startSeconds, _ = bsloot:getServerTime()
      local waitingSeconds = 0
      bsloot_sync:requestAllData(myProfile.mostRecent, source)
    end
    
    C_Timer.After(3, function()
      bsloot:removePrint("Waiting for source "..source)
      if(not startedWaiting or startedWaiting == nil) then
        startedWaiting, _ = bsloot:getServerTime()
      end
      local currentSeconds, _ = bsloot:getServerTime()
      waitingSeconds = currentSeconds - startedWaiting -- TODO if you are getting responses wait 15 seconds after the last one to ask next person
      if(bsloot_sync.lastInboundEventSec > 0) then
        waitingSeconds = currentSeconds - bsloot_sync.lastInboundEventSec
      end      
      if(startedWaiting and bsloot_sync.awaitingResponse and waitingSeconds < bsloot_sync.maxTimeAwaitingResponse) then
        --keep waiting
        bsloot_sync:checkWithNextSourceForNewData(orderedSources, index, startedWaiting)
      else
        --move on
        bsloot_sync:checkWithNextSourceForNewData(orderedSources, index+1)
      end
    end)
  end
end

bsloot_sync.maxTimeAwaitingResponse = 5 --seconds
function bsloot_sync:requestAllData(since, from)
  
  if(bsloot_sync:IsEnabled()) then
    local msg = "syncGetAll"
    if(since and since ~= nil) then
      msg = "syncGetSince "..since
    end

    if(from and from ~= nil) then
      bsloot:broadcastSync(msg, from)
    else
      bsloot:broadcastSync(msg)
    end
  end
end
function bsloot_sync:checkVersion(header, sender)
  
  local versionMismatch = bsloot._versionString ~= header.senderVersion
  if(versionMismatch) then
    bsloot:warnWrongVersion(sender, header.senderVersion)
  end
  return not versionMismatch
end

bsloot_sync.warnTimeLimitMinutes = 30
bsloot_sync.warnedPlayers = {}
function bsloot:warnWrongVersion(sender, version)
  epochSeconds, currTimeStamp = bsloot:getServerTime()
  local warn = false
  if( not bsloot_sync.warnedPlayers[sender] or bsloot_sync.warnedPlayers[sender] == nil) then
    bsloot_sync.warnedPlayers[sender] = {}
    bsloot_sync.warnedPlayers[sender].timestamp = currTimeStamp
    bsloot_sync.warnedPlayers[sender].version = version
    warn = true
  elseif (bsloot_sync.warnedPlayers[sender].version ~= version) then
    bsloot_sync.warnedPlayers[sender].timestamp = currTimeStamp
    bsloot_sync.warnedPlayers[sender].version = version
    warn = true
  elseif (bsloot_sync.warnedPlayers[sender].timestamp and bsloot_sync.warnedPlayers[sender].timestamp ~= nil and (bsloot_sync.warnedPlayers[sender].timestamp.epochMS + (bsloot_sync.warnTimeLimitMinutes * 60 * 1000)) < currTimeStamp.epochMS) then
    bsloot_sync.warnedPlayers[sender].timestamp = currTimeStamp
    bsloot_sync.warnedPlayers[sender].version = version
    warn = true
  end
  if(warn) then
    bsloot:debugPrint("Sync received from " ..sender.. " on version ".. version .. " while you are on "..bsloot._versionString.." one of you should update!",1)
  end
end