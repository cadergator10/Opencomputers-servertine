local module = {}
local compat, config

local GUI = require("GUI")
local JSON = require("JSON")
local mainPage = "https://cadespc.com/servertine/modules/"


function module.setup(compated, configs)
    compat = compated
    config = configs
end

local style = {bottomButton = 0xFFFFFF, bottomText = 0x555555, bottomSelectButton = 0x880000, bottomSelectText = 0xFFFFFF}

function module.erHandle(er) --Was used to print out errors, but moving to PCall as that works more than XPcall
    if compat.workspace ~= nil then
        compat.window:remove()
        compat.workspace:draw(true)
        compat.workspace:stop()
        compat.window, compat.workspace = nil, nil
    end
    GUI.alert("Something went wrong:\n" .. tostring(er) .. ((config.anonymousReport and isDevMode == false) and "\nReporting error to server" or "\nAnonymous Reporting disabled"))

    local workspace
    if not compat.isMine then
        workspace = GUI.application()
    else
        workspace = GUI.workspace()
    end --TODO: Finish zis
    local container = GUI.addBackgroundContainer(workspace, true, true, "Would you like to fill out the report or leave it anonymous?" )
    container.layout:addChild(container.layout:addChild(GUI.label(80,5,16,1, 0x555555, "Filling it out sends the files from your system to the site")))
    container.layout:addChild(container.layout:addChild(GUI.label(80,5,16,1, 0x555555, "as well as creates a page for you to add additional details + remove some files")))
    container.layout:addChild(container.layout:addChild(GUI.label(80,5,16,1, 0x555555, "If you don't go to the site within 30 minutes, it will submit all data anyway")))

    local isFill = -2
    container.layout:addChild(GUI.button(80,5,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "Fill out report")).onTouch = function()
        container:remove()
        workspace:draw(true)
        workspace:stop()
        isFill = true
    end
    container.layout:addChild(GUI.button(80,5,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "Anonymous Only")).onTouch = function()
        container:remove()
        workspace:draw(true)
        workspace:stop()
        isFill = false
    end
    while isFill == -2 do --repeat until user presses button. TEST: Not tested yet
        --os.sleep() --may require restart if os.sleep()
    end

    if config.anonymousReport and isDevMode == false then --DO NOT REPORT if isDevMode is false
        if isFill == false then
            local ev, e = compat.internet.request(mainPage .. "anonymousReport",{["moduleId"] = (modID ~= 0 and modID or nil),["description"] = tostring(er)},{["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.119 Safari/537.36",["Content-Type"]="application/json"})
            if ev then
                ev = JSON.decode(ev)
                if ev.success then
                    GUI.alert("Submitted report")
                else
                    GUI.alert("Failed to submit report: " .. ev.response)
                end
            else
                GUI.alert("Failed request: " .. tostring(e))
            end
        elseif isFill == true then
            local ev, e = compat.internet.request(mainPage .. "filledReport",{["moduleId"] = (modID ~= 0 and modID or nil),["description"] = tostring(er)},{["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.119 Safari/537.36",["Content-Type"]="application/json"})
            if ev then
                ev = JSON.decode(ev)
                if ev.success then
                    GUI.alert("Submitted report")
                else
                    GUI.alert("Failed to submit report: " .. ev.response)
                end
            else
                GUI.alert("Failed request: " .. tostring(e))
            end
        end
    end
    error("Something went wrong:\n" .. tostring(er) .. "\nError reporting will be available in the future")
end