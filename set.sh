#!/bin/bash

# --- 配置部分 ---
# 设置 Docker 镜像加速器（可选，推荐国内用户配置）
DOCKER_MIRROR_URL="https://mirror.aliyuncs.com" # 替换成你 prefer的加速器U R L， 例如 "https://registry.docker-cn.com" 或 "https://YOUR_MIRROR_ID.mirror.aliyuncs.com"
# 例如 阿里云：https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors

# --- 函数定义 ---

# 检查命令是否存在
command_exists () {
    command -v "$@" > /dev/null 2>&1
}

# 安装 QEMU Guest Agent
install_qemu_guest_agent() {
    echo "--- 开始安装 QEMU Guest Agent ---"
    sudo apt update
    sudo apt install -y qemu-guest-agent
    sudo systemctl enable qemu-guest-agent
    sudo systemctl start qemu-guest-agent
    echo "--- QEMU Guest Agent 安装完成并已启动 ---"
}

# 安装 Docker
install_docker() {
    echo "--- 开始安装 Docker ---"

    # 卸载旧版本 Docker (如果存在)
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        sudo apt remove -y $pkg
    done

    # 添加 Docker 官方 GPG 密钥
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # 添加 Docker APT 仓库
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 安装 Docker Engine, containerd, 和 Docker Compose
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 将当前用户添加到 docker 用户组，这样可以不使用 sudo 运行 Docker 命令
    sudo usermod -aG docker $USER
    echo "当前用户 $USER 已添加到 docker 组，需要重新登录或重启才能生效。"

    # 配置 Docker 镜像加速器 (如果已设置 DOCKER_MIRROR_URL)
    if [ -n "$DOCKER_MIRROR_URL" ]; then
        echo "--- 配置 Docker 镜像加速器 ---"
        sudo mkdir -p /etc/docker
        sudo bash -c "cat > /etc/docker/daemon.json <<EOF
{
  \"registry-mirrors\": [\"$DOCKER_MIRROR_URL\"]
}
EOF"
        sudo systemctl daemon-reload
        sudo systemctl restart docker
        echo "Docker 镜像加速器已配置为: $DOCKER_MIRROR_URL"
    else
        echo "未配置 Docker 镜像加速器，如果在中国大陆使用，建议配置以提高下载速度。"
    fi

    echo "--- Docker 和 Docker Compose 安装完成 ---"
    echo "请执行 'newgrp docker' 或重新登录/重启系统，以使 docker 组权限生效。"
}

# --- 主执行逻辑 ---
echo "欢迎使用 Ubuntu 24.04 工作环境配置脚本！"
echo "本脚本将安装 QEMU Guest Agent, Docker Engine 和 Docker Compose。"

# 询问用户是否开始安装
read -p "是否开始执行安装？ (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "安装已取消。"
    exit 1
fi

install_qemu_guest_agent
install_docker

echo "--- 所有安装步骤已完成 ---"
echo "请注意：为了使 Docker 组权限和镜像加速器配置生效，您可能需要执行以下操作之一："
echo "1. 执行命令：newgrp docker （仅对当前终端会话有效）"
echo "2. 注销并重新登录您的用户会话。"
echo "3. 重启虚拟机。"
echo "在执行这些操作后，您应该可以运行 'docker run hello-world' 来验证 Docker 是否正常工作。"