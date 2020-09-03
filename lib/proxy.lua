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
    local request_org_no = headers["org-no"] or headers["ORG-NO"]
    --for k, v in pairs(headers) do
        --         ngx.log(ngx.ERR, "Got header "..k..": "..v..";")
        --       ngx.say("header  ",k,":",v)
    --end

    --  ngx.say("request_org_no:",request_org_no)
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


local function _transferByPercent(old_upstream,new_upstream,proxy_percent)
    ngx.log(ngx.ERR, "proxy_sys_level 0 ")

    if _checkWhiteReq() == true then
        return new_upstream
    end
    -- write first
    if _isProxyNewMust() == true then
        return new_upstream
    end
    local uri = _getRequestUri()
    -- proxy cantain uri
    ngx.log(ngx.ERR, "uri:"..uri.." ")
    if uri  then
        local count = _getReqCountByKey(uri)
        local percent = count % proxy_percent.base
        ngx.log(ngx.ERR, "count: "..count.." ")
        ngx.log(ngx.ERR,"%:"..percent.." ")
        if percent < proxy_percent.new then
            return new_upstream
        end
    end
    return old_upstream
end
local function _transferByOgrNo(old_upstream,new_upstream)
    ngx.log(ngx.ERR, "proxy_sys_level 0 ")

    if _checkWhiteReq() == true then
        return new_upstream
    end
    -- write first
    if _isProxyNewMust() == true then
        return new_upstream
    end
    local uri = _getRequestUri()
    -- proxy cantain uri
    ngx.log(ngx.ERR, "uri:"..uri.." ")
    if uri  then
        local count = _getReqCountByKey(uri)
        local percent = count % proxy_percent.base
        ngx.log(ngx.ERR, "count: "..count.." ")
        ngx.log(ngx.ERR,"%:"..percent.." ")
        if percent < proxy_percent.new then
            return new_upstream
        end
    end
    return old_upstream
end


local function _getUpstreamByUriAndCount()
    local proxy_sys_level = config['proxy_sys_level']
    local old_upstream = config['old_upstream']
    local new_upstream = config['new_upstream']
    local proxy_percent = config['proxy_percent']
    -- system level
    if proxy_sys_level == 0 then
        return _transferByPercent(old_upstream,new_upstream,proxy_percent)
    elseif proxy_sys_level == 1 then
        if _checkOrgNo() == true then
            return new_upstream
        else
            return old_upstream
        end
    elseif proxy_sys_level == 2 then
        if _checkOrgNo() == true then
            return new_upstream
        else
            return _transferByPercent(old_upstream,new_upstream,proxy_percent)
        end
    elseif proxy_sys_level == 3 then
        return old_upstream
    end
end

function _M.init()
    local upstream = _getUpstreamByUriAndCount();
    ngx.var.backend = upstream
end
return _M