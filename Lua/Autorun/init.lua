NTID = {}
NTID.Name="NT Informative Descriptions"
NTID.Version = "1.0"
NTID.Path = table.pack(...)[1]
Timer.Wait(function() if NTC ~= nil and NTC.RegisterExpansion ~= nil then NTC.RegisterExpansion(NTID) end end,1)


if CLIENT or not Game.IsMultiplayer then
  Timer.Wait(function()
      if NTC == nil then
          print("Error loading NT Informative Descriptions: it appears that Neurotrauma isn't enabled!")
          return
      end
    dofile(NTID.Path .. '/Lua/main.lua')
  end,1)
end



