#!/usr/bin/env bash
# install.sh - Installer for rtt (Ratatoskr)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Garkatronics-Labs/Ratatoskr/main/install.sh | bash
#
# Optional environment variables:
#   RTT_INSTALL_DIR   Installation directory (default: ~/.local/bin)
#   RTT_VERSION       Release tag to install (default: latest)

set -euo pipefail

REPO="Garkatronics-Labs/Ratatoskr"
BIN_NAME="rtt"
INSTALL_DIR="${RTT_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${RTT_VERSION:-latest}"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m==>\033[0m %s\n' "$1"; }
error() { printf '\033[1;31mError:\033[0m %s\n' "$1" >&2; exit 1; }

detect_platform() {
	os="$(uname -s)"
	arch="$(uname -m)"

	case "$os" in
		Linux)  os="linux" ;;
		Darwin) os="macos" ;;
		*) error "unsupported operating system: $os" ;;
	esac

	case "$arch" in
		x86_64|amd64) arch="amd64" ;;
		arm64|aarch64) arch="arm64" ;;
		*) error "unsupported architecture: $arch" ;;
	esac

	echo "${os}-${arch}"
}

build_url() {
	local platform="$1"
	if [ "$VERSION" = "latest" ]; then
		echo "https://github.com/${REPO}/releases/latest/download/${BIN_NAME}-${platform}"
	else
		echo "https://github.com/${REPO}/releases/download/${VERSION}/${BIN_NAME}-${platform}"
	fi
}

main() {
	platform="$(detect_platform)"
	url="$(build_url "$platform")"
	tmp_file="$(mktemp)"

	info "downloading ${BIN_NAME} (${platform}, ${VERSION})"

	if ! curl -fsSL -o "$tmp_file" "$url"; then
		rm -f "$tmp_file"
		error "failed to download binary from: $url"
	fi

	if ! file "$tmp_file" | grep -qE 'ELF|Mach-O'; then
		rm -f "$tmp_file"
		error "downloaded file is not a valid binary (does asset '${BIN_NAME}-${platform}' exist?)"
	fi

	mkdir -p "$INSTALL_DIR"
	install -m 755 "$tmp_file" "${INSTALL_DIR}/${BIN_NAME}"
	rm -f "$tmp_file"

	info "installed to ${INSTALL_DIR}/${BIN_NAME}"

	if ! echo ":$PATH:" | grep -q ":${INSTALL_DIR}:"; then
		warn "${INSTALL_DIR} is not in your PATH"
		shell_rc=""
		case "$(basename "${SHELL:-}")" in
			bash) shell_rc="$HOME/.bashrc" ;;
			zsh)  shell_rc="$HOME/.zshrc" ;;
			fish) shell_rc="$HOME/.config/fish/config.fish" ;;
		esac
		if [ -n "$shell_rc" ]; then
			warn "add this line to ${shell_rc}:"
		else
			warn "add this line to your shell config:"
		fi
		echo
		echo "    export PATH=\"${INSTALL_DIR}:\$PATH\""
		echo
	fi

	info "verify the install with: ${BIN_NAME} --version"
}

main "$@"
