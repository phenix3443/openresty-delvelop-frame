-- -*- coding:utf-8 -*-
--- 错误码配置
-- @author:liushangliang@xunlei.com


local M = {}

M.code = {
    ["OK"] = 0,
    ["ERR_PARAM"] = 1,
}

M.msg = {
    ["OK"] = "ok",
    ["ERR_PARAM"] = "参数错误",
}

return M