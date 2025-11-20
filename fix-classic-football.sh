#!/bin/bash

# Classic Football 修复脚本
# 解决 PM2 启动失败问题

echo "--- Classic Football 修复脚本 ---"

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

# 诊断问题
diagnose_issues() {
    show_step "诊断部署问题..."
    
    # 检查项目目录
    if [ ! -d "/var/www/classic-football-shirts" ]; then
        show_error "项目目录不存在"
        return 1
    fi
    
    # 检查构建文件
    if [ ! -d "/var/www/classic-football-shirts/.next" ]; then
        show_warning "项目未构建，将重新构建"
        return 2
    fi
    
    # 检查依赖
    if [ ! -d "/var/www/classic-football-shirts/node_modules" ]; then
        show_warning "依赖未安装，将重新安装"
        return 3
    fi
    
    show_info "✓ 项目目录和构建文件正常"
    return 0
}

# 重新安装依赖
reinstall_dependencies() {
    show_step "重新安装依赖..."
    
    cd /var/www/classic-football-shirts
    
    # 清理现有依赖
    rm -rf node_modules bun.lockb package-lock.json
    
    # 重新安装
    if command -v bun >/dev/null 2>&1; then
        bun install
    else
        npm install
    fi
    
    show_info "✓ 依赖安装完成"
}

# 重新构建项目
rebuild_project() {
    show_step "重新构建项目..."
    
    cd /var/www/classic-football-shirts
    
    # 清理构建文件
    rm -rf .next out
    
    # 设置环境变量
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    # 构建
    if command -v bun >/dev/null 2>&1; then
        bun run build
    else
        npm run build
    fi
    
    if [ $? -eq 0 ]; then
        show_info "✓ 项目构建成功"
    else
        show_error "✗ 项目构建失败"
        return 1
    fi
}

# 测试手动启动
test_manual_start() {
    show_step "测试手动启动..."
    
    cd /var/www/classic-football-shirts
    
    # 设置环境变量
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    export NODE_ENV=production
    export PORT=3000
    
    # 后台启动测试
    nohup npm start > /tmp/manual-start.log 2>&1 &
    TEST_PID=$!
    
    # 等待启动
    sleep 10
    
    # 检查是否成功
    if curl -s http://localhost:3000 > /dev/null; then
        show_info "✓ 手动启动成功"
        kill $TEST_PID 2>/dev/null
        return 0
    else
        show_error "✗ 手动启动失败"
        kill $TEST_PID 2>/dev/null
        echo "启动日志："
        cat /tmp/manual-start.log
        return 1
    fi
}

# 重新配置 PM2
reconfigure_pm2() {
    show_step "重新配置 PM2..."
    
    cd /var/www/classic-football-shirts
    
    # 停止所有现有进程
    pm2 delete all 2>/dev/null || true
    
    # 修复权限
    chown -R $USER:$USER /var/www/classic-football-shirts
    
    # 创建简化的 PM2 配置
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
      PORT: 3000
    },
    error_file: '/var/log/classic-football-error.log',
    out_file: '/var/log/classic-football-out.log',
    log_file: '/var/log/classic-football-combined.log',
    time: true
  }]
};
EOF
    
    # 启动应用
    pm2 start ecosystem.config.js
    
    # 等待启动
    sleep 15
    
    # 检查状态
    if pm2 list | grep -q "classic-football.*online"; then
        show_info "✓ PM2 启动成功"
        pm2 save
        return 0
    else
        show_error "✗ PM2 启动失败"
        pm2 logs classic-football --lines 20
        return 1
    fi
}

# 备用方案：直接使用 node
fallback_start() {
    show_step "备用方案：使用 Node.js 直接启动..."
    
    cd /var/www/classic-football-shirts
    
    # 停止现有 PM2 进程
    pm2 delete all 2>/dev/null || true
    
    # 创建简单启动脚本
    cat > start-app.sh << 'EOF'
#!/bin/bash
cd /var/www/classic-football-shirts
export NODE_ENV=production
export PORT=3000
node .next/standalone/server.js
EOF
    
    chmod +x start-app.sh
    
    # 使用 PM2 启动脚本
    pm2 start start-app.sh --name "classic-football-fallback"
    
    sleep 10
    
    if pm2 list | grep -q "classic-football-fallback.*online"; then
        show_info "✓ 备用方案启动成功"
        pm2 save
        return 0
    else
        show_error "✗ 备用方案启动失败"
        pm2 logs classic-football-fallback --lines 20
        return 1
    fi
}

# 终极方案：开发模式启动
development_start() {
    show_step "终极方案：开发模式启动..."
    
    cd /var/www/classic-football-shirts
    
    # 停止现有进程
    pm2 delete all 2>/dev/null || true
    
    # 使用开发模式启动
    pm2 start "npm run dev" --name "classic-football-dev" -- --port 3000 --hostname 0.0.0.0
    
    sleep 20
    
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

# 验证最终结果
verify_final_result() {
    show_step "验证最终部署..."
    
    # 等待服务稳定
    sleep 10
    
    # 检查 PM2 状态
    pm2 list
    
    # 测试访问
    if curl -s http://localhost:3000 > /dev/null; then
        show_info "✓ 网站访问正常"
    else
        show_warning "网站访问可能需要更多时间启动"
    fi
    
    # 检查端口
    if netstat -tlnp | grep -q ":3000" || ss -tlnp | grep -q ":3000"; then
        show_info "✓ 端口 3000 正在监听"
    else
        show_warning "端口 3000 未监听"
    fi
}

# 显示解决方案
show_solutions() {
    echo ""
    echo "=============================================="
    show_info "修复方案尝试完成！"
    echo ""
    echo "🌐 请测试访问："
    echo "  http://192.168.1.107:3000"
    echo "  http://192.168.1.107 (Nginx)"
    echo ""
    echo "🔧 查看状态："
    echo "  pm2 list"
    echo "  pm2 logs [应用名]"
    echo ""
    echo "📱 如果都失败，请："
    echo "  1. 检查 package.json 脚本"
    echo "  2. 验证 Node.js 版本兼容性"
    echo "  3. 查看详细错误日志"
    echo "=============================================="
}

# 主执行逻辑
show_info "开始修复 Classic Football 部署问题..."

# 检查权限
check_permissions

# 诊断问题
diagnose_issues
DIAG_RESULT=$?

# 根据诊断结果修复
case $DIAG_RESULT in
    1)
        show_error "项目目录问题，请重新部署"
        exit 1
        ;;
    2)
        reinstall_dependencies
        rebuild_project
        ;;
    3)
        reinstall_dependencies
        ;;
esac

# 尝试各种启动方案
if test_manual_start; then
    reconfigure_pm2
else
    show_warning "手动启动失败，尝试备用方案..."
    if ! fallback_start; then
        show_warning "备用方案失败，尝试开发模式..."
        development_start
    fi
fi

# 验证结果
verify_final_result

# 显示解决方案
show_solutions

echo ""
show_info "修复脚本执行完成！"