#!/bin/bash
set -e

# ====== 基础配置（已为您完全硬编码锁定仓库） ======
GITHUB_USER="yunbian3"
REPO_NAME="vaultwarden-bare-metal"
DOWNLOAD_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}/releases/latest/download/vaultwarden-linux-amd64.tar.gz"

echo "========================================="
echo "  Vaultwarden 裸机一键安装/升级脚本 (amd64)  "
echo "========================================="

# 1. 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 root 用户或 sudo 运行此脚本！"
    exit 1
fi

# 2. 安装必要的基础依赖
if ! command -v wget >/dev/null 2>&1; then
    echo "📦 正在安装必备组件 wget..."
    apt-get update && apt-get install -y wget
fi

# 3. 停止现有服务（如果是升级）
if systemctl is-active --quiet vaultwarden; then
    echo "🔄 发现正在运行的 Vaultwarden 服务，正在停止以准备升级..."
    systemctl stop vaultwarden
fi

# 4. 创建必要目录与独立系统用户
echo "📂 正在准备系统环境..."
mkdir -p /var/lib/vaultwarden/data
if ! id -u vaultwarden >/dev/null 2>&1; then
    useradd -m -d /var/lib/vaultwarden -s /usr/sbin/nologin vaultwarden
fi

# 5. 下载并解压 GitHub Actions 刚刚打好的最新包
echo "📥 正在从你的 GitHub 获取最新的裸机打包文件..."
echo "🔗 URL: $DOWNLOAD_URL"
rm -f /tmp/vaultwarden-linux-amd64.tar.gz
wget -O /tmp/vaultwarden-linux-amd64.tar.gz "$DOWNLOAD_URL"

echo "📦 正在解压并部署到核心目录..."
mkdir -p /tmp/vw_extract
tar -xzvf /tmp/vaultwarden-linux-amd64.tar.gz -C /tmp/vw_extract/

# 移动二进制文件到标准系统执行路径
mv -f /tmp/vw_extract/vaultwarden /usr/bin/vaultwarden
chmod +x /usr/bin/vaultwarden

# 移动网页端静态文件到数据目录
rm -rf /var/lib/vaultwarden/web-vault
mv -f /tmp/vw_extract/web-vault /var/lib/vaultwarden/web-vault

# 清理解压残留
rm -rf /tmp/vw_extract /tmp/vaultwarden-linux-amd64.tar.gz

# 6. 修正目录归属权限
echo "🔑 正在配置权限大印..."
chown -R vaultwarden:vaultwarden /var/lib/vaultwarden

# 7. 配置环境变量（处理端口自定义与安全防覆盖逻辑）
if [ ! -f /etc/vaultwarden.env ]; then
    echo "📝 检测到全新安装，进入参数配置阶段："
    
    # 交互式端口获取
    while true; do
        # 👈 核心修正：在这里加入了 </dev/tty，防止管道流传递时直接跳过
        read -p "请输入 Vaultwarden 监听端口 [默认: 8080]: " INPUT_PORT </dev/tty
        # 如果直接敲回车，采用默认端口 8080
        [ -z "$INPUT_PORT" ] && INPUT_PORT=8080
        
        # 防呆测试：必须是纯数字，且在 1-65535 范围内
        if [[ "$INPUT_PORT" =~ ^[0-9]+$ ]] && [ "$INPUT_PORT" -ge 1 ] && [ "$INPUT_PORT" -le 65535 ]; then
            VW_PORT=$INPUT_PORT
            break
        else
            echo "❌ 输入错误！请输入 1 至 65535 之间的合法数字。"
        fi
    done
    
    echo "✅ 已选择端口：$VW_PORT"
    echo "📝 正在初始化 /etc/vaultwarden.env 配置文件..."
    cat <<EOF > /etc/vaultwarden.env
# Vaultwarden 环境变量配置
ROCKET_ADDRESS=127.0.0.1
ROCKET_PORT=$VW_PORT
DATA_FOLDER=/var/lib/vaultwarden/data
WEB_VAULT_FOLDER=/var/lib/vaultwarden/web-vault
WEB_VAULT_ENABLED=true
EOF
    chown vaultwarden:vaultwarden /etc/vaultwarden.env
    chmod 600 /etc/vaultwarden.env
else
    # 升级逻辑：直接读取原先配好的端口，静默升级
    CURRENT_PORT=$(grep -oP '^ROCKET_PORT=\K\d+' /etc/vaultwarden.env || echo "8080")
    echo "🔄 检测到已有配置文件，将继续沿用原配置端口: $CURRENT_PORT"
fi

# 8. 配置 systemd 服务（如果不存在则创建）
if [ ! -f /etc/systemd/system/vaultwarden.service ]; then
    echo "⚙️ 正在注册 systemd 系统服务..."
    cat <<EOF > /etc/systemd/system/vaultwarden.service
[Unit]
Description=Vaultwarden Server (No Docker)
After=network.target

[Service]
User=vaultwarden
Group=vaultwarden
EnvironmentFile=/etc/vaultwarden.env
ExecStart=/usr/bin/vaultwarden
Restart=always
RestartSec=10

# 生产环境安全沙箱限制
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable vaultwarden
fi

# 9. 启动服务并检查状态
echo "🚀 正在启动 Vaultwarden..."
systemctl start vaultwarden

sleep 1
# 动态抓取最终运行的端口供前端回显显示
FINAL_PORT=$(grep -oP '^ROCKET_PORT=\K\d+' /etc/vaultwarden.env || echo "8080")

if systemctl is-active --quiet vaultwarden; then
    echo "========================================="
    echo "      🎉 Vaultwarden 部署/升级成功！     "
    echo "       内部监听: http://127.0.0.1:$FINAL_PORT   "
    echo "========================================="
else
    echo "❌ 启动失败，请运行 'journalctl -u vaultwarden -n 50' 查看错误日志。"
fi