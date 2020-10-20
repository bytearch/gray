local config = require("gray.config")
local Multipart = require("gray.multipart")


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


function read_from_file(file_name)
    local f = assert(io.open(file_name, "r"))
    local string = f:read("*all")
    f:close()
    return string
end




local function _checkOrgNo()
    local headers = ngx.req.get_headers()
    local gray_org_no_list = config['gray_org_no_list']
    local request_org_no = headers["orgCode"] or headers["ORGCODE"] or headers["orgcode"]

--   for k, v in pairs(headers) do
--        ngx.log(ngx.ERR, "Got header "..k..": "..v..";")
--    end

    --前端从cookie取orgCode
    if request_org_no== nil then
        local cookie_orgCode = ngx.var.cookie_orgCode or ngx.var.cookie_orgcode
        request_org_no = cookie_orgCode
    end

    --dfs上传需要根据body判断,针对普通的appId(获取body性能低，未来优化)
    if request_org_no== nil then
        ngx.req.read_body()
        local body,err = ngx.req.get_post_args(10)
        if body ~= nil then
            request_org_no= body["appId"] or  body["appid"]  or  body["Appid"]
        end
    end

    --dfs上传需要根据body判断,针对Multipart里带的appId (获取body性能低，未来优化)
    if request_org_no== nil then
        local body = ngx.req.get_body_data()
        if body == nil then
            --这里返回的是文件路径，需要读取文件内容
            local body_file = ngx.req.get_body_file()
            body = read_from_file(body_file)
        end
        local content_types = headers["Content-Type"]

        --ngx.log(ngx.INFO, "body:"..body.." ")
        ngx.log(ngx.INFO, "content-type:"..content_types.." ")

        -- Initialize with a body
        local multipart_data = Multipart(body,content_types)
        if multipart_data ~= nil then

            -- Get a multipart/form-data representation of the object
            --local bodyString = multipart_data:tostring()
            --ngx.log(ngx.INFO, "multipart_data body string: "..bodyString.."")

            -- Get all the parameters in a Lua table, in the form of {param_name = param_value}
            --local t = multipart_data:get_all()
            --for key, value in pairs(t) do
            --     ngx.log(ngx.INFO, "multipart_data: "..key..": "..value..";")
            --end

            -- Reading parameters
            local parameter = multipart_data:get("appId")
            ngx.log(ngx.INFO, "appId.value:"..parameter.value.." ")

            if parameter ~= nil then
                request_org_no= parameter.value
            end
        end
    end

    --判断是否符合配置
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
--    ngx.log(ngx.ERR, "proxy_sys_level 0 ")

    if _checkWhiteReq() == true then
        return new_upstream
    end
    -- write first
    if _isProxyNewMust() == true then
        return new_upstream
    end
    local uri = _getRequestUri()
    -- proxy cantain uri
--    ngx.log(ngx.ERR, "uri:"..uri.." ")
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
    ngx.header['backend-host']=upstream
    ngx.var.backend = upstream
    ngx.log(ngx.INFO, "backend-host:"..ngx.var.backend.." ")
end
return _M
