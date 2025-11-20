#!/bin/bash

# 创建 Classic Football 测试网站
echo "--- 创建 Classic Football 测试网站 ---"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

show_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
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

# 创建项目结构
create_project_structure() {
    show_step "创建项目结构..."
    
    cd /var/www
    
    # 删除现有目录
    rm -rf classic-football-shirts
    
    # 创建项目目录
    mkdir -p classic-football-shirts
    cd classic-football-shirts
    
    # 创建 package.json
    cat > package.json << 'EOF'
{
  "name": "classic-football-shirts",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^14.2.18",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "@radix-ui/react-slot": "^1.2.3",
    "class-variance-authority": "^0.7.1",
    "clsx": "^2.1.1",
    "lucide-react": "^0.475.0",
    "tailwind-merge": "^3.3.0",
    "tailwindcss-animate": "^1.0.7"
  },
  "devDependencies": {
    "typescript": "^5.8.3",
    "@types/node": "^20.17.50",
    "@types/react": "^18.3.22",
    "@types/react-dom": "^18.3.7",
    "postcss": "^8.5.3",
    "tailwindcss": "^3.4.17",
    "eslint": "^9.27.0",
    "eslint-config-next": "15.1.7"
  }
}
EOF

    # 创建 Next.js 配置
    cat > next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    unoptimized: true,
    domains: [
      "source.unsplash.com",
      "images.unsplash.com",
      "ext.same-assets.com",
      "ugc.same-assets.com",
    ],
    remotePatterns: [
      {
        protocol: "https",
        hostname: "source.unsplash.com",
        pathname: "/**",
      },
      {
        protocol: "https",
        hostname: "images.unsplash.com",
        pathname: "/**",
      },
      {
        protocol: "https",
        hostname: "ext.same-assets.com",
        pathname: "/**",
      },
      {
        protocol: "https",
        hostname: "ugc.same-assets.com",
        pathname: "/**",
      },
    ],
  },
};

module.exports = nextConfig;
EOF

    # 创建 Tailwind 配置
    cat > tailwind.config.ts << 'EOF'
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: ["class"],
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  prefix: "",
  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: {
        "2xl": "1400px",
      },
    },
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: "0" },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
} satisfies Config;

export default config;
EOF

    # 创建 TypeScript 配置
    cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "lib": ["dom", "dom.iterable", "es6"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

    # 创建应用目录结构
    mkdir -p app components/lib

    show_info "✓ 项目结构创建完成"
}

# 创建主页面
create_main_page() {
    show_step "创建主页面..."
    
    # 创建全局样式
    cat > app/globals.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    --primary: 222.2 47.4% 11.2%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96%;
    --secondary-foreground: 222.2 84% 4.9%;
    --muted: 210 40% 96%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96%;
    --accent-foreground: 222.2 84% 4.9%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 222.2 84% 4.9%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 222.2 84% 4.9%;
    --foreground: 210 40% 98%;
    --card: 222.2 84% 4.9%;
    --card-foreground: 210 40% 98%;
    --popover: 222.2 84% 4.9%;
    --popover-foreground: 210 40% 98%;
    --primary: 210 40% 98%;
    --primary-foreground: 222.2 47.4% 11.2%;
    --secondary: 217.2 32.6% 17.5%;
    --secondary-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 17.5%;
    --muted-foreground: 215 20.2% 65.1%;
    --accent: 217.2 32.6% 17.5%;
    --accent-foreground: 210 40% 98%;
    --destructive: 0 62.8% 30.6%;
    --destructive-foreground: 210 40% 98%;
    --border: 217.2 32.6% 17.5%;
    --input: 217.2 32.6% 17.5%;
    --ring: 212.7 26.8% 83.9%;
  }
}

@layer base {
  * {
    @apply border-border;
  }
  body {
    @apply bg-background text-foreground;
  }
}
EOF

    # 创建根布局
    cat > app/layout.tsx << 'EOF'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Classic Football Shirts",
  description: "Vintage and classic football shirts collection",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        {children}
      </body>
    </html>
  );
}
EOF

    # 创建主页面
    cat > app/page.tsx << 'EOF'
export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <div className="container mx-auto px-4 py-8">
        <div className="text-center">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Classic Football Shirts
          </h1>
          <p className="text-xl text-gray-600 mb-8">
            Your gateway to vintage football jersey collections
          </p>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto">
            <div className="bg-white rounded-lg shadow-lg p-6 hover:shadow-xl transition-shadow">
              <div className="w-24 h-24 bg-red-600 rounded-full mx-auto mb-4 flex items-center justify-center">
                <span className="text-white text-2xl font-bold">MU</span>
              </div>
              <h3 className="text-lg font-semibold mb-2">Manchester United</h3>
              <p className="text-gray-600">Classic retro shirts from the Red Devils</p>
            </div>
            
            <div className="bg-white rounded-lg shadow-lg p-6 hover:shadow-xl transition-shadow">
              <div className="w-24 h-24 bg-blue-600 rounded-full mx-auto mb-4 flex items-center justify-center">
                <span className="text-white text-2xl font-bold">FCB</span>
              </div>
              <h3 className="text-lg font-semibold mb-2">Barcelona</h3>
              <p className="text-gray-600">Blaugrana vintage collection</p>
            </div>
            
            <div className="bg-white rounded-lg shadow-lg p-6 hover:shadow-xl transition-shadow">
              <div className="w-24 h-24 bg-red-800 rounded-full mx-auto mb-4 flex items-center justify-center">
                <span className="text-white text-2xl font-bold">ACM</span>
              </div>
              <h3 className="text-lg font-semibold mb-2">AC Milan</h3>
              <p className="text-gray-600">Rossoneri classic jerseys</p>
            </div>
          </div>
          
          <div className="mt-12">
            <div className="bg-white rounded-lg shadow-lg p-8">
              <h2 className="text-2xl font-bold mb-4 text-center">Welcome to Classic Football</h2>
              <p className="text-gray-600 text-center mb-6">
                Explore our collection of vintage football shirts from the greatest teams in history.
                Each jersey tells a story of glory, passion, and football heritage.
              </p>
              <div className="text-center">
                <button className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 px-6 rounded-lg transition-colors">
                  Explore Collection
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
EOF

    show_info "✓ 主页面创建完成"
}

# 安装依赖并构建
install_and_build() {
    show_step "安装依赖并构建项目..."
    
    cd /var/www/classic-football-shirts
    
    # 安装依赖
    npm install
    
    if [ $? -ne 0 ]; then
        echo "依赖安装失败，请检查网络连接"
        return 1
    fi
    
    # 构建项目
    npm run build
    
    if [ $? -ne 0 ]; then
        echo "项目构建失败"
        return 1
    fi
    
    show_info "✓ 项目构建完成"
}

# 配置 PM2
setup_pm2() {
    show_step "配置 PM2..."
    
    cd /var/www/classic-football-shirts
    
    # 停止现有进程
    pm2 delete all 2>/dev/null || true
    
    # 启动应用
    pm2 start npm --name "classic-football" -- start
    
    # 等待启动
    sleep 10
    
    # 保存配置
    pm2 save
    pm2 startup
    
    show_info "✓ PM2 配置完成"
}

# 验证部署
verify_deployment() {
    show_step "验证部署..."
    
    # 等待服务启动
    sleep 15
    
    # 检查 PM2 状态
    if pm2 list | grep -q "classic-football.*online"; then
        show_info "✓ 应用运行正常"
    else
        echo "PM2 状态："
        pm2 list
        return 1
    fi
    
    # 测试访问
    if curl -s http://localhost:3000 >/dev/null; then
        show_info "✓ 网站访问成功"
    else
        echo "网站访问测试失败"
        return 1
    fi
}

# 显示访问信息
show_access_info() {
    SERVER_IP="192.168.1.107"
    
    echo ""
    echo "=============================================="
    show_info "Classic Football 测试网站部署完成！"
    echo ""
    echo "🌐 访问地址："
    echo "  本机访问: http://localhost:3000"
    echo "  局域网访问: http://$SERVER_IP:3000"
    echo "  Nginx代理: http://$SERVER_IP"
    echo ""
    echo "📱 移动访问："
    echo "  手机浏览器: http://$SERVER_IP:3000"
    echo ""
    echo "🔧 管理命令："
    echo "  pm2 list"
    echo "  pm2 logs classic-football"
    echo "  pm2 restart classic-football"
    echo "=============================================="
}

# 主执行逻辑
show_info "创建 Classic Football 测试网站..."

# 检查权限
check_permissions

# 创建项目
create_project_structure
create_main_page
install_and_build
setup_pm2
verify_deployment
show_access_info

echo ""
show_info "🎉 测试网站部署完成！"
echo "访问 http://192.168.1.107:3000 查看网站"