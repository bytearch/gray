-- Copyright (C) www.bytearch.com (iyw)
local _M = {
    _VERSION = "0.0.2"
}
-- 灰度级别
-- 0: 按流量比转发（按比例进入灰度）
-- 1:  只有符合org-no的进入灰度
-- 2: 按流量比转发和按照机构进入灰度
-- 3: 100%流量转发到老系统（纯线上环境）
local proxy_sys_level = 1;

-- 流量控制级别 可调整 当 proxy_sys_level = 0 时生效
-- 0.01%  new = 1, base = 10000
-- 0.1%  new = 1, base = 1000
-- 1%  new = 1, base = 100
-- 10%  new = 10, base = 100
-- 100% new = 100, base = 100
local proxy_percent = {
    new = 1, base = 1000
}

-- 灰度uri配置 此处也可以从配置中心 | redis| 文件 等中获取
local proxy_uri_list = {
    ["/test/api"] = true
}

-- ip白名单 该ip 100%转发到新系统(主要为了方便测试)
local white_ip_list = {
    -- "192.168.0.1"
}
-- 100%转发到新系统uri配置 (可能有些接口需要指定转发到新系统)
local must_proxy_new_uri_list = {
    -- ["/write"] = true,
}
--old
local old_upstream = "proxy_old"
--new
local new_upstream = "proxy_new"


--org_no
local gray_org_no_list = {
    "-1234"
}

_M['proxy_sys_level'] = proxy_sys_level
_M['proxy_percent'] = proxy_percent
_M['white_ip_list'] = white_ip_list
_M['must_proxy_new_uri_list'] = must_proxy_new_uri_list
_M['proxy_uri_list'] = proxy_uri_list
_M['old_upstream'] = old_upstream
_M['new_upstream'] = new_upstream
_M['gray_org_no_list'] = gray_org_no_list

return _M