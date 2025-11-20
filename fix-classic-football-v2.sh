#!/bin/bash

# Classic Football V2 修复脚本
# 解决 Bun 未安装和项目未构建问题

echo "--- Classic Football V2 修复脚本 ---"

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

# 安装 Bun
install_bun() {
    show_step "安装 Bun 包管理器..."
    
    # 删除可能存在的 snap 版本
    snap remove bun-js 2>/dev/null || true
    
    # 使用官方脚本安装
    curl -fsSL https://bun.sh/install | bash
    
    # 设置环境变量
    BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.bashrc
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc
    
    # 重新加载环境
    source ~/.bashrc
    
    # 验证安装
    sleep 5
    if [ -f "$BUN_INSTALL/bin/bun" ]; then
        show_info "✓ Bun 安装成功: $($BUN_INSTALL/bin/bun --version)"
    else
        show_error "✗ Bun 安装失败"
        return 1
    fi
}

# 设置项目
setup_project() {
    show_step "设置项目..."
    
    cd /var/www/classic-football-shirts
    
    # 检查 package.json 是否存在
    if [ ! -f "package.json" ]; then
        show_error "package.json 不存在"
        echo "项目结构："
        ls -la
        return 1
    fi
    
    show_info "✓ 项目目录正确"
    show_info "项目内容："
    ls -la
    
    return 0
}

# 安装依赖
install_dependencies() {
    show_step "安装项目依赖..."
    
    cd /var/www/classic-football-shirts
    
    # 使用 Bun 安装依赖
    $HOME/.bun/bin/bun install
    
    if [ $? -eq 0 ]; then
        show_info "✓ 依赖安装成功"
    else
        show_warning "Bun 安装失败，尝试使用 npm..."
        npm install
        
        if [ $? -eq 0 ]; then
            show_info "✓ npm 依赖安装成功"
        else
            show_error "✗ 依赖安装失败"
            return 1
        fi
    fi
}

# 构建项目
build_project() {
    show_step "构建项目..."
    
    cd /var/www/classic-football-shirts
    
    # 清理旧构建
    rm -rf .next out
    
    # 尝试使用 Bun 构建
    if [ -f "$HOME/.bun/bin/bun" ]; then
        show_info "使用 Bun 构建..."
        $HOME/.bun/bin/bun run build
        
        if [ $? -eq 0 ]; then
            show_info "✓ Bun 构建成功"
        else
            show_warning "Bun 构建失败，尝试 npm..."
            npm run build
        fi
    else
        show_info "使用 npm 构建..."
        npm run build
    fi
    
    # 验证构建
    if [ -d ".next" ] && [ -f ".next/standalone/server.js" ]; then
        show_info "✓ 项目构建成功"
        echo "构建文件："
        ls -la .next/
    else
        show_warning "标准构建失败，尝试开发模式构建..."
        
        # 检查是否有 next.config.js 配置问题
        cat next.config.js
        
        # 尝试简单构建
        npm run build
    fi
}

# 测试应用启动
test_app_start() {
    show_step "测试应用启动..."
    
    cd /var/www/classic-football-shirts
    
    # 设置环境变量
    export NODE_ENV=production
    export PORT=3000
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    # 后台启动测试
    nohup npm start > /tmp/test-start.log 2>&1 &
    TEST_PID=$!
    
    # 等待启动
    sleep 20
    
    # 测试访问
    if curl -s http://localhost:3000 > /dev/null; then
        show_info "✓ 应用启动成功"
        kill $TEST_PID 2>/dev/null
        return 0
    else
        show_error "✗ 应用启动失败"
        kill $TEST_PID 2>/dev/null
        echo "启动日志："
        cat /tmp/test-start.log
        
        # 检查端口占用
        echo "端口占用情况："
        netstat -tlnp | grep 3000 || ss -tlnp | grep 3000
        
        return 1
    fi
}

# 配置 PM2
configure_pm2() {
    show_step "配置 PM2..."
    
    cd /var/www/classic-football-shirts
    
    # 停止现有进程
    pm2 delete all 2>/dev/null || true
    
    # 创建 PM2 配置（使用 npm）
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
        pm2 startup
        return 0
    else
        show_error "✗ PM2 启动失败"
        pm2 logs classic-football --lines 20
        return 1
    fi
}

# 备用方案：使用开发模式
fallback_dev_mode() {
    show_step "备用方案：开发模式启动..."
    
    cd /var/www/classic-football-shirts
    
    # 停止现有进程
    pm2 delete all 2>/dev/null || true
    
    # 开发模式启动
    pm2 start "npm run dev" --name "classic-football-dev" -- --port 3000 --hostname 0.0.0.0
    
    # 等待启动
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

# 最终验证
final_verification() {
    show_step "最终验证..."
    
    # 等待服务稳定
    sleep 10
    
    # PM2 状态
    echo "PM2 进程状态："
    pm2 list
    
    # 测试访问
    if curl -s http://localhost:3000 > /dev/null; then
        show_info "✓ 网站访问成功"
    else
        show_warning "网站访问测试失败"
    fi
    
    # 端口检查
    if netstat -tlnp | grep -q ":3000" || ss -tlnp | grep -q ":3000"; then
        show_info "✓ 端口 3000 正在监听"
    else
        show_warning "端口 3000 未监听"
    fi
}

# 显示信息
show_completion_info() {
    echo ""
    echo "=============================================="
    show_info "Classic Football 修复完成！"
    echo ""
    echo "🌐 访问地址："
    echo "  http://192.168.1.107:3000"
    echo "  http://192.168.1.107 (Nginx)"
    echo ""
    echo "🔧 管理命令："
    echo "  pm2 list"
    echo "  pm2 logs classic-football"
    echo "  pm2 restart classic-football"
    echo ""
    echo "📋 如果还有问题："
    echo "  1. 检查防火墙: ufw status"
    echo "  2. 查看系统日志: journalctl -u nginx"
    echo "  3. 重启服务: systemctl restart nginx"
    echo "=============================================="
}

# 主执行逻辑
show_info "开始 Classic Football V2 修复..."

# 检查权限
check_permissions

# 执行修复步骤
install_bun || exit 1
setup_project || exit 1
install_dependencies || exit 1
build_project || exit 1

# 尝试启动
if test_app_start; then
    configure_pm2
else
    show_warning "生产模式失败，尝试开发模式..."
    fallback_dev_mode
fi

# 最终验证
final_verification

# 显示完成信息
show_completion_info

echo ""
show_info "🎉 修复完成！请访问 http://192.168.1.107:3000 测试"