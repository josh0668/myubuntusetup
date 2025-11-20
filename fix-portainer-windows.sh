#!/bin/bash

# Windows Docker Desktop Portainer 修复脚本
# 解决 "The environment named local is unreachable" 问题

echo "--- Windows Docker Desktop Portainer 修复脚本 ---"

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

# 检查 Docker Desktop 是否运行
check_docker_desktop() {
    show_step "检查 Docker Desktop 状态..."
    
    if ! docker info > /dev/null 2>&1; then
        show_error "Docker Desktop 未运行，请先启动 Docker Desktop"
        echo "在 Windows 中启动 Docker Desktop 后再运行此脚本"
        exit 1
    fi
    
    show_info "✓ Docker Desktop 正在运行"
    echo "  Docker 版本: $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'Unknown')"
    echo "  Docker 架构: $(docker version --format '{{.Server.Arch}}' 2>/dev/null || echo 'Unknown')"
}

# 停止现有 Portainer 容器
stop_existing_portainer() {
    show_step "停止现有 Portainer 容器..."
    
    if docker ps -q -f name=portainer | grep -q .; then
        docker stop portainer
        show_info "✓ 已停止 Portainer 容器"
    fi
    
    if docker ps -aq -f name=portainer | grep -q .; then
        docker rm portainer
        show_info "✓ 已删除 Portainer 容器"
    fi
}

# 创建 Docker Desktop 专用的 Portainer 容器
create_portainer_for_docker_desktop() {
    show_step "创建适用于 Docker Desktop 的 Portainer 容器..."
    
    # 拉取最新镜像
    show_info "拉取最新 Portainer 镜像..."
    docker pull portainer/portainer-ce:latest
    
    # 创建专用的 Docker Socket 挂载点（Docker Desktop 特定）
    show_info "启动 Portainer 容器（Docker Desktop 配置）..."
    
    docker run -d \
        --name portainer \
        --restart always \
        -p 9000:9000 \
        -p 9443:9443 \
        -v //var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        --network bridge \
        --privileged=true \
        portainer/portainer-ce:latest \
        --host unix:///var/run/docker.sock
    
    if [ $? -eq 0 ]; then
        show_info "✓ Portainer 容器启动成功"
    else
        show_error "✗ Portainer 容器启动失败"
        return 1
    fi
}

# 替代方案：使用 TCP 连接
create_portainer_tcp_connection() {
    show_step "尝试 TCP 连接方式（备用方案）..."
    
    # 停止现有容器
    docker stop portainer-tcp 2>/dev/null || true
    docker rm portainer-tcp 2>/dev/null || true
    
    # 启用 Docker Desktop TCP 端口
    show_warning "请在 Docker Desktop 设置中启用 TCP 端口："
    echo "  1. 打开 Docker Desktop"
    echo "  2. 进入 Settings > Docker Engine"
    echo "  3. 添加配置: \"hosts\": [\"tcp://0.0.0.0:2375\"]"
    echo "  4. 重启 Docker Desktop"
    echo ""
    
    read -p "完成后按回车继续..." -r
    
    # 使用 TCP 连接启动 Portainer
    docker run -d \
        --name portainer-tcp \
        --restart always \
        -p 9001:9000 \
        -v portainer_tcp_data:/data \
        portainer/portainer-ce:latest \
        --host tcp://host.docker.internal:2375
    
    if [ $? -eq 0 ]; then
        show_info "✓ Portainer TCP 容器启动成功"
        echo "访问地址: http://localhost:9001"
    else
        show_error "✗ Portainer TCP 容器启动失败"
    fi
}

# 验证修复结果
verify_portainer() {
    show_step "验证 Portainer 状态..."
    
    # 等待容器启动
    echo "等待 Portainer 启动..."
    sleep 15
    
    # 检查容器状态
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "portainer.*Up"; then
        show_info "✓ Portainer 容器正在运行"
        
        # 检查端口
        if netstat -an 2>/dev/null | grep -q ":9000" || ss -an 2>/dev/null | grep -q ":9000"; then
            show_info "✓ 端口 9000 正在监听"
        fi
        
        # 测试容器内 Docker 连接
        if docker exec portainer docker version > /dev/null 2>&1; then
            show_info "✓ Portainer 与 Docker 连接正常"
        else
            show_warning "Portainer 与 Docker 连接可能存在问题"
        fi
        
        return 0
    else
        show_error "✗ Portainer 容器未正常运行"
        echo "容器日志："
        docker logs portainer 2>/dev/null
        return 1
    fi
}

# 显示访问信息和使用指南
show_access_guide() {
    echo ""
    echo "=============================================="
    show_info "Portainer 已为 Docker Desktop 配置完成！"
    echo ""
    echo "📋 访问信息："
    echo "  主地址: http://localhost:9000"
    echo "  HTTPS:  https://localhost:9443"
    echo ""
    echo "🔧 首次使用："
    echo "  1. 创建管理员账户"
    echo "  2. 选择 'Get Started' 连接到本地 Docker"
    echo "  3. 如果仍显示 'local is unreachable'，请："
    echo "     - 点击 'Add Environment'"
    echo "     - 选择 'Docker Standalone'"
    echo "     - 勾选 'Use existing connection'"
    echo "     - 连接地址: unix:///var/run/docker.sock"
    echo ""
    echo "🐳 Docker Desktop 特定说明："
    echo "  - Windows Docker Desktop 使用特殊架构"
    echo "  - 可能需要手动配置环境连接"
    echo "  - 如果问题持续，尝试 TCP 连接方式"
    echo ""
    echo "📞 故障排除："
    echo "  - 查看日志: docker logs portainer"
    echo "  - 重启容器: docker restart portainer"
    echo "  - 检查 Docker Desktop 状态"
    echo "=============================================="
}

# 主执行逻辑
echo "开始为 Windows Docker Desktop 修复 Portainer..."

# 检查 Docker Desktop
check_docker_desktop || exit 1

# 修复过程
stop_existing_portainer
create_portainer_for_docker_desktop

# 验证结果
if verify_portainer; then
    show_access_guide
else
    show_warning "主方案失败，尝试 TCP 连接方案..."
    create_portainer_tcp_connection
    
    echo ""
    show_info "TCP 方案访问地址: http://localhost:9001"
    show_info "如果 TCP 方案也不工作，请检查 Docker Desktop 设置"
fi

echo ""
show_info "修复完成！请按上述指南访问 Portainer"