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

# 拔掉 /usr/bin 目录下的二进制执行文件
if [ -f /usr/bin/vaultwarden ]; then
    rm -f /usr/bin/vaultwarden
    echo "   - 已移除 /usr/bin/vaultwarden"
fi

# 拔掉配置文件（这里面存着你的监听端口和密钥等环境参数）
if [ -f /etc/vaultwarden.env ]; then
    rm -f /etc/vaultwarden.env
    echo "   - 已移除 /etc/vaultwarden.env"
fi

# 拔掉前端网页包目录（保持干净）
if [ -d /var/lib/vaultwarden/web-vault ]; then
    rm -rf /var/lib/vaultwarden/web-vault
    echo "   - 已移除网页前端 (web-vault)"
fi

# 4. 交互式询问：是否删除核心密码数据（UserData）
# 这一步非常关键，防止误操作把好不容易存的密码给一锅端了
echo "-----------------------------------------"
while true; do
    read -p "⚠️ 是否删除核心密码数据库与所有用户数据? (无法恢复!) [y/N]: " CHOOSE
    # 默认敲回车代表不删除（N），确保绝对安全
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

# 5. 抹除专门创建的系统独立用户
if id -u vaultwarden >/dev/null 2>&1; then
    echo "👤 正在抹除系统独立账户 (vaultwarden)..."
    userdel vaultwarden || echo "⚠️ 提示: 用户可能因某些残留目录未直接删净，已剥离其权限。"
fi

# 6. 最终彻底检查收尾
# 如果刚才用户选择了不删数据，那么只清理掉空余的外层壳子
if [ -d /var/lib/vaultwarden ]; then
    # 检查里面是不是只剩下了 data 目录，如果是，说明数据被保留了
    if [ "$(ls -A /var/lib/vaultwarden 2>/dev/null)" = "data" ]; then
        echo "📂 提示：外层工作区已洗净，仅留存了 data 备份资产。"
    else
        # 如果选了连数据一起删，那么整个大文件夹直接全部干掉
        rm -rf /var/lib/vaultwarden
    fi
fi

echo "========================================="
echo "        🎉 Vaultwarden 已完全从系统中卸载！     "
echo "========================================="