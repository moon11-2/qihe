# 契合后端

FastAPI 后端负责 AI 网关、文件处理、合同审查/生成结构化整理和 Word 导出。

## 本地启动

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -e ".[dev]"
uvicorn app.main:app --host 127.0.0.1 --port 8010 --reload
```

iOS shared Scheme 默认连接正式 HTTPS 后端。本地联调时可临时覆盖 `QIHE_API_BASE_URL=http://127.0.0.1:8010`；为避免本机其他 uvicorn/FastAPI 服务占用 8000，联调时请显式使用 8010。

如果仓库位于 Documents、iCloud Drive 或其他同步目录，推荐把虚拟环境放到 `/tmp`，避免同步机制损坏 `.venv` 或 `egg-info`：

```bash
python3 -m venv /tmp/qihe-backend-venv
source /tmp/qihe-backend-venv/bin/activate
python -m pip install -U pip
python -m pip install -e ".[dev]"
python -m pytest
uvicorn app.main:app --host 127.0.0.1 --port 8010
```

## 接口

- `GET /api/health`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/chat`
- `POST /api/files/upload`
- `POST /api/contracts/run`
- `POST /api/contracts/export/word`

当前接口已具备 MVP 契约能力：聊天、合同审查、合同生成、文件上传解析和 Word 导出均有基础实现与测试覆盖；真实 AI 网关和更完整的合同规则可按开发文档继续增强。

认证接口是可选登录能力，不会拦截现有聊天、审查、生成、上传和导出流程。未登录用户仍可使用核心合同能力。

### 认证接口

`POST /api/auth/register`

请求：

```json
{"email":"user@example.com","password":"至少 8 位密码","display_name":"可选昵称"}
```

响应：

```json
{
  "access_token": "<bearer-token>",
  "token_type": "bearer",
  "expires_in": 604800,
  "user": {
    "id": 1,
    "email": "user@example.com",
    "display_name": "可选昵称",
    "created_at": "2026-07-05T00:00:00Z"
  }
}
```

`POST /api/auth/login` 使用 `email` 和 `password`，响应结构与注册一致。

`GET /api/auth/me` 需要请求头：

```http
Authorization: Bearer <access_token>
```

错误统一返回：

```json
{"error":{"code":"invalid_credentials","message":"邮箱或密码不正确"}}
```

常见错误码：`email_already_registered`、`invalid_credentials`、`auth_required`、`invalid_token`、`token_expired`、`auth_not_configured`、`validation_error`。

## 服务器部署

生产环境建议让 FastAPI 只监听本机 `127.0.0.1:8010`，由 nginx 对公网暴露 `https://api.qihe1.xyz/api/...`。客户端和外部调用方不要直连 `:8010`，避免绕过反代层、日志策略和后续 TLS/限流配置。

当前服务器部署约定代码目录为 `/opt/qihe`，后端目录为 `/opt/qihe/backend`，systemd 服务名为 `qihe-backend`。如果新服务器路径不同，替换路径即可。

### 环境变量

生产环境建议使用 `/etc/qihe/backend.env`，只在服务器本地填入真实密钥：

```bash
sudo install -d -m 700 /etc/qihe
sudo cp /opt/qihe/backend/.env.example /etc/qihe/backend.env
sudo chmod 600 /etc/qihe/backend.env
```

`.env` 示例字段如下，真实值不要提交到仓库，也不要贴到工单或聊天记录：

```dotenv
APP_ENV=production
API_PREFIX=/api

QWEN_API_KEY=replace-with-qwen-api-key
QWEN_API_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
QWEN_MODEL=qwen-plus

DIFY_API_KEY=replace-with-dify-api-key-if-used
DIFY_API_BASE_URL=https://api.dify.ai/v1

MAX_UPLOAD_MB=20

AUTH_DB_PATH=/var/lib/qihe/auth.sqlite3
JWT_SECRET=replace-with-random-secret
JWT_EXPIRES_MINUTES=10080
```

`JWT_SECRET` 必须在生产环境配置为随机长字符串。`AUTH_DB_PATH` 指向 SQLite 文件；确保 systemd 运行用户对目录有读写权限。

### 安装依赖

```bash
cd /opt/qihe/backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -U pip
python -m pip install -e .
```

### systemd

创建 `/etc/systemd/system/qihe-backend.service`：

```ini
[Unit]
Description=Qihe FastAPI backend
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/qihe/backend
EnvironmentFile=/etc/qihe/backend.env
ExecStart=/opt/qihe/backend/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8010
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

启用并启动：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now qihe-backend
sudo systemctl status qihe-backend --no-pager
```

### nginx

nginx 只反代 `/api/` 到本机服务端口。正式域名的 HTTP 入口应跳转到 HTTPS：

```nginx
server {
    listen 80;
    server_name api.qihe1.xyz;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.qihe1.xyz;

    ssl_certificate /etc/letsencrypt/live/api.qihe1.xyz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.qihe1.xyz/privkey.pem;

    client_max_body_size 25m;

    location /api/ {
        proxy_pass http://127.0.0.1:8010/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    location / {
        return 404;
    }
}
```

检查并重载 nginx：

```bash
sudo nginx -t
sudo systemctl reload nginx
```

如启用云防火墙或 UFW，只需要开放 80/443 给公网；`8010` 不应对公网开放。

### 正式 HTTPS 上线

iOS 正式环境不能依赖公网 HTTP，也不能依赖 `https://<ip>` 加 `-k` 这类跳过证书校验的方式。IP 访问如果证书 SAN 不包含该 IP，ATS 和标准 TLS 校验都会失败。正式上线需要一个 API 域名和匹配证书。

当前正式 API 域名是 `api.qihe1.xyz`，DNS A 记录指向服务器公网 IP。新环境上线时，用户或运维需要先提供：

- API 域名，例如 `api.qihe1.xyz`。
- DNS 管理权限，将该域名的 A 记录指向服务器公网 IP。
- 服务器 SSH/sudo 权限。
- 云安全组或防火墙权限：公网开放 80/443，不开放 8010。
- Let's Encrypt 注册邮箱，或等价证书平台权限。

DNS 验证：

```bash
dig +short A api.qihe1.xyz
dig +short A api.qihe1.xyz @1.1.1.1
```

nginx HTTP 预配置：

```nginx
server {
    listen 80;
    server_name api.qihe1.xyz;

    client_max_body_size 25m;

    location /api/ {
        proxy_pass http://127.0.0.1:8010/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    location / {
        return 404;
    }
}
```

签发证书：

```bash
sudo certbot --nginx -d api.qihe1.xyz
sudo certbot renew --dry-run
```

最终 nginx 应等价于：

```nginx
server {
    listen 80;
    server_name api.qihe1.xyz;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.qihe1.xyz;

    ssl_certificate /etc/letsencrypt/live/api.qihe1.xyz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.qihe1.xyz/privkey.pem;

    client_max_body_size 25m;

    location /api/ {
        proxy_pass http://127.0.0.1:8010/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    location / {
        return 404;
    }
}
```

上线验证：

```bash
sudo nginx -t
sudo systemctl reload nginx
curl -I http://api.qihe1.xyz/api/health
curl -fsS https://api.qihe1.xyz/api/health
openssl s_client -connect api.qihe1.xyz:443 -servername api.qihe1.xyz </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

原生 iOS App 调 API 不需要 CORS。若后续有 Web 前端跨域访问，再增加显式 origin allowlist，不要在生产用 `*` 搭配 `Authorization`。

Release iOS 的 API base URL 应设置为 `https://api.qihe1.xyz`，不要附带 `/api`，因为客户端请求路径已经包含 `/api/...`。

### 更新代码与重启

```bash
cd /opt/qihe
git pull --ff-only
cd backend
source .venv/bin/activate
python -m pip install -e .
python -m pytest
sudo systemctl restart qihe-backend
```

重启后先查本机，再查公网：

```bash
curl -fsS http://127.0.0.1:8010/api/health
curl -fsS https://api.qihe1.xyz/api/health
```

期望响应：

```json
{"status":"ok","service":"qihe-backend"}
```

### 日志与排障

```bash
sudo journalctl -u qihe-backend -n 100 --no-pager
sudo journalctl -u qihe-backend -f
sudo tail -n 100 /var/log/nginx/access.log
sudo tail -n 100 /var/log/nginx/error.log
```

常见检查点：

- `systemctl status qihe-backend` 确认服务是否运行。
- `curl http://127.0.0.1:8010/api/health` 确认 FastAPI 本机可用。
- `nginx -t` 确认 nginx 配置语法正确。
- `curl https://api.qihe1.xyz/api/health` 确认公网 HTTPS API 可用。
- 云安全组、防火墙不要放行公网 `8010`。
