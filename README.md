# OpenClaw 自崩溃防护方案

## 概述
OpenClaw 自崩溃防护方案用于监控 OpenClaw 服务运行状态，在服务异常崩溃时自动重启，确保服务高可用。

## 功能特性
- ✅ 自动监控 OpenClaw gateway 服务状态
- ✅ 异常崩溃时秒级自动重启
- ✅ 基于 PM2 进程管理，稳定可靠
- ✅ 所有操作可回滚，无破坏性修改
- ✅ 内置多重安全检查，避免配置冲突
- ✅ 无需手动配置，一键安装

## 安装说明
### 前置要求
- 系统已安装 Node.js >= 16.x
- OpenClaw 已正常部署在 `/root/.openclaw` 目录

### 一键安装
```bash
chmod +x install.sh
./install.sh
```

## 回滚说明
如果安装后出现问题，可执行以下操作完全回滚：
```bash
./install.sh rollback
```

回滚会删除所有防护相关配置，恢复到安装前状态。

## 常用命令
```bash
# 查看防护服务运行状态
pm2 status openclaw-gateway

# 查看服务日志
pm2 logs openclaw-gateway

# 手动重启服务
pm2 restart openclaw-gateway

# 停止防护服务
pm2 stop openclaw-gateway
```

## 安全规范
1. 安装脚本会自动备份原有 PM2 配置
2. 仅修改 OpenClaw 相关的进程配置，不影响其他系统服务
3. 所有操作均有日志记录，可追溯
4. 回滚操作会完全删除所有新增配置，无残留
