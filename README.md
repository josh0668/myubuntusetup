# Ubuntu 设置脚本

这是一个用于 Ubuntu 系统的自动化设置脚本，用于安装和配置以下组件：

## 功能特性

- ✅ **QEMU Guest Agent** - 虚拟机增强工具
- ✅ **Docker Engine** - 容器化平台
- ✅ **Docker Compose** - 容器编排工具
- ✅ **镜像加速器** - 阿里云镜像加速配置

## 使用方法

1. 下载脚本：
```bash
wget https://raw.githubusercontent.com/josh0668/myubuntusetup/main/set.sh
```

2. 赋予执行权限：
```bash
chmod +x set.sh
```

3. 运行脚本：
```bash
./set.sh
```

## 系统要求

- Ubuntu 24.04 LTS 或更高版本
- 具有 sudo 权限的用户
- 稳定的网络连接

## 安装完成后

脚本会自动：
- 安装并启动 QEMU Guest Agent
- 安装 Docker Engine 和 Docker Compose
- 配置 Docker 镜像加速器（可选）
- 将当前用户添加到 docker 用户组

## 注意事项

安装完成后，需要执行以下操作之一使权限生效：
- 执行 `newgrp docker`（仅当前会话有效）
- 注销并重新登录
- 重启系统

## 验证安装

验证 Docker 是否正常工作：
```bash
docker run hello-world
```

验证 QEMU Guest Agent：
```bash
systemctl status qemu-guest-agent
```

---
*脚本由 josh0668 创建*