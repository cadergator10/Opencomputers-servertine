local module = {}
local compat, config

compat = require("Compat")
local GUI = require("GUI")
local JSON = require("JSON")
local ser = require("serialization")
local mainPage = "https://cadespc.com/servertine/modules/getalerts"

local aRD = compat.isMine and compat.fs.path(compat.system.getCurrentScript()) or "" --path of program

function module.setup(configs)
    config = configs
end

local style = {bottomButton = 0xFFFFFF, bottomText = 0x555555, bottomSelectButton = 0x880000, bottomSelectText = 0xFFFFFF}

function module.getNotifications()
    if config.getNotif then
        local ev, e = compat.internet.request(mainPage,nil,{["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.119 Safari/537.36"})
        if ev then
            ev = JSON.decode(ev)
            if (ev.success == true) then
                for _, value in pairs(ev.data) do
                    GUI.alert(value.line1, value.line2)
                end
            else
                GUI.alert("Failed to get alerts: " .. ev.response)
            end
        end
    end
end

return module