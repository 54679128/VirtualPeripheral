local util = require("lib.util")

local function unSerializeTable(theTableString)
    local preString = "local theTable;theTable = "
    local afterString = ";return theTable"
    local processTable = preString .. theTableString .. afterString
    return load(processTable, "nothing", "t")()
end

describe("util模块测试", function()
    local p = require("lib.util")
    it("简单表测试", function()
        local testTable = {
            a = 1,
            b = "testItem",
            c = true,
            e = 7.5
        }
        -- print(p.serializeTable(testTable))
        local theTable = unSerializeTable(p.serializeTable(testTable))
        assert.Same(theTable, testTable)
    end)

    it("嵌套表测试", function()
        local testTable = {
            a = {
                c = 3.5,
                k = "hello turtle",
                g = false
            },
            b = "hello",
            c = false
        }
        -- print(p.serializeTable(testTable))
        local theTable = unSerializeTable(p.serializeTable(testTable))
        assert.Same(theTable, testTable)
    end)

    -- it("循环嵌套表测试",function ()
    --     local testTable = {
    --         a = {
    --             c = 3.5,
    --             k = "hello turtle",
    --             g = false
    --         },
    --         b = "hello",
    --         c = false
    --     }
    --     testTable.e = testTable
    --     print(p.serializeTable(testTable))
    --     local theTable = unSerializeTable(p.serializeTable(testTable))
    --     assert.Same(theTable, testTable)
    -- end)
end)

describe("对于readOnly函数", function()
    it("可以返回简单表的只读副本", function()
        local testTable = {
            a = 1,
            b = "hello",
            -- c = function()
            --     return 8
            -- end,
            d = false,
            e = coroutine.create(function(...)

            end)
        }
        local r = util.readOnly(testTable)
        assert.is.same(testTable, r)
        assert.has.error(function() r.a = 2 end)
        assert.has.error(function() r.b = "get out" end)
        assert.has.error(function() r.c = function() return -8 end end)
        assert.has.error(function() r.d = true end)
        assert.has.error(function() r.e = coroutine.create(function(...) end) end)
        assert.is.same(testTable, r)
        assert.is.equal(util.readOnly(testTable), util.readOnly(testTable))
    end)
    it("可以返回嵌套表的只读副本", function()
        local testTable = {
            a = {
                b = 1,
                c = "hello"
            }
        }
        local r = util.readOnly(testTable)
        assert.is.same(testTable, r)
        assert.has.error(function()
            r.a = 2
        end)
        assert.is.same(testTable, r)
        assert.has.error(function()
            r.a.b = 2
        end)
        assert.has.error(function()
            r.a.c = "get out"
        end)
        assert.is.same(testTable, r)
        assert.is.equal(util.readOnly(testTable), util.readOnly(testTable))
    end)
    it("可以返回循环嵌套表的只读副本", function()
        local testTable = {}
        testTable.d = testTable
        local r = util.readOnly(testTable)
        assert.is.same(testTable, r)
        assert.has.error(function()
            r.d = 3
        end)
        assert.is.same(testTable, r)
        assert.is.equal(util.readOnly(testTable), util.readOnly(testTable))
    end)
    it("返回的只读副本可以被pairs或ipairs遍历", function()
        local pairsTable = {
            a = 1,
            b = false,
            c = "hello",
            d = { e = "hello" }
        }
        local ipairsTable = {}
        for i = 1, 10, 1 do
            ipairsTable[i] = math.random(88)
        end
        -- pairs
        local pairsLoopCount = 0
        for key, value in pairs(util.readOnly(pairsTable)) do
            assert.is.same(pairsTable[key], value)
            pairsLoopCount = pairsLoopCount + 1
        end
        assert.equal(4, pairsLoopCount)
        -- ipairs
        local ipairsLoopCount = 0
        for key, value in ipairs(util.readOnly(ipairsTable)) do
            assert.is.equal(ipairsTable[key], value)
            ipairsLoopCount = ipairsLoopCount + 1
        end
        assert.equal(#ipairsTable, ipairsLoopCount)
    end)
    it("使用getmetatable可以查看元表", function()
        local meta = {
            k = 1,
            __index = {
                h = "hello"
            }
        }
        local testT = setmetatable({}, meta)
        local roTestT = util.readOnly(testT)
        assert.is.same(meta, getmetatable(roTestT))
    end)
    it("返回的只读副本的方法可以正常修改字段", function()
        local testClass = {
            data = 1,
            updata = function(self, x)
                self.data = x
            end
        }
        local readOnlyClass = util.readOnly(testClass)
        assert.is.equal(testClass.data, readOnlyClass.data)
        local randomNumber = math.random(88)
        readOnlyClass:updata(randomNumber)
        assert.is.equal(randomNumber, testClass.data, readOnlyClass.data)
    end)
    it("会缓存只读副本，避免制造只读副本的只读副本", function()
        local testClass = {}
        assert.is.equal(util.readOnly(testClass), util.readOnly(util.readOnly(testClass)))
    end)
    it("可以通过多重__index访问方法", function()
        local origin = {}
        origin.__index = origin
        origin.testFunc = function(self, count)
            self.testKey = count
            return count
        end
        local sub1 = setmetatable({}, origin)
        sub1.__index = sub1
        local sub2 = setmetatable({}, sub1)
        local roSub2 = util.readOnly(sub2)
        local result = roSub2:testFunc(44)
        assert.is.equal(44, result)
        assert.is.Number(sub2.testKey)
        assert.is.equal(44, sub2.testKey)
    end)
    it("可以正常使用设置了__call的表的只读副本", function()
        local origin = {}
        origin.__call = function(self, count)
            self.k = count
            return count
        end
        local sub = setmetatable({}, origin)
        local result = util.readOnly(sub)(33)
        assert.is.equal(33, result)
        assert.is.equal(33, sub.k)
    end)
    -- 这是个没法实现的需求，但我把测试注释掉后留在这。毕竟，可能只是我觉得没法实现而已
    -- it("即便是从元表中获取的闭包也可以正常修改表自身", function()
    --     local origin = {}
    --     origin.__index = origin
    --     origin.testFunc = function(self, c)
    --         self.c = c
    --         return self.c
    --     end
    --     spy.on(origin, "testFunc")
    --     local sub = setmetatable({}, origin)
    --     local roSub = util.readOnly(sub)
    --     local theFunc = function()
    --         local meta = getmetatable(roSub)
    --         return meta.testFunc(roSub, 55)
    --     end
    --     local result = theFunc()
    --     assert.spy(origin.testFunc).was.called(1)
    --     assert.is.equal(55, result)
    --     assert.is.equal(55, sub.c)
    -- end)
end)
