local out = {}

local config = {
    readOnly = true
}

--- 设置是否开启只读保护<br>
--- 如果传入参数，则会修改该配置<br>
--- 无论是否传入参数，都会返回当前值（指函数内部操作结束后的值）
---@param status? boolean
---@return boolean # 是否已开启只读保护
function out.readOnly(status)
    if status then
        config.readOnly = status
    end
    return config.readOnly
end

return out
