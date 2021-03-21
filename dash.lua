#!/bin/env lua
local output = {
  { title = "Heizung", elements = {
    { title = "Bad",           topic = "hm/status/bad-heizung:1/ACTUAL_TEMPERATURE",            json = { "val" }, append = "°C" },
    { title = "Schlafzimmer",  topic = "hm/status/schlafzimmer-heizung:1/ACTUAL_TEMPERATURE",   json = { "val" }, append = "°C" },
    { title = "Gästezimmer",   topic = "hm/status/gästezimmer-heizung:1/ACTUAL_TEMPERATURE",    json = { "val" }, append = "°C" },
    { title = "Arbeitszimmer", topic = "hm/status/arbeitszimmer-heizung:1/ACTUAL_TEMPERATURE",  json = { "val" }, append = "°C" },
  }}
}

local function utflen(str)
  local str = tostring(str)
  local length, utf = #str, 0
  for i=1,#str do
    local char = string.sub(str, i, i)
    if string.byte(char) >= 194 then
      utf = utf + 1
    end
  end

  return length - utf
end

local width = {}
local function scanwidth(tbl)
  for id, data in pairs(tbl) do
    if type(data) == "table" and data.title then
      width[tbl] = math.max((width[tbl] or 0), utflen(data.title))
      for id, dat in pairs(data) do
        if type(dat) == "table" and not width[dat] then scanwidth(dat) end
      end
    end
  end
end

local function getspace(context, str)
  local num = width[context] - utflen(str)
  local space = ""
  for i=0,num do space = space .. " " end
  return space, num
end

local function draw()
  -- scan all title widths
  scanwidth(output)

  -- draw content to screen
  io.write("\027[H\027[2J")
  for id, section in pairs(output) do
    print("\027[1m\027[34m:: \027[0m\027[1m" .. section.title .. "\027[0m")

    for id, data in pairs(section.elements) do
      local value = data.value and data.value .. (data.append or "") or "N/A"
      local spacing, num = getspace(section.elements, data.title)
      print("  " .. data.title .. ": " .. spacing .. value)
    end
  end
end

local listen = {}
for id, data in pairs(output) do
  for id, data in pairs(data.elements) do
    listen[data.topic] = listen[data.topic] or {}
    table.insert(listen[data.topic], data)
  end
end

local json = require("dkjson")
local mqtt = require("mosquitto")
local client = mqtt.new()

client.ON_CONNECT = function()
  client:subscribe("#")
end

client.ON_MESSAGE = function(mid, topic, payload)
  if listen[topic] then
    for id, data in pairs(listen[topic]) do
      if data.json then
        local parse = json.decode(payload)
        for _, sub in pairs(data.json) do
          if parse and parse[sub] then parse = parse[sub] end
        end
        data.value = parse
      end
    end

    draw()
  end
end

client:connect("mqtt.midgard")
client:loop_forever()
