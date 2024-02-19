--The startup which checks for updates and whether it's using OpenOS or MineOS
local status, compat = pcall(require,"Compat")
if not status then --auto assume system is OpenOS because MineOS should autoinstall it
    print("Installing Compatability layer")
    os.execute("wget -f https://raw.githubusercontent.com/cadergator10/Opencomputers-serpentine/main/database/Compat.lua Compat.lua")
    compat = require("Compat")
end
local mainPage = "https://cadespc.com/servertine/modules/"
local download = mainPage .. "getservertine" --URL used by boot for servertine stuff
local aRD = compat.isMine and compat.fs.path(compat.system.getCurrentScript()) or "" --path of program
local config = compat.loadTable(aRD .. "bootconfig.txt") --boot configuration
local term = not compat.isMine and require("term") or nil --nil if MineOS, is term API if OpenOS
--openOSReq are library files for GUI and GUI API + JSON
local openOSReq = {["JSON.lua"]="https://github.com/IgorTimofeev/MineOS/raw/master/Libraries/JSON.lua",["GUI.lua"]="https://raw.githubusercontent.com/cadergator10/Opencomputers-serpentine/main/database/GUI.lua",["advancedLua.lua"]="https://github.com/IgorTimofeev/AdvancedLua/raw/master/AdvancedLua.lua",["color.lua"]="https://github.com/IgorTimofeev/Color/raw/master/Color.lua",["doubleBuffering.lua"]="https://github.com/IgorTimofeev/DoubleBuffering/raw/master/DoubleBuffering.lua",["image.lua"]="https://github.com/IgorTimofeev/Image/raw/master/Image.lua",["OCIF.lua"]="https://github.com/IgorTimofeev/Image/raw/master/OCIF.lua"}

if not compat.isMine then --Should, if OpenOS, install all dependencies.
    local status, _ = pcall(require,"GUI") --Check if GUI API exists. Otherwise, download it.
    if not status then
        for key,value in pairs(openOSReq) do
            print("Installing " .. key)
            compat.internet.download(value,"/lib/" .. key)
            --os.execute("wget -f " .. value .. " /lib/" .. key) --(getting rid of wget execute in favor of actual compat downloader)
        end
        os.execute("mkdir /lib/FormatModules")
        print("Installing OCIF in FormatModules folder") --OCIF must be in this folder for Image library to work.
        compat.internet.download("https://github.com/IgorTimofeev/Image/raw/master/OCIF.lua","/lib/FormatModules/OCIF.lua")
    end
end

local GUI = require("GUI")
local JSON = require("JSON")

--libs that get filled in future
local errHan

local didError = false --If error handler detects error, then clearScreen() doesn't clear the screen

local arg = ...
if arg ~= nil then --If someone inputs args, it prints it out.
    print(arg)
end

local function split(s, delimiter) --splits string ("hello,world,yeah") into table {"hello","world","yeah"}
    local result = {}
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match)
    end
    return result
  end

local function installer(version, bootver) --asks user input and stuff, plus installs all files from my website
    local install = false
    local saveBoot = true
    local isConfig = config == nil
    if config == nil then --create boot config.
        config = {["version"] = -1,["bootver"] = -1,["checkVersion"]=true,["lang"]="English",["shutdownonexit"]=true,["startupParams"]={},["anonymousReport"]=true}--startupParams are one-time keys to do stuff, usually done by the database itself.
        saveBoot = true
        install = true
        GUI.alert("By default, anonymous reporting is enabled. If enabled it will automatically send any crashes or errors caused by the system or a module to the developer/owner. You can change this in bootconfig.txt file")
    elseif config.bootver == nil then
        config.bootver = -1
        saveBoot = true
        install = true
    end
    local style = {bottomButton = 0xFFFFFF, bottomText = 0x555555, bottomSelectButton = 0x880000, bottomSelectText = 0xFFFFFF}
    if compat.isMine then --is MineOS
        --TODO: Debug if OpenOS version works, then create MineOS one
        --compat.system.addWindow(0xE1E1E1)
        if isConfig then
            GUI.alert("New system: Installing servertine") --Force install of system. Doesn't ask whether to install
        elseif config.bootver == -1 then
            GUI.alert("Boot files prepping install")
        else
            install = -2 --makes sure it waits until user inputs something
            local workspace = GUI.workspace()
            local container = GUI.addBackgroundContainer(workspace, true, true, "New version available:" )
            if version ~= config.version then container.layout:addChild(GUI.label(80,5,16,1, style.bottomText, "Servertine: " .. tostring(config.version) .. " -> " .. tostring(version))) end
            if bootver ~= config.bootver then container.layout:addChild(GUI.label(80,5,16,1, style.bottomText, "Boot Version: " .. tostring(config.bootver) .. " -> " .. tostring(bootver))) end
            container.layout:addChild(GUI.button(80,5,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "Install")).onTouch = function()
                install = true --Install all stuff
                container:remove()
                workspace:draw(true)
                workspace:stop()
            end
            container.layout:addChild(GUI.button(80,5,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "Don't Install")).onTouch = function()
                install = false --don't install
                container:remove()
                workspace:draw(true)
                workspace:stop()
            end
            container.layout:addChild(GUI.button(80,5,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "Don't ask again")).onTouch = function()
                config.checkVersion = false --don't install and don't version check anymore
                compat.saveTable(config,aRD .. "bootconfig.txt")
                install = false
                container:remove()
                workspace:draw(true)
                workspace:stop()
            end
            container.panel.onTouch = function() --Always install if panel clicked
                install = true --Install all stuff
                container:remove()
                workspace:draw(true)
                workspace:stop()
            end
            workspace:draw(true)
            workspace:start()
        end
        while install == -2 do --repeat until user presses button. TEST: Not tested yet
            --os.sleep() --may require restart if os.sleep()
        end
        if install then
            local worked, errored = compat.internet.request(download .. "files",nil,{["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.119 Safari/537.36"}) --get file urls from server
            if worked then --if successful request
                local tempTable = JSON.decode(worked) --decode JSON to table
                local aRD = compat.fs.path(compat.system.getCurrentScript()) --get file location
                local workspace = GUI.workspace()
                --main stuff
                local container = GUI.addBackgroundContainer(workspace, true, true, "Setting up folders")
                workspace:draw(true)
                local folders = split(tempTable.folders,",") --prep folders? TODO: Fix what's wrong here WHY
                for _,value in pairs(folders) do
                    if compat.fs.isDirectory(aRD .. value) then --if dir exists, delete it. Then it makes a directory again
                        compat.fs.remove(aRD .. value)
                    end
                    compat.fs.makeDirectory(aRD .. value)
                end
                --doing boot stuff first
                if(bootver ~= config.bootver) then --TODO: Fix version checker if broken & make sure it doesnt use openOSReq when downloading the files
                    --[[if not (compat.isMine) then
                        for key,value in pairs(openOSReq) do --install
                            print("Installing " .. key)
                            compat.internet.download(value,"/lib/" .. key)
                            --os.execute("wget -f " .. value .. " /lib/" .. key) --(getting rid of wget execute in favor of actual compat downloader)
                        end
                    end]] --commented since clearly mineos
                    if compat.fs.isDirectory(aRD .. "BootFiles") then
                        compat.fs.remove(aRD .. "BootFiles")
                    end
                    compat.fs.makeDirectory(aRD .. "BootFiles")
                    for _, value in pairs(tempTable.boot) do
                        if value.type == "boot" and value.noMine == false then
                            container.label.text = "Installing boot file to " .. value.path .. " file from URL: " .. value.url
                            workspace:draw(true)
                            compat.internet.download(value.url,string.sub(value.path,1,1) == "~" and aRD .. string.sub(value.path,2,-1) or value.path)
                        end --Shouldn't need itself overwritten since not OpenOS.
                    end  --WHAT AM I THINKING?!? MINEOS HAS ALL BOOT FILES (apart from error checking) TODO: fix the website so it can determine what is only OpenOS and what is for both
                end
                --other stuff
                if(version ~= config.version) then

                    for _, value in pairs(tempTable.files) do
                        if value.type == "db" then --Download the required files in all locations
                            container.label.text = "Installing to " .. value.path .. " file from URL: " .. value.url
                            workspace:draw(true)
                            compat.internet.download(value.url,aRD .. value.path)
                        end
                    end
                end
                container:remove()
                workspace:draw(true)
                config.version = tempTable.version
                config.bootver = tempTable.bootver
                compat.saveTable(config,aRD .. "bootconfig.txt") --update version for version checker
                loc = compat.system.getLocalization(compat.fs.path(compat.system.getCurrentScript()) .. "Localizations/") --Retrieve localizations in boot loader so 1. available in boot file, and 2. Enabled by default.
            else
                error("Failed to download files. Server may be down")
            end
            --perform install
            return true
        elseif not isConfig then
            return true
        else
            return false
        end
    else --OpenOS version
        term.clear()
        if isConfig then
            print("New system: Installing servertine") --force install
        elseif arg == "--install" then
            print("Install command received. Reinstalling everything") --if they run the boot and input --install after it, it will install regardless of version check
            install = true
        else
            print("New version for the Servertine Database is available!") --let them choose whether to install
            if version ~= config.version then print(tostring(config.version) .. " -> " .. tostring(version)) end
            if bootver ~= config.bootver then print(tostring(config.bootver) .. " -> " .. tostring(bootver)) end
            print("Would you like to install this version? yes or no\nSome modules may require the new version")
            local text = term.read():sub(1,-2)
            while text ~= "yes" and text ~= "no" do
                print("Invalid input")
                text = term.read():sub(1,-2)
            end
            if text == "yes" then --install new version
                install = true
            else --don't
                print("Do you want the system to remember your decision?")
                local text = term.read():sub(1,-2)
                while text ~= "yes" and text ~= "no" do
                    print("Invalid input")
                    text = term.read():sub(1,-2)
                end
                if text == "yes" then --skip version checking in future
                    config.checkVersion = false
                    compat.saveTable(config,aRD .. "bootconfig.txt")
                end
            end
        end
        if install then
            local worked, errored = compat.internet.request(download .. "files",nil,{["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.119 Safari/537.36"})
            if worked then
                local tempTable = JSON.decode(worked) --TODO: Make sure this matches json sent by the server
                local aRD = compat.fs.path(compat.system.getCurrentScript())

                local folders = split(tempTable.folders,",") --prep folders?
                for _,value in pairs(folders) do
                    if compat.fs.isDirectory(aRD .. value) then
                        compat.fs.remove(aRD .. value)
                    end --setup folders
                    compat.fs.makeDirectory(aRD .. value)
                end
                --doing boot stuff first
                if(bootver ~= config.bootver) then
                    --[[for key,value in pairs(openOSReq) do --install
                        print("Installing " .. key)
                        compat.internet.download(value,"/lib/" .. key)
                        --os.execute("wget -f " .. value .. " /lib/" .. key) --(getting rid of wget execute in favor of actual compat downloader)
                    end]] --commented out to see if fix
                    if compat.fs.isDirectory(aRD .. "BootFiles") then
                        compat.fs.remove(aRD .. "BootFiles")
                    end
                    compat.fs.makeDirectory(aRD .. "BootFiles")
                    local mainF = null
                    for _, value in pairs(tempTable.boot) do
                        if value.type == "boot" then
                            print("Installing boot file to " .. value.path .. " file from URL: " .. value.url)
                            compat.internet.download(value.url,string.sub(value.path,1,1) == "~" and aRD .. string.sub(value.path,2,-1) or value.path) --Make sure that a "~" allows it to use the local folder rather than global
                        elseif value.type == "bootmain" then
                            mainF = value
                        end
                    end
                    if mainF ~= null then
                        print("Installing main boot program")
                        compat.internet.download(mainF.url, aRD .. "boot.lua")
                    end
                end
                --other stuff
                for _, value in pairs(tempTable.files) do --install files
                    if value.type == "db" then
                        print("Installing to " .. value.path .. " file from URL: " .. value.url)
                        compat.internet.download(value.url,aRD .. value.path)
                    end
                end
                config.version = tempTable.version --change version for version checker
                config.bootver = tempTable.bootver
                local goodBoot = bootver ~= config.bootver
                config.bootver = tempTable.bootver
                compat.saveTable(config,aRD .. "bootconfig.txt")
                if(goodBoot) then
                    print("Please restart computer to run new boot")
                    os.sleep(2)
                    os.execute("shutdown")
                end
                loc = compat.system.getLocalization(compat.fs.path(compat.system.getCurrentScript()) .. "Localizations/") --Retrieve localizations in boot loader so 1. available in boot file, and 2. Enabled by default.
            else
                error("Failed to download files. Server may be down") --failed to connect to server
            end
            --perform install
            return true --true means can run file
        elseif not isConfig then
            return true
        else
            return false --false means can't run file (not installed likely)
        end
    end
    if saveBoot then --at end in case install fails
        compat.saveTable(config,aRD .. "bootconfig.txt")
    end
end

local function clearScreen() --If OpenOS, clear screen to make better after closing.
    if not compat.isMine and not didError then
        if compat.workspace ~= nil then --remove all GUI stuff to see if this fixes bad background
            compat.window:remove()
            compat.workspace:draw(true)
            compat.workspace:stop()
            compat.window, compat.workspace = nil, nil
        end
        term = require("Term")
        term.clear()
        if config.shutdownonexit then
            os.sleep(1) --wait 1 sec
            os.execute("shutdown")
        end
    end
end


if config == nil or arg == "--install" or config.bootver == nil then
    installer() --If no config or --install key passed after running boot, it runs installer
elseif arg == "--lib" then
    for key,value in pairs(openOSReq) do
        print("Installing " .. key)
        compat.internet.download(value,"/lib/" .. key)
        --os.execute("wget -f " .. value .. " /lib/" .. key) --(getting rid of wget execute in favor of actual compat downloader)
    end
elseif arg == "--delcompat" then
    compat.fs.remove(aRD .. "Compat.lua")
    print("Compat library removed! Can be reinstalled after rebooting pc")
    os.sleep(3)
    os.execute("shutdown")
end

errHan = require("BootFiles/errorhandler")
errHan.setup(config)

compat.lang = config.lang --set compat lang file to whatever is in bootconfig (for OpenOS, since no localization stuff works with it.)
local status, loc = pcall(compat.system.getLocalization(compat.fs.path(compat.system.getCurrentScript()) .. "Localizations/")) --Retrieve localizations in boot loader so 1. available in boot file, and 2. Enabled by default.
local result, reason = loadfile(compat.fs.path(compat.system.getCurrentScript()) .. "/Database.lua") --check for database program
if result then --file exists
    result = compat.fs.path(compat.system.getCurrentScript()) .. "/Database.lua" --set path for dofile()
    if config.checkVersion then --If version checking is enabled
        local worked, errored = compat.internet.request(download .. "version",nil,{["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.119 Safari/537.36"})
        if worked then --If got info from website
            local tempTable = JSON.decode(worked)
            if tempTable.success == true and (tempTable.version ~= config.version or tempTable.bootver ~= config.bootver) then --success checking version and version is not the same as one on web (bad version or update to system)
                local goodToRun = installer(tempTable.version, tempTable.bootver) --run installer
                if goodToRun then --run program
                    local success, result = pcall(dofile,result)
                    if not success then
                        errHan.erHandle(result)
                        didError = true
                    end
                    clearScreen()
                end
            else
                local success, result = pcall(dofile,result)
                if not success then
                    errHan.erHandle(result)
                    didError = true
                end
                clearScreen()
            end
        else --failed to connect to web: run database anyway
            GUI.alert("Error getting version from website")
            local success, result = pcall(dofile,result)
            if not success then
                errHan.erHandle(result)
                didError = true
            end
            clearScreen()
        end
    else --no version checking: only run program
        local success, result = pcall(dofile,result)
        if not success then
            errHan.erHandle(result)
            didError = true
        end
        clearScreen()
    end
else --try running installer since db file doesn't exist
    local goodToRun = installer()
    if goodToRun then --file should exist now
        result, reason = loadfile(compat.fs.path(compat.system.getCurrentScript()) .. "/Database.lua")
        if result then --is loaded, so now can run
            result = compat.fs.path(compat.system.getCurrentScript()) .. "/Database.lua"
            local success, result = pcall(dofile,result)
            if not success then
                errHan.erHandle(result)
                didError = true
            end
            clearScreen()
        else --still doesn't exist?
            error("Failed to run installed program. It'sa makea no sensea")
        end
    end
end