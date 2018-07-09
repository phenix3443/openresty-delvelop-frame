-- -*- coding:utf-8; -*-
-- author:liushangliang
-- desc:
-- doc: http://book.open-falcon.org/zh_0_2/usage/data-push.html

local cjson = require("cjson.safe")
local stringx = require("pl.stringx")

local export = {
    need_reload = true,
    default_step = 60,  --  in seconds
    shm_key_mod_map = {}
}

local function get_host_name()
    local f = io.popen ("/bin/hostname")
    local hostname = f:read("*a") or ""
    f:close()
    hostname =string.gsub(hostname, "\n$", "")
    return hostname
end

-- 注册shm_key的解析器
function export.register_shm_key_mod(metric, mod)
    ngx.log(ngx.DEBUG, metric, " register mod start")
    if not metric then
        ngx.log(ngx.ERR, "metric can not be nil")
        return
    end

    -- module检查
    if type(mod) ~= "table" then
        ngx.log(ngx.ERR, "parser should be function")
        return
    end

    local must_method = {"gen_shm_key","change_value", "get_falcon_info"}
    for _, f in pairs(must_method) do
        local func = mod[f]
        if not(func and type(func) == "function") then
            ngx.log(ngx.ERR, "shm key mod invalid function:", f)
            return
        end
    end

    export.shm_key_mod_map[metric] = mod
    ngx.log(ngx.DEBUG, metric, " register mod finished")
    return true
end

function export.get_shm_key_mode(metric)
    local mod = export.shm_key_mod_map[metric]
    if not mod then
        ngx.log(ngx.ERR, "can not find mod for ", metric)
        return
    end
    return mod
end

-- get metric from shm_key
-- shm_key = metric:...
local function get_metric_from_shm_key(shm_key)
    local arr = stringx.split(shm_key, ":")
    if #arr < 1 then
        ngx.log(ngx.ERR, "invalid shm_key,", shm_key)
        return
    end

    local metric = arr[1]

    return metric
end

function export.store_stat_record(shm_name, shm_key, value)
    local metric = get_metric_from_shm_key(shm_key)
    local mod = export.shm_key_mod_map[metric]
    mod.change_value(shm_name, shm_key,value)
end

-- shm_key = metric:counter_type:....
local function parse_shm_key(shm_key)
    local metric = get_metric_from_shm_key(shm_key)
    if not metric then
        local log_msg = string.format("shm_key={},metric=%s", shm_key, metric)
        ngx.log(ngx.DEBUG, log_msg)
        return
    end

    -- 检查metric对应的tags方法是否已经注册
    local mod = export.shm_key_mod_map[metric]
    if not mod then
        ngx.log(ngx.ERR,"shm_key has not mod:", shm_key)
        return
    end

    local counter_type, tags = mod.get_falcon_info(shm_key)

    -- 检查counter有效性
    local valid_counter_type = {
        ["COUNTER"] = true,
        ["GAUGE"] = true
    }

    if not valid_counter_type[counter_type]  then
        local log_msg = string.format("invalid counter type,shm_key=%s,counter_type=%s", shm_key, counter_type)
        ngx.log(ngx.ERR, log_msg)
        return
    end

    return metric, counter_type, tags
end

local host_name = get_host_name()

-- 生成shm_key对应的falcon item
function export.gen_item(shm_key, value)
    local metric, counter_type, tags= parse_shm_key(shm_key)
    if not metric then
        return
    end

    local t = {}
    for k, v in pairs(tags) do
        table.insert(t, string.format("%s=%s",k,v))
    end
    local report_tags = table.concat(t,",")

    local item = {
        endpoint = host_name,
        metric = metric,
        timestamp = ngx.time(),
        step = export.default_step,
        tags = report_tags,
        value = value,
        counterType = counter_type
    }

    local log_msg = string.format("shm_key=%s, value=%s, item=%s", shm_key, value,cjson.encode(item))
    ngx.log(ngx.DEBUG, log_msg)
    return item
end

-- 从shm_dict生成此次上报的payload
function export.gen_payload_from_shm(shm_name)
    local payload = {}
    local dict = ngx.shared[shm_name]
    local keys = dict:get_keys()
    ngx.log(ngx.DEBUG,"all shm keys:", cjson.encode(keys))
    for i,key in pairs(keys) do
        local value = dict:get(key)
        local item = export.gen_item(key, value)
        if item then
            table.insert(payload, item)
        end
    end
    ngx.log(ngx.DEBUG, "payload from shm:",cjson.encode(payload))
    return payload
end

-- 将payload上报falcon
function export.report(payload)
    local resp = ngx.location.capture("/falcon/v1/push",
                                      {
                                          method = ngx.HTTP_POST,
                                          body = cjson.encode(payload)
    })

    if not (resp and resp.status == ngx.HTTP_OK) then
        ngx.log(ngx.ERR, "falcon agent connect failed,status=", resp.status)
        return
    end
    return resp
end


return export
