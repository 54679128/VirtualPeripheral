local util = require("lib.util")
local localNet = require("localNet")
local Base = require("ContainerComponent.base")
-- 通用物品容器外设组件
local out = {}

---@alias slot number

---@class a546.inventoryDev
---@field inv a546.inventory
local InventoryDev = {}
InventoryDev.__index = InventoryDev

--- 将物品从指定的槽位中移除</br>
--- 如果`count`大于该槽位的物品数，则只移除存在的数量
---@param slot integer
---@param count? integer
---@return a546.FakeItem|nil
---@return integer
function InventoryDev:removeItem(slot, count)
    -- 参数处理和检查
    if slot > self.inv.invSize then
        error(("Param slot: %d > %d"):format(slot, self.inv.invSize), 2)
    elseif slot < 0 then
        error(("Param slot: %d < 0"):format(slot), 2)
    end
    if not self.inv.itemList[slot] then
        return nil, 0
    end
    count = count or self.inv.itemList[slot].count
    local preRemove = math.min(count, self.inv.itemList[slot].count)
    -- 移除物品
    local resultItem
    if preRemove >= self.inv.itemList[slot].count then
        resultItem = self.inv.itemList[slot].item
        self.inv.itemList[slot] = nil
    else
        local itemStack = self.inv.itemList[slot]
        ---@cast itemStack -nil
        resultItem = itemStack.item
        itemStack.count = itemStack.count - preRemove
    end
    return resultItem, preRemove
end

--- 向组件中添加一个指定的物品</br>
--- 必要时会将物品分别放入多个不同的槽位</br>
--- 如果指定了槽位，则只会放入指定槽位中
---@param item a546.FakeItem
---@param count integer
---@param slot? integer
---@return integer
function InventoryDev:addItem(item, count, slot)
    local itemList
    if slot then
        if slot < 0 then
            error(("Param slot: %d < 0"):format(slot), 2)
        elseif slot > self.inv.invSize then
            error(("Param slot: %d > %d"):format(slot, self.inv.invSize))
        end
    end
    itemList = self.inv.itemList
    local freeSlot = {}
    local prepareTransfer = count
    for i = slot or 1, slot or self.inv.invSize, 1 do
        local theSlot = i
        local itemStack = itemList[i]
        if not itemStack then
            table.insert(freeSlot, theSlot)
            goto continue
        end
        if itemStack.item.name ~= item.name then
            goto continue
        end
        if util.serializeTable(item.nbt) ~= util.serializeTable(itemStack.item.nbt) then
            goto continue
        end
        local transferCount = math.min(prepareTransfer,
            self.inv.storageCoefficient * itemStack.item.stackLimit - itemStack.count)
        itemStack.count = itemStack.count + transferCount
        prepareTransfer = prepareTransfer - transferCount
        if prepareTransfer == 0 then
            return count
        end
        ::continue::
    end
    -- 既然能走到这，说明还有物品待分配
    for i = 1, #freeSlot do
        local transferCount = math.min(prepareTransfer,
            self.inv.storageCoefficient * item.stackLimit)
        prepareTransfer = prepareTransfer - transferCount
        itemList[freeSlot[i]] = {}
        itemList[freeSlot[i]].item = item
        itemList[freeSlot[i]].count = transferCount
        if prepareTransfer == 0 then
            return count
        end
    end
    return count - prepareTransfer
end

---@class a546.FakeItem
---@field name string
---@field count number
---@field stackLimit number
---@field nbt table<string,any>
local FakeItem = {}
FakeItem.__index = FakeItem

out.FakeItem = FakeItem

--- 创建一个假物品
---@param name string
---@param stackLimit number
---@param nbt table<string,any>
---@return a546.FakeItem
function FakeItem.make(name, stackLimit, nbt)
    local o = setmetatable({}, FakeItem)
    o.name = name
    o.stackLimit = stackLimit
    o.nbt = nbt
    return o
end

---@class a546.inventory:a546.Component
---@field type "inventory" 标识组件类型，这应该是唯一的
---@field invSize number 容器大小
---@field storageCoefficient number 容器单槽位存储系数，单槽位可存储物品数 = 存储系数 * 该槽位物品堆叠上限
---@field itemList table<slot,{item:a546.FakeItem,count:integer}|nil> 物品列表
---@field dev a546.inventoryDev 供开发者和组件自身使用的函数集合
local inventory = setmetatable({}, Base)
inventory.__index = inventory

function out.make(size, storageCoefficient)
    local o = setmetatable({}, inventory)
    ---@cast o a546.inventory
    o.type = "inventory"
    o.invSize = math.max(size or 1, 1)
    o.storageCoefficient = storageCoefficient
    o.itemList = {}
    o.dev = setmetatable({}, InventoryDev)
    o.dev.inv = o
    return o
end

function inventory:size()
    return self.invSize
end

function inventory:list()
    local result = {}
    for slot, itemStack in pairs(self.itemList) do
        local item = itemStack.item
        result[slot] = {}
        result[slot].name = item.name
        result[slot].count = itemStack.count
        result[slot].nbt = util.serializeTable(item.nbt)
        ::continue::
    end
    return result
end

function inventory:getItemDetail(slot)
    local itemList = inventory:list()
    return itemList[slot]
end

function inventory:getItemLimit(slot)
    return 64 * self.storageCoefficient
end

function inventory:pushItems(toName, fromSlot, ...)
    -- 参数处理
    local limit, toSlot
    local paramCount = select("#", ...)
    if paramCount == 2 then
        limit, toSlot = ...
        limit = limit or 64
    elseif paramCount == 1 then
        limit = ...
    end

    -- 检查参数合法
    if not localNet.isPresent(toName) or not localNet.inSameNet(toName, self.fatherContainer.name) then
        error(("Can't find peripheral: %s"):format(toName), 2)
    end
    -- 查找远程外设
    local targetComponent = localNet.getPeripheral(localNet.findPeripheral(toName) --[[@as integer]], toName).component[self.type]
    if not targetComponent.type then
        error(("The peripheral: %s isn't inventory"):format(toName), 2)
    end
    ---@cast targetComponent a546.inventory

    -- 移除物品
    local transferItem, removedCount = self.dev:removeItem(fromSlot, limit)
    if not transferItem then
        return 0
    end
    -- 转移物品
    local actuallyTransfer = targetComponent.dev:addItem(transferItem, removedCount, toSlot)
    if actuallyTransfer == removedCount then
        return actuallyTransfer
    end
    -- 处理无法转移的物品
    self.dev:removeItem(fromSlot)
    self.dev:addItem(transferItem, removedCount - actuallyTransfer, fromSlot)
end

function inventory:pullItems(fromName, fromSlot, ...)
    -- 检查参数合法
    if not localNet.isPresent(fromName) or not localNet.inSameNet(fromName, self.fatherContainer.name) then
        error(("Can't find peripheral: %s"):format(fromName), 2)
    end
    -- 查找远程外设
    local targetComponent = localNet.getPeripheral(localNet.findPeripheral(fromName) --[[@as integer]], fromName).component[self.type]
    if not targetComponent then
        error(("The peripheral: %s isn't inventory"):format(fromName), 2)
    end
    ---@cast targetComponent a546.inventory
    -- 检查槽位
    if fromSlot > self.invSize or fromSlot < 1 then
        error(("Param \"fromSlot\" must between %d and %d"):format(1, self.invSize), 2)
    end

    -- 调用对方的push方法
    return targetComponent:pushItems(self.fatherContainer.name, fromSlot, ...)
end

return out
