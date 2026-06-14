#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

# A handy tool to launch CVD with local build or remote build.

# Constants
ACLOUD_PREBUILT="prebuilts/asuite/acloud/linux-x86/acloud"
OPT_SKIP_PRERUNCHECK='--skip-pre-run-check'
PRODUCT='aosp_cf_x86_64_phone'
# Color constants
#BOLD="$(tput bold)" # Unused
END="$(tput sgr0)"
GREEN="$(tput setaf 2)"
RED="$(tput setaf 198)"
YELLOW="$(tput setaf 3)"
# BLUE="$(tput setaf 34)" # Unused

SKIP_BUILD=false
GCOV=false
DEBUG=false
KASAN=false
EXTRA_OPTIONS=()

function print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script will build images and launch a Cuttlefish device."
    echo ""
    echo "Available options:"
    echo "  --skip-build          Skip the image build step. Will build by default if in repo."
    echo "  --gcov                Launch CVD with gcov enabled kernel"
    echo "  --debug               Launch CVD with debug enabled kernel"
    echo "  --kasan               Launch CVD with kasan enabled kernel"
    echo "  -pb <platform_build>, --platform-build=<platform_build>"
    echo "                        The platform build path. Can be a local path or a remote build"
    echo "                        as ab://<branch>/<build_target>/<build_id>."
    echo "                        If not specified, it will use the platform build in the local"
    echo "                        repo, or the default compatible platform build for the kernel."
    echo "  -sb <system_build>, --system-build=<system_build>"
    echo "                        The system build path for GSI testing. Can be a local path or"
    echo "                        remote build as ab://<branch>/<build_target>/<build_id>."
    echo "                        If not specified, no system build will be used."
    echo "  -kb <kernel_build>, --kernel-build=<kernel_build>"
    echo "                        The kernel build path. Can be a local path or a remote build"
    echo "                        as ab://<branch>/<build_target>/<build_id>."
    echo "                        If not specified, it will use the kernel in the local repo."
    echo "  --acloud-bin=<acloud_bin>"
    echo "                        The alternative alcoud binary path."
    echo "  --cf-product=<product_type>"
    echo "                        The alternative cuttlefish product type for local build."
    echo "                        Will use default aosp_cf_x86_64_phone if not specified."
    echo "  --acloud-arg=<acloud_arg>"
    echo "                        Additional acloud command arg. Can be repeated."
    echo "                        For example --acloud-arg=--local-instance to launch a local cvd."
    echo "  -h, --help            Display this help message and exit"
    echo ""
    echo "Examples:"
    echo "$0"
    echo "$0 --acloud-arg=--local-instance"
    echo "$0 -pb ab://git_main/aosp_cf_x86_64_phone-userdebug/latest"
    echo "$0 -pb ~/aosp-main/out/target/product/vsoc_x86_64/"
    echo "$0 -kb ~/android-mainline/out/virtual_device_x86_64/"
    echo ""
    exit 0
}

function parse_arg() {
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                print_help
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            -pb)
                shift
                if test $# -gt 0; then
                    PLATFORM_BUILD=$1
                else
                    print_error "platform build is not specified"
                fi
                shift
                ;;
            --platform-build=*)
                PLATFORM_BUILD=$(echo "$1" | sed -e "s/^[^=]*=//g")
                shift
                ;;
            -sb)
                shift
                if test $# -gt 0; then
                    SYSTEM_BUILD=$1
                else
                    print_error "system build is not specified"
                fi
                shift
                ;;
            --system-build=*)
                SYSTEM_BUILD=$(echo "$1" | sed -e "s/^[^=]*=//g")
                shift
                ;;
            -kb)
                shift
                if test $# -gt 0; then
                    KERNEL_BUILD=$1
                else
                    print_error "kernel build path is not specified"
                fi
                shift
                ;;
            --kernel-build=*)
                KERNEL_BUILD=$(echo "$1" | sed -e "s/^[^=]*=//g")
                shift
                ;;
            --acloud-arg=*)
                EXTRA_OPTIONS+=("$(echo "$1" | sed -e "s/^[^=]*=//g")") # Use array append syntax
                shift
                ;;
            --acloud-bin=*)
                ACLOUD_BIN=$(echo "$1" | sed -e "s/^[^=]*=//g")
                shift
                ;;
            --cf-product=*)
                PRODUCT=$(echo "$1" | sed -e "s/^[^=]*=//g")
                shift
                ;;
            --gcov)
                GCOV=true
                shift
                ;;
            --debug)
                DEBUG=true
                shift
                ;;
            --kasan)
                KASAN=true
                shift
                ;;
            *)
                print_error "Unsupported flag: $1" >&2
                ;;
        esac
    done
}

function adb_checker() {
    if ! which adb &> /dev/null; then
        print_error "adb not found!"
    fi
}

function create_kernel_build_cmd() {
    local cf_kernel_repo_root=$1
    local cf_kernel_version=$2

    local regex="((?<=android-)mainline|(\K\d+\.\d+(?=-stable)))|((?:android)\K\d+)"
    local android_version
    android_version=$(grep -oP "$regex" <(echo "$cf_kernel_version"))
    local build_cmd=""
    if [ -f "$cf_kernel_repo_root/common-modules/virtual-device/BUILD.bazel" ]; then
        # support android-mainline, android16, android15, android14, android13
        build_cmd+="tools/bazel run --config=fast"
        if [ "$GCOV" = true ]; then
            build_cmd+=" --gcov"
        fi
        if [ "$DEBUG" = true ]; then
            build_cmd+=" --debug"
        fi
        if [ "$KASAN" = true ]; then
            build_cmd+=" --kasan"
        fi
        build_cmd+=" //common-modules/virtual-device:virtual_device_x86_64_dist"
    elif [ -f "$cf_kernel_repo_root/build/build.sh" ]; then
        if [[ "$android_version" == "12" ]]; then
            build_cmd+="BUILD_CONFIG=common/build.config.gki.x86_64 build/build.sh"
            build_cmd+=" && "
            build_cmd+="BUILD_CONFIG=common-modules/virtual-device/build.config.virtual_device.x86_64 build/build.sh"
        elif [[ "$android_version" == "11" ]] || [[ "$android_version" == "4.19" ]]; then
            build_cmd+="BUILD_CONFIG=common/build.config.gki.x86_64 build/build.sh"
            build_cmd+=" && "
            build_cmd+="BUILD_CONFIG=common-modules/virtual-device/build.config.cuttlefish.x86_64 build/build.sh"
        else
            echo "The Kernel build $cf_kernel_version is not yet supported" >&2
            return 1
        fi
    else
        echo "The Kernel build $cf_kernel_version is not yet supported" >&2
        return 1
    fi

    echo "$build_cmd"
}

function create_kernel_build_path() {
    local cf_kernel_version=$1

    local regex="((?<=android-)mainline|(\K\d+\.\d+(?=-stable)))|((?:android)\K\d+)"
    local android_version
    android_version=$(grep -oP "$regex" <(echo "$cf_kernel_version"))
    if [ "$android_version" = "mainline" ] || greater_than_or_equal_to "$android_version" "14"; then
        # support android-mainline, android16, android15, android14
        echo "out/virtual_device_x86_64/dist"
    elif greater_than_or_equal_to "$android_version" "11" || [[ "$android_version" == "4.19" ]]; then
        # support android13, android12, android11, android-4.19-stable
        echo "out/$cf_kernel_version/dist"
    else
        echo "The version of this kernel build $cf_kernel_version is not supported yet" >&2
        return 1
    fi
}

function go_to_repo_root() {
    current_dir="$1"
    while [ ! -d ".repo" ] && [ "$current_dir" != "/" ]; do
        current_dir=$(dirname "$current_dir")  # Go up one directory
        cd "$current_dir" || print_error "Failed to cd to $current_dir"
    done
}

function greater_than_or_equal_to() {
    local num1="$1"
    local num2="$2"

    # This regex matches strings formatted as floating-point or integer numbers
    local num_regex="^[0]([\.][0-9]+)?$|^[1-9][0-9]*([\.][0-9]+)?$"
    if [[ ! "$num1" =~ $num_regex ]] || [[ ! "$num2" =~ $num_regex ]]; then
        return 1
    fi

    if [[ $(echo "$num1 >= $num2" | bc -l) -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

# Checks if target_path is within root_directory
function is_path_in_root() {
    local root_directory="$1"
    local target_path="$2"

    # expand the path variable, for example:
    # "~/Documents" becomes "/home/user/Documents"
    root_directory=$(eval echo "$root_directory")
    target_path=$(eval echo "$target_path")

    # remove the trailing slashes
    root_directory=$(realpath -m "$root_directory")
    target_path=$(realpath -m "$target_path")

    # handles the corner case, for example:
    # $root_directory="/home/user/Doc", $target_path="/home/user/Documents/"
    root_directory="${root_directory}/"

    if [[ "$target_path" = "$root_directory"* ]]; then
        return 0
    else
        return 1
    fi
}

function print_info() {
    echo "[$MY_NAME]: ${GREEN}$1${END}"
}

function print_warn() {
    echo "[$MY_NAME]: ${YELLOW}$1${END}"
}

function print_error() {
    echo -e "[$MY_NAME]: ${RED}$1${END}"
    cd "$OLD_PWD" || echo "Failed to cd to $OLD_PWD"
    exit 1
}

function set_platform_repo() {
    print_warn "Build target product '${TARGET_PRODUCT}' does not match expected '$1'"
    local lunch_cli="source build/envsetup.sh && lunch $1"
    if [ -f "build/release/release_configs/trunk_staging.textproto" ]; then
        lunch_cli+="-trunk_staging-userdebug"
    else
        lunch_cli+="-userdebug"
    fi
    print_info "Setup build environment with: $lunch_cli"
    eval "$lunch_cli"
}

function find_repo() {
    manifest_output=$(grep -e "superproject" -e "gs-pixel" -e "private/google-modules/soc/gs" \
    -e "kernel/common" -e "common-modules/virtual-device" .repo/manifests/default.xml)
    case "$manifest_output" in
        *platform/superproject*)
            PLATFORM_REPO_ROOT="$PWD"
            PLATFORM_VERSION=$(grep -e "platform/superproject" .repo/manifests/default.xml | \
            grep -oP 'revision="\K[^"]*')
            print_info "PLATFORM_REPO_ROOT=$PLATFORM_REPO_ROOT, PLATFORM_VERSION=$PLATFORM_VERSION"
            if [ -z "$PLATFORM_BUILD" ]; then
                PLATFORM_BUILD="$PLATFORM_REPO_ROOT"
            fi
            ;;
        *kernel/superproject*)
            if [[ "$manifest_output" == *common-modules/virtual-device* ]]; then
                CF_KERNEL_REPO_ROOT="$PWD"
                CF_KERNEL_VERSION=$(grep -e "common-modules/virtual-device" \
                .repo/manifests/default.xml | grep -oP 'revision="\K[^"]*')
                print_info "CF_KERNEL_REPO_ROOT=$CF_KERNEL_REPO_ROOT, CF_KERNEL_VERSION=$CF_KERNEL_VERSION"
                if [ -z "$KERNEL_BUILD" ]; then
                    output=$(create_kernel_build_path "$CF_KERNEL_VERSION" 2>&1)
                    if [[ $? -ne 0 ]]; then
                        print_error "$output"
                    fi
                    KERNEL_BUILD="${CF_KERNEL_REPO_ROOT}/$output"
                    print_info "KERNEL_BUILD=$KERNEL_BUILD"
                fi
            fi
            ;;
        *)
            print_warn "Unexpected manifest output. Could not determine repository type."
            ;;
    esac
}

function rebuild_platform() {
    build_cmd="m -j12"
    print_warn "Flag --skip-build is not set. Rebuilt images at $PWD with: $build_cmd"
    eval "$build_cmd"
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        if [ -f "${ANDROID_PRODUCT_OUT}/system.img" ]; then
            print_info "$build_cmd succeeded"
        else
            print_error "${ANDROID_PRODUCT_OUT}/system.img doesn't exist"
        fi
    else
        print_warn "$build_cmd returned exit_code $exit_code or ${ANDROID_PRODUCT_OUT}/system.img is not found"
        print_error "$build_cmd failed"
    fi
}

adb_checker

OLD_PWD=$PWD
MY_NAME=$0

parse_arg "$@"

FULL_COMMAND_PATH=$(dirname "$PWD/$0")
REPO_LIST_OUT=$(repo list 2>&1)
if [[ "$REPO_LIST_OUT" == "error"* ]]; then
    echo -e "[$MY_NAME]: ${RED}Current path $PWD is not in an Android repo. Change path to repo root.${END}"
    go_to_repo_root "$FULL_COMMAND_PATH"
    print_info "Changed path to $PWD"
else
    go_to_repo_root "$PWD"
fi

find_repo

if [ "$SKIP_BUILD" = false ] && [ -n "$PLATFORM_BUILD" ] && [[ "$PLATFORM_BUILD" != ab://* ]] \
&& [ -d "$PLATFORM_BUILD" ]; then
    # Check if PLATFORM_BUILD is an Android platform repo, if yes rebuild
    cd "$PLATFORM_BUILD" || print_error "Failed to cd to $PLATFORM_BUILD"
    PLATFORM_REPO_LIST_OUT=$(repo list 2>&1)
    if [[ "$PLATFORM_REPO_LIST_OUT" != "error"* ]]; then
        go_to_repo_root "$PWD"
        if [ -z "${TARGET_PRODUCT}" ] || [[ "${TARGET_PRODUCT}" != "$PRODUCT" ]]; then
            set_platform_repo "$PRODUCT"
            rebuild_platform
            PLATFORM_BUILD=${ANDROID_PRODUCT_OUT}
        fi
    fi
fi

if [ "$SKIP_BUILD" = false ] && [ -n "$SYSTEM_BUILD" ] && [[ "$SYSTEM_BUILD" != ab://* ]] \
&& [ -d "$SYSTEM_BUILD" ]; then
    # Get GSI build
    cd "$SYSTEM_BUILD" || print_error "Failed to cd to $SYSTEM_BUILD"
    SYSTEM_REPO_LIST_OUT=$(repo list 2>&1)
    if [[ "$SYSTEM_REPO_LIST_OUT" != "error"* ]]; then
        go_to_repo_root "$PWD"
        if [ -z "${TARGET_PRODUCT}" ] || [[ "${TARGET_PRODUCT}" != "aosp_x86_64" ]]; then
            set_platform_repo "aosp_x86_64"
            rebuild_platform
            SYSTEM_BUILD="${ANDROID_PRODUCT_OUT}/system.img"
        fi
    fi
fi

if [ "$SKIP_BUILD" = false ] && [ -n "$KERNEL_BUILD" ] && [[ "$KERNEL_BUILD" != ab://* ]]; then
    if [ -d "$CF_KERNEL_REPO_ROOT" ] && [ -n "$CF_KERNEL_VERSION" ] && is_path_in_root "$CF_KERNEL_REPO_ROOT" "$KERNEL_BUILD"; then
        # Support first-build in the local kernel repository
        target_path="$CF_KERNEL_REPO_ROOT"
    elif [ -d $KERNEL_BUILD ]; then
        target_path="$KERNEL_BUILD"
    else
        print_error "Built kernel not found. Either build the kernel or use the default kernel from the local repository"
    fi

    cd "$target_path" || print_error "Failed to cd to $target_path"
    KERNEL_REPO_LIST_OUT=$(repo list 2>&1)
    if [[ "$KERNEL_REPO_LIST_OUT" != "error"* ]]; then
        go_to_repo_root "$target_path"
        target_kernel_repo_root="$PWD"
        target_cf_kernel_version=$(grep -e "common-modules/virtual-device" \
        .repo/manifests/default.xml | grep -oP 'revision="\K[^"]*')

        print_info "target_kernel_repo_root=$target_kernel_repo_root, target_cf_kernel_version=$target_cf_kernel_version"

        output=$(create_kernel_build_cmd $PWD $target_cf_kernel_version 2>&1)
        if [[ $? -ne 0 ]]; then
            print_error "$output"
        fi
        build_cmd="$output"
        print_warn "Flag --skip-build is not set. Rebuild the kernel with: $build_cmd."
        eval "$build_cmd" && print_info "$build_cmd succeeded" || print_error "$build_cmd failed"
    else
        print_warn "Current path $PWD is not a valid Android repo, please ensure it contains the kernel"
    fi
fi

if [ -z "$ACLOUD_BIN" ] || ! [ -x "$ACLOUD_BIN" ]; then
    output=$(which acloud 2>&1)
    if [ -z "$output" ]; then
        print_info "Use acloud binary from $ACLOUD_PREBUILT"
        if [ -n "${PLATFORM_REPO_ROOT}" ]; then
            ACLOUD_PREBUILT="${PLATFORM_REPO_ROOT}/${ACLOUD_PREBUILT}"
        elif  [ -n "${CF_KERNEL_REPO_ROOT}" ]; then
            ACLOUD_PREBUILT="${CF_KERNEL_REPO_ROOT}/${ACLOUD_PREBUILT}"
        else
            print_error "Unable to determine repository root path from repo manifest"
        fi
        ACLOUD_BIN="$ACLOUD_PREBUILT"
    else
        print_info "Use acloud binary from $output"
        ACLOUD_BIN="$output"
    fi

    # Check if the newly found or prebuilt ACLOUD_BIN is executable
    if ! [ -x "$ACLOUD_BIN" ]; then
        print_error "$ACLOUD_BIN is not executable"
    fi
fi

acloud_cli="$ACLOUD_BIN create"
EXTRA_OPTIONS+=("$OPT_SKIP_PRERUNCHECK")

# Add in branch if not specified

if [ -z "$PLATFORM_BUILD" ]; then
    print_warn "Platform build is not specified, will use the latest aosp-main build."
    acloud_cli+=' --branch aosp-main'
elif [[ "$PLATFORM_BUILD" == ab://* ]]; then
    IFS='/' read -ra array <<< "$PLATFORM_BUILD"
    acloud_cli+=" --branch ${array[2]}"

    # Check if array[3] exists before using it
    if [ ${#array[@]} -ge 3 ] && [ -n "${array[3]}" ]; then
        acloud_cli+=" --build-target ${array[3]}"

        # Check if array[4] exists and is not 'latest' before using it
        if [ ${#array[@]} -ge 4 ] && [ -n "${array[4]}" ] && [ "${array[4]}" != 'latest' ]; then
            acloud_cli+=" --build-id ${array[4]}"
        fi
    fi
else
    acloud_cli+=" --local-image $PLATFORM_BUILD"
fi

if [ -z "$KERNEL_BUILD" ]; then
    print_warn "Flag --kernel-build is not set, will not launch Cuttlefish with different kernel."
elif [[ "$KERNEL_BUILD" == ab://* ]]; then
    IFS='/' read -ra array <<< "$KERNEL_BUILD"
    acloud_cli+=" --kernel-branch ${array[2]}"

    # Check if array[3] exists before using it
    if [ ${#array[@]} -ge 3 ] && [ -n "${array[3]}" ]; then
        acloud_cli+=" --kernel-build-target ${array[3]}"

        # Check if array[4] exists and is not 'latest' before using it
        if [ ${#array[@]} -ge 4 ] && [ -n "${array[4]}" ] && [ "${array[4]}" != 'latest' ]; then
            acloud_cli+=" --kernel-build-id ${array[4]}"
        fi
    fi
else
    acloud_cli+=" --local-kernel-image $KERNEL_BUILD"
fi

if [ -z "$SYSTEM_BUILD" ]; then
    print_warn "System build is not specified, will not launch Cuttlefish with GSI mixed build."
elif [[ "$SYSTEM_BUILD" == ab://* ]]; then
    IFS='/' read -ra array <<< "$SYSTEM_BUILD"
    acloud_cli+=" --system-branch ${array[2]}"

     # Check if array[3] exists before using it
    if [ ${#array[@]} -ge 3 ] && [ -n "${array[3]}" ]; then
        acloud_cli+=" --system-build-target ${array[3]}"

        # Check if array[4] exists and is not 'latest' before using it
        if [ ${#array[@]} -ge 4 ] && [ -n "${array[4]}" ] && [ "${array[4]}" != 'latest' ]; then
            acloud_cli+=" --system-build-id ${array[4]}"
        fi
    fi
else
    acloud_cli+=" --local-system-image $SYSTEM_BUILD"
fi

acloud_cli+=" ${EXTRA_OPTIONS[*]}"
print_info "Launch CVD with command: $acloud_cli"
eval "$acloud_cli"
