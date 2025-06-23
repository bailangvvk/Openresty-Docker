#!/bin/sh

# 默认端口 80，如果环境变量有覆盖则用覆盖的
NGINX_PORT="${NGINX_PORT:-80}"

# 替换端口变量，生成最终配置
envsubst '${NGINX_PORT}' < /nginx.vh.default.conf > /usr/local/openresty/nginx/conf/nginx.conf

exec "$@"
