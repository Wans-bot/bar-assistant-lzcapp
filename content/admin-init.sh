#!/bin/sh
# bar-assistant 首次初始化（幂等）：用部署参数里的管理员邮箱 / 显示名 / 密码，
# 通过应用自己的 REST 接口 POST /api/auth/register 建立账号。
#
# 为什么放在容器里做：镜像自带的注册接口是开放的（ALLOW_REGISTRATION=true），
# 但没有任何环境变量能「预建管理员」；用户装完若不注册就进不去，不符合开箱即用。
# 这个一次性脚本等接口就绪后调一次 register：
#   - HTTP 201 = 刚建号，成功；
#   - HTTP 422 "The email has already been taken" = 账号已存在（重装 / 重启），同样算完成；
# 两种都视为成功，所以整个步骤可重复执行。
#
# 凭据由 lzc-manifest.yml 渲染成环境变量（与浏览器 inject 用的是同一组模板表达式），
# 保证「这里建的密码」==「登录页自动填充的密码」。
set -u

API="http://bar-assistant:8080/api"
EMAIL="${LZC_ADMIN_EMAIL:-}"
PASSWORD="${LZC_ADMIN_PASSWORD:-}"
NAME="${LZC_ADMIN_NAME:-Bar Admin}"

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
  echo "lazycat: 缺少管理员邮箱或密码（部署参数未注入），跳过首次初始化" >&2
  while true; do sleep 3600; done
fi

# 等 bar-assistant 的 HTTP 接口就绪（容器 depends_on 只保证进程起来，不保证迁移完成）。
i=0
while [ "$i" -lt 180 ]; do
  if curl -fsS -o /dev/null --max-time 5 "$API/auth/sso/providers" 2>/dev/null; then
    break
  fi
  i=$((i + 1))
  sleep 5
done

# 用 PHP 的 json_encode 生成请求体（正确转义引号 / 反斜杠 / 非 ASCII），避免手拼 JSON。
BODY=$(php -r 'echo json_encode(["email" => getenv("LZC_ADMIN_EMAIL"), "name" => getenv("LZC_ADMIN_NAME"), "password" => getenv("LZC_ADMIN_PASSWORD")], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);')
if [ -z "$BODY" ]; then
  echo "lazycat: 生成注册请求体失败" >&2
else
  CODE=$(curl -sS -o /tmp/ba-register.out -w '%{http_code}' --max-time 30 \
    -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' \
    --data-binary "$BODY" "$API/auth/register" 2>/dev/null || echo 000)
  echo "lazycat: POST /api/auth/register -> HTTP $CODE $(head -c 300 /tmp/ba-register.out 2>/dev/null)"
  case "$CODE" in
    201)
      echo "lazycat: 管理员账号已创建（$EMAIL）"
      ;;
    422)
      echo "lazycat: 管理员账号已存在，跳过（$EMAIL）"
      ;;
    *)
      echo "lazycat: 注册返回意外状态 $CODE，稍后重试" >&2
      ;;
  esac
fi

# depends_on 只保证容器能起来；保持常驻，避免反复重启（healthcheck 恒为 true）。
while true; do sleep 3600; done
