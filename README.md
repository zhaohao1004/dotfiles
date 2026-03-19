# 🏠 Dotfiles

个人开发环境配置文件集合

## 📁 目录结构

```
.
├── ghostty/          # Ghostty 终端配置
│   └── config
└── README.md
```

## 🔧 配置文件

### Ghostty Terminal

现代化的 GPU 加速终端模拟器。

- **配置文件**: `ghostty/config`
- **安装位置**: `~/.config/ghostty/config`

**特性**:
- TokyoNight Moon 主题
- JetBrains Mono Nerd Font 字体
- Vim 风格的分屏导航快捷键
- macOS 原生集成

**使用方法**:
```bash
# 创建配置目录
mkdir -p ~/.config/ghostty

# 复制配置文件（选择以下任一方式）

# 方式1: 创建符号链接（推荐，便于同步更新）
ln -s $(pwd)/ghostty/config ~/.config/ghostty/config

# 方式2: 直接复制
cp ghostty/config ~/.config/ghostty/config
```

## 📝 说明

这个仓库用于备份和同步我的开发环境配置。每个配置文件都经过精心调优，适合日常开发使用。

## 🔗 相关链接

- [Ghostty](https://ghostty.org/) - 现代化终端模拟器

---

💡 持续更新中...
