#!/usr/bin/env sh
# Boidwatch CLI installer.
#
# Usage:
#   curl -fsSL https://boidwatch.com/install.sh | sh
#   curl -fsSL https://boidwatch.com/install.sh | BOIDWATCH_VERSION=v1.2.3 sh
#   curl -fsSL https://boidwatch.com/install.sh | BOIDWATCH_INSTALL_DIR=/usr/local/bin sh
#
# Detects OS/arch, downloads the matching tarball from GitHub Releases,
# verifies its SHA-256 against the published checksums.txt, and installs
# the `boidwatch` binary into BOIDWATCH_INSTALL_DIR (defaults to
# /usr/local/bin or ~/.local/bin if /usr/local/bin is not writable).

set -eu

REPO="${BOIDWATCH_REPO:-boidwatch/cli}"
RELEASE_BASE="https://github.com/${REPO}/releases"

err() {
	printf 'install.sh: %s\n' "$*" >&2
	exit 1
}

require() {
	command -v "$1" >/dev/null 2>&1 || err "missing required command: $1"
}

detect_os() {
	uname_out=$(uname -s)
	case "$uname_out" in
		Linux) printf 'linux' ;;
		Darwin) printf 'darwin' ;;
		MINGW*|MSYS*|CYGWIN*) err "Windows is not installed via this script. Use Scoop or download the .zip from ${RELEASE_BASE}." ;;
		*) err "unsupported OS: $uname_out" ;;
	esac
}

detect_arch() {
	uname_out=$(uname -m)
	case "$uname_out" in
		x86_64|amd64) printf 'x86_64' ;;
		arm64|aarch64) printf 'arm64' ;;
		*) err "unsupported architecture: $uname_out" ;;
	esac
}

resolve_version() {
	if [ -n "${BOIDWATCH_VERSION:-}" ]; then
		printf '%s' "$BOIDWATCH_VERSION"
		return
	fi
	require curl
	tag=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
		| sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' \
		| head -n 1)
	if [ -z "$tag" ]; then
		err "could not determine latest release tag from GitHub. Set BOIDWATCH_VERSION explicitly."
	fi
	printf '%s' "$tag"
}

resolve_install_dir() {
	if [ -n "${BOIDWATCH_INSTALL_DIR:-}" ]; then
		printf '%s' "$BOIDWATCH_INSTALL_DIR"
		return
	fi
	if [ -w /usr/local/bin ] 2>/dev/null; then
		printf '/usr/local/bin'
		return
	fi
	if [ -d /usr/local/bin ] && [ "$(id -u)" = "0" ]; then
		printf '/usr/local/bin'
		return
	fi
	printf '%s/.local/bin' "$HOME"
}

verify_sha256() {
	file="$1"
	expected="$2"
	if command -v sha256sum >/dev/null 2>&1; then
		actual=$(sha256sum "$file" | awk '{print $1}')
	elif command -v shasum >/dev/null 2>&1; then
		actual=$(shasum -a 256 "$file" | awk '{print $1}')
	else
		err "neither sha256sum nor shasum is available; cannot verify checksum"
	fi
	if [ "$actual" != "$expected" ]; then
		err "checksum mismatch: expected $expected, got $actual"
	fi
}

main() {
	require curl
	require tar

	os=$(detect_os)
	arch=$(detect_arch)
	version=$(resolve_version)
	install_dir=$(resolve_install_dir)

	# Strip leading 'v' from version for archive filename.
	plain_version=${version#v}
	archive="boidwatch_${plain_version}_${os}_${arch}.tar.gz"
	archive_url="${RELEASE_BASE}/download/${version}/${archive}"
	checksums_url="${RELEASE_BASE}/download/${version}/checksums.txt"

	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT

	printf 'install.sh: downloading %s\n' "$archive_url" >&2
	curl -fsSL -o "${tmp}/${archive}" "$archive_url" \
		|| err "failed to download $archive_url"

	curl -fsSL -o "${tmp}/checksums.txt" "$checksums_url" \
		|| err "failed to download $checksums_url"

	expected_sha=$(grep " ${archive}\$" "${tmp}/checksums.txt" | awk '{print $1}')
	if [ -z "$expected_sha" ]; then
		err "could not find ${archive} entry in checksums.txt"
	fi
	verify_sha256 "${tmp}/${archive}" "$expected_sha"

	tar -xzf "${tmp}/${archive}" -C "$tmp"
	if [ ! -x "${tmp}/boidwatch" ]; then
		err "extracted archive does not contain a boidwatch binary"
	fi

	mkdir -p "$install_dir"
	if ! mv -f "${tmp}/boidwatch" "${install_dir}/boidwatch" 2>/dev/null; then
		if command -v sudo >/dev/null 2>&1; then
			printf 'install.sh: %s is not writable; retrying with sudo\n' "$install_dir" >&2
			sudo mv -f "${tmp}/boidwatch" "${install_dir}/boidwatch" \
				|| err "could not install to $install_dir"
		else
			err "$install_dir is not writable and sudo is unavailable; set BOIDWATCH_INSTALL_DIR to a writable path"
		fi
	fi

	printf 'install.sh: installed boidwatch %s to %s/boidwatch\n' "$version" "$install_dir"
	case ":${PATH}:" in
		*":${install_dir}:"*) ;;
		*) printf 'install.sh: NOTE: %s is not in your PATH. Add it to your shell profile.\n' "$install_dir" >&2 ;;
	esac

	"${install_dir}/boidwatch" version 2>/dev/null || true
}

main "$@"
