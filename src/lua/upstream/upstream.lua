-- -*- coding:utf-8 -*-
-- author:liushangliang@xunlei.com
-- desc:对外接口代码示例

local cjson = require("cjson.safe")
local http = require("resty.http")

local export = {}
local mt = {__index = export}

function export.new(cfg)
    local httpc = http.new()
    local ok, err = httpc:connect(cfg.host, cfg.port)

    if not ok then
        ngx.log(ngx.ERR,"failed to connect: ", err)
        return
    end

    ngx.log(ngx.DEBUG,"connected to http server.")

    return setmetatable({httpc=httpc}, mt)
end

function export.close(self)
    local ok, err = self.httpc:set_keepalive(10000, 100)
    if not ok then
        ngx.log(ngx.ERR, "failed to set keepalive: ", err)
        return
    end
end

function export.send(self, req)
    ngx.log(ngx.DEBUG, "req:", cjson.encode(req))
    local res, err = self.httpc:request(req)
    if not res then
        ngx.log(ngx.ERR, "failed to get resp:", err)
        return
    end

    if res.status ~= ngx.HTTP_OK then
        ngx.log(ngx.ERR, "resp http status err, status", res.status, " reason:", res.reason)
        return
    end

    local body = res:read_body()
    ngx.log(ngx.DEBUG, "resp body:", body)

    local data = cjson.decode(body)
    if not data then
        ngx.log(ngx.WARN, "resp data json decode error")
        return
    end

    return data
end

-- 添加业务代码
function export.interface(self, args)
    local req = {
        method = "POST",
        path = "/path",
        headers = {
            ["Content-Type"] = "application/json",
        },
        body = ""
    }

    local resp = export.send(self, req)
    return resp
end

return export