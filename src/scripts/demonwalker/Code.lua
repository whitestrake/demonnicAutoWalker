--[===[
The MIT License (MIT)

Copyright (c) 2020 Damian Monogue

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]===]
demonnic = demonnic or {}
demonnic.autowalker = demonnic.autowalker or {}
demonnic.autowalker.config = demonnic.autowalker.config or {}
if demonnic.autowalker.enabled == nil then
  demonnic.autowalker.enabled = false
end

-- Set to false if you don't want to go back to the room you start the walker in when it's done
demonnic.autowalker.config.returnToStart = true

function demonnic:echo(msg)
  cecho(string.format("\n<blue>(<green>Demonnic<blue>):<white> %s", msg))
end

function demonnic:findAndRemove(targetTable, item)
  table.remove(targetTable, table.index_of(targetTable, item))
end

function demonnic.autowalker:init(rooms)
  if rooms == nil then
    rooms = {}
  end
  if type(rooms) ~= "table" then
    demonnic:echo("You tried to initialize the autowalker with an argument, and it was not a table of room ID numbers. Try again")
    return
  end

  if demonnic.autowalker.enabled then
    return
  end
  demonnic.autowalker.enabled = true
  local currentRoom = mmp.currentroom
  demonnic.autowalker.currentRoom = currentRoom
  demonnic.autowalker.startingRoom = currentRoom
  local area = getRoomArea(currentRoom)
  demonnic.autowalker.area = area
  if #rooms ~= 0 then
    area = getRoomArea(rooms[1])
    demonnic.autowalker.area = area
    if table.index_of(rooms, currentRoom) then
      demonnic:findAndRemove(rooms, currentRoom)
    end
    demonnic.autowalker.remainingRooms = table.deepcopy(rooms)
  else
    local areaRooms = getAreaRooms(area)
    demonnic:findAndRemove(areaRooms, currentRoom)
    if areaRooms[0] then
      areaRooms[#areaRooms+1] = areaRooms[0]
      areaRooms[0] = nil
    end
    demonnic.autowalker.remainingRooms = table.deepcopy(areaRooms)
  end
  demonnic.autowalker:registerEventHandlers()
  raiseEvent("demonwalker.arrived")
end

function demonnic.autowalker:stop()
  if not demonnic.autowalker.enabled then
    return
  end
  demonnic.autowalker.currentRoom = nil
  demonnic.autowalker.remainingRooms = nil
  demonnic.autowalker.enabled = false
  demonnic.autowalker:removeEventHandlers()
  raiseEvent("demonwalker.finished")
  if demonnic.autowalker.config.returnToStart then
    mmp.gotoRoom(demonnic.autowalker.startingRoom)
  end
end

function demonnic.autowalker:move()
  if not demonnic.autowalker.enabled then
    return
  end
  demonnic.autowalker.nextRoom = demonnic.autowalker:closestRoom()
  if demonnic.autowalker.nextRoom ~= "" then
    tempTimer(0, function() mmp.gotoRoom(demonnic.autowalker.nextRoom) end)
  else
    raiseEvent("demonwalker.stop")
  end
end

function demonnic.autowalker:arrived()
  if tonumber(mmp.currentroom) == tonumber(demonnic.autowalker.nextRoom) then
    demonnic.autowalker.currentRoom = mmp.currentroom
    demonnic:findAndRemove(demonnic.autowalker.remainingRooms, mmp.currentroom)
    raiseEvent("demonwalker.arrived")
  else
    debugc("demonwalker: Somehow, the mudlet mapper says we have arrived but it is not to the room we said to go to.")
  end
end

function demonnic.autowalker:failedPath()
  demonnic:findAndRemove(demonnic.autowalker.remainingRooms, demonnic.autowalker.nextRoom)
  demonnic.autowalker.currentRoom = mmp.currentroom
  raiseEvent("demonwalker.move")
end

function demonnic.autowalker:removeEventHandlers()
  for _, handlerID in pairs(demonnic.autowalker.eventHandlers) do
    killAnonymousEventHandler(handlerID)
  end
end

function demonnic.autowalker:registerEventHandlers()
  demonnic.autowalker.eventHandlers = demonnic.autowalker.eventHandlers or {}
  demonnic.autowalker:removeEventHandlers()
  demonnic.autowalker.eventHandlers.move = registerAnonymousEventHandler("demonwalker.move", demonnic.autowalker.move)
  demonnic.autowalker.eventHandlers.stop = registerAnonymousEventHandler("demonwalker.stop", demonnic.autowalker.stop)
  demonnic.autowalker.eventHandlers.arrived = registerAnonymousEventHandler("mmapper arrived", demonnic.autowalker.arrived)
  demonnic.autowalker.eventHandlers.failedPath = registerAnonymousEventHandler("mmapper failed path", demonnic.autowalker.failedPath)
end

function demonnic.autowalker:getAdjacantRooms(roomID)
  local adjacentRooms = table.keys(getSpecialExits(roomID))
  local exits = getRoomExits(roomID)
  for _,id in pairs(exits) do
    adjacentRooms[#adjacentRooms+1] = id
  end
  return adjacentRooms
end

function demonnic.autowalker:extractFirstUnvisitedRoom(rooms)
  local remainingRooms = demonnic.autowalker.remainingRooms
  for _,id in ipairs(rooms) do
    if table.index_of(remainingRooms, id) then
      return id
    end
  end
  return nil
end

function demonnic.autowalker:closestRoom()
  local adjacentRooms = demonnic.autowalker:getAdjacantRooms(mmp.currentroom)
  local remainingRooms = demonnic.autowalker.remainingRooms
  if not remainingRooms then return "" end
  if #remainingRooms == 0 then return "" end
  local roomID
  -- check all the directly adjacent rooms
  roomID = demonnic.autowalker:extractFirstUnvisitedRoom(adjacentRooms)
  if roomID then return roomID end

  -- ok, check all the rooms 2 steps away
  for _,id in ipairs(adjacentRooms) do
    local adjRooms = demonnic.autowalker:getAdjacantRooms(id)
    roomID = demonnic.autowalker:extractFirstUnvisitedRoom(adjRooms)
    if roomID then return roomID end
  end

  -- fine, I'll brute force it.
  local distance = 99999
  for _, v in pairs(remainingRooms) do
    local ok, pathLength = getPath(demonnic.autowalker.currentRoom, v)
    if ok and pathLength < distance then
      distance = pathLength
      roomID = v
      if distance <= 3 then return roomID end
    end
  end
  return roomID or ""
end
