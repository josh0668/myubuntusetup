#!/bin/bash

# Classic Football 网站自动部署脚本
# 目标环境: Debian 24.04 虚拟机
# IP: 192.168.1.107

echo "--- Classic Football 网站自动部署脚本 ---"
echo "目标服务器: Debian 24.04 (192.168.1.107)"
echo ""

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

# 检查是否为 root
check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        show_error "此脚本需要 root 权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 更新系统
update_system() {
    show_step "更新系统包..."
    apt update && apt upgrade -y
    show_info "✓ 系统更新完成"
}

# 安装 Node.js 和 Bun
install_nodejs_bun() {
    show_step "安装 Node.js 和 Bun..."
    
    # 安装必要工具
    apt install -y curl wget git build-essential
    
    # 安装 Node.js 18 LTS
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    
    # 安装 Bun
    curl -fsSL https://bun.sh/install | bash
    
    # 设置环境变量
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.bashrc
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc
    
    # 验证安装
    source ~/.bashrc
    node --version
    npm --version
    
    show_info "✓ Node.js 和 Bun 安装完成"
}

# 安装 PM2
install_pm2() {
    show_step "安装 PM2 进程管理器..."
    
    npm install -g pm2
    
    show_info "✓ PM2 安装完成"
}

# 创建项目目录
setup_project_directory() {
    show_step "设置项目目录..."
    
    # 创建 Web 目录
    mkdir -p /var/www
    cd /var/www
    
    # 克隆项目（使用你提供的仓库）
    if [ -d "classic-football-shirts" ]; then
        rm -rf classic-football-shirts
        show_info "✓ 删除现有项目目录"
    fi
    
    show_info "正在克隆项目..."
    git clone https://github.com/josh0668/myubuntusetup.git classic-football-shirts
    
    # 进入项目目录
    cd /var/www/classic-football-shirts
    
    show_info "✓ 项目目录设置完成"
}

# 安装项目依赖
install_dependencies() {
    show_step "安装项目依赖..."
    
    cd /var/www/classic-football-shirts
    
    # 设置 Bun 环境变量
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    # 使用 Bun 安装依赖
    $HOME/.bun/bin/bun install
    
    show_info "✓ 依赖安装完成"
}

# 构建项目
build_project() {
    show_step "构建 Next.js 项目..."
    
    cd /var/www/classic-football-shirts
    
    # 设置环境变量
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    # 构建
    $HOME/.bun/bin/bun run build
    
    show_info "✓ 项目构建完成"
}

# 配置 PM2 启动
setup_pm2_config() {
    show_step "配置 PM2 启动..."
    
    cd /var/www/classic-football-shirts
    
    # 创建 PM2 配置文件
    cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'classic-football',
    script: 'node_modules/next/dist/bin/next',
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
    
    # 创建日志目录
    mkdir -p /var/log
    
    # 设置环境变量并启动
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    # 启动应用
    pm2 start ecosystem.config.js
    
    # 保存 PM2 配置
    pm2 save
    
    # 设置 PM2 开机自启
    pm2 startup
    
    show_info "✓ PM2 配置完成"
}

# 配置防火墙
setup_firewall() {
    show_step "配置防火墙..."
    
    # 安装 ufw（如果没有）
    apt install -y ufw
    
    # 配置防火墙规则
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 3000/tcp
    ufw --force enable
    
    show_info "✓ 防火墙配置完成"
}

# 安装 Nginx（可选）
install_nginx() {
    show_step "安装和配置 Nginx（可选）..."
    
    # 安装 Nginx
    apt install -y nginx
    
    # 创建 Nginx 配置文件
    cat > /etc/nginx/sites-available/classic-football << 'EOF'
server {
    listen 80;
    server_name 192.168.1.107;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
    
    # 启用站点
    ln -sf /etc/nginx/sites-available/classic-football /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # 测试并重启 Nginx
    nginx -t && systemctl restart nginx
    
    # 启用 Nginx 开机自启
    systemctl enable nginx
    
    # 开放 80 端口
    ufw allow 80/tcp
    
    show_info "✓ Nginx 配置完成"
}

# 创建监控脚本
create_monitoring() {
    show_step "创建监控脚本..."
    
    # 创建健康检查脚本
    cat > /usr/local/bin/check-classic-football.sh << 'EOF'
#!/bin/bash

# 检查 Classic Football 网站状态
if ! curl -s http://localhost:3000 > /dev/null; then
    echo "$(date): Classic Football 网站无响应，尝试重启..." >> /var/log/classic-football-health.log
    pm2 restart classic-football
    sleep 10
    
    if curl -s http://localhost:3000 > /dev/null; then
        echo "$(date): 重启成功" >> /var/log/classic-football-health.log
    else
        echo "$(date): 重启失败，需要人工干预" >> /var/log/classic-football-health.log
    fi
fi
EOF
    
    chmod +x /usr/local/bin/check-classic-football.sh
    
    # 添加到 crontab（每5分钟检查一次）
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/check-classic-football.sh") | crontab -
    
    show_info "✓ 监控脚本创建完成"
}

# 验证部署
verify_deployment() {
    show_step "验证部署状态..."
    
    # 等待服务启动
    sleep 15
    
    # 检查 PM2 状态
    if pm2 list | grep -q "classic-football.*online"; then
        show_info "✓ PM2 进程运行正常"
    else
        show_error "✗ PM2 进程异常"
        pm2 list
        return 1
    fi
    
    # 检查端口监听
    if netstat -tlnp | grep -q ":3000" || ss -tlnp | grep -q ":3000"; then
        show_info "✓ 端口 3000 正在监听"
    else
        show_error "✗ 端口 3000 未监听"
        return 1
    fi
    
    # 测试本地访问
    if curl -s http://localhost:3000 > /dev/null; then
        show_info "✓ 本地访问测试通过"
    else
        show_warning "本地访问测试失败，可能还在启动中"
    fi
    
    return 0
}

# 显示访问信息
show_access_info() {
    SERVER_IP="192.168.1.107"
    
    echo ""
    echo "=============================================="
    show_info "Classic Football 网站部署完成！"
    echo ""
    echo "🌐 访问地址："
    echo "  直接访问: http://$SERVER_IP:3000"
    echo "  Nginx代理: http://$SERVER_IP"
    echo ""
    echo "🔧 管理命令："
    echo "  查看状态: pm2 list"
    echo "  查看日志: pm2 logs classic-football"
    echo "  重启服务: pm2 restart classic-football"
    echo "  停止服务: pm2 stop classic-football"
    echo ""
    echo "📊 监控信息："
    echo "  健康检查: /var/log/classic-football-health.log"
    echo "  应用日志: /var/log/classic-football-*.log"
    echo ""
    echo "🔍 调试命令："
    echo "  测试本地: curl http://localhost:3000"
    echo "  检查端口: netstat -tlnp | grep 3000"
    echo ""
    echo "📱 移动访问："
    echo "  手机/平板: http://$SERVER_IP:3000"
    echo "  局域网设备: http://$SERVER_IP"
    echo "=============================================="
}

# 主执行逻辑
show_info "开始部署 Classic Football 网站到 Debian 24.04..."

# 检查权限
check_permissions

# 执行部署步骤
update_system || exit 1
install_nodejs_bun || exit 1
install_pm2 || exit 1
setup_project_directory || exit 1
install_dependencies || exit 1
build_project || exit 1
setup_pm2_config || exit 1
setup_firewall || exit 1
install_nginx || exit 1
create_monitoring || exit 1

# 验证部署
verify_deployment

# 显示访问信息
show_access_info

echo ""
show_info "🎉 Classic Football 网站部署完成！"
echo "请使用上述地址访问测试。"