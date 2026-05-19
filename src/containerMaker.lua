-- 规定如何组装一个假容器，并规定这个容器的相关信息如何存储

local dataHolder = require("dataHolder")
local util = require("lib.util")

local out = {}
---@type table<string,number>
local containerId = {}

---@class a546.FakeContainer
---@field name string
---@field type string
---@field component table<string,a546.Component>
local container = {}
container.__index = container

--- 制造一个假容器外设
---@param type string 容器类型
---@param ... a546.Component 容器组件
function out.make(type, ...)
    -- 初始化
    local o = setmetatable({}, container)
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
        o.component[component.type] = component
        dataHolder.bindComponent(o, component)
        -- 由于传入的是只读副本，无法修改外设组件的字段
        component.fatherContainer = o
        ::continue::
    end
    containerId[type] = id + 1
    o.type = type
    --
    dataHolder.registerContainer(o)
    return util.readOnly(o, true)
end

return out
