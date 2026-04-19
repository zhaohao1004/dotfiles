#!/usr/bin/env bash

# Claude Code Powerline 状态栏
# 功能：实时显示项目信息、Git 状态、Context 使用情况和 Worktree 信息
# 风格：Powerline 分段设计，动态颜色，进度条可视化

set -euo pipefail # 严格模式

# 常量定义
readonly CACHE_TTL=5  # Git 信息缓存时间（秒）
readonly SCRIPT_NAME="statusline.sh"
readonly VERSION="1.0.0"

# Powerline 符号
readonly POWERLINE_SEPARATOR=""
readonly POWERLINE_SEPARATOR_R2L=""

# 256 色常量
readonly COLOR_BLUE=34
readonly COLOR_GREEN=28
readonly COLOR_YELLOW=220
readonly COLOR_RED=196
readonly COLOR_PURPLE=61
readonly COLOR_GRAY=236
readonly COLOR_WHITE=231
readonly COLOR_ORANGE=208

# 工具函数

# 错误日志（输出到 stderr）
log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] ERROR: $*" >&2
}

# 安全的 JSON 提取（带默认值）
safe_jq() {
    local key="$1"
    local default="${2:-}"
    echo "$input" | jq -r "${key} // \"${default}\"" 2>/dev/null || echo "$default"
}

# 获取缓存文件路径
get_cache_file() {
    local key="$1"
    local cache_dir="/tmp"
    local cache_key=$(echo "$key" | shasum -a 256 | cut -d' ' -f1)
    echo "${cache_dir}/claude-statusline-${cache_key}.cache"
}

# 从缓存读取（带过期检查）
read_cache() {
    local cache_file="$1"
    if [ -f "$cache_file" ]; then
        local cache_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
        if [ "$cache_age" -lt "$CACHE_TTL" ]; then
            cat "$cache_file" 2>/dev/null && return 0
        fi
    fi
    return 1
}

# 写入缓存
write_cache() {
    local cache_file="$1"
    local content="$2"
    echo "$content" > "$cache_file" 2>/dev/null || true
}

# 清理缓存（退出时调用）
cleanup() {
    # 可选：清理过期的缓存文件
    find /tmp -name "claude-statusline-*.cache" -mtime +1 -delete 2>/dev/null || true
}

# Powerline 渲染函数

# 全局变量：记住上一个分段的背景色
last_bg_color=""

# 渲染 Powerline 分段
# 参数: $1 文本内容, $2 背景色, $3 前景色
powerline_segment() {
    local text="$1"
    local bg_color="$2"
    local fg_color="$3"

    local output=""

    # 添加分隔符（使用上一段的背景色作为前景色）
    if [ -n "$last_bg_color" ]; then
        output+=$(printf '\033[48;5;%sm\033[38;5;%sm%s\033[0m' "$bg_color" "$last_bg_color" "$POWERLINE_SEPARATOR")
    fi

    # 添加内容（背景色 + 前景色）
    output+=$(printf '\033[48;5;%sm\033[38;5;%sm %s \033[0m' "$bg_color" "$fg_color" "$text")

    # 记住当前背景色
    last_bg_color="$bg_color"

    echo -n "$output"
}

# 渲染进度条
# 参数: $1 百分比（0-100）
render_progress_bar() {
    local pct="$1"
    local pct_int=${pct%.*}  # 取整数部分
    pct_int=${pct_int:-0}    # 默认值

    # 限制范围
    if [ "$pct_int" -lt 0 ]; then pct_int=0; fi
    if [ "$pct_int" -gt 100 ]; then pct_int=100; fi

    # 构建进度条（10 格）
    local filled=$((pct_int / 10))
    local empty=$((10 - filled))

    local bar=""
    if [ "$filled" -gt 0 ]; then
        bar+=$(printf '▓%.0s' $(seq 1 $filled 2>/dev/null) || printf '%*s' "$filled" | tr ' ' '▓')
    fi
    if [ "$empty" -gt 0 ]; then
        bar+=$(printf '░%.0s' $(seq 1 $empty 2>/dev/null) || printf '%*s' "$empty" | tr ' ' '░')
    fi

    echo "$bar"
}

# 根据 Context 使用百分比选择颜色
get_context_color() {
    local pct="$1"
    local pct_int=${pct%.*}
    pct_int=${pct_int:-0}

    if [ "$pct_int" -lt 40 ]; then
        echo "$COLOR_GREEN"
    elif [ "$pct_int" -lt 70 ]; then
        echo "$COLOR_YELLOW"
    else
        echo "$COLOR_RED"
    fi
}

# 信息获取函数

# 获取 Git 信息（带缓存）
build_git_segment() {
    local cwd="$1"
    local cache_file
    cache_file=$(get_cache_file "git-$cwd")

    # 尝试从缓存读取
    local cached_result
    if cached_result=$(read_cache "$cache_file"); then
        last_bg_color=""  # 重置背景色（因为缓存结果中已经包含了）
        echo -n "$cached_result"
        return
    fi

    # 检查是否是 Git 仓库
    if ! git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
        # 不是 Git 仓库，显示简单信息
        local result
        last_bg_color=""  # 重置以便正确渲染
        result=$(powerline_segment "not a repo" "$COLOR_GRAY" "248")
        write_cache "$cache_file" "$result"
        echo -n "$result"
        return
    fi

    # 获取分支名称
    local branch
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || echo "")

    # Detached HEAD 状态
    if [ -z "$branch" ]; then
        branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null || echo "detached")
    fi

    # 获取文件状态
    local modified=0
    local staged=0
    local untracked=0

    local status_output
    status_output=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null || echo "")

    if [ -n "$status_output" ]; then
        # 统计修改的文件
        modified=$(echo "$status_output" | grep -cE '^ M|^ M|^MM' 2>/dev/null || echo 0)
        modified=$(echo "$modified" | tr -d '[:space:]')
        # 统计已暂存的文件
        staged=$(echo "$status_output" | grep -cE '^[MADRC]' 2>/dev/null || echo 0)
        staged=$(echo "$staged" | tr -d '[:space:]')
        # 统计未跟踪的文件
        untracked=$(echo "$status_output" | grep -cE '^\?\?' 2>/dev/null || echo 0)
        untracked=$(echo "$untracked" | tr -d '[:space:]')
    fi

    # 构建状态文本
    local status_text="$branch"
    local total_changes=$((modified + staged + untracked))

    if [ "$total_changes" -eq 0 ]; then
        status_text="$branch ✓"  # 干净的工作区
    else
        status_text="$branch ⚡"
        [ "$modified" -gt 0 ] && status_text+=" M:$modified"
        [ "$staged" -gt 0 ] && status_text+=" S:$staged"
        [ "$untracked" -gt 0 ] && status_text+=" ?:$untracked"
    fi

    # 渲染分段
    local result
    last_bg_color=""  # 重置以便正确渲染
    result=$(powerline_segment "$status_text" "$COLOR_GREEN" "$COLOR_WHITE")

    # 缓存结果
    write_cache "$cache_file" "$result"

    echo -n "$result"
}

# 构建 Context 使用率分段
build_context_segment() {
    local used_pct="$1"
    local input_tokens="$2"
    local output_tokens="$3"

    # 提取整数部分
    local pct_int=${used_pct%.*}
    pct_int=${pct_int:-0}

    # 根据使用率选择颜色
    local bg_color
    bg_color=$(get_context_color "$pct_int")

    # 构建进度条
    local bar
    bar=$(render_progress_bar "$pct_int")

    # 构建显示文本
    local display_text="ctx ${bar} ${pct_int}%"

    # 可选：添加 token 数量（如果小于 1k 则省略）
    if [ -n "$input_tokens" ] && [ "$input_tokens" != "null" ] && [ "$input_tokens" != "0" ]; then
        local input_k=$((input_tokens / 1000))
        local output_k=$((output_tokens / 1000))
        if [ "$input_k" -gt 0 ]; then
            display_text+=" (${input_k}k"
            [ "$output_k" -gt 0 ] && display_text+="/${output_k}k"
            display_text+=")"
        fi
    fi

    # 渲染分段
    powerline_segment "$display_text" "$bg_color" "$COLOR_WHITE"
}

# 构建 Worktree 分段（如果存在）
build_worktree_segment() {
    local worktree_name="$1"

    if [ -z "$worktree_name" ] || [ "$worktree_name" = "null" ]; then
        return 0
    fi

    powerline_segment "wt: $worktree_name" "$COLOR_PURPLE" "$COLOR_WHITE"
}

# 构建模型信息分段
build_model_segment() {
    local model_name="$1"

    if [ -z "$model_name" ] || [ "$model_name" = "null" ]; then
        model_name="unknown"
    fi

    # 简化模型名称
    local short_name="$model_name"
    case "$model_name" in
        *claude-sonnet*) short_name="Sonnet" ;;
        *claude-opus*) short_name="Opus" ;;
        *claude-haiku*) short_name="Haiku" ;;
    esac

    powerline_segment "$short_name" "$COLOR_ORANGE" "$COLOR_WHITE"
}

# 构建成本分段
build_cost_segment() {
    local cost="$1"

    if [ -z "$cost" ] || [ "$cost" = "null" ]; then
        return 0
    fi

    # 格式化成本（保留 2 位小数）
    local formatted_cost
    formatted_cost=$(printf "%.2f" "$cost" 2>/dev/null || echo "0.00")

    # 如果成本大于 0 才显示
    if [ "$(echo "$formatted_cost > 0" | bc 2>/dev/null || echo 0)" -eq 1 ]; then
        powerline_segment "\$${formatted_cost}" "$COLOR_GRAY" "226"
    fi
}

# 主函数

build_statusline() {
    local input="$1"

    # 提取 JSON 数据
    local cwd model_name used_pct input_tokens output_tokens worktree_name cost

    cwd=$(safe_jq '.workspace.current_dir' '.')
    model_name=$(safe_jq '.model.display_name' 'unknown')
    used_pct=$(safe_jq '.context_window.used_percentage' '0')
    input_tokens=$(safe_jq '.context_window.current_usage.input_tokens' '0')
    output_tokens=$(safe_jq '.context_window.current_usage.output_tokens' '0')
    worktree_name=$(safe_jq '.worktree.name' '')
    cost=$(safe_jq '.cost.total_cost_usd' '0')

    # 重置背景色
    last_bg_color=""

    # 1. 项目名分段
    local project_name
    project_name=$(basename "$cwd" 2>/dev/null || echo "unknown")
    powerline_segment " $project_name" "$COLOR_BLUE" "$COLOR_WHITE"

    # 2. Git 信息分段
    build_git_segment "$cwd"

    # 3. Worktree 分段（可选）
    build_worktree_segment "$worktree_name"

    # 4. 模型信息分段
    build_model_segment "$model_name"

    # 5. Context 使用率分段
    build_context_segment "$used_pct" "$input_tokens" "$output_tokens"

    # 6. 成本分段（可选）
    build_cost_segment "$cost"

    # 结束分段（添加最后一个分隔符）
    if [ -n "$last_bg_color" ]; then
        printf '\033[0m\033[38;5;%sm%s\033[0m' "$last_bg_color" "$POWERLINE_SEPARATOR"
    fi

    echo ""  # 换行
}

# 主程序入口

main() {
    # 设置退出时清理
    trap cleanup EXIT

    # 读取 stdin 输入
    local input
    input=$(cat 2>/dev/null) || {
        # 如果读取失败，输出默认状态栏
        echo "claude-code-powerline-status"
        exit 0
    }

    # 检查输入是否为空
    if [ -z "$input" ]; then
        echo "claude-code-powerline-status"
        exit 0
    fi

    # 验证 JSON 格式
    if ! echo "$input" | jq empty 2>/dev/null; then
        log_error "Invalid JSON input"
        echo "claude-code-powerline-status (error)"
        exit 0
    fi

    # 构建状态栏
    build_statusline "$input"
}

# 执行主函数
main "$@"
