---@class a546.Component
---@field type string 标识组件类型，这应该是唯一的
---@field fatherContainer a546.VirtualPeripheral 被植入的容器对象
---@field private __binding boolean
local Base = {__binding = false}
Base.__index = Base

--- 将自身绑定到一个虚拟外设上
---@param target a546.VirtualPeripheral
function Base:bindTo(target)
    if self.__binding then
        return
    end
    if self.fatherContainer then
        error(("Component: %s has been bindTo peripheral: %s"):format(tostring(self), target.name), 3)
    end
    self.__binding = true
    local result, msg = pcall(target.bind, target, self)
    self.__binding = false
    if not result then
        error(msg, 3)
    end
    self.fatherContainer = target
end

return Base
