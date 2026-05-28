local VirtualPeripheral = require("VirtualPeripheral")
local Inventory = require("ContainerComponent.Inventory")

describe("containerMaker模块测试", function()
    it("容器能被正常创建", function()
        local chestComponent = Inventory.make(28, 1)
        local theRandomAndMaybeOnlyType = tostring(math.random()).. "only!!!".. tostring(math.random())
        local c = VirtualPeripheral.make(theRandomAndMaybeOnlyType, chestComponent)
        assert.is.same(c.component["Inventory"], chestComponent)
        assert.is.equal(c.name, theRandomAndMaybeOnlyType.."_0")
        assert.is.equal(c.type, theRandomAndMaybeOnlyType)
    end)
    it("创建的同类容器编号应该连续且递增", function()
        local oldId = tonumber(VirtualPeripheral.make("chest", Inventory.make(28, 1)).name:match(".*_(.*)$"))
        for i = 1, 100, 1 do
            local chestComponent = Inventory.make(28, 1)
            local c = VirtualPeripheral.make("chest", chestComponent)
            local containerId = tonumber(c.name:match(".*_(.*)$"))
            assert.is.Not.Nil(containerId)
            assert.is.equal(containerId - oldId, 1)
            ---@cast containerId -nil
            oldId = containerId
        end
        local otherContainerId = tonumber(VirtualPeripheral.make("ae2:interface", Inventory.make(9, 1)).name:match(
            ".*_(.*)$"))
        assert.is.False(otherContainerId - oldId > 0)
    end)
end)
