#!/bin/env lua
local output = {
  ["Heizung"] = {
    ["Schlafzimmer"] = { topic = "hm/status/schlafzimmer-heizung:1/ACTUAL_TEMPERATURE", json = { "val" }, append = "°C" },
    ["Bad"]          = { topic = "hm/status/bad-heizung:1/ACTUAL_TEMPERATURE",          json = { "val" }, append = "°C" },
    ["Gästezimmer"]  = { topic = "hm/status/gästezimmer-heizung:1/ACTUAL_TEMPERATURE",  json = { "val" }, append = "°C" },
  }
}

local function draw()
  io.write("\027[H\027[2J")
  for category, data in pairs(output) do
    print("\027[1m\027[34m:: \027[0m\027[1m" .. category .. "\027[0m")
    for title, data in pairs(data) do
      local value = data.value and data.value .. (data.append or "") or "N/A"
      print("  " .. title .. ": " .. value)
    end
  end
end

local listen = {}
for category, data in pairs(output) do
  for title, data in pairs(data) do
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
