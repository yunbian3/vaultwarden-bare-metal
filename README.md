# Vaultwarden Bare Metal (linux-amd64)

[![Auto Extract Vaultwarden Binary](https://github.com/yunbian3/vaultwarden-bare-metal/actions/workflows/sync-and-build.yml/badge.svg)](https://github.com/yunbian3/vaultwarden-bare-metal/actions/workflows/sync-and-build.yml)
[![GitHub Release](https://img.shields.io/github/v/release/yunbian3/vaultwarden-bare-metal?color=blue&logo=github)](https://github.com/yunbian3/vaultwarden-bare-metal/releases/latest)

这是一个通过 **GitHub Actions 自动化流水线** 实现的 Vaultwarden 裸机资产提取与一键部署项目。
---
由于 Vaultwarden 官方和社区默认**只发布 Docker 镜像，不直接提供预编译的二进制文件**，本项目利用 CI/CD 技术，每天定时从官方最新的 `alpine` 镜像中，逆向提取出采用**静态链接（Static Linking）**的纯净单文件二进制（Bare Metal Binary）以及前端网页包（`web-vault`），并按照标准的 Linux 服务规范提供一键安装与平滑升级脚本。

---
## ✨ 项目亮点
* **极致轻量：** 拒绝 Docker 容器宿主机的额外内存与 CPU 开销，纯原生单文件运行，内存占用仅 10M~20M 左右，极其适合精简版 Debian/Ubuntu 弱鸡服务器（VPS）。
* **自动化同步：** 每天北京时间上午 10:00 自动刺探官方 Alpine 镜像的心脏，提取最新稳定版（带哨兵异常兜底机制），确保你用的永远是最新版。
* **自选监听端口：** 一键脚本在全新安装时提供交互式输入，允许自由定义 ROCKET_PORT 端口，并自带数字防呆校验。
* **安全平滑升级：** 再次运行安装脚本时，会自动读取并沿用你原先在 `/etc/vaultwarden.env` 里配置好的所有参数和端口，静默覆盖升级，绝不破坏核心数据库。
* **独立权限隔离：** 脚本不使用 `root` 用户直接运行主程序，而是自动创建专属的 `vaultwarden:vaultwarden` 系统安全账户进行沙箱隔离。
---
## 🚀 快速一键部署
在你的 Debian / Ubuntu 裸机服务器上，直接复制并运行以下命令。

> **💡 贴心提示：** > 1. 如果你在国内服务器运行，建议先配置好你的终端系统代理，并在 `sudo` 后面加上 `-E` 参数来继承代理变量。
> 2. 脚本会自动为你检测并用 `apt` 补全 `wget` 依赖。
---
Install：

```bash
curl -Ls https://raw.githubusercontent.com/yunbian3/vaultwarden-bare-metal/main/install.sh | sudo -E bash
```

## 📝 全新安装时的交互流程：
脚本会自动准备 /var/lib/vaultwarden 系统环境。

停留在终端等待你的键盘响应：请输入 Vaultwarden 监听端口 [默认: 8080]: 。

输入你心仪的内部端口后，脚本将自动配置 /etc/vaultwarden.env 环境文件，并注册 systemd 系统服务。

部署成功后，你只需要用 Nginx / Caddy 对该端口进行反向代理并配置好 SSL 证书，即可完美畅玩。


## 🔄 一键平滑升级
当本仓库的 Releases 页面跟随官方发布了更高版本的 Tag 时，你无需手动下载。再次无脑执行上方的安装命令即可：

```Bash
curl -Ls https://raw.githubusercontent.com/yunbian3/vaultwarden-bare-metal/main/install.sh | sudo -E bash
```
脚本会智能识别到已有配置，打印出：🔄 检测到已有配置文件，将继续沿用原配置端口: XXXX，并在 3 秒内完成核心文件替换与服务重启。

## ⚠️ 卸载时的安全守则：
卸载中途会强行拦截终端，弹出灵魂拷问：
⚠️ 是否删除核心密码数据库与所有用户数据? (无法恢复!) [y/N]: 

直接敲回车（或输入 N）： 卸载主程序、注销系统服务、抹除系统账户，但会把你的核心密码数据库（SQLite）完好无损地保留在 /var/lib/vaultwarden/data 中，方便你打包带走。

输入 Y： 彻底物理粉碎所有数据，不留一点痕迹。


uninstall:

```bash
curl -Ls https://raw.githubusercontent.com/yunbian3/vaultwarden-bare-metal/main/uninstall.sh | sudo -E bash
```


## 📂 系统文件结构规范
一键部署成功后，系统内的核心资产分布如下：

```
Plaintext
├── /usr/bin/vaultwarden           # 核心二进制主程序
├── /etc/vaultwarden.env           # 环境参数配置文件 (端口、密钥、数据库路径)
├── /etc/systemd/system/vaultwarden.service  # systemd 系统服务定义文件
└── /var/lib/vaultwarden/          # 核心工作区大本营
    ├── web-vault/                 # 前端网页静态资产包
    └── data/                      # 🔒 你的核心密码数据库 (请务必定期备份此目录！)

```
## 🛡️ 进阶：配置异地登录邮件报警 (SMTP)
自建密码库后，如果需要开启新设备或异地登录邮件提醒，可以编辑你的配置文件：

```Bash
sudo nano /etc/vaultwarden.env
```
在末尾追加你的邮箱 SMTP 授权码参数（以 QQ 邮箱为例）：
```bash
Ini, TOML
SMTP_HOST=smtp.qq.com
SMTP_PORT=465
SMTP_SECURITY=force_tls
SMTP_USERNAME=你的QQ号@qq.com
SMTP_PASSWORD=你的十几位纯字母邮箱授权码
SMTP_FROM=你的QQ号@qq.com
SMTP_FROM_NAME=Vaultwarden 密码库
保存退出后，运行 sudo systemctl restart vaultwarden 即可激活报警链路。
```
## ⚖️ 免责声明 (License)
本项目仅作为个人技术探索与自动化构建学术交流使用。
项目提取的二进制及网页端核心知识产权归 Vaultwarden 官方开源社区 所有。请确保不要将自建密码服务暴露在无 SSL 保护的公网环境中。

---

## 🛠️ Credits & Backstage

* **Core Upstream:** [dani-garcia/vaultwarden](https://github.com/dani-garcia/vaultwarden)
* **Automation Architect:** Powered with 💜 by **Gemini** (Your AI Collaborator)
