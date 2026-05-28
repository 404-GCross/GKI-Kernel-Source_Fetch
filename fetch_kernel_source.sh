#!/usr/bin/env bash
# ============================================================
# 脚本: fetch_kernel_source.sh
# 功能: 从固定 Release 拉取 GKI 内核源码分卷，自动校验、合并、解压
# 支持镜像加速（可选），单源测速 ≤ 30 秒
# 依赖: aria2, curl, awk (gawk), sha256sum, tar
# ============================================================
set -euo pipefail

# -------------------- 固定仓库与标签 --------------------
REPO="404-GCross/Kernel-Source_Pull"
TAG="all-kernel-sources-20260527-26484777478"
# --------------------------------------------------------

BASE_RAW="https://github.com/${REPO}/releases/download/${TAG}"
OUTPUT_DIR="${OUTPUT_DIR:-${PWD}/kernel-sources}"
KEEP_TARBALL="${KEEP_TARBALL:-no}"
FLAT_OUTPUT="${FLAT_OUTPUT:-no}"

# 测速专用文件（使用 raw 链接）
SPEEDTEST_URL="https://raw.githubusercontent.com/404-GCross/GKI-Kernel-Source_Fetch/main/speedtest.mp4"

MIRRORS=(
    "https://gh-proxy.com/"
    "https://gh.llkk.cc/"
    "https://gh.ddlc.top/"
)

declare -A VERSIONS=(
    ["android12-5.10"]="66 81 101 110 117 136 149 160 168 177 185 198 205 209 218 226 233 236 237 240 246 X"
    ["android13-5.15"]="74 78 94 104 119 123 137 144 148 149 151 153 167 170 178 180 185 189 194 X"
    ["android14-6.1"]="25 43 57 68 75 78 84 90 93 99 112 115 118 124 128 129 134 138 141 145 157 162 X"
    ["android15-6.6"]="50 56 57 58 66 77 82 87 89 92 98 102 118 127 X"
    ["android16-6.12"]="23 30 38 58"
)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# 增强依赖检查：确保 curl、awk 等存在
check_deps() {
    local missing=()
    if ! command -v aria2c &>/dev/null; then missing+=("aria2"); fi
    if ! command -v curl &>/dev/null; then missing+=("curl"); fi
    if ! command -v awk &>/dev/null; then missing+=("gawk"); fi
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}缺少依赖: ${missing[*]}，正在尝试安装...${NC}"
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y ${missing[*]}
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y ${missing[*]}
        elif command -v yum &>/dev/null; then
            sudo yum install -y ${missing[*]}
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm ${missing[*]}
        else
            echo -e "${RED}无法自动安装，请手动安装: ${missing[*]}${NC}"
            exit 1
        fi
    fi
}

# 确保临时目录使用磁盘空间而非 tmpfs
mkdir -p "${TMPDIR:-$PWD/.tmp}"

select_option() {
    local prompt="$1"; shift
    local opts=("$@")
    echo -e "${YELLOW}$prompt${NC}" >&2
    local idx=1
    for opt in "${opts[@]}"; do
        echo "  $idx) $opt" >&2
        ((idx++))
    done
    local choice
    while true; do
        read -p "#? " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#opts[@]} )); then
            echo "${opts[$((choice-1))]}"
            return 0
        fi
        echo -e "${RED}无效选项${NC}" >&2
    done
}

speed_test() {
    local mirror="$1"
    local url="${mirror}${SPEEDTEST_URL}"
    local tmpfile=$(mktemp --tmpdir="${TMPDIR:-$PWD/.tmp}")
    local start end size duration speed
    start=$(date +%s.%N)
    if curl -fSL --retry 1 --connect-timeout 10 --max-time 30 -o "$tmpfile" "$url" 2>/dev/null; then
        end=$(date +%s.%N)
        size=$(stat -c%s "$tmpfile" 2>/dev/null || stat -f%z "$tmpfile" 2>/dev/null)
        duration=$(awk "BEGIN { printf \"%.2f\", $end - $start }")
        if [[ "$size" -gt 0 ]]; then
            speed=$(awk "BEGIN { printf \"%.1f\", $size / 1024 / $duration }")
        else
            speed="0.0"
        fi
        rm -f "$tmpfile"
        printf "%s %.2f" "$speed" "$duration"
    else
        rm -f "$tmpfile"
        echo "FAIL"
    fi
}

download() {
    local path="$1"
    local dest="$2"
    local url="${MIRROR}${BASE_RAW}/${path}"
    local dir=$(dirname "$dest")
    local fname=$(basename "$dest")
    aria2c -x 4 -s 4 --max-connection-per-server=4 \
        --retry-wait 5 --max-tries 3 \
        --show-console-readout=true --summary-interval=5 \
        -d "$dir" -o "$fname" "$url"
}

main() {
    check_deps

    IFS=$'\n' majors=($(for k in "${!VERSIONS[@]}"; do echo "$k"; done | sort))
    local major=$(select_option "选择内核大版本：" "${majors[@]}")

    IFS=' ' read -ra subs <<< "${VERSIONS[$major]}"
    local sub=$(select_option "选择小版本：" "${subs[@]}")

    local vid="${major}-${sub}"
    local sha="kernel-source-${vid}.tar.gz.sha256"
    echo -e "${GREEN}目标版本：${vid}${NC}"

    local all_sources=("直连（不使用镜像）" "${MIRRORS[@]}" "自定义镜像（手动输入URL）")
    while true; do
        echo -e "${YELLOW}请选择下载源：${NC}"
        local selected=$(select_option "" "${all_sources[@]}")
        if [[ "$selected" == "自定义镜像（手动输入URL）" ]]; then
            read -p "请输入镜像URL（示例：https://gh.llkk.cc/，留空则直连）： " custom_url
            if [[ -z "$custom_url" ]]; then MIRROR=""; else
                [[ "$custom_url" != */ ]] && custom_url="${custom_url}/"
                MIRROR="$custom_url"
            fi
        elif [[ "$selected" == "直连（不使用镜像）" ]]; then
            MIRROR=""
        else
            MIRROR="$selected"
        fi

        echo -e "${YELLOW}是否对所选源进行测速（最长 30 秒，约 23 MB）？(y/n) [n]:${NC}"
        read -r do_speedtest
        if [[ "$do_speedtest" == "y" || "$do_speedtest" == "Y" ]]; then
            echo -n "  测速 ${MIRROR:-直连} ... "
            local out=$(speed_test "$MIRROR")
            if [[ "$out" == "FAIL" ]]; then
                echo -e "${RED}失败（超时或无法连接）${NC}"
            else
                local sp=$(echo "$out" | awk '{print $1}')
                local tm=$(echo "$out" | awk '{print $2}')
                echo -e "${GREEN}${sp} KB/s (${tm}s)${NC}"
            fi
        fi

        echo -e "${YELLOW}是否使用此源继续？(y/n) [y]:${NC}"
        read -r use_source
        if [[ "$use_source" != "n" && "$use_source" != "N" ]]; then
            break
        fi
    done

    echo -e "${GREEN}使用源：${MIRROR:-直连}${NC}"

    local tmpdir=$(mktemp -d --tmpdir="${TMPDIR:-$PWD/.tmp}" kernel-dl-XXXXXX)
    trap "rm -rf '$tmpdir'" EXIT

    echo -e "${GREEN}[1/5] 下载校验文件...${NC}"
    download "$sha" "$tmpdir/$sha" || {
        echo -e "${RED}下载校验文件失败，请更换下载源后重试${NC}"; exit 1
    }

    local parts=($(awk '{print $2}' "$tmpdir/$sha"))
    echo -e "${GREEN}[2/5] 下载 ${#parts[@]} 个分卷（进度条如下）...${NC}"
    for part in "${parts[@]}"; do
        echo -n "   -> "
        download "$part" "$tmpdir/$part" || {
            echo -e "${RED}下载失败${NC}"; exit 1
        }
    done

    echo -e "${GREEN}[3/5] 校验中...${NC}"
    (cd "$tmpdir" && sha256sum -c "$sha" --quiet) || {
        echo -e "${RED}校验失败，请重新运行${NC}"; exit 1
    }
    echo -e "  ${GREEN}校验通过${NC}"

    local tar="kernel-source-${vid}.tar.gz"
    echo -e "${GREEN}[4/5] 合并分卷...${NC}"
    cat "${parts[@]/#/$tmpdir/}" > "$tmpdir/$tar"

    local dest
    if [[ "$FLAT_OUTPUT" == "yes" ]]; then
        dest="$OUTPUT_DIR"
    else
        dest="${OUTPUT_DIR}/kernel-source-${vid}"
    fi
    mkdir -p "$dest"
    echo -e "${GREEN}[5/5] 解压到 ${dest}${NC}"
    tar xzf "$tmpdir/$tar" -C "$dest"

    if [[ "$KEEP_TARBALL" == "yes" ]]; then
        mv "$tmpdir/$tar" "${OUTPUT_DIR}/"
        echo -e "  保留压缩包：${OUTPUT_DIR}/$tar"
    fi

    echo -e "\n${GREEN}===== 完成 =====${NC}"
    echo -e "源码路径：${dest}"
}

main
