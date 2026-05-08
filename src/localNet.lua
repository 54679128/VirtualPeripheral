-- 规定如何创建一个本地外设网络，该网络该保存什么信息
local out = {}
---@type table<number,table<string,a546.FakeContainer>>
local netList = {}

--- 创建一个本地网络并返回
---@return integer 本地网络id
function out.make()
    table.insert(netList, {})
    return #netList
end

--- 重置模块状态，清除所有已创建网络及相关外设信息
function out.reset()
    netList = {}
end

--- 向指定 id 所代表的网络添加外设
---@param lNetId integer
---@param peripheral a546.FakeContainer
function out.addPeripheral(lNetId, peripheral)
    if out.isPresent(peripheral.name) then
        error(("The peripheral: %s has been add to some local net."):format(peripheral.name))
    end
    if not netList[lNetId] then
        error(("Local net id: %d doesn't exist!"):format(tonumber(lNetId)))
    end
    netList[lNetId][peripheral.name] = peripheral
end

--- 从指定 id 代表的网络移除外设</br>
--- id 所代表的网络不存在或指定的外设不存在都会导致报错
---@param lNetId integer
---@param name string
function out.removePeripheral(lNetId, name)
    if not netList[lNetId] then
        error(("Local net id: %d doesn't exist!"):format(tonumber(lNetId)))
    end
    if not netList[lNetId][name] then
        error(("Can't find peripheral: %s in local net: %d"):format(tostring(name), lNetId))
    end
    netList[lNetId][name] = nil
end

--- 获取所有网络中的所有外设
---@return table<string,a546.FakeContainer>
function out.getAllPeripheral()
    local result = {}
    for i = 1, #netList do
        for peripheralName, fakePeripheral in pairs(netList[i]) do
            result[peripheralName] = fakePeripheral
        end
    end
    return result
end

--- 从指定 id 代表的网络获取外设</br>
--- id 所代表的网络不存在会导致报错</br>
--- 不提供`name`参数时会返回指定网络中的所有外设
---@param lNetId integer
---@param name? string
---@return a546.FakeContainer|a546.FakeContainer[] 🐢
function out.getPeripheral(lNetId, name)
    if not netList[lNetId] then
        error(("Local net id: %d doesn't exist!"):format(tonumber(lNetId)))
    end
    if not name then
        local result = {}
        for _, fakePeripheral in pairs(netList[lNetId]) do
            table.insert(result, fakePeripheral)
        end
        return result
    end
    if not netList[lNetId][name] then
        error(("Can't find peripheral: %s in local net: %d"):format(tostring(name), lNetId))
    end
    return netList[lNetId][name]
end

--- 查找指定外设位于哪个网络中
---@param name string
---@return integer|nil 代表网络的数字id，如果没找到会返回nil
function out.findPeripheral(name)
    for i = 1, #netList do
        for peripheralName, _ in pairs(netList[i]) do
            if peripheralName == name then
                return i
            end
        end
    end
end

--- 判断一个外设是否存在于某个本地网络
---@param name string
---@return boolean
function out.isPresent(name)
    if out.findPeripheral(name) then
        return true
    end
    return false
end

--- 判断两个外设是否在同一个本地网络中
---@param name1 string
---@param name2 string
---@return integer|nil 代表网络的数字id或代表两者不在同一个网络中的nil
function out.inSameNet(name1, name2)
    local id1 = out.findPeripheral(name1)
    local id2 = out.findPeripheral(name2)
    if id1 == id2 then
        return id1
    end
    return
end

return out
