#!/bin/bash

# Portainer 修复脚本
# 解决 "The environment named local is unreachable" 问题

echo "--- Portainer 环境修复脚本 ---"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查命令是否存在
command_exists () {
    command -v "$@" > /dev/null 2>&1
}

# 显示带颜色的消息
show_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

show_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 修复 Docker 权限
fix_docker_permissions() {
    echo ""
    show_info "检查 Docker 权限..."
    
    # 检查当前用户是否在 docker 组中
    if groups $USER | grep -q docker; then
        show_info "用户已在 docker 组中"
    else
        show_warning "用户不在 docker 组中，正在添加..."
        sudo usermod -aG docker $USER
        echo "请执行 'newgrp docker' 或重新登录后再试"
    fi
    
    # 检查 docker.sock 权限
    if [ -S /var/run/docker.sock ]; then
        DOCKER_GROUP=$(stat -c '%G' /var/run/docker.sock)
        if groups $USER | grep -q "$DOCKER_GROUP"; then
            show_info "docker.sock 权限正常"
        else
            show_warning "docker.sock 权限异常，正在修复..."
            sudo chmod 666 /var/run/docker.sock
        fi
    else
        show_error "docker.sock 不存在"
        return 1
    fi
}

# 测试 Docker 连接
test_docker_connection() {
    echo ""
    show_info "测试 Docker 连接..."
    
    if docker ps > /dev/null 2>&1; then
        show_info "Docker 连接正常"
    else
        show_error "Docker 连接失败"
        echo "请检查 Docker 服务是否正常运行："
        echo "  sudo systemctl status docker"
        echo "  sudo systemctl start docker"
        return 1
    fi
}

# 重建 Portainer 容器
rebuild_portainer() {
    echo ""
    show_info "重建 Portainer 容器..."
    
    # 停止并删除现有容器
    show_info "停止现有 Portainer 容器..."
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
    
    # 清理可能存在的数据目录权限问题
    if [ -d /var/lib/portainer ]; then
        sudo chown -R $USER:$USER /var/lib/portainer 2>/dev/null || true
    fi
    
    # 重新创建数据目录
    sudo mkdir -p /var/lib/portainer
    sudo chown -R $USER:$USER /var/lib/portainer 2>/dev/null || true
    
    # 拉取最新镜像
    show_info "拉取最新 Portainer 镜像..."
    docker pull portainer/portainer-ce:latest
    
    # 运行新容器
    show_info "启动 Portainer 容器..."
    docker run -d \
        --name portainer \
        --restart always \
        -p 9000:9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /var/lib/portainer:/data \
        --network bridge \
        portainer/portainer-ce:latest
    
    if [ $? -eq 0 ]; then
        show_info "Portainer 容器启动成功"
    else
        show_error "Portainer 容器启动失败"
        return 1
    fi
}

# 验证修复结果
verify_fix() {
    echo ""
    show_info "验证修复结果..."
    
    # 等待容器启动
    sleep 10
    
    # 检查容器状态
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "portainer.*Up"; then
        show_info "✓ Portainer 容器正在运行"
    else
        show_error "✗ Portainer 容器未运行"
        echo "容器日志："
        docker logs portainer
        return 1
    fi
    
    # 检查端口
    if netstat -tlnp 2>/dev/null | grep -q ":9000" || ss -tlnp 2>/dev/null | grep -q ":9000"; then
        show_info "✓ 端口 9000 正在监听"
    else
        show_warning "端口 9000 未监听，请检查防火墙设置"
    fi
    
    # 测试 Docker 连接（通过容器）
    echo "测试 Portainer 与 Docker 的连接..."
    if docker exec portainer docker version > /dev/null 2>&1; then
        show_info "✓ Portainer 与 Docker 连接正常"
    else
        show_warning "Portainer 与 Docker 连接可能存在问题"
    fi
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "=================================="
    show_info "修复完成！访问信息："
    echo ""
    echo "  本地访问: http://localhost:9000"
    echo "  局域网访问: http://$(hostname -I | awk '{print $1}'):9000"
    echo ""
    echo "如果仍然显示 'environment local is unreachable'："
    echo "1. 请使用 'newgrp docker' 或重新登录"
    echo "2. 清除浏览器缓存并刷新页面"
    echo "3. 如果问题持续，查看容器日志：docker logs portainer"
    echo "=================================="
}

# 主执行逻辑
echo "开始修复 Portainer 环境问题..."

# 检查必要的命令
if ! command_exists docker; then
    show_error "Docker 未安装"
    exit 1
fi

# 执行修复步骤
fix_docker_permissions || show_warning "权限修复可能需要重新登录"

# 重新加载用户组权限（可选）
echo ""
read -p "是否现在重新加载用户组权限？这将使用 newgrp 命令 (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    show_info "重新加载用户组权限..."
    newgrp docker << 'EOF'
test_docker_connection && rebuild_portainer && verify_fix && show_access_info
EOF
else
    test_docker_connection
    rebuild_portainer
    verify_fix
    show_access_info
fi

echo ""
show_info "修复脚本执行完成！"