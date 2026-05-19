local localNet = require("localNet")
local dataHolder = require("dataHolder")
local util = require("lib.util")
-- 通用流体容器外设组件
local out = {}

---@class a546.TankDev
---@field tank a546.Tank
local TankDev = {}
TankDev.__index = TankDev

--- 查找是否有指定的液体</br>
--- 写完后我才发现没必要为一个只用一次的操作写一个函数……
---@param fluidList {fluid:a546.FakeFluid,amount:number,capacity:number}[] 与Tank的fluidList字段类型相同
---@param name string
---@return integer|nil
local function findFluid(fluidList, name)
    for slot, fluidStack in pairs(fluidList) do
        if not fluidStack.fluid then
            goto continue
        end
        if fluidStack.fluid.name == name then
            return slot
        end
        ::continue::
    end
end

--- 移除指定的流体</br>
--- 如果`amount`大于储存于该槽位的流体，则只移除该槽位的流体
---@param name string
---@param amount? number
---@return a546.FakeFluid|nil
---@return number
function TankDev:removeFluid(name, amount)
    -- 参数处理和检查
    local slot = findFluid(self.tank.fluidList, name)
    if not slot then
        return nil, 0
    end
    if (amount or 1) < 0 then
        error(("Param \"amount\" can't be %d"):format(amount))
    end
    amount = amount or self.tank.fluidList[slot].amount
    local preRemove = math.min(amount , self.tank.fluidList[slot].amount)
    -- 移除流体
    local resultFluid = self.tank.fluidList[slot].fluid
    if preRemove >= self.tank.fluidList[slot].amount then
        self.tank.fluidList[slot].fluid = nil
        self.tank.fluidList[slot].amount = 0
    else
        local fluidStack = self.tank.fluidList[slot]
        fluidStack.amount = fluidStack.amount - preRemove
    end
    return resultFluid, preRemove
end

--- 向组件中添加指定数量的流体</br>
--- 会先查找是否有包含相同流体的储罐</br>
--- 如果没有找到，则会选择一个空储罐储存输入流体
---@param fluid a546.FakeFluid
---@param amount? number
---@return number
function TankDev:addFluid(fluid, amount)
    if (amount or 1) < 0 then
        error(("Param \"amount\" can't be %d"):format(amount))
    end
    ---@cast amount number
    local fluidList = self.tank.fluidList
    local freeSlot
    local prepareTransfer = amount
    for i = 1, self.tank.invSize, 1 do
        local fluidStack = fluidList[i]
        if not fluidStack.fluid then
            freeSlot = freeSlot or i
            goto continue
        end
        if fluidStack.fluid.name ~= fluid.name then
            goto continue
        end
        local transferAmount = math.min(prepareTransfer, self.tank.storageCoefficient * fluidStack.capacity - fluidStack.amount)
        if transferAmount == 0 then
            goto continue
        end
        fluidStack.amount = fluidStack.amount + transferAmount
        prepareTransfer = prepareTransfer - transferAmount
        if prepareTransfer == 0 then
            return amount
        else
            return amount - prepareTransfer
        end
        ::continue::
    end
    if not freeSlot then
        return amount - prepareTransfer
    end
    -- 既然能走到这，说明还有流体待分配，还有空储罐可用
    -- 经过实际测试发现，cc不会检查是否还有更多空储罐，所以下面这段代码中只处理最先被找到的空储罐
    local fluidStack = fluidList[freeSlot]
    local transferAmount = math.min(prepareTransfer, self.tank.storageCoefficient * fluidStack.capacity)
    prepareTransfer = prepareTransfer - transferAmount
    fluidList[freeSlot].fluid = fluid
    fluidList[freeSlot].amount = transferAmount
    if prepareTransfer == 0 then
        return amount
    end
    return amount - prepareTransfer
end

---@class a546.FakeFluid
---@field name string
local FakeFluid = {}
FakeFluid.__index = FakeFluid

out.FakeFluid = FakeFluid

--- 创建一个假流体
---@param name string
---@return a546.FakeFluid
function FakeFluid.make(name)
    local o = setmetatable({}, FakeFluid)
    o.name = name
    return o
end

---@class a546.Tank.FluidStack
---@field fluid a546.FakeFluid
---@field amount number
---@field capacity number

---@class a546.Tank:a546.Component
---@field type "tank" 标识组件类型，这应该是唯一的
---@field invSize number 容器大小，在这里可以理解为最多可以同时存储多少种类的流体
---@field storageCoefficient number 容器单槽位存储系数，单槽位可存储流体量 = 存储系数 * 该槽位容量上限（capacity）
---@field fluidList a546.Tank.FluidStack[] 流体列表
---@field dev a546.TankDev 供开发者和组件自身使用的函数集合
local Tank = {}
Tank.__index = Tank

--- 创建一个流体储罐组件
---@param size integer
---@param storageCoefficient number
---@param capacityList number[]
---@return a546.Tank
function out.make(size, storageCoefficient, capacityList)
    local o = setmetatable({}, Tank)
    o.type = "tank"
    o.invSize = math.max(size or 1, 1)
    o.storageCoefficient = storageCoefficient
    o.fluidList = {}
    -- 初始化fluidList
    for i = 1, o.invSize, 1 do
        table.insert(o.fluidList, { capacity = math.abs(capacityList[i] or 1000), amount = 0 })
    end
    o.dev = setmetatable({}, TankDev)
    o.dev.tank = o
    dataHolder.registerComponents(o, util.readOnly(o, true))
    return util.readOnly(o, true)
    -- return o
end

function Tank:tanks()
    local result = {}
    for slot, fluidStack in pairs(self.fluidList) do
        if not fluidStack.fluid then
            goto continue
        end
        result[slot] = {}
        result[slot].name = fluidStack.fluid.name
        result[slot].amount = fluidStack.amount
        ::continue::
    end
    return result
end

function Tank:pushFluid(toName, ...)
    -- 参数处理
    local limit, fluidName
    local paramCount = select("#", ...)
    if paramCount == 2 then
        limit, fluidName = ...
    elseif paramCount == 1 then
        limit = ...
    end
    --- 自身储罐内能找到的第一种流体</br>
    --- 可能不存在（容器为空时）
    ---@type {fluid:a546.FakeFluid,amount:number,capacity:number}
    local selfFirstFluidStack

    for _, fluidStack in pairs(self.fluidList) do
        if not fluidStack.fluid then
            goto continue
        end
        selfFirstFluidStack = fluidStack
        break
        ::continue::
    end

    fluidName = fluidName or selfFirstFluidStack.fluid.name

    -- 检查参数合法
    if not localNet.isPresent(toName) or not localNet.inSameNet(toName, dataHolder.getContainer(self).name) then
        error(("Can't find peripheral: %s"):format(toName), 2)
    end
    -- 查找远程外设
    local targetComponent = localNet.getPeripheral(localNet.findPeripheral(toName) --[[@as integer]], toName).component[self.type]
    if not targetComponent then
        error(("The peripheral: %s isn't %s"):format(toName, self.type), 2)
    end
    ---@cast targetComponent a546.Tank

    -- 移除流体
    local transferFluid, removedAmount = self.dev:removeFluid(fluidName, limit)

    if not transferFluid then
        return 0
    end

    --print(("从 %s 移除了 %.2f %s"):format(dataHolder.getContainer(self).name, removedAmount, transferFluid.name))

    -- 转移流体
    local actuallyTransfer = targetComponent.dev:addFluid(transferFluid, removedAmount)

    --print(("向 %s 添加了 %.2f %s"):format(toName, actuallyTransfer, transferFluid.name))

    if actuallyTransfer == removedAmount then
        return actuallyTransfer
    end
    -- 处理无法转移的流体
    self.dev:removeFluid(fluidName)

    --print(("从 %s 移除了所有流体"):format(dataHolder.getContainer(self).name))

    self.dev:addFluid(transferFluid, removedAmount - actuallyTransfer)

    --print(("向 %s 添加了 %.2f %s"):format(dataHolder.getContainer(self).name, removedAmount - actuallyTransfer, transferFluid.name))

    return actuallyTransfer
end

function Tank:pullFluid(fromName, ...)
    -- 检查参数合法
    if not localNet.isPresent(fromName) or not localNet.inSameNet(fromName, dataHolder.getContainer(self).name) then
        error(("Can't find peripheral: %s"):format(fromName), 2)
    end
    -- 查找远程外设
    local targetComponent = localNet.getPeripheral(localNet.findPeripheral(fromName) --[[@as integer]], fromName).component[self.type]
    if not targetComponent then
        error(("The peripheral: %s isn't %s"):format(fromName, self.type), 2)
    end
    ---@cast targetComponent a546.Tank

    -- 调用对方的push方法
    return targetComponent:pushFluid(dataHolder.getContainer(self).name, ...)
end

return out
