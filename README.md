# VPS Manager

一个完整的 VPS 管理工具，包含 Go 服务端和 Flutter 安卓客户端。

## 功能

**服务端**
- 系统信息监控（CPU、内存、磁盘、网络、负载）
- 文件管理（根目录起，增删改查、上传下载）
- 文本编辑器
- 交互式终端（PTY，支持 vim/nano/htop）
- 进程管理（列表、kill）
- Token 认证
- 可选 HTTPS/TLS

**客户端（Android）**
- 多 VPS 管理，快速切换
- 实时系统仪表盘（含折线图）
- 文件管理器（根目录）
- 交互式终端
- 进程管理
- 暗色主题

---

## 服务端部署

### 1. 下载二进制

从 [Releases](../../releases) 下载对应架构的 `vps-agent-*`：

```bash
# x86_64 VPS
wget https://github.com/youruser/vps-manager/releases/latest/download/vps-agent-linux-amd64
chmod +x vps-agent-linux-amd64
mv vps-agent-linux-amd64 /usr/local/bin/vps-agent
```

### 2. 创建配置文件

```bash
mkdir -p /opt/vps-agent
cat > /opt/vps-agent/config.yaml << EOF
port: "8888"
token: "$(openssl rand -hex 32)"
tls:
  enabled: false
  cert: ""
  key: ""
EOF
```

**启用 HTTPS（使用 Let's Encrypt 证书）：**
```yaml
port: "443"
token: "your-strong-secret-token"
tls:
  enabled: true
  cert: "/etc/letsencrypt/live/yourdomain.com/fullchain.pem"
  key: "/etc/letsencrypt/live/yourdomain.com/privkey.pem"
```

### 3. 配置 systemd 服务

```bash
cp vps-agent.service /etc/systemd/system/
cp vps-agent /opt/vps-agent/
cp config.yaml /opt/vps-agent/

systemctl daemon-reload
systemctl enable vps-agent
systemctl start vps-agent
systemctl status vps-agent
```

### 4. 防火墙

```bash
# UFW
ufw allow 8888/tcp

# firewalld
firewall-cmd --permanent --add-port=8888/tcp
firewall-cmd --reload
```

---

## 客户端安装

从 [Releases](../../releases) 下载 APK：

| 文件 | 适用设备 |
|------|---------|
| `vps-manager-arm64.apk` | 大多数现代安卓手机（推荐）|
| `vps-manager-armv7.apk` | 旧款 32 位安卓 |
| `vps-manager-x86_64.apk` | 安卓模拟器 |

安装时需要开启「允许未知来源」。

---

## 客户端使用

1. 打开 App，点击右下角 **添加服务器**
2. 填写：
   - **名称**：自定义（如「美国 VPS」）
   - **主机**：IP 地址或域名
   - **端口**：与服务端 `port` 一致
   - **Token**：与服务端 `token` 一致
   - **TLS**：若服务端开启 HTTPS 则打开
3. 点击「测试连接」验证
4. 保存后点击服务器卡片连接

---

## 本地构建

### 服务端

```bash
cd server
go mod tidy
go build -o vps-agent .
./vps-agent -c config.yaml
```

### 客户端

```bash
cd client
flutter pub get
flutter build apk --release
# APK 在 build/app/outputs/flutter-apk/
```

### 触发 GitHub Actions 发布

```bash
git tag v1.0.0
git push origin v1.0.0
```

Actions 会自动编译并创建 Release，附上所有二进制文件和 APK。

---

## API 文档

所有请求需携带 Header：`X-Token: your-token`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/verify` | 验证 Token |
| GET | `/api/system/info` | 系统信息 |
| GET | `/api/system/processes` | 进程列表 |
| DELETE | `/api/system/processes/:pid` | Kill 进程 |
| GET | `/api/files?path=/` | 列目录 |
| GET | `/api/files/read?path=` | 读取文件内容 |
| POST | `/api/files/write` | 写入文件 |
| POST | `/api/files/upload` | 上传文件（multipart）|
| GET | `/api/files/download?path=` | 下载文件 |
| POST | `/api/files/mkdir` | 创建目录 |
| POST | `/api/files/rename` | 重命名 |
| DELETE | `/api/files` | 删除文件/目录 |
| POST | `/api/files/touch` | 创建空文件 |
| WS | `/ws/terminal?token=` | PTY 终端 |

---

## 安全建议

- 使用强随机 Token：`openssl rand -hex 32`
- 生产环境务必启用 TLS
- 服务端以 root 运行，请确保 Token 保密
- 可在 VPS 防火墙限制访问 IP
