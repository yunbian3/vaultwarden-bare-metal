#!/bin/bash
set -e

echo "========================================="
echo "   Vaultwarden 裸机一键完全卸载脚本      "
echo "========================================="

# 1. 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 root 用户或 sudo 运行此脚本！"
    exit 1
fi

# 2. 停止并禁用 systemd 服务
echo "🔄 正在停止并注销 Vaultwarden 系统服务..."
if systemctl is-active --quiet vaultwarden; then
    systemctl stop vaultwarden
fi

if [ -f /etc/systemd/system/vaultwarden.service ]; then
    systemctl disable vaultwarden
    rm -f /etc/systemd/system/vaultwarden.service
    systemctl daemon-reload
    echo "✅ systemd 服务已彻底注销。"
fi

# 3. 清理核心程序与配置文件
echo "🗑️ 正在清理核心程序文件..."

if [ -f /usr/bin/vaultwarden ]; then
    rm -f /usr/bin/vaultwarden
    echo "   - 已移除 /usr/bin/vaultwarden"
fi

if [ -f /etc/vaultwarden.env ]; then
    rm -f /etc/vaultwarden.env
    echo "   - 已移除 /etc/vaultwarden.env"
fi

if [ -d /var/lib/vaultwarden/web-vault ]; then
    rm -rf /var/lib/vaultwarden/web-vault
    echo "   - 已移除网页前端 (web-vault)"
fi

# 4. 交互式询问：安全接管终端输入 </dev/tty
echo "-----------------------------------------"
while true; do
    # 👈 核心修正：加了 </dev/tty，强行等待你的键盘敲击
    read -p "⚠️ 是否删除核心密码数据库与所有用户数据? (无法恢复!) [y/N]: " CHOOSE </dev/tty
    [ -z "$CHOOSE" ] && CHOOSE="N"
    
    case "$CHOOSE" in
        [Yy])
            echo "💥 正在粉碎数据目录 /var/lib/vaultwarden/data ..."
            rm -rf /var/lib/vaultwarden/data
            echo "✅ 所有密码数据已彻底人间蒸发！"
            break
            ;;
        [Nn])
            echo "🔒 保持克制：您的核心密码数据目录已被完整保留在 /var/lib/vaultwarden/data"
            break
            ;;
        *)
            echo "❌ 输入错误，请输入 Y (是) 或 N (否)"
            ;;
    esac
done
echo "-----------------------------------------"

# 5. 抹除用户
if id -u vaultwarden >/dev/null 2>&1; then
    echo "👤 正在抹除系统独立账户 (vaultwarden)..."
    userdel vaultwarden || echo "⚠️ 提示: 用户可能因某些残留目录未直接删净，已剥离其权限。"
fi

if [ -d /var/lib/vaultwarden ]; then
    if [ "$(ls -A /var/lib/vaultwarden 2>/dev/null)" = "data" ]; then
        echo "📂 提示：外层工作区已洗净，仅留存了 data 备份资产。"
    else
        rm -rf /var/lib/vaultwarden
    fi
fi

echo "========================================="
echo "        🎉 Vaultwarden 已完全从系统中卸载！     "
echo "========================================="