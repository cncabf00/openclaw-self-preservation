#!/bin/bash
set -euo pipefail

# OpenClaw 自崩溃防护一键安装脚本
# 安全规范：所有修改可回滚，无破坏性操作

# 配置变量
OPENCLAW_BIN="/usr/bin/openclaw"
OPENCLAW_WORKDIR="/root/.openclaw"
PM2_CONF_NAME="openclaw-gateway"
BACKUP_DIR="/root/.openclaw/backup/self-preservation-$(date +%Y%m%d%H%M%S)"
LOG_FILE="/var/log/openclaw-self-preservation-install.log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 安全检查
security_check() {
    log "=== 开始安全检查 ==="
    
    # 检查 OpenClaw 目录是否存在
    if [ ! -d "$OPENCLAW_WORKDIR" ]; then
        log "错误：OpenClaw 工作目录 $OPENCLAW_WORKDIR 不存在，请先安装 OpenClaw"
        exit 1
    fi
    
    # 检查 OpenClaw 可执行文件是否存在
    if [ ! -f "$OPENCLAW_BIN" ]; then
        log "错误：OpenClaw 可执行文件不存在，安装路径可能不正确"
        exit 1
    fi
    
    # 检查是否有足够权限
    if [ "$(id -u)" -ne 0 ]; then
        log "警告：当前非 root 用户，可能无法配置开机自启，建议使用 root 运行"
    fi
    
    log "✅ 安全检查通过"
}

# 安装依赖
install_dependencies() {
    log "=== 安装依赖 ==="
    
    # 检查 Node.js 是否安装
    if ! command -v node &> /dev/null; then
        log "错误：Node.js 未安装，请先安装 Node.js >= 16.x"
        exit 1
    fi
    
    # 检查 PM2 是否安装
    if ! command -v pm2 &> /dev/null; then
        log "PM2 未安装，开始安装 PM2..."
        npm install -g pm2
        log "✅ PM2 安装完成"
    else
        log "✅ PM2 已存在，版本：$(pm2 -v)"
    fi
}

# 备份现有配置
backup_existing() {
    log "=== 备份现有配置 ==="
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 备份现有的 PM2 openclaw-gateway 配置（如果存在）
    if pm2 status | grep -q "$PM2_CONF_NAME"; then
        log "检测到现有 $PM2_CONF_NAME 进程，正在备份配置..."
        pm2 save "$BACKUP_DIR/pm2-backup.json"
        log "✅ 现有配置已备份到 $BACKUP_DIR"
    else
        log "无现有 $PM2_CONF_NAME 进程，无需备份"
    fi
}

# 安装防护服务
install_service() {
    log "=== 安装自崩溃防护服务 ==="
    
    # 停止现有同名进程（如果存在）
    if pm2 status | grep -q "$PM2_CONF_NAME"; then
        log "停止现有 $PM2_CONF_NAME 进程..."
        pm2 delete "$PM2_CONF_NAME" > /dev/null 2>&1
    fi
    
    # 启动 OpenClaw gateway 服务通过 PM2
    log "启动 OpenClaw gateway 服务..."
    pm2 start "$OPENCLAW_BIN" --name "$PM2_CONF_NAME" --cwd "$OPENCLAW_WORKDIR" -- gateway start
    
    # 保存 PM2 配置
    pm2 save
    
    # 设置开机自启
    log "配置开机自启..."
    pm2 startup systemd -u root --hp /root || true
    
    log "✅ 自崩溃防护服务安装完成"
}

# 回滚操作
rollback() {
    log "=== 开始回滚操作 ==="
    
    # 停止并删除防护进程
    if pm2 status | grep -q "$PM2_CONF_NAME"; then
        log "停止并删除 $PM2_CONF_NAME 进程..."
        pm2 delete "$PM2_CONF_NAME" > /dev/null 2>&1
    fi
    
    # 恢复备份（如果有）
    if [ -d "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/pm2-backup.json" ]; then
        log "恢复原有 PM2 配置..."
        pm2 restore "$BACKUP_DIR/pm2-backup.json" > /dev/null 2>&1
        pm2 save
    fi
    
    # 移除开机自启配置（可选，不影响其他服务）
    pm2 unstartup systemd > /dev/null 2>&1 || true
    
    log "✅ 回滚完成，已恢复到安装前状态"
    exit 0
}

# 显示安装结果
show_result() {
    log "=== 安装成功 ==="
    echo ""
    echo "🎉 OpenClaw 自崩溃防护服务已安装完成！"
    echo ""
    echo "常用命令："
    echo "  pm2 status $PM2_CONF_NAME    # 查看服务状态"
    echo "  pm2 logs $PM2_CONF_NAME      # 查看服务日志"
    echo "  pm2 restart $PM2_CONF_NAME   # 手动重启服务"
    echo "  pm2 stop $PM2_CONF_NAME      # 停止防护服务"
    echo ""
    echo "如需回滚，执行：./install.sh rollback"
    echo ""
    log "安装日志已保存到 $LOG_FILE"
}

# 主流程
main() {
    # 检查是否是回滚操作
    if [ $# -eq 1 ] && [ "$1" = "rollback" ]; then
        rollback
    fi
    
    security_check
    install_dependencies
    backup_existing
    install_service
    show_result
}

main "$@"
