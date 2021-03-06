-- -*- coding:utf-8 -*-
--- 接口相关统计.
-- @script stat.interface
-- @author:phenix3443@gmail.com

local shm = require ("misc.shm")
local qps = require("falcon.metrics.qps")
local tps = require("falcon.metrics.tps")
local status = require("falcon.metrics.status")
local request_time = require("falcon.metrics.request_time")

--- 统计接口相关的数据
-- 每次请求后，递增接口的 qps，tps 等统计数据
local function stat_interface_metrics()
    local domain = ngx.var.server_name
    local url = ngx.escape_uri(ngx.var.uri)
    local status_code = ngx.var.status
    local req_time = ngx.var.request_time
    -- qps
    local shm_key = qps.gen_shm_key(domain, url)
    shm.incr_value(shm_key)

    -- tps
    shm_key = tps.gen_shm_key(domain, url)
    shm.incr_value(shm_key)

    -- status
    shm_key = status.gen_shm_key(domain, url, status_code)
    shm.incr_value(shm_key)

    -- request_time
    shm_key = request_time.gen_shm_key(domain, url, req_time)
    shm.incr_value(shm_key)

end

stat_interface_metrics()
