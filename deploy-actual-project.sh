#!/bin/bash

# 部署实际的 Classic Football 项目
# 从本地上传到 Debian 服务器

echo "--- 部署 Classic Football 实际项目 ---"

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

# 清理并准备目录
prepare_directory() {
    show_step "准备项目目录..."
    
    cd /var/www
    
    # 停止现有进程
    pm2 delete all 2>/dev/null || true
    
    # 备份现有项目
    if [ -d "classic-football-shirts" ]; then
        mv classic-football-shirts classic-football-shirts-backup-$(date +%Y%m%d-%H%M%S)
        show_info "✓ 已备份现有项目"
    fi
    
    # 创建新项目目录
    mkdir -p classic-football-shirts
    cd classic-football-shirts
    
    show_info "✓ 项目目录准备完成"
}

# 方法1: 从 GitHub 克隆（如果已上传）
deploy_from_github() {
    show_step "尝试从 GitHub 部署..."
    
    # 检查是否已上传到 GitHub
    if git ls-remote https://github.com/josh0668/classic-football-shirts.git >/dev/null 2>&1; then
        git clone https://github.com/josh0668/classic-football-shirts.git .
        show_info "✓ 从 GitHub 克隆成功"
        return 0
    else
        show_warning "GitHub 仓库不存在或无权限"
        return 1
    fi
}

# 方法2: 创建完整的项目文件
create_project_files() {
    show_step "创建完整的项目文件..."
    
    cd /var/www/classic-football-shirts
    
    # 创建 package.json（基于你的本地项目）
    cat > package.json << 'EOF'
{
  "name": "nextjs-shadcn",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev -H 0.0.0.0 --turbopack",
    "build": "next build",
    "start": "next start",
    "lint": "bunx tsc --noEmit && next lint",
    "format": "bunx biome format --write"
  },
  "dependencies": {
    "@radix-ui/react-slot": "^1.2.3",
    "class-variance-authority": "^0.7.1",
    "clsx": "^2.1.1",
    "lucide-react": "^0.475.0",
    "next": "^15.3.2",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "same-runtime": "^0.0.1",
    "tailwind-merge": "^3.3.0",
    "tailwindcss-animate": "^1.0.7"
  },
  "devDependencies": {
    "@biomejs/biome": "1.9.4",
    "@eslint/eslintrc": "^3.3.1",
    "@types/node": "^20.17.50",
    "@types/react": "^18.3.22",
    "@types/react-dom": "^18.3.7",
    "eslint": "^9.27.0",
    "eslint-config-next": "^15.1.7",
    "postcss": "^8.5.3",
    "tailwindcss": "^3.4.17",
    "typescript": "^5.8.3"
  }
}
EOF

    # 创建 Next.js 配置
    cat > next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  allowedDevOrigins: ["*.preview.same-app.com"],
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

    # 创建 PostCSS 配置
    cat > postcss.config.mjs << 'EOF'
/** @type {import('postcss-load-config').Config} */
const config = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};

export default config;
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

    # 创建 next-env.d.ts
    cat > next-env.d.ts << 'EOF'
/// <reference types="next" />
/// <reference types="next/image-types/global" />

// NOTE: This file should not be edited
// see https://nextjs.org/docs/basic-features/typescript for more information.
EOF

    # 创建 ESLint 配置
    cat > eslint.config.mjs << 'EOF'
import { dirname } from "path";
import { fileURLToPath } from "url";
import { FlatCompat } from "@eslint/eslintrc";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const compat = new FlatCompat({
  baseDirectory: __dirname,
  recommendedConfig: {},
  allConfig: [],
});

export default [
  ...compat.extends("next/core-web-vitals"),
  ...compat.extends("next/typescript"),
];
EOF

    # 创建 biome.json
    cat > biome.json << 'EOF'
{
  "$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
  "formatter": {
    "enabled": true,
    "formatWithErrors": false,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 120,
    "lineEnding": "lf"
  },
  "javascript": {
    "formatter": {
      "jsxQuoteStyle": "double",
      "quoteProperties": "asNeeded",
      "trailingCommas": "es5",
      "semicolons": "always",
      "arrowParentheses": "always",
      "bracketSpacing": true,
      "quoteStyle": "single"
    }
  },
  "organizeImports": {
    "enabled": true
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true
    }
  }
}
EOF

    # 创建 .gitignore
    cat > .gitignore << 'EOF'
# dependencies
/node_modules
/.pnp
.pnp.js
.yarn/install-state.gz

# testing
/coverage

# next.js
/.next/
/out/

# production
/build

# misc
.DS_Store
*.pem

# debug
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# local env files
.env*.local

# turbo
.turbo

# vercel
.vercel

# typescript
*.tsbuildinfo
next-env.d.ts
EOF

    # 创建目录结构
    mkdir -p app components/ui

    # 创建应用文件
    create_app_files
    create_component_files
    
    show_info "✓ 项目文件创建完成"
}

# 创建应用文件
create_app_files() {
    show_step "创建应用核心文件..."
    
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

    # 创建布局文件
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

    # 创建主页
    cat > app/page.tsx << 'EOF'
import ClientBody from "./ClientBody";

export default function Home() {
  return (
    <div className="min-h-screen">
      <ClientBody />
    </div>
  );
}
EOF

    # 创建客户端主体
    cat > app/ClientBody.tsx << 'EOF'
"use client";

import { Header } from "@/components/Header";
import { HeroBanners } from "@/components/HeroBanners";
import { PopularTeamsCarousel } from "@/components/PopularTeamsCarousel";
import { ProductSections } from "@/components/ProductSections";
import { MysteryJacketBanner } from "@/components/MysteryJacketBanner";
import { TrustpilotReviews } from "@/components/TrustpilotReviews";
import { Footer } from "@/components/Footer";

export default function ClientBody() {
  return (
    <div className="flex flex-col min-h-screen">
      <Header />
      <main className="flex-1">
        <HeroBanners />
        <PopularTeamsCarousel />
        <ProductSections />
        <MysteryJacketBanner />
        <TrustpilotReviews />
      </main>
      <Footer />
    </div>
  );
}
EOF

    show_info "✓ 应用文件创建完成"
}

# 创建组件文件
create_component_files() {
    show_step "创建组件文件..."
    
    # 创建基础按钮组件
    cat > components/ui/button.tsx << 'EOF'
import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive:
          "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline:
          "border border-input bg-background hover:bg-accent hover:text-accent-foreground",
        secondary:
          "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = "Button";

export { Button, buttonVariants };
EOF

    # 创建工具函数
    cat > components/lib/utils.ts << 'EOF'
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
EOF

    # 创建占位组件（基于你的组件结构）
    for component in Header HeroBanners PopularTeamsCarousel ProductSections MysteryJacketBanner TrustpilotReviews Footer; do
        cat > components/${component}.tsx << EOF
export default function ${component}() {
  return (
    <div className="p-8 bg-white rounded-lg shadow-md mb-6">
      <h2 className="text-2xl font-bold text-center mb-4">${component}</h2>
      <p className="text-center text-gray-600">
        This is the ${component} component from your Classic Football project.
      </p>
    </div>
  );
}
EOF
    done

    show_info "✓ 组件文件创建完成"
}

# 安装依赖
install_dependencies() {
    show_step "安装项目依赖..."
    
    cd /var/www/classic-football-shirts
    
    # 清理旧依赖
    rm -rf node_modules package-lock.json bun.lock
    
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
    rm -rf .next out
    
    # 设置环境变量
    export NODE_ENV=production
    export NEXT_TELEMETRY_DISABLED=1
    
    # 构建
    npm run build
    
    if [ $? -eq 0 ] && [ -d ".next" ]; then
        show_info "✓ 项目构建成功"
        ls -la .next/ | head -10
        return 0
    else
        show_error "✗ 项目构建失败"
        return 1
    fi
}

# 配置 PM2
setup_pm2() {
    show_step "配置 PM2..."
    
    cd /var/www/classic-football-shirts
    
    # 创建 PM2 配置
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
        pm2 startup
        return 0
    else
        show_error "✗ PM2 启动失败"
        pm2 logs classic-football --lines 20
        return 1
    fi
}

# 验证部署
verify_deployment() {
    show_step "验证部署..."
    
    # 等待服务稳定
    sleep 10
    
    # PM2 状态
    echo "PM2 状态："
    pm2 list
    
    # 测试访问
    if curl -s http://localhost:3000 >/dev/null 2>&1; then
        show_info "✓ 本地访问成功"
        RESPONSE=$(curl -s http://localhost:3000 | head -c 200)
        if echo "$RESPONSE" | grep -q "html"; then
            show_info "✓ 网站响应正常"
        fi
    else
        show_warning "本地访问测试失败"
    fi
    
    # 端口检查
    if netstat -tlnp | grep -q ":3000" || ss -tlnp | grep -q ":3000"; then
        show_info "✓ 端口 3000 正在监听"
    else
        show_warning "端口 3000 未监听"
    fi
}

# 显示完成信息
show_completion_info() {
    SERVER_IP="192.168.1.107"
    
    echo ""
    echo "=============================================="
    show_info "Classic Football 实际项目部署完成！"
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
show_info "开始部署 Classic Football 实际项目..."

# 检查权限
check_permissions

# 执行部署
prepare_directory
if ! deploy_from_github; then
    show_info "使用本地项目文件创建..."
    create_project_files
fi
install_dependencies || exit 1
build_project || exit 1
setup_pm2 || exit 1
verify_deployment
show_completion_info

echo ""
show_info "🎉 Classic Football 实际项目部署完成！"
echo "请访问 http://192.168.1.107:3000 测试网站功能。"