#!/bin/bash

# Classic Football V4 修复脚本
# 解决 npm 安装 Bun 的路径问题

echo "--- Classic Football V4 修复脚本 ---"

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

# 修复依赖冲突
fix_package_conflicts() {
    show_step "修复包冲突..."
    
    # 更新包列表
    apt update
    
    # 移除冲突的包
    apt remove -y npm nodejs
    
    # 重新安装 Node.js 和 npm
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
    
    # 安装系统依赖
    apt install -y curl wget unzip git build-essential
    
    show_info "✓ 包冲突修复完成"
}

# 直接使用 npm 和 Node.js（不依赖 Bun）
setup_with_npm() {
    show_step "使用 npm 和 Node.js 设置项目..."
    
    # 验证安装
    node --version
    npm --version
    
    if [ $? -ne 0 ]; then
        show_error "Node.js 或 npm 安装失败"
        return 1
    fi
    
    show_info "✓ Node.js 和 npm 正常"
    return 0
}

# 检查项目
check_project() {
    show_step "检查项目..."
    
    cd /var/www/classic-football-shirts
    
    # 检查 package.json
    if [ ! -f "package.json" ]; then
        show_error "package.json 不存在"
        echo "当前目录内容："
        ls -la
        return 1
    fi
    
    show_info "✓ 项目文件存在"
    
    # 显示项目信息
    echo "项目信息："
    echo "项目名称: $(grep -o '"name": "[^"]*' package.json | cut -d'"' -f4 || echo '未知')"
    echo "版本: $(grep -o '"version": "[^"]*' package.json | cut -d'"' -f4 || echo '未知')"
    echo "Node.js 版本要求: $(grep -o '"node": "[^"]*' package.json | cut -d'"' -f4 || echo '未指定')"
    
    return 0
}

# 安装依赖
install_dependencies() {
    show_step "安装项目依赖..."
    
    cd /var/www/classic-football-shirts
    
    # 清理旧依赖
    rm -rf node_modules package-lock.json
    
    # 使用 npm 安装
    npm install
    
    if [ $? -eq 0 ]; then
        show_info "✓ 依赖安装成功"
        echo "安装的包数量: $(ls node_modules | wc -l)"
        return 0
    else
        show_error "✗ 依赖安装失败"
        return 1
    fi
}

# 构建项目
build_project() {
    show_step "构建项目..."
    
    cd /var/www/classic-football-shirts
    
    # 清理旧构建
    rm -rf .next out build dist
    
    # 设置环境变量
    export NODE_ENV=production
    export NEXT_TELEMETRY_DISABLED=1
    
    # 检查构建脚本
    echo "可用构建脚本："
    grep -A 10 '"scripts"' package.json
    
    # 使用 npm 构建
    npm run build
    
    if [ $? -eq 0 ] && [ -d ".next" ]; then
        show_info "✓ 项目构建成功"
        echo "构建文件："
        ls -la .next/ | head -10
        
        # 检查是否有 server.js
        if [ -f ".next/standalone/server.js" ]; then
            show_info "✓ 找到独立构建文件"
        elif [ -f ".next/server.js" ]; then
            show_info "✓ 找到服务器文件"
        else
            show_warning "未找到标准服务器文件，可能需要开发模式"
        fi
        return 0
    else
        show_error "✗ 项目构建失败"
        
        # 显示构建错误
        if [ -f ".next/build.log" ]; then
            echo "构建日志："
            cat .next/build.log
        fi
        
        return 1
    fi
}

# 测试启动
test_startup() {
    show_step "测试应用启动..."
    
    cd /var/www/classic-football-shirts
    
    # 设置环境变量
    export NODE_ENV=production
    export PORT=3000
    export NEXT_TELEMETRY_DISABLED=1
    export HOSTNAME=0.0.0.0
    
    # 检查启动脚本
    echo "启动脚本："
    grep '"start"' package.json
    
    # 后台启动测试
    timeout 30 npm start > /tmp/test-start.log 2>&1 &
    START_PID=$!
    
    # 等待启动
    for i in {1..30}; do
        sleep 1
        if curl -s http://localhost:3000 >/dev/null 2>&1; then
            show_info "✓ 应用启动成功 (耗时 ${i}s)"
            kill $START_PID 2>/dev/null
            return 0
        fi
        
        # 显示启动进度
        if [ $((i % 5)) -eq 0 ]; then
            echo "等待启动... (${i}s)"
        fi
    done
    
    show_error "✗ 应用启动超时"
    kill $START_PID 2>/dev/null
    
    # 显示启动日志
    echo "启动日志："
    cat /tmp/test-start.log
    
    return 1
}

# 配置 PM2
configure_pm2() {
    show_step "配置 PM2..."
    
    cd /var/www/classic-football-shirts
    
    # 停止现有进程
    pm2 delete all 2>/dev/null || true
    
    # 创建 PM2 配置文件
    cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'classic-football',
    script: 'npm',
    args: 'start',
    cwd: '/var/www/classic-football-shirts',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      HOSTNAME: '0.0.0.0',
      NEXT_TELEMETRY_DISABLED: 1
    },
    error_file: '/var/log/classic-football-error.log',
    out_file: '/var/log/classic-football-out.log',
    log_file: '/var/log/classic-football-combined.log',
    time: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
EOF
    
    # 创建日志目录
    mkdir -p /var/log
    
    # 启动应用
    pm2 start ecosystem.config.js
    
    # 等待启动
    sleep 20
    
    # 检查状态
    if pm2 list | grep -q "classic-football.*online"; then
        show_info "✓ PM2 启动成功"
        pm2 save
        
        # 设置 PM2 开机自启
        pm2 startup
        
        return 0
    else
        show_error "✗ PM2 启动失败"
        echo "PM2 状态："
        pm2 list
        
        echo "PM2 日志："
        pm2 logs classic-football --lines 20
        
        return 1
    fi
}

# 备用方案：开发模式
fallback_dev_mode() {
    show_step "备用方案：开发模式启动..."
    
    cd /var/www/classic-football-shirts
    
    # 停止现有进程
    pm2 delete all 2>/dev/null || true
    
    # 开发模式启动
    pm2 start "npm run dev" --name "classic-football-dev" -- --port 3000 --hostname 0.0.0.0
    
    # 等待启动
    sleep 25
    
    if pm2 list | grep -q "classic-football-dev.*online"; then
        show_info "✓ 开发模式启动成功"
        pm2 save
        return 0
    else
        show_error "✗ 开发模式启动失败"
        pm2 logs classic-football-dev --lines 20
        return 1
    fi
}

# 最终验证
final_verification() {
    show_step "最终验证..."
    
    # 等待服务稳定
    sleep 10
    
    # PM2 状态
    echo "PM2 状态："
    pm2 list
    
    # 测试访问
    if curl -s http://localhost:3000 >/dev/null 2>&1; then
        show_info "✓ 本地访问成功"
        
        # 测试响应内容
        RESPONSE=$(curl -s http://localhost:3000 | head -c 200)
        if echo "$RESPONSE" | grep -q "html"; then
            show_info "✓ 网站响应正常"
        fi
    else
        show_warning "本地访问失败"
    fi
    
    # 端口检查
    if netstat -tlnp | grep -q ":3000" || ss -tlnp | grep -q ":3000"; then
        show_info "✓ 端口 3000 正在监听"
    else
        show_warning "端口 3000 未监听"
    fi
    
    # 防火墙检查
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "3000.*ALLOW"; then
            show_info "✓ 防火墙已配置"
        else
            show_warning "防火墙可能阻止访问，执行: ufw allow 3000"
        fi
    fi
}

# 显示访问信息
show_access_info() {
    SERVER_IP="192.168.1.107"
    
    echo ""
    echo "=============================================="
    show_info "Classic Football 部署完成！"
    echo ""
    echo "🌐 访问地址："
    echo "  本机访问: http://localhost:3000"
    echo "  局域网访问: http://$SERVER_IP:3000"
    echo "  Nginx代理: http://$SERVER_IP"
    echo ""
    echo "🔧 管理命令："
    echo "  查看状态: pm2 list"
    echo "  查看日志: pm2 logs classic-football"
    echo "  重启服务: pm2 restart classic-football"
    echo "  停止服务: pm2 stop classic-football"
    echo ""
    echo "📱 移动访问："
    echo "  手机浏览器: http://$SERVER_IP:3000"
    echo "  平板访问: http://$SERVER_IP:3000"
    echo ""
    echo "📊 监控信息："
    echo "  应用日志: /var/log/classic-football-*.log"
    echo "  PM2 监控: pm2 monit"
    echo "=============================================="
}

# 主执行逻辑
show_info "开始 Classic Football V4 修复（纯 npm 方案）..."

# 检查权限
check_permissions

# 执行步骤
fix_package_conflicts || exit 1
setup_with_npm || exit 1
check_project || exit 1
install_dependencies || exit 1
build_project || exit 1

# 尝试启动
if test_startup; then
    configure_pm2
else
    show_warning "生产模式失败，尝试开发模式..."
    fallback_dev_mode
fi

# 最终验证
final_verification

# 显示访问信息
show_access_info

echo ""
show_info "🎉 Classic Football 网站部署完成！"
echo "请在浏览器中访问 http://192.168.1.107:3000"