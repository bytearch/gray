OPENRESTY_HOME ?= /usr/local/openresty
.PHONY: install test
test:
	@mkdir -p ${OPENRESTY_HOME}/nginx/conf/servers
	@cp  ./conf/*.conf ${OPENRESTY_HOME}/nginx/conf/servers/
	@echo "Successful! proxy.conf,test_new.conf,test_old.conf cp to ${OPENRESTY_HOME}/nginx/conf/servers/"
install:
	@mkdir -p ${OPENRESTY_HOME}/lualib/gray
	@cp ./lib/*.lua ${OPENRESTY_HOME}/lualib/gray/
	@echo "Successful! proxy.lua,config.lua cp to ${OPENRESTY_HOME}/lualib/gray/"
