-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.0, 05|05|2023
-- @filename: main.lua

local modName = g_currentModName
local rollingFruitsType = {}
local isCreated = false

FSMissionInfo.rollingRequiredEnabled = true

local function loadMap(self)
  local missionInfo = g_currentMission.missionInfo

  if missionInfo ~= nil and missionInfo.savegameDirectory ~= nil then
    local xmlFile = loadXMLFile("careerXML", missionInfo.savegameDirectory .. "/careerSavegame.xml")

    if xmlFile ~= nil then
      missionInfo.rollingRequiredEnabled = Utils.getNoNil(getXMLBool(xmlFile, missionInfo.xmlKey .. ".settings.rollingRequiredEnabled"), true)

      delete(xmlFile)
    end
  end

  for i = 1, #g_fruitTypeManager.fruitTypes do
    local fruitType = g_fruitTypeManager.fruitTypes[i]

    if fruitType.needsRolling == true then
      rollingFruitsType[fruitType.index] = true

      fruitType.needsRolling = FSMissionInfo.rollingRequiredEnabled
    end
  end
end

FSBaseMission.loadMap = Utils.appendedFunction(FSBaseMission.loadMap, loadMap)

local function onStartMission(self)
  if self.missionInfo ~= nil then
    Logging.info("Savegame Setting 'rollingRequiredEnabled': %s", self.missionInfo.rollingRequiredEnabled)
  end
end

FSBaseMission.onStartMission = Utils.appendedFunction(FSBaseMission.onStartMission, onStartMission)

FSBaseMission.setRollingRequiredEnabled = function (self, isEnabled, noEventSend)
  if isEnabled ~= self.missionInfo.rollingRequiredEnabled then
    self.missionInfo.rollingRequiredEnabled = isEnabled

    for i = 1, #g_fruitTypeManager.fruitTypes do
      local fruitType = g_fruitTypeManager.fruitTypes[i]

      if rollingFruitsType[fruitType.index] == true then
        fruitType.needsRolling = FSMissionInfo.rollingRequiredEnabled
      end
    end

    SavegameSettingsEvent.sendEvent(noEventSend)
    Logging.info("Savegame Setting 'rollingRequiredEnabled': %s", isEnabled)
    self.inGameMenu:onSoilSettingChanged()
  end
end

local function saveToXMLFile(self)
  if self.isValid then
    setXMLBool(self.xmlFile, self.xmlKey .. ".settings.rollingRequiredEnabled", self.rollingRequiredEnabled)
  end
end

FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, saveToXMLFile)

local function readStream(self, streamId, connection)
  local rollingRequired = streamReadBool(streamId)

  if connection:getIsServer() or g_currentMission.userManager:getIsConnectionMasterUser(connection) then
    g_currentMission:setRollingRequiredEnabled(rollingRequired, true)

    if not connection:getIsServer() then
      g_server:broadcastEvent(self, false, connection)
    end
  end
end

SavegameSettingsEvent.readStream = Utils.appendedFunction(SavegameSettingsEvent.readStream, readStream)

local function writeStream(self, streamId, connection)
  streamWriteBool(streamId, g_currentMission.missionInfo.rollingRequiredEnabled)
end

SavegameSettingsEvent.writeStream = Utils.appendedFunction(SavegameSettingsEvent.writeStream, writeStream)

local function fieldAddRolling(self, superFunc, data, box)
  if not g_currentMission.missionInfo.rollingRequiredEnabled then
    return
  end

  return superFunc(self, data, box)
end

PlayerHUDUpdater.fieldAddRolling = Utils.overwrittenFunction(PlayerHUDUpdater.fieldAddRolling, fieldAddRolling)

local function onFrameOpen(self, superFunc, element)
  superFunc(self, element)

  if not isCreated then
    local checkRollingRequired = self.checkPlowingRequired:clone(self.boxLayout)

    checkRollingRequired.elements[4]:setText(self.l10n:getText("setting_rollingRequired", modName))
    checkRollingRequired.elements[6]:setText(self.l10n:getText("toolTip_rollingRequired", modName))

    checkRollingRequired.parent:removeElement(checkRollingRequired)

    function checkRollingRequired.onClickCallback(_, ...)
      self:onClickRollingRequired(...)
    end

    checkRollingRequired:reloadFocusHandling(true)
    checkRollingRequired:setIsChecked(self.missionInfo.rollingRequiredEnabled)
    checkRollingRequired:setDisabled(not self.hasMasterRights)

    local index = #self.checkPlowingRequired.parent.elements + 1

    for i = 1, #self.checkPlowingRequired.parent.elements do
      if self.checkPlowingRequired.parent.elements[i] == self.checkPlowingRequired then
        index = i + 1

        break
      end
    end

    table.insert(self.checkPlowingRequired.parent.elements, index, checkRollingRequired)

    checkRollingRequired.parent = self.checkPlowingRequired.parent

    self.boxLayout:invalidateLayout()

    isCreated = true
  end
end

InGameMenuGameSettingsFrame.onFrameOpen = Utils.overwrittenFunction(InGameMenuGameSettingsFrame.onFrameOpen, onFrameOpen)

InGameMenuGameSettingsFrame.onClickRollingRequired = function (self, state)
  if self.hasMasterRights then
    g_currentMission:setRollingRequiredEnabled(state == CheckedOptionElement.STATE_CHECKED)
  end
end

local function cutFruitArea(self, superFunc, fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, destroySpray, useMinForageState, excludedSprayType, setsWeeds, limitToField)
  local numPixels, totalNumPixels, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, beeFactor, growthState, maxArea, terrainDetailPixelsSum = superFunc(self, fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, destroySpray, useMinForageState, excludedSprayType, setsWeeds, limitToField)

  if not g_currentMission.missionInfo.rollingRequiredEnabled then
    rollerFactor = 1
  end

  return numPixels, totalNumPixels, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, beeFactor, growthState, maxArea, terrainDetailPixelsSum
end

FSDensityMapUtil.cutFruitArea = Utils.overwrittenFunction(FSDensityMapUtil.cutFruitArea, cutFruitArea)

local function getRollerFactorDensityMap(self, superFunc, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
  local ret = superFunc(self, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)

  if not g_currentMission.missionInfo.rollingRequiredEnabled then
    ret = 0
  end

  return ret
end

FSDensityMapUtil.getRollerFactor = Utils.overwrittenFunction(FSDensityMapUtil.getRollerFactor, getRollerFactorDensityMap)

local function getRollerFactor(self, superFunc, field)
  local ret = superFunc(self, field)

  if not g_currentMission.missionInfo.rollingRequiredEnabled then
    ret = 1
  end

  return ret
end

FieldUtil.getRollerFactor = Utils.overwrittenFunction(FieldUtil.getRollerFactor, getRollerFactor)

function buildSoilStateMapOverlay(self, superFunc, soilStateFilter)
  soilStateFilter[MapOverlayGenerator.SOIL_STATE_INDEX.NEEDS_ROLLING] = soilStateFilter[MapOverlayGenerator.SOIL_STATE_INDEX.NEEDS_ROLLING] and g_currentMission.missionInfo.rollingRequiredEnabled

  superFunc(self, soilStateFilter)
end

MapOverlayGenerator.buildSoilStateMapOverlay = Utils.overwrittenFunction(MapOverlayGenerator.buildSoilStateMapOverlay, buildSoilStateMapOverlay)

function getDisplaySoilStates(self, superFunc)
  local displayValues = superFunc(self)

  displayValues[MapOverlayGenerator.SOIL_STATE_INDEX.NEEDS_ROLLING].isActive = g_currentMission.missionInfo.rollingRequiredEnabled

  return displayValues
end

MapOverlayGenerator.getDisplaySoilStates = Utils.overwrittenFunction(MapOverlayGenerator.getDisplaySoilStates, getDisplaySoilStates)