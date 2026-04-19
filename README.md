# Dotfiles

个人开发环境配置文件集合。

## 目录结构

```
.
├── ghostty/          # Ghostty 终端配置
│   └── config
├── claude/           # Claude Code 配置
│   └── statusline.sh
└── README.md
```

## 配置文件

### Ghostty

GPU 加速终端模拟器。

- 配置文件: `ghostty/config`
- 安装位置: `~/.config/ghostty/config`
- 特性: TokyoNight Moon 主题、JetBrains Mono Nerd Font、Vim 风格分屏导航、macOS 原生集成

### Claude Code

- `claude/statusline.sh` -- Powerline 风格状态栏，显示项目名、Git 状态、模型、Context 用量、成本

## 安装

```bash
# Ghostty（符号链接方式，推荐）
mkdir -p ~/.config/ghostty
ln -s $(pwd)/ghostty/config ~/.config/ghostty/config
```

## 链接

- [Ghostty](https://ghostty.org/) - 终端模拟器
