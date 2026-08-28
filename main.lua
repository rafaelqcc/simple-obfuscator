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

local a = true
local b = false

if a then
    print("true")
end

if b then
    print("false")
end
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
local ]]..name..[[ = ]]..id..[[;
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

local BooleanObfuscation = ast.nodeclass("booleanobfuscation")

function BooleanObfuscation:init(value)
    self.value = value
end

function BooleanObfuscation:serialize(consume)
    local a = math.random(10, 999)
    local b
    local op

    if self.value then
        local mode = math.random(1, 5)

        if mode == 1 then
            b = a
            op = "=="
        elseif mode == 2 then
            b = a + math.random(1, 100)
            op = "<"
        elseif mode == 3 then
            b = a - math.random(1, 100)
            op = ">"
        elseif mode == 4 then
            b = a
            op = "<="
        else
            b = a
            op = ">="
        end
    else
        local mode = math.random(1, 3)

        if mode == 1 then
            b = a
            op = "~="
        elseif mode == 2 then
            b = a + math.random(1, 100)
            op = ">"
        else
            b = a - math.random(1, 100)
            op = "<"
        end
    end

    consume("(" .. a .. op .. b .. ")")
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
    if node.type == "true" or node.type == "false" then
        return BooleanObfuscation(node.value)
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

print(minifiedCode)
