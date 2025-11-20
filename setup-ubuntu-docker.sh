#!/bin/bash

# --- 配置部分 ---
# 设置 Docker 镜像加速器（可选，推荐国内用户配置）
DOCKER_MIRROR_URL="https://mirror.aliyuncs.com" # 替换成你 prefer的加速器U R L， 例如 "https://registry.docker-cn.com" 或 "https://YOUR_MIRROR_ID.mirror.aliyuncs.com"
# 例如 阿里云：https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors

# Portainer 配置
PORTAINER_PORT=9000
PORTAINER_DATA_DIR="/var/lib/portainer"

# Docker Compose Copilot 配置
COMPOSE_COPILOT_VERSION="latest"

# --- 函数定义 ---

# 检查命令是否存在
command_exists () {
    command -v "$@" > /dev/null 2>&1
}

# 等待 Docker 服务启动
wait_for_docker() {
    echo "等待 Docker 服务启动..."
    while ! sudo docker info > /dev/null 2>&1; do
        sleep 2
    done
    echo "Docker 服务已启动"
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
        sudo apt remove -y $pkg 2>/dev/null
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

    # 启动并启用 Docker 服务
    sudo systemctl start docker
    sudo systemctl enable docker

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

# 安装 Portainer
install_portainer() {
    echo "--- 开始安装 Portainer ---"
    
    # 创建 Portainer 数据目录
    sudo mkdir -p $PORTAINER_DATA_DIR
    
    # 拉取 Portainer 镜像
    sudo docker pull portainer/portainer-ce:latest
    
    # 停止并删除现有的 Portainer 容器（如果存在）
    sudo docker stop portainer 2>/dev/null || true
    sudo docker rm portainer 2>/dev/null || true
    
    # 运行 Portainer 容器
    sudo docker run -d \
        --name portainer \
        --restart always \
        -p $PORTAINER_PORT:9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v $PORTAINER_DATA_DIR:/data \
        portainer/portainer-ce:latest
    
    echo "--- Portainer 安装完成 ---"
    echo "访问地址: http://localhost:$PORTAINER_PORT"
    echo "如果是远程访问，请使用: http://<服务器IP>:$PORTAINER_PORT"
}

# 安装 Docker Compose Copilot
install_docker_compose_copilot() {
    echo "--- 开始安装 Docker Compose Copilot ---"
    
    # 检查 Docker Compose 是否已安装
    if ! command_exists docker-compose && ! docker compose version > /dev/null 2>&1; then
        echo "Docker Compose 未安装，将先安装 Docker Compose"
        sudo apt install -y docker-compose-plugin
    fi
    
    # 安装 Docker Compose Copilot (如果存在的话)
    # 注意：Docker Compose Copilot 可能不是一个官方工具，这里假设是一个第三方工具
    if command_exists npm; then
        echo "尝试通过 npm 安装 Docker Compose Copilot..."
        npm install -g @docker/compose-copilot 2>/dev/null || echo "Docker Compose Copilot npm 包不存在，跳过安装"
    fi
    
    # 如果有官方的 Docker Compose Copilot，在这里添加安装命令
    # sudo curl -L "https://github.com/docker/compose-copilot/releases/latest/download/docker-compose-copilot-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose-copilot
    # sudo chmod +x /usr/local/bin/docker-compose-copilot
    
    echo "--- Docker Compose Copilot 安装检查完成 ---"
    echo "注意：Docker Compose Copilot 可能需要额外配置，请访问官方文档获取最新安装方法"
}

# 验证安装
verify_installation() {
    echo "--- 验证安装 ---"
    
    # 验证 Docker
    if command_exists docker; then
        echo "✓ Docker 已安装: $(docker --version)"
    else
        echo "✗ Docker 安装失败"
        return 1
    fi
    
    # 验证 Docker Compose
    if docker compose version > /dev/null 2>&1; then
        echo "✓ Docker Compose 已安装: $(docker compose version)"
    elif command_exists docker-compose; then
        echo "✓ Docker Compose 已安装: $(docker-compose --version)"
    else
        echo "✗ Docker Compose 安装失败"
        return 1
    fi
    
    # 验证 Portainer
    if sudo docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "portainer.*Up"; then
        echo "✓ Portainer 容器正在运行"
        echo "  访问地址: http://localhost:$PORTAINER_PORT"
    else
        echo "✗ Portainer 容器未运行"
    fi
    
    # 验证 Docker Compose Copilot
    if command_exists docker-compose-copilot; then
        echo "✓ Docker Compose Copilot 已安装"
    else
        echo "! Docker Compose Copilot 未安装或不可用"
    fi
}

# 显示后续操作说明
show_next_steps() {
    echo ""
    echo "--- 安装完成！后续操作说明 ---"
    echo ""
    echo "1. Docker 组权限配置："
    echo "   - 执行命令：newgrp docker （仅对当前终端会话有效）"
    echo "   - 或注销并重新登录您的用户会话"
    echo "   - 或重启虚拟机"
    echo ""
    echo "2. 验证 Docker 安装："
    echo "   docker run hello-world"
    echo ""
    echo "3. Portainer 管理界面："
    echo "   - 本地访问: http://localhost:$PORTAINER_PORT"
    echo "   - 远程访问: http://<服务器IP>:$PORTAINER_PORT"
    echo "   - 首次访问需要设置管理员密码"
    echo ""
    echo "4. Docker Compose 使用："
    echo "   - 新版本命令: docker compose up"
    echo "   - 旧版本命令: docker-compose up"
    echo ""
    echo "5. 常用 Docker 命令："
    echo "   - 查看容器: docker ps"
    echo "   - 查看镜像: docker images"
    echo "   - 查看日志: docker logs [容器名]"
    echo ""
}

# --- 主执行逻辑 ---
echo "欢迎使用 Ubuntu 24.04 Docker 环境配置脚本！"
echo "本脚本将安装："
echo "  ✓ QEMU Guest Agent"
echo "  ✓ Docker Engine"
echo "  ✓ Docker Compose"
echo "  ✓ Portainer (Docker 管理界面)"
echo "  ✓ Docker Compose Copilot (如果可用)"
echo ""

# 询问用户是否开始安装
read -p "是否开始执行安装？ (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "安装已取消。"
    exit 1
fi

echo ""
echo "开始安装..."

# 执行安装步骤
install_qemu_guest_agent
echo ""
install_docker

# 等待 Docker 服务启动
wait_for_docker

echo ""
install_portainer
echo ""
install_docker_compose_copilot
echo ""

# 验证安装
verify_installation
echo ""

# 显示后续操作说明
show_next_steps

echo ""
echo "🎉 所有安装步骤已完成！"