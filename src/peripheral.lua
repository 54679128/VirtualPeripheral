local LocalNet = require("LocalNet")

-- 模拟 `peripheral` API，将被注入全局环境中
local out = {}

---@class a546.WrapPeripheral
---@field __name string
---@field __type string
---@field [string] function

--- 检查一个外设是否存在
---@param name string|a546.WrapPeripheral
local function assertExist(name)
    local theName
    if type(name) == "table" then
        theName = name.__name
    else
        theName = name
    end
    ---@cast theName string
    if not LocalNet.isPresent(theName) then
        error(("Can't find peripheral: %s"):format(theName), 3)
    end
end

function out.isPresent(name)
    return LocalNet.isPresent(name)
end

function out.getNames()
    local peripheralList = LocalNet.getAllPeripheral()
    local result = {}
    for peripheralName, _ in pairs(peripheralList) do
        table.insert(result, peripheralName)
    end
    return result
end

function out.wrap(name)
    assertExist(name)
    local targetPeripheral = LocalNet.getPeripheral(LocalNet.findPeripheral(name) --[[@as integer]], name)
    local result = {}
    result.__name = name
    result.__type = targetPeripheral.type
    -- 前面检查过了
    ---@diagnostic disable-next-line: param-type-mismatch
    for _, funcName in ipairs(out.getMethods(name)) do
        result[funcName] = function(...)
            return out.call(name, funcName, ...)
        end
    end
    return result
end

function out.getType(nameOrPeripheral)
    assertExist(nameOrPeripheral)
    if type(nameOrPeripheral) == "table" then
        ---@cast nameOrPeripheral a546.WrapPeripheral
        return nameOrPeripheral.__type
    end
    local targetPeripheral = LocalNet.getPeripheral(LocalNet.findPeripheral(nameOrPeripheral) --[[@as integer]],
        nameOrPeripheral)
    local typeList = {}
    table.insert(typeList, targetPeripheral.type)
    for _, component in pairs(targetPeripheral.component) do
        table.insert(typeList, component.type)
    end
    return table.unpack(typeList)
end

function out.hasType(name, type)
    if not out.isPresent(name) then
        return nil
    end
    -- 但现在我有点懒了。
    local typeList = { out.getType(name) }
    for i = 1, #typeList do
        if typeList[i] == type then
            return true
        end
    end
    return false
end

function out.getMethods(name)
    assertExist(name)
    local targetPeripheral = LocalNet.getPeripheral(LocalNet.findPeripheral(name) --[[@as integer]],
        name)
    local result = {}
    for _, component in pairs(targetPeripheral.component) do
        for funcName, maybeFunc in pairs(getmetatable(component) or {}) do
            if type(maybeFunc) ~= "function" then
                goto continue
            end
            if string.find(funcName, "__") then
                goto continue
            end
            table.insert(result, funcName)
            ::continue::
        end
    end
    if next(result) then
        return result
    else
        return nil
    end
end

function out.call(name, method, ...)
    assertExist(name)
    local targetMethod
    local targetPeripheral = LocalNet.getPeripheral(LocalNet.findPeripheral(name) --[[@as integer]], name)
    for _, component in pairs(targetPeripheral.component) do
        if not component[method] then            
            goto continue
        end
        targetMethod = function(...)
            return component[method](component, ...)
        end
        ::continue::
    end
    return (targetMethod or function()
        error(("Can't find method: %s in peripheral: %s"):format(tostring(method), name))
    end)(...)
end

function out.find(type, filter)
    local theFilter = filter or function()
        return true
    end
    local result = {}
    for peripheralName, per in pairs(LocalNet.getAllPeripheral()) do
        if per.type ~= type then
            goto continue
        end
        if not theFilter(peripheralName, out.wrap(peripheralName)) then
            goto continue
        end
        table.insert(result, out.wrap(peripheralName))
        ::continue::
    end
    return table.unpack(result)
end

return out
