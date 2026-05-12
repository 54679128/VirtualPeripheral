local containerMaker = require("containerMaker")
local inventory = require("ContainerComponent.inventory")

describe("containerMaker模块测试", function()
    it("容器能被正常创建", function()
        local chestComponent = inventory.make(28, 1)
        local theRandomAndMaybeOnlyType = tostring(math.random()).. "only!!!".. tostring(math.random())
        local c = containerMaker.make(theRandomAndMaybeOnlyType, chestComponent)
        assert.is.same(c.component["inventory"], chestComponent)
        assert.is.equal(c.name, theRandomAndMaybeOnlyType.."_0")
        assert.is.equal(c.type, theRandomAndMaybeOnlyType)
    end)
    it("创建的同类容器编号应该连续且递增", function()
        local oldId = tonumber(containerMaker.make("chest", inventory.make(28, 1)).name:match(".*_(.*)$"))
        for i = 1, 100, 1 do
            local chestComponent = inventory.make(28, 1)
            local c = containerMaker.make("chest", chestComponent)
            local containerId = tonumber(c.name:match(".*_(.*)$"))
            assert.is.Not.Nil(containerId)
            assert.is.equal(containerId - oldId, 1)
            ---@cast containerId -nil
            oldId = containerId
        end
        local otherContainerId = tonumber(containerMaker.make("ae2:interface", inventory.make(9, 1)).name:match(
            ".*_(.*)$"))
        assert.is.False(otherContainerId - oldId > 0)
    end)
end)
