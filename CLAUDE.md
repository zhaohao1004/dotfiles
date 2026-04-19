# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

个人开发环境 dotfiles 仓库，用于备份和同步配置文件。使用 feature branch 工作流，通过 Pull Request 合并到 main。

## 目录结构

- `ghostty/config` — Ghostty 终端模拟器配置（主题、字体、快捷键、macOS 集成、SSH terminfo）
- `claude/statusline.sh` — Claude Code Powerline 状态栏脚本，从 stdin 读取 JSON，渲染项目名、Git 状态、模型名、Context 用量、成本等分段

## 安装

```bash
# Ghostty 配置（符号链接方式）
mkdir -p ~/.config/ghostty
ln -s $(pwd)/ghostty/config ~/.config/ghostty/config
```

`claude/statusline.sh` 需在 Claude Code 的 settings.json 中配置为 statusline 命令。脚本依赖 `jq` 和 `bc`。

## statusline.sh 关键设计

- Git 信息使用 `/tmp/claude-statusline-*.cache` 缓存，TTL 5 秒
- Context 用量颜色阈值：<40% 绿色，40-70% 黄色，>70% 红色
- 使用 256 色终端颜色 + Powerline 分隔符渲染
- 输入为 JSON（从 stdin 读取），需要 `jq` 解析

