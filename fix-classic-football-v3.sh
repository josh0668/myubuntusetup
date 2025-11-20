#!/bin/bash

# Classic Football V3 修复脚本
# 解决 unzip 缺失等系统依赖问题

echo "--- Classic Football V3 修复脚本 ---"

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

# 安装系统依赖
install_system_deps() {
    show_step "安装系统依赖..."
    
    # 更新包列表
    apt update
    
    # 安装必要的系统工具
    apt install -y curl wget unzip git build-essential \
        ca-certificates gnupg2 lsb-release software-properties-common \
        nodejs npm make g++ python3
    
    show_info "✓ 系统依赖安装完成"
}

# 安装 Bun (多种方法)
install_bun() {
    show_step "安装 Bun 包管理器..."
    
    # 方法1: 官方脚本
    show_info "尝试方法1: 官方安装脚本..."
    if curl -fsSL https://bun.sh/install | bash; then
        BUN_INSTALL="$HOME/.bun"
        if [ -f "$BUN_INSTALL/bin/bun" ]; then
            show_info "✓ 官方脚本安装成功: $($BUN_INSTALL/bin/bun --version)"
            return 0
        fi
    fi
    
    # 方法2: npm 安装
    show_warning "官方脚本失败，尝试 npm 安装..."
    if npm install -g bun; then
        BUN_INSTALL=$(npm config get prefix)
        if [ -f "$BUN_INSTALL/bin/bun" ]; then
            show_info "✓ npm 安装成功: $($BUN_INSTALL/bin/bun --version)"
            return 0
        fi
    fi
    
    # 方法3: 二进制下载
    show_warning "npm 安装失败，尝试直接下载二进制..."
    
    # 确定架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            BUN_ARCH="x64"
            ;;
        aarch64|arm64)
            BUN_ARCH="aarch64"
            ;;
        *)
            show_error "不支持的架构: $ARCH"
            return 1
            ;;
    esac
    
    # 下载最新版本
    LATEST_VERSION=$(curl -s https://api.github.com/repos/oven-sh/bun/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
    BUN_VERSION=${LATEST_VERSION#v}
    
    if [ -z "$BUN_VERSION" ]; then
        show_error "无法获取 Bun 最新版本"
        return 1
    fi
    
    # 下载并解压
    cd /tmp
    wget "https://github.com/oven-sh/bun/releases/download/${LATEST_VERSION}/bun-linux-${BUN_ARCH}.zip" -O bun.zip
    unzip bun.zip
    chmod +x bun-linux-${BUN_ARCH}/bun
    mv bun-linux-${BUN_ARCH}/bun /usr/local/bin/bun
    
    # 验证安装
    if /usr/local/bin/bun --version; then
        BUN_INSTALL="/usr/local"
        show_info "✓ 二进制安装成功: $(/usr/local/bin/bun --version)"
        return 0
    else
        show_error "✗ 二进制安装失败"
        return 1
    fi
}

# 设置 Bun 环境变量
setup_bun_env() {
    show_step "设置 Bun 环境变量..."
    
    # 设置环境变量
    if [ -f "$HOME/.bun/bin/bun" ]; then
        BUN_INSTALL="$HOME/.bun"
    elif [ -f "/usr/local/bin/bun" ]; then
        BUN_INSTALL="/usr/local"
    else
        show_error "找不到 Bun 安装位置"
        return 1
    fi
    
    export BUN_INSTALL="$BUN_INSTALL"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    # 添加到 .bashrc
    if ! grep -q "BUN_INSTALL" ~/.bashrc; then
        echo "export BUN_INSTALL=\"$BUN_INSTALL\"" >> ~/.bashrc
        echo "export PATH=\"\$BUN_INSTALL/bin:\$PATH\"" >> ~/.bashrc
    fi
    
    # 验证
    if command -v bun >/dev/null 2>&1; then
        show_info "✓ Bun 环境变量设置成功: $(bun --version)"
        return 0
    else
        show_error "✗ Bun 环境变量设置失败"
        return 1
    fi
}

# 检查项目
check_project() {
    show_step "检查项目..."
    
    cd /var/www/classic-football-shirts
    
    # 检查 package.json
    if [ ! -f "package.json" ]; then
        show_error "package.json 不存在，需要完整的项目代码"
        echo "当前目录内容："
        ls -la
        return 1
    fi
    
    show_info "✓ package.json 存在"
    
    # 显示项目信息
    echo "项目信息："
    echo "Node.js 版本要求: $(grep -o '"node": "[^"]*' package.json | cut -d'"' -f4)"
    echo "项目名称: $(grep -o '"name": "[^"]*' package.json | cut -d'"' -f4)"
    echo "版本: $(grep -o '"version": "[^"]*' package.json | cut -d'"' -f4)"
    
    return 0
}

# 安装项目依赖
install_dependencies() {
    show_step "安装项目依赖..."
    
    cd /var/www/classic-football-shirts
    
    # 清理旧依赖
    rm -rf node_modules bun.lockb package-lock.json
    
    # 优先使用 Bun
    if command -v bun >/dev/null 2>&1; then
        show_info "使用 Bun 安装依赖..."
        bun install
        
        if [ $? -eq 0 ]; then
            show_info "✓ Bun 依赖安装成功"
            return 0
        else
            show_warning "Bun 安装失败，尝试 npm..."
        fi
    fi
    
    # 备用: 使用 npm
    show_info "使用 npm 安装依赖..."
    npm install
    
    if [ $? -eq 0 ]; then
        show_info "✓ npm 依赖安装成功"
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
    
    # 设置构建环境
    export NODE_ENV=production
    export BUN_INSTALL="$BUN_INSTALL"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    # 检查 Next.js 配置
    if [ -f "next.config.js" ]; then
        show_info "发现 next.config.js，检查配置..."
        echo "next.config.js 内容："
        cat next.config.js
    fi
    
    # 尝试使用 Bun 构建
    if command -v bun >/dev/null 2>&1; then
        show_info "使用 Bun 构建..."
        bun run build
        
        if [ $? -eq 0 ] && [ -d ".next" ]; then
            show_info "✓ Bun 构建成功"
            ls -la .next/ | head -10
            return 0
        else
            show_warning "Bun 构建失败，尝试 npm..."
        fi
    fi
    
    # 使用 npm 构建
    show_info "使用 npm 构建..."
    npm run build
    
    if [ $? -eq 0 ] && [ -d ".next" ]; then
        show_info "✓ npm 构建成功"
        ls -la .next/ | head -10
        return 0
    else
        show_error "✗ 构建失败"
        echo "构建错误信息："
        cat .next/build.log 2>/dev/null || echo "无构建日志"
        return 1
    fi
}

# 测试应用启动
test_startup() {
    show_step "测试应用启动..."
    
    cd /var/www/classic-football-shirts
    
    # 设置环境变量
    export NODE_ENV=production
    export PORT=3000
    export BUN_INSTALL="$BUN_INSTALL"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    # 检查 package.json 脚本
    echo "可用脚本："
    grep -A 10 '"scripts"' package.json
    
    # 尝试启动
    if command -v bun >/dev/null 2>&1 && grep -q '"start"' package.json; then
        show_info "使用 Bun 启动测试..."
        timeout 30 bun start > /tmp/bun-start.log 2>&1 &
    elif grep -q '"start"' package.json; then
        show_info "使用 npm 启动测试..."
        timeout 30 npm start > /tmp/npm-start.log 2>&1 &
    else
        show_error "没有 start 脚本"
        return 1
    fi
    
    START_PID=$!
    
    # 等待启动
    for i in {1..30}; do
        sleep 1
        if curl -s http://localhost:3000 >/dev/null 2>&1; then
            show_info "✓ 应用启动成功"
            kill $START_PID 2>/dev/null
            return 0
        fi
    done
    
    show_error "✗ 应用启动超时"
    kill $START_PID 2>/dev/null
    
    # 显示启动日志
    if [ -f "/tmp/bun-start.log" ]; then
        echo "Bun 启动日志："
        cat /tmp/bun-start.log
    fi
    
    if [ -f "/tmp/npm-start.log" ]; then
        echo "npm 启动日志："
        cat /tmp/npm-start.log
    fi
    
    return 1
}

# 配置 PM2
setup_pm2() {
    show_step "配置 PM2..."
    
    cd /var/www/classic-football-shirts
    
    # 停止现有进程
    pm2 delete all 2>/dev/null || true
    
    # 创建配置文件
    cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'classic-football',
    script: command_exists bun && 'bun' || 'npm',
    args: command_exists bun && 'start' || 'start',
    cwd: '/var/www/classic-football-shirts',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      BUN_INSTALL: '$BUN_INSTALL',
      PATH: '$BUN_INSTALL/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
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
    sleep 20
    
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

# 显示完成信息
show_completion() {
    SERVER_IP="192.168.1.107"
    
    echo ""
    echo "=============================================="
    show_info "Classic Football 部署完成！"
    echo ""
    echo "🌐 访问地址："
    echo "  直接访问: http://$SERVER_IP:3000"
    echo "  Nginx代理: http://$SERVER_IP"
    echo ""
    echo "🔧 管理命令："
    echo "  查看状态: pm2 list"
    echo "  查看日志: pm2 logs classic-football"
    echo "  重启服务: pm2 restart classic-football"
    echo ""
    echo "📱 移动访问："
    echo "  手机/平板: http://$SERVER_IP:3000"
    echo "  局域网设备: http://$SERVER_IP"
    echo "=============================================="
}

# 主执行逻辑
show_info "开始 Classic Football V3 修复..."

# 检查权限
check_permissions

# 执行步骤
install_system_deps || exit 1
install_bun || exit 1
setup_bun_env || exit 1
check_project || exit 1
install_dependencies || exit 1
build_project || exit 1
test_startup || exit 1
setup_pm2 || exit 1

# 最终验证
final_verification

# 显示完成信息
show_completion

echo ""
show_info "🎉 Classic Football 网站部署完成！"
echo "请访问 http://192.168.1.107:3000 测试网站功能。"