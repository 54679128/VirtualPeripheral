local localNet = require("localNet")
local containerMaker = require("containerMaker")
local inventory = require("ContainerComponent.inventory")
local peripheral = require("peripheral")
local util = require("lib.util")

local function randomString(len)
    if len < 1 then
        return ""
    end
    local char = "abcdefghijklmnopqrstuvwxyz"
    local theString = {}
    for i = 1, len, 1 do
        local theLen = math.random(26)
        table.insert(theString, char:sub(theLen, theLen))
    end
    return table.concat(theString, "")
end

local function fakeComponent(type)
    return { type = type }
end

describe("模拟peripheralAPI测试", function()
    it("wrap测试", function() -- 对于这个测试，还缺少多组件、多方法情况下的测试
        local aNet = localNet.make()
        for i = 1, 100, 1 do
            local tempFuncName = randomString(8)
            local tempComponent = fakeComponent(randomString(5))
            local randomNumber = math.random()
            tempComponent[tempFuncName] = function()
                return randomNumber
            end
            local aC = containerMaker.make("test", tempComponent)
            localNet.addPeripheral(aNet, aC)
            local wrappedPeripheral = peripheral.wrap(aC.name)
            assert.is.equal(wrappedPeripheral.__name, aC.name)
            assert.is.equal(wrappedPeripheral.__type, aC.type)
            assert.is.equal(randomNumber, wrappedPeripheral[tempFuncName]() or error("错误的函数"))
            localNet.removePeripheral(aNet, aC.name)
        end
    end)
    it("getNames函数应该给出所有本地网络中的所有外设", function()
        localNet.reset()
        local nameList = {}
        local aNet = localNet.make()
        local bNet = localNet.make()
        for i = 1, 10, 1 do
            local aC = containerMaker.make(randomString(7))
            local bC = containerMaker.make(randomString(8))
            nameList[aC.name] = true
            nameList[bC.name] = true
            localNet.addPeripheral(aNet, aC)
            localNet.addPeripheral(bNet, bC)
        end
        local peripheralList = peripheral.getNames()
        local totalPeripheral = 0
        for _, peripheralName in pairs(peripheralList) do
            totalPeripheral = totalPeripheral + 1
            assert.is.True(nameList[peripheralName])
        end
        assert.is.equal(totalPeripheral, 20)
    end)
    it("isPresent函数应该可以检查到某个外设是否存在", function()
        local nameList = {}
        local aNet = localNet.make()
        local bNet = localNet.make()
        for i = 1, 100, 1 do
            local aC = containerMaker.make(randomString(8))
            local bC = containerMaker.make(randomString(8))
            localNet.addPeripheral(aNet, aC)
            localNet.addPeripheral(bNet, bC)
            nameList[aC.name] = true
            nameList[bC.name] = true
        end
        for name, _ in pairs(nameList) do
            assert.is.True(peripheral.isPresent(name))
        end
    end)
    it("hasType函数测试", function()
        local aNet = localNet.make()
        for i = 1, 100, 1 do
            local containerType = randomString(5)
            local componentType = randomString(8)
            local aC = containerMaker.make(containerType, fakeComponent(componentType))
            localNet.addPeripheral(aNet, aC)
            assert.is.True(peripheral.hasType(aC.name, containerType))
            assert.is.True(peripheral.hasType(aC.name, componentType))
            assert.is.False(peripheral.hasType(aC.name, randomString(5)))
            assert.is.Nil(peripheral.hasType(randomString(5), componentType))
        end
    end)
    it("getType函数测试", function()
        local aNet = localNet.make()
        for i = 1, 100, 1 do
            local containerType = randomString(5)
            local componentType = randomString(8)
            local aC = containerMaker.make(containerType, fakeComponent(componentType))
            localNet.addPeripheral(aNet, aC)
            local typeList = { peripheral.getType(aC.name) }
            local typeNumber = 0
            for _, type in pairs(typeList) do
                if type == containerType or type == componentType then
                    typeNumber = typeNumber + 1
                end
            end
            assert.is.equal(typeNumber, 2)
        end
    end)
    it("call函数测试", function()
        local aNet = localNet.make()
        for i = 1, 100, 1 do
            local tempFuncName = randomString(8)
            local tempComponent = fakeComponent(randomString(4))
            local randomNumber = math.random(2, 88)
            tempComponent[tempFuncName] = function()
                return randomNumber
            end
            local aC = containerMaker.make("call_test", tempComponent)
            localNet.addPeripheral(aNet, aC)
            local result = peripheral.call(aC.name, tempFuncName)
            assert.is.equal(result, randomNumber)
        end
    end)
    it("getMethods测试", function()
        local aNet = localNet.make()
        for i = 1, 30, 1 do
            local tempComponent = fakeComponent(randomString(8))
            local funcNameList = {}
            for j = 1, 10, 1 do
                local tempFuncName = randomString(8)
                local randomNumber = math.random()
                tempComponent[tempFuncName] = function()
                    return randomNumber
                end
                funcNameList[tempFuncName] = randomNumber
            end
            local aC = containerMaker.make(randomString(5), tempComponent)
            localNet.addPeripheral(aNet, aC)
            local methodList = peripheral.getMethods(aC.name)
            assert.is.Table(methodList)
            ---@cast methodList -nil
            for index, funcName in ipairs(methodList) do
                assert.is.True(funcNameList[funcName])
                assert.is.equal(funcNameList[funcName], peripheral.call(aC.name, funcName))
            end
        end
    end)
    it("find测试", function()
        localNet.reset()
        local aNet = localNet.make()
        local tempComponent = fakeComponent(randomString(8))
        tempComponent["test_func"] = function()
            return 1
        end
        local aC = containerMaker.make(randomString(5), tempComponent)
        localNet.addPeripheral(aNet, aC)
        local findPeripheral = peripheral.find(aC.type)
        local wrappedPeripheral = peripheral.wrap(aC.name)
        assert.is.equal(findPeripheral.__name, wrappedPeripheral.__name)
        assert.is.equal(findPeripheral.__type, wrappedPeripheral.__type)
        assert.is.Function(findPeripheral["test_func"])
    end)
end)
