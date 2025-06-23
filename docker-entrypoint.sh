#!/bin/sh
set -e

NGINX_PORT="${NGINX_PORT:-80}"

# 替换端口变量，生成最终虚拟主机配置
envsubst '${NGINX_PORT}' < /nginx.vh.default.conf > /opt/openresty/nginx/conf/nginx.conf

exec "$@"
