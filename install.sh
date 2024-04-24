#!/bin/bash

# Http request CLI (per default use curl)
KCL_HTTP_REQUEST_CLI=curl


#
# Print green info message
# ========================
#
info() {
    local action="$1"
    local details="$2"
    command printf '\033[1;32m%12s\033[0m %s\n' "$action" "$details" 1>&2
}


error() {
    command printf '\033[1;31mError\033[0m: %s\n' "$1" 1>&2
}


#
# 
#
getSystemInfo() {
    ARCH=$(uname -m)
    case $ARCH in
        armv7*) ARCH="arm";;
        aarch64) ARCH="arm64";;
        x86_64) ARCH="amd64";;
    esac

    OS=$(echo `uname`|tr '[:upper:]' '[:lower:]')

    info "OS: $OS ARCH: $ARCH"
}


#
# Find a download tool
# ====================
#
checkHttpRequestCLI() {
    if type "curl" > /dev/null; then
        KCL_HTTP_REQUEST_CLI=curl
    elif type "wget" > /dev/null; then
        KCL_HTTP_REQUEST_CLI=wget
    else
        error "Either curl or wget is required"
        exit 1
    fi
}


#
# Get Latest Release for GITHUB_ORG and GITHUB_REPO
# =================================================
#
getLatestRelease() {
    local KCLReleaseUrl="https://api.github.com/repos/${GITHUB_ORG}/${GITHUB_REPO}/releases"
    local latest_release=""

    if [ "$KCL_HTTP_REQUEST_CLI" == "curl" ]; then
        latest_release=$(curl -s $KCLReleaseUrl | grep \"tag_name\" | grep -v rc | awk 'NR==1{print $2}' |  sed -n 's/\"\(.*\)\",/\1/p')
    else
        latest_release=$(wget -q --header="Accept: application/json" -O - $KCLReleaseUrl | grep \"tag_name\" | grep -v rc | awk 'NR==1{print $2}' |  sed -n 's/\"\(.*\)\",/\1/p')
    fi

    echo $latest_release
}


#
# download release from GitHub
# ============================
#
downloadFile() {
    local PREFIX=$1
    local LATEST_RELEASE_TAG=$2

    KCL_CLI_ARTIFACT="${PREFIX}-${LATEST_RELEASE_TAG}-${OS}-${ARCH}.tar.gz"
    DOWNLOAD_BASE="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download"
    DOWNLOAD_URL="${DOWNLOAD_BASE}/${LATEST_RELEASE_TAG}/${KCL_CLI_ARTIFACT}"

    # Create the temp directory
    KCL_TMP_ROOT=$(mktemp -dt kcl-install-XXXXXX)
    ARTIFACT_TMP_FILE="$KCL_TMP_ROOT/$KCL_CLI_ARTIFACT"

    info "Downloading $DOWNLOAD_URL ..."
    if [ "$KCL_HTTP_REQUEST_CLI" == "curl" ]; then
        curl -SsL "$DOWNLOAD_URL" -o "$ARTIFACT_TMP_FILE"
    else
        wget -q -O "$ARTIFACT_TMP_FILE" "$DOWNLOAD_URL"
    fi

    if [ ! -f "$ARTIFACT_TMP_FILE" ]; then
        error "Failed to download $DOWNLOAD_URL ..."
        exit 1
    else
        info "Scucessful to download $DOWNLOAD_URL"
    fi
}


#
# Install file to ~/bin
# =====================
#
installFile() {
    local FILE=$1

    tar xf $ARTIFACT_TMP_FILE -C $KCL_TMP_ROOT
    local tmp_kcl_folder=$KCL_TMP_ROOT
 
    if [ ! -f "$tmp_kcl_folder/$FILE" ]; then
        error "Failed to unpack $FILE executable."
        exit 1
    fi

    # Copy temp kcl folder into the target installation directory.
    info "Copy the $FILE from temp folder $tmp_kcl_folder into the target installation directory $HOME/bin"
    cp -f $tmp_kcl_folder/$FILE $HOME/bin
}



#
# Installs the KCL CLI
# ====================
#
install_cli() {
    # GitHub Organization and repo name to download release
    GITHUB_ORG=kcl-lang
    GITHUB_REPO=cli

    local LATEST_RELEASE=$(getLatestRelease)

    echo "Latest Release CLI: $LATEST_RELEASE"

    downloadFile kcl $LATEST_RELEASE
    installFile kcl
}


#
# Installs the KCL LSP
# ====================
#
install_lsp() {
    # GitHub Organization and repo name to download release
    GITHUB_ORG=kcl-lang
    GITHUB_REPO=kcl

    local LATEST_RELEASE=$(getLatestRelease)

    echo "Latest Release LSP: $LATEST_RELEASE"

    downloadFile kclvm $LATEST_RELEASE
    installFile kclvm/bin/kcl-language-server
}


getSystemInfo
checkHttpRequestCLI

# install CLI and KCL LSP
install_cli
install_lsp