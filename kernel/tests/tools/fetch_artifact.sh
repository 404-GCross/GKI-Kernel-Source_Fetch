#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

# fetch_artifact .sh is a handy tool dedicated to download artifacts from ci.
# The fetch_artifact binary is needed for this script. Please see more info at:
#    go/fetch_artifact,
#    or
#    https://android.googlesource.com/tools/fetch_artifact/
# Will use x20 binary: /google/data/ro/projects/android/fetch_artifact by default.
# Can install fetch_artifact locally with:
# sudo glinux-add-repo android stable && \
# sudo apt update && \
# sudo apt install android-fetch-artifact#
#
DEFAULT_FETCH_ARTIFACT=/google/data/ro/projects/android/fetch_artifact
BOLD="$(tput bold)"
END="$(tput sgr0)"
GREEN="$(tput setaf 2)"
RED="$(tput setaf 198)"
YELLOW="$(tput setaf 3)"
BLUE="$(tput setaf 34)"

function print_info() {
    echo "[$MY_NAME]: ${GREEN}$1${END}"
}

function print_warn() {
    echo "[$MY_NAME]: ${YELLOW}$1${END}"
}

function print_error() {
    echo -e "[$MY_NAME]: ${RED}$1${END}"
    exit 1
}

function binary_checker() {
    if which fetch_artifact &> /dev/null; then
        FETCH_CMD="fetch_artifact"
    elif [ ! -z "${FETCH_ARTIFACT}" ] && [ -f "${FETCH_ARTIFACT}" ]; then
        FETCH_CMD="${FETCH_ARTIFACT}"
    elif [ -f "$DEFAULT_FETCH_ARTIFACT" ]; then
        FETCH_CMD="$DEFAULT_FETCH_ARTIFACT"
    else
        print_error "\n${RED} fetch_artifact is not found${END}"
        echo -e "\n${RED} Please see go/fetch_artifact${END} or
        https://android.googlesource.com/tools/fetch_artifact/+/refs/heads/main"
        exit 1
    fi
}


binary_checker

fetch_cli="$FETCH_CMD"

BUILD_INFO=
BUILD_FORMAT="ab://<branch>/<build_target>/<build_id>/<file_name>"
EXTRA_OPTIONS=

MY_NAME="${0##*/}"

for i in "$@"; do
    case $i in
        "ab://"*)
        BUILD_INFO=$i
        ;;
        *)
        EXTRA_OPTIONS+=" $i"
        ;;
    esac
done
if [ -z "$BUILD_INFO" ]; then
    print_error "$0 didn't come with the expected $BUILD_FORMAT"
fi

IFS='/' read -ra array <<< "$BUILD_INFO"
if [ ${#array[@]} -lt 6 ]; then
    print_error "Invalid build format: $BUILD_INFO. Needs to be: $BUILD_FORMAT"
elif [ ${#array[@]} -gt 7 ]; then
    print_error "Invalid TEST_DIR format: $BUILD_INFO. Needs to be: $BUILD_FORMAT"
else
    fetch_cli+=" --branch ${array[2]}"
    fetch_cli+=" --target ${array[3]}"
    if [[ "${array[4]}" != latest* ]]; then
        fetch_cli+=" --bid ${array[4]}"
    else
        fetch_cli+=" --latest"
    fi
    fetch_cli+="$EXTRA_OPTIONS"
    fetch_cli+=" '${array[5]}'"
fi

print_info "Run: $fetch_cli"
eval "$fetch_cli"
