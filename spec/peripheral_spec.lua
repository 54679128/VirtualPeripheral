local localNet = require("localNet")
local containerMaker = require("containerMaker")
local peripheral = require("peripheral")
local util = require("lib.util")
local Base = require("ContainerComponent.base")

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

--- 返回一个假外设组件
---@param type string
---@param ... {name:string,func:function}
---@return a546.Component
local function fakeComponent(type, ...)
    local funcList = { ... }
    local meta = setmetatable({}, Base)
    ---@cast meta +table<string,function>
    meta.__index = meta
    for _, funcStack in ipairs(funcList) do
        meta[funcStack.name] = function(self, ...)
            return funcStack.func(self, ...)
        end
    end
    return setmetatable({ type = type }, meta)--[[@as a546.Component]]
end

describe("模拟peripheralAPI测试", function()
    -- it("wrap测试", function() -- 对于这个测试，还缺少多组件、多方法情况下的测试
    --     local aNet = localNet.make()
    --     for i = 1, 100, 1 do
    --         local tempFuncName = randomString(8)
    --         local tempComponent = fakeComponent(randomString(5))
    --         local randomNumber = math.random()
    --         tempComponent[tempFuncName] = function()
    --             return randomNumber
    --         end
    --         local aC = containerMaker.make("test", tempComponent)
    --         localNet.addPeripheral(aNet, aC)
    --         local wrappedPeripheral = peripheral.wrap(aC.name)
    --         assert.is.equal(wrappedPeripheral.__name, aC.name)
    --         assert.is.equal(wrappedPeripheral.__type, aC.type)
    --         assert.is.equal(randomNumber, wrappedPeripheral[tempFuncName]() or error("错误的函数"))
    --         localNet.removePeripheral(aNet, aC.name)
    --     end
    -- end)
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
    -- it("call函数测试", function()
    --     local aNet = localNet.make()
    --     for i = 1, 100, 1 do
    --         local tempFuncName = randomString(8)
    --         local tempComponent = fakeComponent(randomString(4))
    --         local randomNumber = math.random(2, 88)
    --         tempComponent[tempFuncName] = function()
    --             return randomNumber
    --         end
    --         local aC = containerMaker.make("call_test", tempComponent)
    --         localNet.addPeripheral(aNet, aC)
    --         local result = peripheral.call(aC.name, tempFuncName)
    --         assert.is.equal(result, randomNumber)
    --     end
    -- end)
    -- it("getMethods测试", function()
    --     local aNet = localNet.make()
    --     for i = 1, 30, 1 do
    --         local tempComponent = fakeComponent(randomString(8))
    --         local funcNameList = {}
    --         for j = 1, 10, 1 do
    --             local tempFuncName = randomString(8)
    --             local randomNumber = math.random()
    --             tempComponent[tempFuncName] = function()
    --                 return randomNumber
    --             end
    --             funcNameList[tempFuncName] = randomNumber
    --         end
    --         local aC = containerMaker.make(randomString(5), tempComponent)
    --         localNet.addPeripheral(aNet, aC)
    --         local methodList = peripheral.getMethods(aC.name)
    --         assert.is.Table(methodList)
    --         ---@cast methodList -nil
    --         for index, funcName in ipairs(methodList) do
    --             assert.is.True(funcNameList[funcName])
    --             assert.is.equal(funcNameList[funcName], peripheral.call(aC.name, funcName))
    --         end
    --     end
    -- end)
    -- it("find测试", function()
    --     localNet.reset()
    --     local aNet = localNet.make()
    --     local tempComponent = fakeComponent(randomString(8))
    --     tempComponent["test_func"] = function()
    --         return 1
    --     end
    --     local aC = containerMaker.make(randomString(5), tempComponent)
    --     localNet.addPeripheral(aNet, aC)
    --     local findPeripheral = peripheral.find(aC.type)
    --     local wrappedPeripheral = peripheral.wrap(aC.name)
    --     assert.is.equal(findPeripheral.__name, wrappedPeripheral.__name)
    --     assert.is.equal(findPeripheral.__type, wrappedPeripheral.__type)
    --     assert.is.Function(findPeripheral["test_func"])
    -- end)
end)

describe("对于peripheral模块", function()
    local randomFuncName
    local randomNumber
    local aNet
    local componentA
    local componentAA
    local componentB
    local componentC
    local aC
    local bC
    local cC
    local dC
    before_each(function()
        randomFuncName = randomString(5)
        randomNumber = math.random(88)
        aNet = localNet.make()
        componentA = fakeComponent("testComponentA", {
            name = randomFuncName .. "_1",
            func = function()
                return randomNumber
            end
        }, {
            name = randomFuncName .. "_2",
            func = function(self)
                return self.type
            end
        })
        componentAA = fakeComponent("testComponentA", {
            name = randomFuncName .. "_1",
            func = function()
                return randomNumber
            end
        }, {
            name = randomFuncName .. "_2",
            func = function(self)
                return self.type
            end
        })
        componentB = fakeComponent("testComponentB", {
            name = randomFuncName .. "_3",
            func = function()
                return randomNumber
            end
        }, {
            name = randomFuncName .. "_4",
            func = function(self)
                return self.type
            end
        })
        componentC = fakeComponent("testComponentC")
        aC = containerMaker.make("testA", componentA)
        bC = containerMaker.make("testA", componentAA, componentB)
        cC = containerMaker.make("testB", componentC)
        dC = containerMaker.make("testB")
        localNet.addPeripheral(aNet, aC)
        localNet.addPeripheral(aNet, bC)
        localNet.addPeripheral(aNet, cC)
        localNet.addPeripheral(aNet, dC)
    end)
    after_each(function()
        localNet.reset()
    end)
    describe("对于getMethods", function()
        describe("当虚拟外设只存在一个有方法的外设组件时", function()
            it("可以获取外设的方法列表", function()
                local methodSet = {
                    [randomFuncName .. "_1"] = true,
                    [randomFuncName .. "_2"] = true,
                }
                local methodList = peripheral.getMethods(aC.name)
                assert.is.Table(methodList)
                ---@cast methodList -nil
                local resultMethodSet = {}
                for _, methodName in ipairs(methodList) do
                    resultMethodSet[methodName] = true
                end
                assert.is.same(methodSet, resultMethodSet)
            end)
        end)
        describe("当虚拟外设存在至少两个有方法的外设组件时", function()
            it("可以获取外设的方法列表", function()
                local methodSet = {
                    [randomFuncName .. "_1"] = true,
                    [randomFuncName .. "_2"] = true,
                    [randomFuncName .. "_3"] = true,
                    [randomFuncName .. "_4"] = true,
                }
                local methodList = peripheral.getMethods(bC.name)
                assert.is.Table(methodList)
                ---@cast methodList -nil
                local resultMethodSet = {}
                for _, methodName in ipairs(methodList) do
                    resultMethodSet[methodName] = true
                end
                assert.is.same(methodSet, resultMethodSet)
            end)
        end)
        describe("当虚拟外设只有一个没有方法的外设组件时", function()
            it("应该返回nil", function()
                local methodList = peripheral.getMethods(cC.name)
                assert.is.Nil(methodList)
            end)
        end)
        describe("当虚拟外设没有任何外设组件时", function()
            it("应该返回nil", function()
                local methodList = peripheral.getMethods(dC.name)
                assert.is.Nil(methodList)
            end)
        end)
        describe("当指定的虚拟外设不存在时", function()
            it("应该引发错误", function()
                assert.has.error(function()
                    peripheral.getMethods("Doesn't exist peripheral name")
                end, ("Can't find peripheral: %s"):format("Doesn't exist peripheral name"))
            end)
        end)
    end)
    describe("对于call", function()
        it("可以正确访问外设组件的方法", function()
            assert.is.equal(randomNumber, peripheral.call(bC.name, randomFuncName .. "_1"))
            assert.is.equal(componentA.type, peripheral.call(bC.name, randomFuncName .. "_2"))
            assert.is.equal(randomNumber, peripheral.call(bC.name, randomFuncName .. "_3"))
            assert.is.equal(componentB.type, peripheral.call(bC.name, randomFuncName .. "_4"))
        end)
        it("向存在的外设调用不存在的方法时应该报错", function()
            assert.has.error(function()
                peripheral.call(bC.name, "non-exist function name")
            end, ("Can't find method: %s in peripheral: %s"):format("non-exist function name", bC.name))
        end)
        it("向不存在的外设调用任何方法应该报错", function()
            assert.has.error(function()
                peripheral.call("non-exist peripheral name", randomFuncName)
            end, ("Can't find peripheral: %s"):format("non-exist peripheral name"))
        end)
    end)
    describe("对于wrap", function()
        it("可以正确包裹外设组件的方法", function()
            local p = peripheral.wrap(bC.name)
            assert.is.equal(randomNumber, p[randomFuncName .. "_1"]())
            assert.is.equal(componentA.type, p[randomFuncName .. "_2"]())
            assert.is.equal(randomNumber, p[randomFuncName .. "_3"]())
            assert.is.equal(componentB.type, p[randomFuncName .. "_4"]())
        end)
        it("包裹不存在的外设会报错", function()
            assert.has.error(function()
                peripheral.wrap("non-exist peripheral name")
            end, ("Can't find peripheral: %s"):format("non-exist peripheral name"))
        end)
        it("尝试从被包裹的外设中调用不存在的方法应该报错", function()
            local p = peripheral.wrap(bC.name)
            assert.has.error(function()
                p.someFunction()
            end)
        end)
    end)
    describe("对于find", function()
        it("在没有给出过滤器时，可以返回所有外设", function()
            local peripheralList = { peripheral.find(aC.type) }
            local a, b
            for _, per in pairs(peripheralList) do
                if per[randomFuncName .. "_3"] then
                    b = per
                else
                    a = per
                end
            end
            assert.is.Not.Nil(a)
            assert.is.Not.Nil(b)

            assert.is.equal(randomNumber, a[randomFuncName .. "_1"]())
            assert.is.equal(componentA.type, a[randomFuncName .. "_2"]())

            assert.is.equal(randomNumber, b[randomFuncName .. "_1"]())
            assert.is.equal(componentA.type, b[randomFuncName .. "_2"]())
            assert.is.equal(randomNumber, b[randomFuncName .. "_3"]())
            assert.is.equal(componentB.type, b[randomFuncName .. "_4"]())
        end)
        it("在给出过滤器时，可以过滤要返回的外设", function()
            local yesName, falseName -- 这两个变量用来记录下面的判断函数接受了什么外设名
            local peripheralList = { peripheral.find(aC.type, function(name, wrap)
                if wrap[randomFuncName .. "_3"] then
                    yesName = name
                    return true
                else
                    falseName = name
                    return false
                end
            end) }
            assert.is.equal(bC.name, yesName)
            assert.is.equal(aC.name, falseName)

            local b = peripheralList[1]
            assert.is.Not.Nil(b)

            assert.is.equal(randomNumber, b[randomFuncName .. "_1"]())
            assert.is.equal(componentA.type, b[randomFuncName .. "_2"]())
            assert.is.equal(randomNumber, b[randomFuncName .. "_3"]())
            assert.is.equal(componentB.type, b[randomFuncName .. "_4"]())
        end)
        it("在找不到要求类型的外设时，返回nil", function()
            assert.is.Nil(peripheral.find("Doesn't exist peripheral type"))
            assert.is.Nil(peripheral.find(aC.type, function()
                return false
            end))
        end)
    end)
end)
