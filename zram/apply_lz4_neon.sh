#!/bin/bash
# ================================================================
# apply_lz4_neon.sh
# Add ARM64 NEON conditional compilation for LZ4 decompression calls.
# Replaces version-specific patch files by matching patterns instead of fixed lines.
#
# Usage: run from the kernel source root directory (common/)
#   bash /path/to/apply_lz4_neon.sh
# Language: choose at startup, or set SCRIPT_LANG=en/zh to skip the prompt.
# ================================================================
set -euo pipefail

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

  if [ ! -t 0 ]; then
    SCRIPT_LANG="$(detect_script_lang)"
    export SCRIPT_LANG
    return 0
  fi

  echo "请选择语言 / Select language:" >&2
  echo "  1) 中文" >&2
  echo "  2) English" >&2
  local choice
  while true; do
    if ! read -r -p "#? " choice; then
      echo >&2
      echo "未收到输入，退出 / No input received; exiting." >&2
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
        echo "无效选项 / Invalid option" >&2
        ;;
    esac
  done
  export SCRIPT_LANG
}

text() {
  local key="$1"; shift
  case "${SCRIPT_LANG}:${key}" in
    zh:skip_missing) printf "跳过（不存在）: %s" "$1" ;;
    en:skip_missing) printf "Skipped (missing): %s" "$1" ;;
    zh:skip_patched) printf "跳过（已修补）: %s" "$1" ;;
    en:skip_patched) printf "Skipped (already patched): %s" "$1" ;;
    zh:patched) printf "已修补: %s" "$1" ;;
    en:patched) printf "Patched: %s" "$1" ;;
    zh:patch_failed) printf "::error::修补失败: %s" "$1" ;;
    en:patch_failed) printf "::error::Patch failed: %s" "$1" ;;
    zh:summary) printf "=== LZ4 NEON 补丁完成: %s 成功, %s 跳过, %s 失败 ===" "$1" "$2" "$3" ;;
    en:summary) printf "=== LZ4 NEON patch complete: %s patched, %s skipped, %s failed ===" "$1" "$2" "$3" ;;
    *) printf "%s" "$key" ;;
  esac
}

choose_script_lang

PATCHED=0
SKIPPED=0
FAILED=0

# Check whether the file has already been patched.
already_patched() {
  grep -q "LZ4_arm64_decompress_safe" "$1" 2>/dev/null
}

# ---- 1. crypto/lz4.c 和 crypto/lz4hc.c ----
# 模式一致：int out_len = LZ4_decompress_safe(src, dst, slen, *dlen);
for file in crypto/lz4.c crypto/lz4hc.c; do
  if [ ! -f "$file" ]; then
    echo "$(text skip_missing "$file")"; ((SKIPPED++)) || true; continue
  fi
  if already_patched "$file"; then
    echo "$(text skip_patched "$file")"; ((SKIPPED++)) || true; continue
  fi

  perl -i -pe '
    if (/int out_len = LZ4_decompress_safe\(src, dst, slen, \*dlen\);/) {
      $_ = "\tint out_len;\n\n"
         . "#if defined(CONFIG_ARM64) && defined(CONFIG_KERNEL_MODE_NEON)\n"
         . "\tout_len = LZ4_arm64_decompress_safe(src, dst, slen, *dlen, false);\n"
         . "#else\n"
         . "\tout_len = LZ4_decompress_safe(src, dst, slen, *dlen);\n"
         . "#endif\n";
    }
  ' "$file"

  if already_patched "$file"; then
    echo "$(text patched "$file")"; ((PATCHED++)) || true
  else
    echo "$(text patch_failed "$file")"; ((FAILED++)) || true
  fi
done

# ---- 2. fs/f2fs/compress.c ----
# 将 LZ4_decompress_safe(dic->cbuf->cdata, ...) 替换为条件编译版本
file="fs/f2fs/compress.c"
if [ ! -f "$file" ]; then
  echo "$(text skip_missing "$file")"; ((SKIPPED++)) || true
elif already_patched "$file"; then
  echo "$(text skip_patched "$file")"; ((SKIPPED++)) || true
else
  perl -i -0777 -pe '
    s{(\t)ret = LZ4_decompress_safe\(dic->cbuf->cdata, dic->rbuf,\s*\n\s*dic->clen, dic->rlen\);}
     {#if defined(CONFIG_ARM64) && defined(CONFIG_KERNEL_MODE_NEON)\n${1}ret = LZ4_arm64_decompress_safe(dic->cbuf->cdata, dic->rbuf,\n\t\t\t\t\t\tdic->clen, dic->rlen, false);\n#else\n${1}ret = LZ4_decompress_safe(dic->cbuf->cdata, dic->rbuf,\n\t\t\t\t\t\tdic->clen, dic->rlen, false);\n#endif}
  ' "$file"

  if already_patched "$file"; then
    echo "$(text patched "$file")"; ((PATCHED++)) || true
  else
    echo "$(text patch_failed "$file")"; ((FAILED++)) || true
  fi
fi

# ---- 3. fs/incfs/data_mgmt.c（部分内核版本才有） ----
file="fs/incfs/data_mgmt.c"
if [ ! -f "$file" ]; then
  echo "$(text skip_missing "$file")"; ((SKIPPED++)) || true
elif already_patched "$file"; then
  echo "$(text skip_patched "$file")"; ((SKIPPED++)) || true
else
  perl -i -0777 -pe '
    s{(\t+)result = LZ4_decompress_safe\(src\.data, dst\.data, src\.len,\s*\n\s*dst\.len\);}
     {#if defined(CONFIG_ARM64) && defined(CONFIG_KERNEL_MODE_NEON)\n${1}result = LZ4_arm64_decompress_safe(src.data, dst.data, src.len, dst.len, false);\n#else\n${1}result = LZ4_decompress_safe(src.data, dst.data, src.len, dst.len);\n#endif}
  ' "$file"

  if already_patched "$file"; then
    echo "$(text patched "$file")"; ((PATCHED++)) || true
  else
    echo "$(text patch_failed "$file")"; ((FAILED++)) || true
  fi
fi

echo ""
echo "$(text summary "$PATCHED" "$SKIPPED" "$FAILED")"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
