--File holding functions that the Database uses. Used to make stuff work on both MineOS and OpenOS

local module = {["system"]={},["fs"]={},["event"]={},["internet"]={}}

local component = require("component")
local gpu = component.gpu

local guiGood, GUI = pcall(require,"GUI") --In case GUI hasn't been installed yet (by boot)
local ser = require("serialization")
local uuid = require("uuid")

module.isMine = true
module.lang = "English"

local event, system, shell, internet, process, json, io,fs
local status, lfs = pcall(require, "System")
if not status then
    lfs = nil
    module.isMine = false
    event = require("event")
    fs = require("filesystem")
    system = require("shell")
    internet = require("internet")
    process = require("process")
    io = require("io")
else
    event = require("event")
    fs = require("Filesystem")
    internet = require("Internet")
    json = require("JSON")
    system = lfs
    lfs = nil
end

function module.fs.open(sfile, type)
    if module.isMine then
        return fs.open(sfile, type)
    else
        return io.open(sfile, type)
    end
end

function module.saveTable(  tbl,filename )
    if module.isMine then
        local tableFile = fs.open(filename, "w")
        tableFile:write(ser.serialize(tbl))
        tableFile:close()
    else
        local tableFile = assert(io.open(filename, "w"))
        tableFile:write(ser.serialize(tbl))
        tableFile:close()
    end
end
 
function module.loadTable( sfile )
    if module.isMine then
        local tableFile = fs.open(sfile, "r")
        if tableFile ~= nil then
            return ser.unserialize(tableFile:readAll())
        else
            return nil
        end
    else
        local tableFile = io.open(sfile)
        if tableFile ~= nil then
            return ser.unserialize(tableFile:read("*all"))
        else
            return nil
        end
    end
end

function module.fs.path(path)
    if module.isMine then
        return fs.path(path)
    else
        return fs.path(path)
    end
end

function module.fs.isDirectory(path)
    if module.isMine then
        return fs.isDirectory(path)
    else
        return fs.isDirectory(path)
    end
end

function module.fs.remove(path)
    if module.isMine then
        return fs.remove(path)
    else
        return fs.remove(path)
    end
end

function module.fs.list(path)
    if module.isMine then
        return fs.list(path)
    else
        local tempTable = {}
        for file in fs.list(path) do
            table.insert(tempTable,file)
        end
        return #tempTable > 0 and tempTable or nil
    end
end

function module.fs.makeDirectory(path)
    if module.isMine then
        return fs.makeDirectory(path)
    else
        return fs.makeDirectory(path)
    end
end

function module.system.getCurrentScript()
    if module.isMine then
        return system.getCurrentScript()
    else
        return system.resolve(process.info().path)
    end
end

function module.system.getLocalization(path)
    if module.isMine then
        module.loc = system.getLocalization(path)
        return module.loc
    else
        local loc = module.loadTable(path .. module.lang .. ".lang")
        if loc == nil then
            loc = module.loadTable(path .. "English.lang")
        end
        module.loc = loc
        return loc
    end
end

function module.system.addContextMenu(menu,file)
    if module.isMine then
        return menu:addContextMenuItem(file)
    else
        return menu:addContextMenu(file)
    end
end

function module.event.pull(time)
    if module.isMine then
        return event.pull(time)
    else
        return event.pull(time)
    end
end

function module.event.addhandler(handler)
    if module.isMine then
        return event.addHandler(handler)
    else
        event.listen("cardInsert",handler)
        event.listen("cardRemove",handler)
        return handler
    end
end

function module.event.removehandler(handler)
    if module.isMine then
        return event.removeHandler(handler)
    else
        event.ignore("cardInsert",handler)
        event.ignore("cardRemove",handler)
    end
end

function module.internet.request(url,postData,headers,method)
    if module.isMine then
        return internet.request(url,postData ~= nil and internet.serialize(postData) or nil,headers,method)
    else
        local JSON = require("JSON")
        local text = ""
        for chunk in internet.request(url,postData ~= nil and JSON.encode(postData) or nil,headers,method) do
            text = text .. chunk
        end
        return text, "error unknown (openos)"
    end
end

function module.internet.download(url,path)
    if module.isMine then
        return internet.download(url,path)
    else
        local file = ""
        for chunk in internet.request(url,nil,{["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.119 Safari/537.36",["content-type"]="application/json"}) do
            file = file .. chunk
        end
        if fs.exists(path) then
            fs.remove(path)
        end
        local tableFile = assert(io.open(path, "w")) --error
        tableFile:write(file)
        tableFile:close()
        file = nil
        return true
    end
end

function module.fs.readTable(path)
    if module.isMine then
        return fs.readTable(path)
    else
        return module.loadTable(path)
    end
end

function module.system.addWindow(style)
    if not guiGood then
        GUI = require("GUI")
        guiGood = true
    end
    if module.isMine then
        return system.addWindow(GUI.filledWindow(2,2,150,45,style))
    else
        local work = GUI.application()
        local window = work:addChild(GUI.container(1,1,work.width,work.height))
        module.workspace, module.window = work, window
        window:addChild(GUI.panel(1,1,window.width,window.height,style))
        return work, window, work:addChild(GUI.menu(1,1,work.width,0xEEEEEE, 0x666666, 0x3366CC, 0xFFFFFF)) --TODO: Check if legacy GUI works with this
    end
end

return module