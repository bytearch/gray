-- Copyright (C) www.bytearch.com (iyw)
local config = require("gray.config")

-- 按流量灰度
local _M = {
    _VERSION = "0.0."
}
-- request count
local req_count = 0;

local uri_req_count_map = {}

local function _getRequestUri()
    local uri = ngx.var.uri
    return uri
end
-- write api transmit to new api
local function _isProxyNewMust()
    local proxy_new_uri_list = config['must_proxy_new_uri_list']
    if proxy_new_uri_list[_getRequestUri()] then
        return true
    end
    return false;
end

local function _checkWhiteReq()
    local headers = ngx.req.get_headers()
    local white_ip_list = config['white_ip_list']
    local ip = headers["X-REAL-IP"] or headers["X_FORWARDED_FOR"] or ngx.var.remote_addr or "0.0.0.0"
    for _, v in ipairs(white_ip_list) do
        if v == ip then
            return true
        end
    end
    return false
end


local function _checkOrgNo()
    local headers = ngx.req.get_headers()
    local gray_org_no_list = config['gray_org_no_list']
    local request_org_no = headers["org_no"] or headers["ORG_NO"]
    for _, v in ipairs(gray_org_no_list) do
        if v == request_org_no then
            return true
        end
    end
    return false
end

local function _getReqCnt()
    req_count = req_count + 1
    return req_count;
end

local function _getReqCountByKey(key)
    local req_count = uri_req_count_map[key]
    if req_count == nil then
        req_count = 0
    end
    uri_req_count_map[key] = req_count + 1
    return uri_req_count_map[key]
end

local function _getUpstreamByUriAndCount()
    local proxy_sys_level = config['proxy_sys_level']
    local old_upstream = config['old_upstream']
    local new_upstream = config['new_upstream']
    local proxy_percent = config['proxy_percent']
    -- system level
    if proxy_sys_level == 2 then
        return old_upstream
    elseif proxy_sys_level == 3 then
        if _checkOrgNo() == true then
            return new_upstream
        end
    elseif proxy_sys_level == 0 then
        if _checkWhiteReq() == true then
            return new_upstream
        end
        -- write first
        if _isProxyNewMust() == true then
            return new_upstream
        end
        local uri = _getRequestUri()
        -- proxy cantain uri
        if uri  then
            local count = _getReqCountByKey(uri)
            if (count % proxy_percent.base) < proxy_percent.new and _checkOrgNo() == true then
                return new_upstream
            end
        end
        return old_upstream
    end
end

function _M.init()
    local upstream = _getUpstreamByUriAndCount();
    ngx.var.backend = upstream
end
return _M


