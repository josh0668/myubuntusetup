#!/bin/bash

# Debian Portainer 最终修复脚本
# 解决所有权限和用户问题

echo "--- Portainer 最终修复脚本 ---"

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

# 修复 Docker Socket 权限
fix_docker_socket_permissions() {
    show_step "修复 Docker Socket 权限..."
    
    DOCKER_SOCKET="/var/run/docker.sock"
    
    if [ ! -S "$DOCKER_SOCKET" ]; then
        show_error "Docker Socket 不存在"
        return 1
    fi
    
    # 设置权限
    chgrp docker "$DOCKER_SOCKET"
    chmod 660 "$DOCKER_SOCKET"
    
    show_info "✓ Docker Socket 权限已修复"
}

# 正确重建 Portainer（不指定用户）
rebuild_portainer_correctly() {
    show_step "使用正确配置重建 Portainer..."
    
    # 停止并删除现有容器
    if docker ps -q -f name=portainer | grep -q .; then
        docker stop portainer
        show_info "✓ 已停止 Portainer 容器"
    fi
    
    if docker ps -aq -f name=portainer | grep -q .; then
        docker rm portainer
        show_info "✓ 已删除 Portainer 容器"
    fi
    
    # 确保数据目录
    mkdir -p /var/lib/portainer
    
    # 不指定用户 - 让容器使用默认配置
    show_info "启动 Portainer 容器（默认权限）..."
    docker run -d \
        --name portainer \
        --restart always \
        -p 9000:9000 \
        -p 8000:8000 \
        -v /var/run/docker.sock:/var/run/docker.sock:rw \
        -v /var/lib/portainer:/data \
        portainer/portainer-ce:latest
    
    if [ $? -eq 0 ]; then
        show_info "✓ Portainer 容器启动成功"
    else
        show_error "✗ Portainer 容器启动失败"
        return 1
    fi
}

# 备用方案1: 使用特权模式
rebuild_portainer_privileged() {
    show_step "尝试特权模式（方案1）..."
    
    docker stop portainer-priv 2>/dev/null || true
    docker rm portainer-priv 2>/dev/null || true
    
    docker run -d \
        --name portainer-priv \
        --restart always \
        -p 9001:9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /var/lib/portainer:/data \
        --privileged \
        portainer/portainer-ce:latest
    
    if [ $? -eq 0 ]; then
        show_info "✓ 特权模式 Portainer 启动成功"
        show_warning "访问地址: http://192.168.1.107:9001"
        return 0
    else
        show_error "✗ 特权模式启动失败"
        return 1
    fi
}

# 备用方案2: 使用主机网络模式
rebuild_portainer_host_network() {
    show_step "尝试主机网络模式（方案2）..."
    
    docker stop portainer-host 2>/dev/null || true
    docker rm portainer-host 2>/dev/null || true
    
    docker run -d \
        --name portainer-host \
        --restart always \
        --net host \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /var/lib/portainer:/data \
        portainer/portainer-ce:latest
    
    if [ $? -eq 0 ]; then
        show_info "✓ 主机网络模式 Portainer 启动成功"
        show_warning "访问地址: http://192.168.1.107:9000"
        return 0
    else
        show_error "✗ 主机网络模式启动失败"
        return 1
    fi
}

# 备用方案3: 使用 UID 映射
rebuild_portainer_uid_mapping() {
    show_step "尝试 UID 映射方案（方案3）..."
    
    docker stop portainer-uid 2>/dev/null || true
    docker rm portainer-uid 2>/dev/null || true
    
    docker run -d \
        --name portainer-uid \
        --restart always \
        -p 9002:9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /var/lib/portainer:/data \
        --user "$(id -u):$(id -g)" \
        portainer/portainer-ce:latest
    
    if [ $? -eq 0 ]; then
        show_info "✓ UID 映射模式 Portainer 启动成功"
        show_warning "访问地址: http://192.168.1.107:9002"
        return 0
    else
        show_error "✗ UID 映射模式启动失败"
        return 1
    fi
}

# 验证每个容器
verify_containers() {
    show_step "验证所有容器状态..."
    
    containers=("portainer" "portainer-priv" "portainer-host" "portainer-uid")
    ports=("9000" "9001" "9000" "9002")
    names=("标准模式" "特权模式" "主机网络" "UID映射")
    
    for i in "${!containers[@]}"; do
        container="${containers[$i]}"
        port="${ports[$i]}"
        name="${names[$i]}"
        
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container.*Up"; then
            show_info "✓ $name ($container) 正在运行 - 端口 $port"
            
            # 测试 Docker 权限
            if docker exec "$container" docker ps >/dev/null 2>&1; then
                show_info "  └─ Docker 权限正常 ✓"
            else
                show_warning "  └─ Docker 权限可能有限制 ⚠"
            fi
        fi
    done
}

# 显示所有访问选项
show_all_access_options() {
    SERVER_IP="192.168.1.107"
    
    echo ""
    echo "=============================================="
    show_info "所有可用的 Portainer 实例："
    echo ""
    
    if docker ps --format "{{.Names}}" | grep -q "portainer$"; then
        echo "🔵 标准模式: http://$SERVER_IP:9000"
    fi
    
    if docker ps --format "{{.Names}}" | grep -q "portainer-priv"; then
        echo "🟠 特权模式: http://$SERVER_IP:9001"
    fi
    
    if docker ps --format "{{.Names}}" | grep -q "portainer-uid"; then
        echo "🟢 UID映射: http://$SERVER_IP:9002"
    fi
    
    echo ""
    echo "🎯 推荐测试顺序："
    echo "1. 先试标准模式 (9000)"
    echo "2. 如果有问题试特权模式 (9001)"
    echo "3. 最后试 UID 映射 (9002)"
    echo ""
    echo "⚠️  如果都显示 'local unreachable'："
    echo "   在 Portainer 界面手动添加环境"
    echo "   连接地址: unix:///var/run/docker.sock"
    echo "=============================================="
}

# 主执行逻辑
show_info "开始 Portainer 最终修复..."

# 检查权限
check_permissions

# 获取用户信息
get_current_user

# 执行修复
fix_docker_socket_permissions || exit 1

# 尝试多种启动方式
rebuild_portainer_correctly
rebuild_portainer_privileged
rebuild_portainer_uid_mapping

# 验证所有容器
verify_containers

# 显示访问选项
show_all_access_options

echo ""
show_info "修复完成！请按推荐顺序测试各个端口。"