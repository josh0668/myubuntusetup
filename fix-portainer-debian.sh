#!/bin/bash

# Debian 12.04 虚拟机 Portainer 修复脚本
# 专门解决 "The environment named local is unreachable" 问题

echo "--- Debian 12.04 虚拟机 Portainer 修复脚本 ---"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检查是否为 root 或有 sudo 权限
check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        echo "此脚本需要 root 权限运行，请使用: sudo $0"
        exit 1
    fi
    show_info "✓ 具有管理员权限"
}

# 诊断 Docker 服务状态
diagnose_docker() {
    show_step "诊断 Docker 服务状态..."
    
    # 检查 Docker 服务
    if ! systemctl is-active --quiet docker; then
        show_error "Docker 服务未运行"
        systemctl start docker
        show_info "✓ Docker 服务已启动"
    else
        show_info "✓ Docker 服务正在运行"
    fi
    
    # 检查 Docker 是否开机自启
    if ! systemctl is-enabled --quiet docker; then
        systemctl enable docker
        show_info "✓ Docker 已设置开机自启"
    fi
    
    # 检查 Docker 连接
    if ! docker version > /dev/null 2>&1; then
        show_error "Docker 无法连接"
        return 1
    else
        show_info "✓ Docker 连接正常"
    fi
}

# 修复用户权限
fix_user_permissions() {
    show_step "检查和修复用户权限..."
    
    # 获取当前用户
    CURRENT_USER=${SUDO_USER:-$USER}
    
    # 检查用户是否在 docker 组
    if ! groups "$CURRENT_USER" | grep -q docker; then
        show_warning "用户 $CURRENT_USER 不在 docker 组中"
        usermod -aG docker "$CURRENT_USER"
        show_info "✓ 已将用户 $CURRENT_USER 添加到 docker 组"
        show_warning "请执行 'newgrp docker' 或重新登录使权限生效"
    else
        show_info "✓ 用户 $CURRENT_USER 已在 docker 组中"
    fi
    
    # 修复 Docker Socket 权限
    DOCKER_SOCKET="/var/run/docker.sock"
    if [ -S "$DOCKER_SOCKET" ]; then
        DOCKER_GROUP=$(stat -c '%G' "$DOCKER_SOCKET")
        if [ "$DOCKER_GROUP" = "docker" ]; then
            show_info "✓ Docker Socket 组权限正确"
        else
            show_warning "修复 Docker Socket 权限..."
            chgrp docker "$DOCKER_SOCKET"
            chmod 660 "$DOCKER_SOCKET"
            show_info "✓ Docker Socket 权限已修复"
        fi
    else
        show_error "Docker Socket 不存在"
        return 1
    fi
}

# 完全重建 Portainer
rebuild_portainer() {
    show_step "完全重建 Portainer 容器..."
    
    # 停止并删除现有容器
    if docker ps -q -f name=portainer | grep -q .; then
        docker stop portainer
        show_info "✓ 已停止 Portainer 容器"
    fi
    
    if docker ps -aq -f name=portainer | grep -q .; then
        docker rm portainer
        show_info "✓ 已删除 Portainer 容器"
    fi
    
    # 清理数据目录（可选）
    DATA_DIR="/var/lib/portainer"
    if [ -d "$DATA_DIR" ]; then
        echo "是否清理 Portainer 数据目录？(y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$DATA_DIR"
            mkdir -p "$DATA_DIR"
            show_info "✓ 已清理 Portainer 数据目录"
        fi
    else
        mkdir -p "$DATA_DIR"
        chown -R "$CURRENT_USER":docker "$DATA_DIR" 2>/dev/null || true
    fi
    
    # 拉取最新镜像
    show_info "拉取最新 Portainer 镜像..."
    if ! docker pull portainer/portainer-ce:latest; then
        show_error "镜像拉取失败"
        return 1
    fi
    
    # 创建网络（如果不存在）
    if ! docker network inspect portainer-network >/dev/null 2>&1; then
        docker network create portainer-network
        show_info "✓ 已创建 Portainer 网络"
    fi
    
    # 启动容器 - 使用更安全的配置
    show_info "启动 Portainer 容器..."
    docker run -d \
        --name portainer \
        --restart always \
        -p 9000:9000 \
        -p 8000:8000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$DATA_DIR:/data" \
        --network portainer-network \
        --privileged=false \
        --user root \
        portainer/portainer-ce:latest
    
    if [ $? -eq 0 ]; then
        show_info "✓ Portainer 容器启动成功"
    else
        show_error "✗ Portainer 容器启动失败"
        return 1
    fi
}

# 详细验证
verify_portainer() {
    show_step "验证 Portainer 状态..."
    
    # 等待容器完全启动
    show_info "等待 Portainer 启动..."
    sleep 20
    
    # 检查容器状态
    CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' portainer 2>/dev/null)
    if [ "$CONTAINER_STATUS" = "running" ]; then
        show_info "✓ Portainer 容器正在运行"
    else
        show_error "✗ Portainer 容器未运行，状态: $CONTAINER_STATUS"
        show_error "容器日志："
        docker logs portainer
        return 1
    fi
    
    # 检查端口
    if netstat -tlnp | grep -q ":9000" || ss -tlnp | grep -q ":9000"; then
        show_info "✓ 端口 9000 正在监听"
    else
        show_warning "端口 9000 未监听"
    fi
    
    # 测试容器内 Docker 访问
    if docker exec portainer docker version >/dev/null 2>&1; then
        show_info "✓ Portainer 可以访问 Docker"
    else
        show_warning "Portainer 无法访问 Docker，可能需要手动配置"
    fi
    
    # 检查防火墙
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "9000"; then
            show_info "✓ 防火墙已配置端口 9000"
        else
            show_warning "建议开放端口 9000: ufw allow 9000"
        fi
    fi
}

# 显示访问信息和故障排除
show_access_info() {
    CURRENT_USER=${SUDO_USER:-$USER}
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "=============================================="
    show_info "Debian 虚拟机 Portainer 修复完成！"
    echo ""
    echo "📋 访问信息："
    echo "  本机访问: http://localhost:9000"
    echo "  局域网访问: http://$SERVER_IP:9000"
    echo ""
    echo "🔧 首次使用："
    echo "  1. 打开浏览器访问上述地址"
    echo "  2. 创建管理员账户"
    echo "  3. 选择 'Get Started'"
    echo ""
    echo "⚠️  如果仍显示 'environment local is unreachable'："
    echo "  1. 在 Portainer 中点击 'Add Environment'"
    echo "  2. 选择 'Docker Standalone'"
    echo "  3. 连接方式: 'Use existing connection'"
    echo "  4. Socket 路径: unix:///var/run/docker.sock"
    echo ""
    echo "🔍 故障排除："
    echo "  查看容器日志: docker logs portainer"
    echo "  重启容器: docker restart portainer"
    echo "  检查权限: groups $CURRENT_USER"
    echo ""
    echo "⚡ 重要提醒："
    echo "  如果是权限问题，请执行: newgrp docker"
    echo "  或重新登录以刷新用户组权限"
    echo "=============================================="
}

# 主执行逻辑
show_info "开始为 Debian 12.04 虚拟机修复 Portainer..."

# 检查权限
check_permissions

# 执行修复步骤
diagnose_docker || exit 1
fix_user_permissions
rebuild_portainer || exit 1

# 验证结果
verify_portainer

# 显示访问信息
show_access_info

echo ""
show_info "修复脚本执行完成！如果问题持续，请查看日志并重启系统。"