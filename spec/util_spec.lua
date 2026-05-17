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
    describe("对于readOnly函数", function()
        it("可以返回简单表的只读副本", function()
            local testTable = {
                a = 1,
                b = "hello",
                c = function()
                    return 8
                end,
                d = false,
                e = coroutine.create(function(...)

                end)
            }
            local r = util.readOnly(testTable)
            assert.is.same(testTable, r)
            r.a = 2
            r.b = "get out"
            r.c = function()
                return -8
            end
            r.d = true
            r.e = coroutine.create(function(...)

            end)
            assert.is.same(testTable, r)
            assert.is.equal(util.readOnly(testTable, true), util.readOnly(testTable, true))
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
            r.a = 2
            assert.is.same(testTable, r)
            r.a.b = 2
            r.a.c = "get out"
            assert.is.same(testTable, r)
            assert.is.equal(util.readOnly(testTable, true), util.readOnly(testTable, true))
        end)
        it("可以返回循环嵌套表的只读副本", function()
            local testTable = {}
            testTable.d = testTable
            local r = util.readOnly(testTable, true) -- 当theTable是循环嵌套表时，必须启用usingCache
            assert.is.same(testTable, r)
            r.d = 3
            assert.is.same(testTable, r)
            assert.is.equal(util.readOnly(testTable, true), util.readOnly(testTable, true))
        end)
        it("返回的只读副本可以被pairs或ipairs遍历", function()
            local pairsTable = {
                a = 1,
                b = false,
                c = "hello"
            }
            local ipairsTable = {}
            for i = 1, 10, 1 do
                ipairsTable[i] = math.random(88)
            end
            -- pairs
            local pairsLoopCount = 0
            for key, value in pairs(util.readOnly(pairsTable, true)) do
                assert.is.equal(pairsTable[key], value)
                pairsLoopCount = pairsLoopCount + 1
            end
            assert.equal(3, pairsLoopCount)
            -- ipairs
            local ipairsLoopCount = 0
            for key, value in ipairs(util.readOnly(ipairsTable, true)) do
                assert.is.equal(ipairsTable[key], value)
                ipairsLoopCount = ipairsLoopCount + 1
            end
            assert.equal(#ipairsTable, ipairsLoopCount)
        end)
    end)
end)
