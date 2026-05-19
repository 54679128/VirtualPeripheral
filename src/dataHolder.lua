local out = {}

---@type table<string, a546.FakeContainer> 这里的键是值的`name`字段
local containers = setmetatable({}, { __mode = "v" })
---@type table<a546.Component, a546.FakeContainer> 这里的值是每个外设组件被绑定到的外设
local bindComponents = setmetatable({}, { __mode = "v" })
---@type table<a546.Component, a546.Component> 这里的键是原始表，值是只读表
local components = setmetatable({},{__mode = "kv"})

--- 注册容器
---@param container a546.FakeContainer
function out.registerContainer(container)
    containers[container.name] = container
end

--- 注册外设组件
---@param component a546.Component
function out.registerComponents(component, readOnlyOne)
    components[component] = readOnlyOne
end

--- 绑定外设组件
---@param container a546.FakeContainer
---@param component a546.Component
function out.bindComponent(container, component)
    bindComponents[component] = container
end

--- 获取容器
---@param nameOrComponent string|a546.Component
---@return nil|a546.FakeContainer
function out.getContainer(nameOrComponent)
    if type(nameOrComponent) == "string" then
        return containers[nameOrComponent]
    else
        local result = bindComponents[components[nameOrComponent]]
        if result then
            return result
        else
            error("我没找到啊？", 2)
        end
    end
end

return out
