#!/usr/bin/env bash
set -euo pipefail

# ================== 配置 ==================
REPO="404-GCross/Kernel-Source_Pull"
TAG="all-kernel-sources-1"
BASE_RAW="https://github.com/${REPO}/releases/download/${TAG}"
OUTPUT_DIR="${OUTPUT_DIR:-${PWD}/kernel-sources}"
KEEP_TARBALL="${KEEP_TARBALL:-no}"
FLAT_OUTPUT="${FLAT_OUTPUT:-no}"

SPEEDTEST_FILE="speedtest.mp4"          # 实际大小 25.1 MB

MIRRORS=(
    "https://gh-proxy.com/"
    "https://gh.llkk.cc/"
    "https://gh.ddlc.top/"
    "https://hub.gitmirror.com/"
    "https://ghproxy.homeboyc.cn/"
    "https://ghproxy.com/"
    "https://gh.api.99988866.xyz/"
    "https://gh.con.sh/"
    "https://mirror.ghproxy.com/"
    "https://ghproxy.cc/"
)

declare -A VERSIONS=(
    ["android12-5.10"]="66 81 101 110 117 136 149 160 168 177 185 198 205 209 218 226 233 236 237 240 246 X"
    ["android13-5.15"]="74 78 94 104 119 123 137 144 148 149 151 153 167 170 178 180 185 189 194 X"
    ["android14-6.1"]="25 43 57 68 75 78 84 90 93 99 112 115 118 124 128 129 134 138 141 145 157 162 X"
    ["android15-6.6"]="50 56 57 58 66 77 82 87 89 92 98 102 118 127 X"
    ["android16-6.12"]="23 30 38 58"
)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

check_deps() {
    if ! command -v curl &>/dev/null; then
        echo -e "${YELLOW}需要 curl，正在安装...${NC}"
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y curl
        elif command -v yum &>/dev/null; then
            sudo yum install -y curl
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm curl
        else
            echo -e "${RED}请手动安装 curl${NC}"; exit 1
        fi
    fi
}

select_option() {
    local prompt="$1"; shift
    local opts=("$@")
    echo -e "${YELLOW}$prompt${NC}" >&2
    select opt in "${opts[@]}"; do
        if [[ -n "$opt" ]]; then echo "$opt"; return 0; fi
        echo -e "${RED}无效选项${NC}" >&2
    done
}

# 测速：下载 speedtest.mp4，计算平均速度（KB/s）和耗时，单源超时 30 秒
speed_test() {
    local mirror="$1"
    local url="${mirror}${BASE_RAW}/${SPEEDTEST_FILE}"
    local tmpfile=$(mktemp)
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
    curl -fSL --retry 3 --retry-delay 5 -# -o "$dest" "$url"
}

main() {
    check_deps

    # ---------- 选择版本 ----------
    IFS=$'\n' majors=($(for k in "${!VERSIONS[@]}"; do echo "$k"; done | sort))
    local major=$(select_option "选择内核大版本：" "${majors[@]}")

    IFS=' ' read -ra subs <<< "${VERSIONS[$major]}"
    local sub=$(select_option "选择小版本：" "${subs[@]}")

    local vid="${major}-${sub}"
    local sha="kernel-source-${vid}.tar.gz.sha256"
    echo -e "${GREEN}目标版本：${vid}${NC}"

    # ---------- 测速（单源 ≤ 30s） ----------
    echo -e "${YELLOW}是否对镜像源进行测速（单源最长 30 秒，约 25.1MB 测试文件）？(y/n) [n]:${NC}"
    read -r do_speedtest
    local speed_results=()

    if [[ "$do_speedtest" == "y" || "$do_speedtest" == "Y" ]]; then
        echo -e "${GREEN}正在测速（下载 speedtest.mp4），请稍候...${NC}"

        echo -n "  直连 ... "
        local direct_out
        direct_out=$(speed_test "")
        if [[ "$direct_out" == "FAIL" ]]; then
            echo -e "${RED}失败（超时或无法连接）${NC}"
        else
            local direct_speed=$(echo "$direct_out" | awk '{print $1}')
            local direct_time=$(echo "$direct_out" | awk '{print $2}')
            echo -e "${GREEN}${direct_speed} KB/s (${direct_time}s)${NC}"
            speed_results+=("$direct_speed $direct_time 直连（不使用镜像）")
        fi

        for mirror in "${MIRRORS[@]}"; do
            echo -n "  $mirror ... "
            local out
            out=$(speed_test "$mirror")
            if [[ "$out" == "FAIL" ]]; then
                echo -e "${RED}失败（超时或无法连接）${NC}"
            else
                local m_speed=$(echo "$out" | awk '{print $1}')
                local m_time=$(echo "$out" | awk '{print $2}')
                echo -e "${GREEN}${m_speed} KB/s (${m_time}s)${NC}"
                speed_results+=("$m_speed $m_time $mirror")
            fi
        done

        if [[ ${#speed_results[@]} -gt 0 ]]; then
            IFS=$'\n' sorted=($(sort -t' ' -k1 -rn <<< "${speed_results[*]}"))
            unset IFS

            echo -e "\n${GREEN}测速排名（速度越快越靠前）：${NC}"
            local idx=1
            local speed_opts=()
            for line in "${sorted[@]}"; do
                local sp=$(echo "$line" | awk '{print $1}')
                local tm=$(echo "$line" | awk '{print $2}')
                local nm=$(echo "$line" | cut -d' ' -f3-)
                speed_opts+=("${sp} KB/s (${tm}s) - ${nm}")
                printf "  %d) %s KB/s (%s s) - %s\n" "$idx" "$sp" "$tm" "$nm"
                idx=$((idx + 1))
            done
            speed_opts+=("自定义镜像（手动输入URL）")
            echo "  $idx) 自定义镜像（手动输入URL）"

            echo -e "${YELLOW}请根据测速结果选择下载源（输入序号）：${NC}"
            local selected=$(select_option "" "${speed_opts[@]}")

            if [[ "$selected" == "自定义镜像（手动输入URL）" ]]; then
                read -p "请输入镜像URL（示例：https://gh.llkk.cc/，留空则直连）： " custom_url
                if [[ -z "$custom_url" ]]; then MIRROR=""; else
                    [[ "$custom_url" != */ ]] && custom_url="${custom_url}/"
                    MIRROR="$custom_url"
                fi
            else
                local chosen_name=$(echo "$selected" | sed -E 's/^[0-9.]* KB\/s \([0-9.]*s\) - //')
                if [[ "$chosen_name" == "直连（不使用镜像）" ]]; then
                    MIRROR=""
                else
                    MIRROR="$chosen_name"
                fi
            fi
        else
            echo -e "${RED}所有源测速均失败（30秒内无法完成下载），将手动选择下载源。${NC}"
        fi
    fi

    if [[ -z "${MIRROR+x}" ]]; then
        local all_sources=("直连（不使用镜像）" "${MIRRORS[@]}" "自定义镜像（手动输入URL）")
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
    fi

    echo -e "${GREEN}使用源：${MIRROR:-直连}${NC}"

    # ---------- 下载、校验、合并、解压 ----------
    local tmpdir=$(mktemp -d -t kernel-dl-XXXXXX)
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
