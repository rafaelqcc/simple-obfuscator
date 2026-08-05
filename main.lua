--[[
  ____  _                 _         ___  _      __                     _             
 / ___|(_)_ __ ___  _ __ | | ___   / _ \| |__  / _|_   _ ___  ___ __ _| |_ ___  _ __ 
 \___ \| | '_ ` _ \| '_ \| |/ _ \ | | | | '_ \| |_| | | / __|/ __/ _` | __/ _ \| '__|
  ___) | | | | | | | |_) | |  __/ | |_| | |_) |  _| |_| \__ \ (_| (_| | || (_) | |   
 |____/|_|_| |_| |_| .__/|_|\___|  \___/|_.__/|_|  \__,_|___/\___\__,_|\__\___/|_|   
                   |_|
]]

local Parser = require("parser")
local ast = require("parser.lua.ast")

local function countLines(str)
    local lines = 1

    for _ in str:gmatch("\n") do
        lines = lines + 1
    end

    return lines
end

--Put your code here
local code = [[
local function c(a,b)
return a+b
end
print(c(5,6))
print("This is a text that will be obfuscated.")
]]

local tree, err = Parser.parse(code, "test.lua", "5.4")

if not tree then
    error(err)
end

local function dump(node, indent)
    indent = indent or ""

    print(indent .. "TYPE: " .. tostring(node.type))

    for k, v in pairs(node) do
        if k ~= "parent" then
            if type(v) == "table" and v.type then
                print(indent .. "FIELD " .. k)
                dump(v, indent .. "  ")
            elseif type(v) == "table" then
                print(indent .. "FIELD " .. k .. " (table)")
                for i, child in ipairs(v) do
                    if type(child) == "table" and child.type then
                        dump(child, indent .. "  ")
                    end
                end
            else
                print(indent .. "  " .. k .. " = " .. tostring(v))
            end
        end
    end
end

--dump(tree)

local FlattenString = ast.nodeclass("flattenstring")

function FlattenString:init(parts)
    self.parts = parts
end

function FlattenString:serialize(consume)
    for i, part in ipairs(self.parts) do
        if i > 1 then
            consume("..")
        end
        consume('"'..part..'"')
    end
end

local function flattenString(str, size)
    local parts = {}

    for i = 1, #str, size do
        local part = str:sub(i, i + size - 1)

        local encoded = ""

        for j = 1, #part do
            encoded = encoded .. "\\" .. part:byte(j)
        end

        parts[#parts+1] = encoded
    end

    return parts
end

local templates = {
    function(name)
        local id = math.random(1000,9999)
        return [[
local ]]..name..[[ = ]]..id..[[
if ]]..name..[[ ~= ]]..id..[[ then
    local x = 0
else
    local y = 1
end
]]
    end,

    function(name)
        local state = math.random(1,5)
        return [[
local ]]..name..[[ = ]]..state..[[
while true do
    if ]]..name..[[ == ]]..state..[[ then
        break
    else
        ]]..name..[[ = ]]..name..[[ + 1
    end
end
]]
    end,

    function(name)
        local a = math.random(10,99)
        local b = math.random(100,999)

        return [[
local ]]..name..[[ = ]]..a..[[
if ]]..name..[[ > ]]..b..[[ then
    print("super cfg wow")
end
]]
    end,

    function(name)
        return [[
do
    local ]]..name..[[ = function()
        return false
    end

    if ]]..name..[[]() then
       if 10+3-1+2==15 then return "noooo lgic" end
       print("U can deobf")
    end
end
]]
    end
}

local DeadCode = ast.nodeclass("deadcode")

function DeadCode:init(name, template)
    self.name = name
    self.template = template
end

function DeadCode:serialize(consume)
    consume(";" .. self.template(self.name))
end

local names = {
    "a",
    "tmp",
    "cache",
    "data2"
}

local passes = {}

passes[#passes+1] = function(node)
    if node.type == "string" and #node.value > 4 then
        return FlattenString(flattenString(node.value,3))
    end
    return node
end

passes[#passes+1] = function(node)
    if node.type == "block" and math.random(1,3) == 1 then
        table.insert(node,
            DeadCode(
                names[math.random(#names)],
                templates[math.random(#templates)]
            )
        )
    end

    return node
end

ast.traverse(tree,function(node)
    for _,pass in ipairs(passes) do
        node = pass(node)
    end

    return node
end)

local function minifyLua(code)
    local result = {}
    local i = 1
    local len = #code
    local inString = false
    local quote
    local buffer = ""

    while i <= len do
        local c = code:sub(i,i)

        if inString then
            buffer = buffer .. c

            if c == "\\" then
                i = i + 1
                buffer = buffer .. code:sub(i,i)
            elseif c == quote then
                inString = false
            end

        else
            if c == '"' or c == "'" then
                inString = true
                quote = c
                buffer = buffer .. c

            elseif code:sub(i,i+3) == "--[[" then
                i = code:find("]]", i+4) or len
                i = i + 1

            elseif code:sub(i,i+1) == "--" then
                local n = code:find("\n", i+2)
                if n then
                    i = n
                else
                    break
                end

            else
                buffer = buffer .. c
            end
        end

        i = i + 1
    end

    buffer = buffer:gsub("[ \t\r\n]+", " ")
    buffer = buffer:gsub("%s*([%(%)%{%}%[%],;=+%-%*/%%<>])%s*", "%1")

    return buffer
end

local obfCode = tree:toLua()

local minifiedCode = minifyLua(obfCode)

local lines = countLines(minifiedCode)

-- Simple Anti tamper
local antiTamperCode = [=[
do
local function _81779df7(g)local uchar=utf8.char;local J=g:gsub("........",{['e317353a']=uchar(0x74);['bc270951']=uchar(0x65);['3719ef79']=uchar(0x62);['e325f309']=uchar(0x53);['bc3bbd28']=uchar(0x21);['cd765057']=uchar(0x64);['2dde31c9']=uchar(0x70);['f5045829']=uchar(0x54);['18592d09']=uchar(0x61);['c9514e7e']=uchar(0x6d);['2996e65f']=uchar(0x3a);['6c298fd9']=uchar(0x20);['56c4adc7']=uchar(0x40);['4e5320e7']=uchar(0x41);['c1cb0d38']=uchar(0x72);['b03bd59f']=uchar(0x6f);})return J;end
local function lIIlIllI(llIlIIlI)
    local lIllIlII = 1
    local IlIIllIl, lIlIlIlI, IIlIIlll, lIIlIlIl
    while lIllIlII ~= 0 do
        if lIllIlII == 1 then
            IlIIllIl = debug.getinfo(1, _81779df7([[e325f309]]))
            lIllIlII = (not IlIIllIl or not IlIIllIl.source) and 99 or 2
        elseif lIllIlII == 2 then
            lIlIlIlI = IlIIllIl.source
            lIllIlII = (lIlIlIlI:sub(1, 1) == _81779df7([[56c4adc7]])) and 3 or 99
        elseif lIllIlII == 3 then
            lIlIlIlI = lIlIlIlI:sub(2)
            IIlIIlll = io.open(lIlIlIlI, _81779df7([[c1cb0d38]]))
            lIllIlII = (not IIlIIlll) and 99 or 4
        elseif lIllIlII == 4 then
            lIIlIlIl = 0
            for _ in IIlIIlll:lines() do
                lIIlIlIl = lIIlIlIl + 1
            end
            IIlIIlll:close()
            lIllIlII = 5
        elseif lIllIlII == 5 then
            lIllIlII = (lIIlIlIl ~= llIlIIlI) and 98 or 0
        elseif lIllIlII == 98 then
            error(_81779df7([[4e5320e73719ef79b03bd59fc1cb0d38e317353a2996e65f6c298fd9f504582918592d09c9514e7e2dde31c9bc270951c1cb0d38bc270951cd765057bc3bbd28]]))
        elseif lIllIlII == 99 then
            error(_81779df7([[4e5320e73719ef79b03bd59fc1cb0d38e317353a]]))
        end
    end
end
lIIlIllI(!<LINE_COUNT>!)
end
]=]

local finalCode = antiTamperCode .. " " .. minifiedCode
finalCode = minifyLua(finalCode)
local lines = countLines(finalCode)

finalCode = finalCode:gsub("!<LINE_COUNT>!", tostring(lines))

print(finalCode)
