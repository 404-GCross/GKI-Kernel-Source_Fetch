#!/usr/bin/env bash
# ============================================================
# Script: fetch_kernel_source_no-extract.sh
# Purpose: Download GKI kernel source split archives from a fixed Release,
#          verify and merge them. By default, this keeps the .tar.gz file
#          without extracting it.
# Language: choose at startup, or set SCRIPT_LANG=en/zh to skip the prompt.
# Dependencies: curl, awk (gawk), sha256sum, tar
# ============================================================
set -euo pipefail

# -------------------- Fixed repository and tag --------------------
REPO="404-GCross/Kernel-Source_Pull"
TAG="all-kernel-sources-20260608-27112872553"
# --------------------------------------------------------

BASE_RAW="https://github.com/${REPO}/releases/download/${TAG}"
OUTPUT_DIR="${OUTPUT_DIR:-${PWD}/kernel-sources}"
KEEP_TARBALL="${KEEP_TARBALL:-yes}"          # Keep tar.gz by default when not extracting.
FLAT_OUTPUT="${FLAT_OUTPUT:-no}"             # Use flat output when extracting.
EXTRACT="${EXTRACT:-no}"                     # Extract archive. Default: no.

# Speed-test file
SPEEDTEST_URL="https://github.com/404-GCross/GKI-Kernel-Source_Fetch/releases/download/all-kernel-sources-1/speedtest.mp4"

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

detect_script_lang() {
    local requested="${SCRIPT_LANG:-auto}"
    case "$requested" in
        zh|zh_CN|zh-CN|cn|chinese) echo "zh" ;;
        en|en_US|en-US|english) echo "en" ;;
        auto|"")
            local locale="${LANGUAGE:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}"
            case "$locale" in
                zh*|zh_CN*|zh-CN*) echo "zh" ;;
                en*|en_US*|en-US*) echo "en" ;;
                *) echo "zh" ;;
            esac
            ;;
        *) echo "zh" ;;
    esac
}

SCRIPT_LANG="${SCRIPT_LANG:-}"

choose_script_lang() {
    case "${SCRIPT_LANG:-}" in
        zh|zh_CN|zh-CN|cn|chinese|en|en_US|en-US|english)
            SCRIPT_LANG="$(detect_script_lang)"
            export SCRIPT_LANG
            return 0
            ;;
    esac

    echo -e "${YELLOW}请选择语言 / Select language:${NC}" >&2
    echo "  1) 中文" >&2
    echo "  2) English" >&2
    local choice
    while true; do
        if ! read -r -p "#? " choice; then
            echo >&2
            echo -e "${RED}未收到输入，退出 / No input received; exiting.${NC}" >&2
            exit 1
        fi
        case "$choice" in
            1|zh|ZH|cn|CN|中文|中)
                SCRIPT_LANG="zh"
                break
                ;;
            2|en|EN|english|English)
                SCRIPT_LANG="en"
                break
                ;;
            *)
                echo -e "${RED}无效选项 / Invalid option${NC}" >&2
                ;;
        esac
    done
    export SCRIPT_LANG
}

text() {
    local key="$1"; shift
    case "${SCRIPT_LANG}:${key}" in
        zh:missing_deps) printf "缺少依赖: %s，正在尝试安装..." "$1" ;;
        en:missing_deps) printf "Missing dependencies: %s. Trying to install..." "$1" ;;
        zh:install_failed) printf "无法自动安装，请手动安装: %s" "$1" ;;
        en:install_failed) printf "Automatic installation failed. Please install manually: %s" "$1" ;;
        zh:invalid_option) printf "无效选项" ;;
        en:invalid_option) printf "Invalid option" ;;
        zh:no_input) printf "未收到输入，退出。" ;;
        en:no_input) printf "No input received; exiting." ;;
        zh:release_fetch_failed) printf "无法获取 Release 信息，请检查网络" ;;
        en:release_fetch_failed) printf "Failed to fetch Release metadata. Please check your network." ;;
        zh:lts_not_found) printf "未在 Release 中找到 %s 的 LTS 真实版本" "$1" ;;
        en:lts_not_found) printf "Could not find the real LTS version for %s in the Release assets" "$1" ;;
        zh:select_major) printf "选择内核大版本：" ;;
        en:select_major) printf "Select Android/kernel major version:" ;;
        zh:select_sub) printf "选择小版本：" ;;
        en:select_sub) printf "Select sublevel version:" ;;
        zh:resolving_lts) printf "正在获取 %s 的最新 LTS 版本号..." "$1" ;;
        en:resolving_lts) printf "Resolving the latest LTS version for %s..." "$1" ;;
        zh:resolve_lts_failed) printf "无法自动确定 LTS 版本，请重新选择或检查网络" ;;
        en:resolve_lts_failed) printf "Could not resolve the LTS version automatically. Select another version or check your network." ;;
        zh:lts_real_version) printf "LTS 真实版本：%s" "$1" ;;
        en:lts_real_version) printf "Resolved LTS version: %s" "$1" ;;
        zh:target_version) printf "目标版本：%s" "$1" ;;
        en:target_version) printf "Target version: %s" "$1" ;;
        zh:direct_source) printf "直连（不使用镜像）" ;;
        en:direct_source) printf "Direct GitHub (no mirror)" ;;
        zh:custom_source) printf "自定义镜像（手动输入URL）" ;;
        en:custom_source) printf "Custom mirror (enter URL manually)" ;;
        zh:select_source) printf "请选择下载源：" ;;
        en:select_source) printf "Select download source:" ;;
        zh:custom_url_prompt) printf "请输入镜像URL（示例：https://gh.llkk.cc/，留空则直连）： " ;;
        en:custom_url_prompt) printf "Enter mirror URL (example: https://gh.llkk.cc/; leave empty for direct GitHub): " ;;
        zh:speedtest_prompt) printf "是否对所选源进行测速（最长 30 秒，约 23 MB）？(y/n) [n]:" ;;
        en:speedtest_prompt) printf "Run a speed test for this source (up to 30s, about 23 MB)? (y/n) [n]:" ;;
        zh:direct_label) printf "直连" ;;
        en:direct_label) printf "Direct GitHub" ;;
        zh:speedtesting) printf "  测速 %s ... " "$1" ;;
        en:speedtesting) printf "  Testing %s ... " "$1" ;;
        zh:failed_timeout) printf "失败（超时或无法连接）" ;;
        en:failed_timeout) printf "Failed (timeout or connection error)" ;;
        zh:speedtest_failed_retry) printf "测速失败，请重新选择下载源" ;;
        en:speedtest_failed_retry) printf "Speed test failed. Please select another download source." ;;
        zh:use_source_prompt) printf "是否使用此源继续？(y/n) [y]:" ;;
        en:use_source_prompt) printf "Continue with this source? (y/n) [y]:" ;;
        zh:using_source) printf "使用源：%s" "$1" ;;
        en:using_source) printf "Using source: %s" "$1" ;;
        zh:download_checksum_step) printf "[1/5] 下载校验文件..." ;;
        en:download_checksum_step) printf "[1/5] Downloading checksum file..." ;;
        zh:download_checksum_failed) printf "下载校验文件失败，请更换下载源后重试" ;;
        en:download_checksum_failed) printf "Failed to download checksum file. Try another source and rerun." ;;
        zh:download_parts_step) printf "[2/5] 下载 %s 个分卷（进度条如下）..." "$1" ;;
        en:download_parts_step) printf "[2/5] Downloading %s split parts (progress shown below)..." "$1" ;;
        zh:download_failed) printf "下载失败" ;;
        en:download_failed) printf "Download failed" ;;
        zh:verify_step) printf "[3/5] 校验中..." ;;
        en:verify_step) printf "[3/5] Verifying checksums..." ;;
        zh:verify_failed) printf "校验失败，请重新运行" ;;
        en:verify_failed) printf "Checksum verification failed. Please rerun the script." ;;
        zh:verify_ok) printf "校验通过" ;;
        en:verify_ok) printf "Checksum verification passed" ;;
        zh:merge_step) printf "[4/5] 合并分卷 -> %s" "$1" ;;
        en:merge_step) printf "[4/5] Merging split parts -> %s" "$1" ;;
        zh:extract_step) printf "[5/5] 解压到 %s" "$1" ;;
        en:extract_step) printf "[5/5] Extracting to %s" "$1" ;;
        zh:keep_tarball) printf "保留压缩包：%s" "$1" ;;
        en:keep_tarball) printf "Kept tarball: %s" "$1" ;;
        zh:keep_tarball_step) printf "[5/5] 保留压缩包至 %s" "$1" ;;
        en:keep_tarball_step) printf "[5/5] Keeping tarball at %s" "$1" ;;
        zh:done) printf "===== 完成 =====" ;;
        en:done) printf "===== Done =====" ;;
        zh:source_path) printf "源码路径：%s" "$1" ;;
        en:source_path) printf "Source path: %s" "$1" ;;
        zh:archive_path) printf "压缩包路径：%s" "$1" ;;
        en:archive_path) printf "Archive path: %s" "$1" ;;
        zh:extract_hint) printf "如需解压，请设置环境变量 EXTRACT=yes 重新运行，或手动执行：" ;;
        en:extract_hint) printf "To extract it, rerun with EXTRACT=yes or run manually:" ;;
        zh:target_dir) printf "目标目录" ;;
        en:target_dir) printf "target-directory" ;;
        *) printf "%s" "$key" ;;
    esac
}

# Enhanced dependency check: ensure curl, awk, etc. exist.
check_deps() {
    local missing=()
    if ! command -v curl &>/dev/null; then missing+=("curl"); fi
    if ! command -v awk &>/dev/null; then missing+=("gawk"); fi
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}$(text missing_deps "${missing[*]}")${NC}"
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y ${missing[*]}
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y ${missing[*]}
        elif command -v yum &>/dev/null; then
            sudo yum install -y ${missing[*]}
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm ${missing[*]}
        else
            echo -e "${RED}$(text install_failed "${missing[*]}")${NC}"
            exit 1
        fi
    fi
}

# Ensure temporary files use disk space instead of tmpfs (WSL compatible).
mkdir -p "${TMPDIR:-$PWD/.tmp}"

select_option() {
    local prompt="$1"; shift
    local opts=("$@")
    if [[ -n "$prompt" ]]; then
        echo -e "${YELLOW}$prompt${NC}" >&2
    fi
    local idx=1
    for opt in "${opts[@]}"; do
        echo "  $idx) $opt" >&2
        ((idx++))
    done
    local choice
    while true; do
        if ! read -r -p "#? " choice; then
            echo >&2
            echo -e "${RED}$(text no_input)${NC}" >&2
            return 1
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#opts[@]} )); then
            echo "${opts[$((choice-1))]}"
            return 0
        fi
        echo -e "${RED}$(text invalid_option)${NC}" >&2
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
    curl -fSL --retry 3 --retry-delay 5 -# -o "$dest" "$url"
}

# Resolve the real LTS sublevel for a major version from Release assets.
resolve_lts_version() {
    local major="$1"   # Example: android12-5.10
    local api_url="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
    local tmpjson=$(mktemp --tmpdir="${TMPDIR:-$PWD/.tmp}")
    if ! curl -sL --retry 2 --connect-timeout 10 "$api_url" -o "$tmpjson"; then
        echo -e "${RED}$(text release_fetch_failed)${NC}"
        return 1
    fi
    # Parse asset names like kernel-source-android12-5.10-123.tar.gz.sha256.
    local real_sub
    real_sub=$(grep -o "kernel-source-${major}-[0-9]*\.tar\.gz\.sha256" "$tmpjson" | head -n1 | sed "s/kernel-source-${major}-//; s/\.tar\.gz\.sha256//")
    rm -f "$tmpjson"
    if [ -z "$real_sub" ]; then
        echo -e "${RED}$(text lts_not_found "$major")${NC}"
        return 1
    fi
    echo "$real_sub"
}

main() {
    choose_script_lang
    check_deps

    IFS=$'\n' majors=($(for k in "${!VERSIONS[@]}"; do echo "$k"; done | sort))
    local major
    major=$(select_option "$(text select_major)" "${majors[@]}") || exit 1

    IFS=' ' read -ra subs <<< "${VERSIONS[$major]}"
    local sub
    sub=$(select_option "$(text select_sub)" "${subs[@]}") || exit 1

    # Resolve the real sublevel if X is selected.
    if [[ "$sub" == "X" ]]; then
        echo -e "${YELLOW}$(text resolving_lts "$major")${NC}"
        local resolved
        resolved=$(resolve_lts_version "$major") || {
            echo -e "${RED}$(text resolve_lts_failed)${NC}"
            exit 1
        }
        echo -e "${GREEN}$(text lts_real_version "$resolved")${NC}"
        sub="$resolved"
    fi

    local vid="${major}-${sub}"
    local sha="kernel-source-${vid}.tar.gz.sha256"
    echo -e "${GREEN}$(text target_version "$vid")${NC}"

    local direct_source custom_source
    direct_source="$(text direct_source)"
    custom_source="$(text custom_source)"
    local all_sources=("$direct_source" "${MIRRORS[@]}" "$custom_source")
    while true; do
        echo -e "${YELLOW}$(text select_source)${NC}"
        local selected
        selected=$(select_option "" "${all_sources[@]}") || exit 1
        if [[ "$selected" == "$custom_source" ]]; then
            read -p "$(text custom_url_prompt)" custom_url
            if [[ -z "$custom_url" ]]; then MIRROR=""; else
                [[ "$custom_url" != */ ]] && custom_url="${custom_url}/"
                MIRROR="$custom_url"
            fi
        elif [[ "$selected" == "$direct_source" ]]; then
            MIRROR=""
        else
            MIRROR="$selected"
        fi

        local speed_fail=0
        echo -e "${YELLOW}$(text speedtest_prompt)${NC}"
        read -r do_speedtest
        if [[ "$do_speedtest" == "y" || "$do_speedtest" == "Y" ]]; then
            echo -n "$(text speedtesting "${MIRROR:-$(text direct_label)}")"
            local out=$(speed_test "$MIRROR")
            if [[ "$out" == "FAIL" ]]; then
                echo -e "${RED}$(text failed_timeout)${NC}"
                speed_fail=1
            else
                local sp=$(echo "$out" | awk '{print $1}')
                local tm=$(echo "$out" | awk '{print $2}')
                echo -e "${GREEN}${sp} KB/s (${tm}s)${NC}"
            fi
        fi

        if [[ "$speed_fail" -eq 1 ]]; then
            echo -e "${RED}$(text speedtest_failed_retry)${NC}"
        else
            echo -e "${YELLOW}$(text use_source_prompt)${NC}"
            read -r use_source
            if [[ "$use_source" != "n" && "$use_source" != "N" ]]; then
                break
            fi
        fi
    done

    echo -e "${GREEN}$(text using_source "${MIRROR:-$(text direct_label)}")${NC}"

    local tmpdir=$(mktemp -d --tmpdir="${TMPDIR:-$PWD/.tmp}" kernel-dl-XXXXXX)
    trap "rm -rf '$tmpdir'" EXIT

    echo -e "${GREEN}$(text download_checksum_step)${NC}"
    download "$sha" "$tmpdir/$sha" || {
        echo -e "${RED}$(text download_checksum_failed)${NC}"; exit 1
    }

    local parts=($(awk '{print $2}' "$tmpdir/$sha"))
    echo -e "${GREEN}$(text download_parts_step "${#parts[@]}")${NC}"
    for part in "${parts[@]}"; do
        echo -n "   -> "
        download "$part" "$tmpdir/$part" || {
            echo -e "${RED}$(text download_failed)${NC}"; exit 1
        }
    done

    echo -e "${GREEN}$(text verify_step)${NC}"
    (cd "$tmpdir" && sha256sum -c "$sha" --quiet) || {
        echo -e "${RED}$(text verify_failed)${NC}"; exit 1
    }
    echo -e "  ${GREEN}$(text verify_ok)${NC}"

    local tar="kernel-source-${vid}.tar.gz"
    echo -e "${GREEN}$(text merge_step "$tar")${NC}"
    cat "${parts[@]/#/$tmpdir/}" > "$tmpdir/$tar"

    # Decide whether to extract or keep the archive only.
    if [[ "$EXTRACT" == "yes" ]]; then
        local dest
        if [[ "$FLAT_OUTPUT" == "yes" ]]; then
            dest="$OUTPUT_DIR"
        else
            dest="${OUTPUT_DIR}/kernel-source-${vid}"
        fi
        mkdir -p "$dest"
        echo -e "${GREEN}$(text extract_step "$dest")${NC}"
        tar xzf "$tmpdir/$tar" -C "$dest"
        if [[ "$KEEP_TARBALL" == "yes" ]]; then
            mv "$tmpdir/$tar" "${OUTPUT_DIR}/"
            echo -e "  $(text keep_tarball "${OUTPUT_DIR}/$tar")"
        fi
        echo -e "\n${GREEN}$(text done)${NC}"
        echo -e "$(text source_path "$dest")"
    else
        # Keep archive only by default.
        mkdir -p "$OUTPUT_DIR"
        mv "$tmpdir/$tar" "$OUTPUT_DIR/"
        echo -e "${GREEN}$(text keep_tarball_step "${OUTPUT_DIR}/${tar}")${NC}"
        echo -e "\n${GREEN}$(text done)${NC}"
        echo -e "$(text archive_path "${OUTPUT_DIR}/${tar}")"
        echo -e "$(text extract_hint)"
        echo -e "  tar xzf ${OUTPUT_DIR}/${tar} -C $(text target_dir)"
    fi
}

main
