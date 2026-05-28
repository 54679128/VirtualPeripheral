local config = require "config"
local util   = require "lib.util"
-- 规定如何组装一个假容器，并规定这个容器的相关信息如何存储
local out = {}
---@type table<string,number>
local containerId = {}

---@class a546.FakeContainer
---@field name string
---@field type string
---@field component table<string,a546.Component>
---@field private __binding boolean
local VirtualPeripheral = {__binding = false}
VirtualPeripheral.__index = VirtualPeripheral

--- 将某个外设组件绑定到自身
---@param source a546.Component
function VirtualPeripheral:bind(source)
    if self.__binding then
        return
    end
    if self.component[source.type] then
        error(("peripheral: %s has bind this type component"):format(self.name), 3)
    end
    self.__binding = true
    local result, msg = pcall(source.bindTo, source, self)
    self.__binding = false
    if not result then
        error(msg, 3)
    end
    self.component[source.type] = source
end

--- 制造一个假容器外设
---@param type string 容器类型
---@param ... a546.Component 容器组件
function out.make(type, ...)
    -- 初始化
    local o = setmetatable({}, VirtualPeripheral)
    o.component = {}
    --
    local installComponent = {}
    containerId[type] = containerId[type] or 0
    local id = containerId[type]
    o.name = ("%s_%d"):format(type, id)
    for _, component in pairs({ ... }) do
        if installComponent[component.type] then
            goto continue
        end
        -- o.component[component.type] = component
        -- component.fatherContainer = o
        component:bindTo(o)
        ::continue::
    end
    containerId[type] = id + 1
    o.type = type
    if config.readOnly() then
        return util.readOnly(o)
    end
    return o
end

return out
