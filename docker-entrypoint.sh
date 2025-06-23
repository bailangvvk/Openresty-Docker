#!/bin/sh

# 默认端口 8080，如果 NGINX_PORT 被指定则使用
NGINX_PORT="${NGINX_PORT:-8080}"

# 替换端口变量并生成配置
envsubst '${NGINX_PORT}' < /nginx.template.conf > /opt/openresty/nginx/conf/nginx.conf

exec "$@"
