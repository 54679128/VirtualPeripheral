local out = {}
local originRequire = require
local parentModuleName = (({ ... })[1]) --:gsub("\\[^\\]+$", "")
--print(("父模块路径：%s"):format(parentModuleName))
local function modifiedRequire(moduleName)
    local modifiedModuleName = ("%s.%s.%s"):format(parentModuleName, "src", moduleName)
    --print(("修改后的模块名为：%s"):format(modifiedModuleName))
    return originRequire(modifiedModuleName)
end

--- 加载子模块
---@param moduleName string
local function loadModule(moduleName)
    local moduleActuallyName = moduleName:match("%.?([^%.]+)$")
    --print(("实际模块名为：%s"):format(moduleActuallyName))
    out[moduleActuallyName] = require(moduleName)
    print(("成功加载 \"%s\" 模块"):format(moduleActuallyName))
end

--- 注入API
---@param moduleName string
local function loadApi(moduleName)
    local moduleActuallyName = moduleName:match("%.?([^%.]+)$")
    --print(("实际模块名为：%s"):format(moduleActuallyName))
    _G[moduleActuallyName] = require(moduleName)
    --print(("成功注入 \"%s\" API"):format(moduleActuallyName))
end

require = modifiedRequire
--print(("成功替换 require 函数"))

-- 加载第一层模块
loadModule("ContainerComponent.Inventory")
loadModule("ContainerComponent.Tank")
loadModule("LocalNet")
loadApi("peripheral")
loadModule("containerMaker")
loadModule("config")

require = originRequire
--print(("成功恢复 require 函数"));
return out
