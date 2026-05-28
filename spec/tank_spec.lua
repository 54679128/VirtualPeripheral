local Tank = require("src.ContainerComponent.Tank")
local LocalNet = require("LocalNet")
local peripheral = require("peripheral")
local containerMaker = require("containerMaker")

local theWater
local function water()
    theWater = theWater or Tank.FakeFluid.make("minecraft:water")
    return theWater
end

local theLava
local function lava()
    theLava = theLava or Tank.FakeFluid.make("minecraft:lava")
    return theLava
end

describe("tank模块", function()
    describe("假流体", function()
        it("可以被正常创建", function()
            local testWater = Tank.FakeFluid.make("minecraft:water")
            assert.is.equal("minecraft:water", testWater.name)
        end)
    end)
    describe("tank组件", function()
        it("可以被正常创建", function()
            local capacityList = { 1, 2, 10000, 0.000001 }
            local size = 4
            local storageCoefficient = 1
            local testTank = Tank.make(size, storageCoefficient, capacityList)
            assert.is.equal(size, testTank.invSize)
            for i = 1, #capacityList, 1 do
                assert.is.equal(capacityList[i], testTank.fluidList[i].capacity)
            end
            assert.is.equal("tank", testTank.type)
        end)
        describe("通过容器内容操作接口（dev）", function()
            local sizeList = { 4, 4, 4, 4 } -- 至少大于 2
            local storageCoefficient = { 1, 2, 0.5, 8 }
            local commonCapacity = 1500
            --- 统计列表中空储罐和含液体储罐的数量
            ---@param fluidList a546.Tank.FluidStack[]
            ---@return number fullTankNum
            ---@return number emptyTankNum
            local function fullAndEmptyTankNum(fluidList)
                local fullTankNum = 0
                local emptyTankNum = 0
                for _, fluidStack in pairs(fluidList) do
                    if fluidStack.fluid then
                        fullTankNum = fullTankNum + 1
                    else
                        emptyTankNum = emptyTankNum + 1
                    end
                end
                return fullTankNum, emptyTankNum
            end
            for i = 1, #sizeList, 1 do
                it(("在单组件储罐数为：%d，存储系数为：%.2f，单储罐容量为：%d mb时可以添加流体"):format(sizeList[i], storageCoefficient[i], commonCapacity), function()
                    local tempCapacityList = {}
                    for j = 1, sizeList[i], 1 do
                        tempCapacityList[j] = commonCapacity
                    end
                    local testTank = Tank.make(sizeList[i], storageCoefficient[i], tempCapacityList)
                    assert.is.equal(math.min(testTank.storageCoefficient * commonCapacity,
                        1000), testTank.dev:addFluid(water(), 1000))
                    for _, fluidStack in pairs(testTank.fluidList) do
                        if not fluidStack.fluid then
                            goto continue
                        end
                        assert.is.same(water(), fluidStack.fluid)
                        assert.is.equal(fluidStack.amount, math.min(testTank.storageCoefficient * commonCapacity,
                            1000))
                        break
                        ::continue::
                    end
                end)
                it(("在单组件储罐数为：%d，存储系数为：%.2f，单储罐容量为：%d mb时，多次添加过量（超出单个储罐容量）流体，应优先填充已含同种流体的未满储罐，其次填充空储罐"):format(sizeList[i], storageCoefficient[i], commonCapacity), function()
                    local tempCapacityList = {}
                    for j = 1, sizeList[i], 1 do
                        tempCapacityList[j] = commonCapacity
                    end
                    local testTank = Tank.make(sizeList[i], storageCoefficient[i], tempCapacityList)
                    testTank.dev:addFluid(water(), 0.001)
                    testTank.dev:addFluid(water(), 0.001)
                    local fullTankNum, emptyTankNum = fullAndEmptyTankNum(testTank.fluidList)
                    assert.is.equal(1, fullTankNum)
                    assert.is.equal(sizeList[i] - 1, emptyTankNum)

                    testTank = Tank.make(sizeList[i], storageCoefficient[i], tempCapacityList)
                    testTank.dev:addFluid(water(), 2 ^ 12 * storageCoefficient[i])
                    local actuallyTransfer = testTank.dev:addFluid(water(), 0.001)
                    fullTankNum, emptyTankNum = fullAndEmptyTankNum(testTank.fluidList)
                    assert.is.Not.equal(0, actuallyTransfer)
                    assert.is.equal(2, fullTankNum)
                    assert.is.equal(sizeList[i] - 2, emptyTankNum)
                end)
                it(("在单组件储罐数为：%d，存储系数为：%.2f，单储罐容量为：%d mb时可以移除流体"):format(sizeList[i], storageCoefficient[i], commonCapacity), function()
                    local tempCapacityList = {}
                    for j = 1, sizeList[i], 1 do
                        tempCapacityList[j] = commonCapacity
                    end
                    local testTank = Tank.make(sizeList[i], storageCoefficient[i], tempCapacityList)
                    assert.is.equal(math.min(testTank.storageCoefficient * commonCapacity, 1000), testTank.dev:addFluid(water(), 1000))
                    local wantRemove = 0.5 * math.min(testTank.storageCoefficient * commonCapacity, 1000)
                    local removedFluid, actuallyRemoved = testTank.dev:removeFluid(water().name, wantRemove)
                    assert.is.equal(actuallyRemoved, wantRemove)
                    local atLeastFined = false
                    for _, fluidStack in pairs(testTank.fluidList) do
                        if not fluidStack.fluid then
                            goto continue
                        end
                        assert.is.same(water(), fluidStack.fluid)
                        assert.is.equal(fluidStack.amount, wantRemove)
                        removedFluid, actuallyRemoved = testTank.dev:removeFluid(water().name, wantRemove)
                        assert.is.equal(actuallyRemoved, wantRemove)
                        assert.is.Nil(fluidStack.fluid)
                        atLeastFined = true
                        break
                        ::continue::
                    end
                    assert.is.True(atLeastFined)
                end)
                it(("在单组件储罐数为：%d，存储系数为：%.2f，单储罐容量为：%d mb且储罐充满流体时，只会移除其中一个储罐的流体"):format(sizeList[i], storageCoefficient[i], commonCapacity), function()
                    local tempCapacityList = {}
                    for j = 1, sizeList[i], 1 do
                        tempCapacityList[j] = commonCapacity
                    end
                    local testTank = Tank.make(sizeList[i], storageCoefficient[i], tempCapacityList)
                    for j = 1, sizeList[i], 1 do
                        testTank.dev:addFluid(water(), 2 ^ 12 * storageCoefficient[i])
                    end
                    local fullTankNum, emptyTankNum = fullAndEmptyTankNum(testTank.fluidList)
                    assert.is.equal(sizeList[i], fullTankNum)
                    testTank.dev:removeFluid(water().name)
                    fullTankNum, emptyTankNum = fullAndEmptyTankNum(testTank.fluidList)
                    assert.is.equal(1, emptyTankNum)
                    assert.is.equal(sizeList[i] - 1, fullTankNum)
                end)
            end
            pending("使用负数调用addFluid和removeFluid会报错", function()

            end)
        end)
        local tankAProperties = {
            sizeList = { 4, 4, 4, 4, 2, 2 },
            storageCoefficient = { 1, 2, 0.5, 16, 1, 1 },
            capacityList = { { 1000, 1000, 1000, 1000 }, { 1000, 1000, 1000, 1000 }, { 1000, 1000, 1000, 1000 }, { 1000, 1000, 1000, 1000 }, { 1000, 1000 }, { 500, 500 } }
        }
        local tankBProperties = {
            sizeList = { 4, 4, 4, 4, 2, 2 },
            storageCoefficient = { 1, 24, 0.5, 8, 1, 1 },
            capacityList = { { 1000, 1000, 1000, 1000 }, { 1000, 1000, 1000, 1000 }, { 1000, 1000, 1000, 1000 }, { 1000, 1000, 1000, 1000 }, { 500, 500 }, { 1000, 100 } }
        }
        local commonFluidInput = 10000
        for i = 1, #tankAProperties.sizeList, 1 do
            local describeText = ("[容器A参数: size: %d, coefficient: %.2f, capacity: %s -- 容器B参数: size: %d, coefficient: %.2f, capacity: %s]")
                :format(tankAProperties.sizeList[i], tankAProperties.storageCoefficient[i], ("{%s}"):format(table.concat(tankAProperties.capacityList[i], ", ")), tankBProperties.sizeList[i], tankBProperties.storageCoefficient[i], ("{%s}"):format(table.concat(tankBProperties.capacityList[i], ", ")))
            describe(describeText, function()
                local aNet
                local bNet
                local otherPeripheral
                local tankA
                local tankB
                local tankC
                local tankAComponent
                local tankBComponent
                ---@cast tankA a546.VirtualPeripheral
                ---@cast tankB a546.VirtualPeripheral
                ---@cast tankAComponent a546.Tank
                ---@cast tankBComponent a546.Tank
                local sizeA = tankAProperties.sizeList[i]
                local sizeB = tankBProperties.sizeList[i]
                local coeA = tankAProperties.storageCoefficient[i]
                local coeB = tankBProperties.storageCoefficient[i]
                local capacityA = tankAProperties.capacityList[i]
                local capacityB = tankBProperties.capacityList[i]
                before_each(function()
                    aNet = LocalNet.make()
                    bNet = LocalNet.make()
                    tankAComponent = Tank.make(tankAProperties.sizeList[i], tankAProperties.storageCoefficient[i], tankAProperties.capacityList[i])
                    tankAComponent.dev:addFluid(water(), commonFluidInput)
                    tankBComponent = Tank.make(tankBProperties.sizeList[i], tankBProperties.storageCoefficient[i], tankBProperties.capacityList[i])
                    tankA = containerMaker.make("bottle", tankAComponent)
                    tankB = containerMaker.make("bottle", tankBComponent)
                    tankC = containerMaker.make("bottle", Tank.make(1, 1, { 1 })) -- 这个外设主要是为了验证不同网络间的外设不能互相访问，组件设定（我写到这的时候忘记怎么描述这些参数了）之类的东西不用管
                    otherPeripheral = containerMaker.make("turtle")
                    LocalNet.addPeripheral(aNet, tankA)
                    LocalNet.addPeripheral(aNet, tankB)
                    LocalNet.addPeripheral(bNet, tankC)
                    LocalNet.addPeripheral(aNet, otherPeripheral)
                end)
                after_each(function()
                    -- ---@cast tankA a546.VirtualPeripheral
                    -- ---@cast tankB a546.VirtualPeripheral
                    -- LocalNet.removePeripheral(aNet, tankA.name)
                    -- LocalNet.removePeripheral(aNet, tankB.name)
                    LocalNet.reset()
                end)
                --- 从列表中查找指定流体</br>
                --- 如果没找到会返回nil，同时第二个返回值为-1
                ---@param fluidList a546.Tank.FluidStack[]
                ---@param name string
                ---@return a546.Tank.FluidStack|nil
                ---@return integer
                local function findFluidStack(fluidList, name)
                    for slot, fluidStack in pairs(fluidList) do
                        if not fluidStack.fluid then
                            goto continue
                        end
                        if fluidStack.fluid.name == name then
                            return fluidStack, slot
                        end
                        ::continue::
                    end
                    return nil, -1
                end
                it("tanks方法应该正常工作", function()
                    local p = peripheral.wrap(tankA.name)
                    local fluidList = p.tanks()
                    for _, fluidInfo in pairs(fluidList) do
                        local fluidStack = findFluidStack(tankAComponent.fluidList, fluidInfo.name)
                        assert.is.Not.Nil(fluidStack)
                        ---@cast fluidStack -nil
                        assert.is.equal(fluidStack.amount, fluidInfo.amount)
                    end
                    assert.is.Not.Nil(next(p.tanks()))
                    tankAComponent.dev:removeFluid(water().name)
                    assert.is.Nil(next(p.tanks()))
                end)
                it("在自身储罐没有对应流体时，pullFluid可以将目标容器中的流体拉取到自身的一个空储罐中", function()
                    local p = peripheral.wrap(tankB.name)
                    local transferFluidStackA, slotA = findFluidStack(tankAComponent.fluidList, water().name)
                    assert.is.Not.Nil(transferFluidStackA)
                    ---@cast transferFluidStackA -nil
                    local originAFluidAmount = transferFluidStackA.amount
                    local actuallyTransfer = p.pullFluid(tankA.name)
                    local transferFluidStackB, slotB = findFluidStack(tankBComponent.fluidList, water().name)
                    assert.is.Not.Nil(transferFluidStackB)
                    ---@cast transferFluidStackB -nil
                    local exceptTransfer = math.min(coeB * capacityB[slotB], commonFluidInput, coeA * capacityA[slotA])
                    assert.is.equal(exceptTransfer, actuallyTransfer)
                    assert.is.equal(transferFluidStackB.amount, actuallyTransfer)
                    assert.is.equal(originAFluidAmount, transferFluidStackA.amount + transferFluidStackB.amount)
                end)
                it("在自身储罐存在对应流体时，pullFluid会尝试将目标容器的流体拉取到存储着相同流体的储罐中", function()
                    local preloadVolume = 1
                    tankBComponent.dev:addFluid(water(), preloadVolume)
                    local transferFluidStackB, slotB = findFluidStack(tankBComponent.fluidList, water().name)
                    assert.is.Not.Nil(transferFluidStackB)
                    ---@cast transferFluidStackB -nil
                    assert.is.equal(preloadVolume, transferFluidStackB.amount)
                    local p = peripheral.wrap(tankB.name)
                    local transferFluidStackA, slotA = findFluidStack(tankAComponent.fluidList, water().name)
                    assert.is.Not.Nil(transferFluidStackA)
                    ---@cast transferFluidStackA -nil
                    local originAFluidAmount = transferFluidStackA.amount
                    local actuallyTransfer = p.pullFluid(tankA.name)
                    local exceptTransfer = math.min(coeB * capacityB[slotB] - preloadVolume, commonFluidInput, coeA * capacityA[slotA])
                    assert.is.equal(exceptTransfer, actuallyTransfer)
                    assert.is.equal(transferFluidStackB.amount, actuallyTransfer + preloadVolume)
                    assert.is.equal(originAFluidAmount, transferFluidStackA.amount + transferFluidStackB.amount - preloadVolume)
                end)
                it("在自身某个储罐存在对应流体但该储罐已满时，pullFluid会尝试将流体拉取到可能的空储罐", function()
                    tankBComponent.dev:addFluid(water(), 2 ^ 12 * coeB)
                    local p = peripheral.wrap(tankB.name)

                    local transferFluidStackA, slotA = findFluidStack(tankAComponent.fluidList, water().name)
                    assert.is.Not.Nil(transferFluidStackA)
                    ---@cast transferFluidStackA -nil
                    local originAFluidAmount = transferFluidStackA.amount

                    local transferFluidStackB, slotB = findFluidStack(tankBComponent.fluidList, water().name)

                    local actuallyTransfer = p.pullFluid(tankA.name)

                    for slot, fluidStack in pairs(tankBComponent.fluidList) do
                        if not fluidStack.fluid then
                            goto continue
                        end
                        if slot == slotB then
                            goto continue
                        end
                        transferFluidStackB = fluidStack
                        slotB = slot
                        break
                        ::continue::
                    end
                    assert.is.Not.Nil(transferFluidStackB)
                    ---@cast transferFluidStackB -nil
                    local exceptTransfer = math.min(coeB * capacityB[slotB], commonFluidInput, coeA * capacityA[slotA])

                    local containFluidNum = 0
                    for _, fluidStack in pairs(tankBComponent.fluidList) do
                        if fluidStack.fluid then
                            containFluidNum = containFluidNum + 1
                        end
                    end
                    if sizeB == 1 then
                        assert.is.equal(1, containFluidNum)
                        assert.is.equal(0, actuallyTransfer)
                    else
                        assert.is.equal(2, containFluidNum)
                    end
                    assert.is.equal(exceptTransfer, actuallyTransfer)
                    assert.is.equal(transferFluidStackB.amount, actuallyTransfer)
                    assert.is.equal(originAFluidAmount, transferFluidStackA.amount + transferFluidStackB.amount)
                end)
                it("容器满时pullFluid不会拉取任何流体", function()
                    for j = 1, sizeB, 1 do
                        tankBComponent.dev:addFluid(water(), 2 ^ 12 * coeB)
                    end
                    local p = peripheral.wrap(tankB.name)
                    local actuallyTransfer = p.pullFluid(tankA.name)
                    assert.is.equal(0, actuallyTransfer)
                end)
                it("可以使用limit参数限制pullFluid拉取的流体数量", function()
                    local p = peripheral.wrap(tankB.name)
                    local _, slotA = findFluidStack(tankAComponent.fluidList, water().name)
                    local theRandomNum = math.random(888)
                    local actuallyTransfer = p.pullFluid(tankA.name, theRandomNum)
                    local _, slotB = findFluidStack(tankBComponent.fluidList, water().name)
                    assert.is.equal(math.min(theRandomNum, coeA * capacityA[slotA], coeB * capacityB[slotB]), actuallyTransfer)
                end)
                it("可以使用fluidName参数限制pullFluid拉取的流体", function()
                    tankAComponent.dev:addFluid(lava(), 34)
                    local p = peripheral.wrap(tankB.name)
                    p.pullFluid(tankA.name, nil, lava().name)
                    local findLava = false
                    for _, fluidStack in pairs(tankBComponent.fluidList) do
                        if not fluidStack.fluid then
                            goto continue
                        end
                        assert.is.same(fluidStack.fluid, lava())
                        findLava = true
                        ::continue::
                    end
                    assert.is.True(findLava)
                end)
                it("使用不存在的外设名调用pullFluid应该报错", function()
                    local p = peripheral.wrap(tankB.name)
                    assert.has.error(function()
                        p.pullFluid("Doesn't exist peripheral name")
                    end)
                end)
                it("尝试用pullFluid跨网络拉取流体应该报错", function()
                    local p = peripheral.wrap(tankC.name)
                    assert.has.error(function()
                        p.pullFluid(tankA.name)
                    end, ("Can't find peripheral: %s"):format(tankA.name))
                end)
                it("尝试用pullFluid从非tank外设上拉取流体应该报错", function()
                    local p = peripheral.wrap(tankB.name)
                    assert.has.error(function()
                        p.pullFluid(otherPeripheral.name)
                    end, ("The peripheral: %s isn't %s"):format(otherPeripheral.name, tankBComponent.type))
                end)
            end)
        end
    end)
end)
