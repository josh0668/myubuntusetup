#!/bin/bash

# Debian Portainer 权限问题修复脚本
# 解决 "点击 local 环境后变成 down" 的问题

echo "--- Portainer 权限问题修复脚本 ---"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

show_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查权限
check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        echo "此脚本需要 root 权限，请使用: sudo $0"
        exit 1
    fi
}

# 获取当前用户
get_current_user() {
    CURRENT_USER=${SUDO_USER:-$USER}
    show_info "当前用户: $CURRENT_USER"
}

# 修复 Docker Socket 权限（关键步骤）
fix_docker_socket_permissions() {
    show_step "修复 Docker Socket 权限..."
    
    DOCKER_SOCKET="/var/run/docker.sock"
    
    # 检查 Socket 文件
    if [ ! -S "$DOCKER_SOCKET" ]; then
        show_error "Docker Socket 不存在"
        return 1
    fi
    
    # 获取当前权限
    CURRENT_GROUP=$(stat -c '%G' "$DOCKER_SOCKET")
    CURRENT_PERM=$(stat -c '%a' "$DOCKER_SOCKET")
    
    show_info "当前 Socket 权限: $CURRENT_PERM, 组: $CURRENT_GROUP"
    
    # 修复权限
    show_info "修复 Docker Socket 权限..."
    
    # 1. 确保组是 docker
    chgrp docker "$DOCKER_SOCKET"
    
    # 2. 设置权限为 660 (用户+组读写，其他无权限)
    chmod 660 "$DOCKER_SOCKET"
    
    # 3. 验证修复
    NEW_GROUP=$(stat -c '%G' "$DOCKER_SOCKET")
    NEW_PERM=$(stat -c '%a' "$DOCKER_SOCKET")
    
    if [ "$NEW_GROUP" = "docker" ] && [ "$NEW_PERM" = "660" ]; then
        show_info "✓ Docker Socket 权限修复成功"
    else
        show_error "✗ Docker Socket 权限修复失败"
        return 1
    fi
}

# 确保用户在 docker 组
ensure_user_in_docker_group() {
    show_step "确保用户在 docker 组中..."
    
    if ! groups "$CURRENT_USER" | grep -q docker; then
        show_warning "用户 $CURRENT_USER 不在 docker 组中"
        usermod -aG docker "$CURRENT_USER"
        show_info "✓ 已将用户 $CURRENT_USER 添加到 docker 组"
        show_warning "需要执行 'newgrp docker' 或重新登录才能生效"
    else
        show_info "✓ 用户 $CURRENT_USER 已在 docker 组中"
    fi
}

# 使用 root 权限重建 Portainer（关键修复）
rebuild_portainer_with_root() {
    show_step "使用 root 权限重建 Portainer..."
    
    # 停止并删除现有容器
    if docker ps -q -f name=portainer | grep -q .; then
        docker stop portainer
        show_info "✓ 已停止 Portainer 容器"
    fi
    
    if docker ps -aq -f name=portainer | grep -q .; then
        docker rm portainer
        show_info "✓ 已删除 Portainer 容器"
    fi
    
    # 确保数据目录权限正确
    DATA_DIR="/var/lib/portainer"
    mkdir -p "$DATA_DIR"
    chown -R root:root "$DATA_DIR"
    chmod -R 755 "$DATA_DIR"
    
    # 使用 root 权限启动（关键修复点）
    show_info "以 root 权限启动 Portainer 容器..."
    docker run -d \
        --name portainer \
        --restart always \
        -p 9000:9000 \
        -p 8000:8000 \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -v "$DATA_DIR:/data" \
        --user root \
        --privileged=false \
        portainer/portainer-ce:latest
    
    if [ $? -eq 0 ]; then
        show_info "✓ Portainer 容器启动成功（root 权限）"
    else
        show_error "✗ Portainer 容器启动失败"
        return 1
    fi
}

# 备用方案：使用特权模式
rebuild_portainer_privileged() {
    show_step "尝试特权模式（备用方案）..."
    
    # 停止现有容器
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
    
    # 使用特权模式启动
    docker run -d \
        --name portainer-privileged \
        --restart always \
        -p 9001:9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /var/lib/portainer:/data \
        --privileged \
        portainer/portainer-ce:latest
    
    if [ $? -eq 0 ]; then
        show_info "✓ Portainer 特权模式启动成功"
        show_warning "访问地址: http://192.168.1.107:9001"
    else
        show_error "✗ 特权模式启动失败"
    fi
}

# 设置权限持久化
make_permissions_persistent() {
    show_step "设置权限持久化..."
    
    # 创建 systemd 服务来修复权限
    cat > /etc/systemd/system/fix-docker-permissions.service << 'EOF'
[Unit]
Description=Fix Docker Socket Permissions
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/bin/chmod 660 /var/run/docker.sock
ExecStart=/bin/chgrp docker /var/run/docker.sock

[Install]
WantedBy=multi-user.target
EOF

    # 启用服务
    systemctl daemon-reload
    systemctl enable fix-docker-permissions.service
    systemctl start fix-docker-permissions.service
    
    show_info "✓ 权限持久化服务已创建"
}

# 验证修复效果
verify_fix() {
    show_step "验证修复效果..."
    
    # 等待容器启动
    show_info "等待 Portainer 完全启动..."
    sleep 15
    
    # 检查容器状态
    CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' portainer 2>/dev/null)
    if [ "$CONTAINER_STATUS" = "running" ]; then
        show_info "✓ Portainer 容器正在运行"
    else
        show_error "✗ Portainer 容器状态异常: $CONTAINER_STATUS"
        return 1
    fi
    
    # 测试容器内 Docker 权限（关键测试）
    if docker exec portainer docker ps >/dev/null 2>&1; then
        show_info "✓ Portainer 可以正常执行 Docker 命令"
    else
        show_error "✗ Portainer 无法执行 Docker 命令"
        show_error "这是导致点击后断开的根本原因"
        return 1
    fi
    
    # 测试 Docker 信息获取
    if docker exec portainer docker info >/dev/null 2>&1; then
        show_info "✓ Portainer 可以获取 Docker 信息"
    else
        show_warning "Portainer 获取 Docker 信息可能有限制"
    fi
}

# 显示使用指南
show_usage_guide() {
    echo ""
    echo "=================================================="
    show_info "Portainer 权限问题修复完成！"
    echo ""
    echo "🌐 访问地址:"
    echo "  http://192.168.1.107:9000"
    echo ""
    echo "🔧 修复要点:"
    echo "  1. 使用 root 权限运行 Portainer"
    echo "  2. Docker Socket 权限设置为 660"
    echo "  3. 确保用户在 docker 组中"
    echo ""
    echo "⚠️  测试步骤:"
    echo "  1. 打开 http://192.168.1.107:9000"
    echo "  2. 看到 local 环境显示 up"
    echo "  3. 点击进入 local 环境"
    echo "  4. 现在应该可以正常访问了"
    echo ""
    echo "🔄 如果仍有问题:"
    echo "  1. 清除浏览器缓存"
    echo "  2. 重新加载页面"
    echo "  3. 检查容器日志: docker logs portainer"
    echo "  4. 尝试特权模式: http://192.168.1.107:9001"
    echo ""
    echo "📞 权限验证命令:"
    echo "  验证权限: docker exec portainer docker ps"
    echo "  查看日志: docker logs portainer"
    echo "=================================================="
}

# 主执行逻辑
show_info "开始修复 Portainer 权限问题..."

# 检查权限
check_permissions

# 获取用户信息
get_current_user

# 执行修复步骤
fix_docker_socket_permissions || exit 1
ensure_user_in_docker_group
rebuild_portainer_with_root || exit 1
make_permissions_persistent

# 验证修复
verify_fix

# 显示使用指南
show_usage_guide

echo ""
show_info "权限修复完成！请测试点击 local 环境是否正常工作。"