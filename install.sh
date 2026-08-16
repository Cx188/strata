#!/bin/sh

set -eu
umask 022

fail() {
  printf 'Strata installer: %s\n' "$1" >&2
  exit 1
}

ensure_directory() {
  directory="$1"
  description="$2"

  if [ -e "$directory" ] && [ ! -d "$directory" ]; then
    fail "$description path exists but is not a directory: $directory"
  fi
  if ! mkdir -p "$directory"; then
    fail "could not create $description directory: $directory"
  fi
  if [ ! -w "$directory" ]; then
    fail "$description directory is not writable: $directory"
  fi
}

if [ "$(uname -s)" != "Linux" ]; then
  printf '%s\n' 'This installer is for Linux. Use install.ps1 on Windows or download the macOS package from GitHub Releases.' >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  fail 'installation requires curl.'
fi

if ! command -v od >/dev/null 2>&1; then
  fail 'installation requires od to validate the AppImage.'
fi

case "$(uname -m)" in
  x86_64|amd64) ;;
  *)
    printf '%s\n' 'The current Strata Linux release is built for x86_64 systems.' >&2
    exit 1
    ;;
esac

if [ -z "${HOME:-}" ]; then
  fail 'HOME is not set for the current user.'
fi

default_install_dir="${HOME}/.local/opt/strata"
install_dir="${STRATA_INSTALL_DIR:-$default_install_dir}"

if [ -z "${STRATA_INSTALL_DIR:-}" ] && [ -r /dev/tty ]; then
  printf 'Install Strata to [%s]: ' "$default_install_dir" >/dev/tty
  chosen_install_dir=''
  IFS= read -r chosen_install_dir </dev/tty || true
  if [ -n "$chosen_install_dir" ]; then
    install_dir="$chosen_install_dir"
  fi
fi

case "$install_dir" in
  "~") install_dir="$HOME" ;;
  "~/"*) install_dir="${HOME}/${install_dir#~/}" ;;
esac

case "$install_dir" in
  /*) ;;
  *) install_dir="$(pwd)/$install_dir" ;;
esac

ensure_directory "$install_dir" 'installation'

latest_release_url="$(curl -fsSL \
  --retry 3 \
  --connect-timeout 10 \
  --max-time 60 \
  -o /dev/null \
  -w '%{url_effective}' \
  -H 'User-Agent: Strata-Linux-Installer' \
  'https://github.com/Cx188/strata/releases/latest')"
release_tag="${latest_release_url##*/}"

if ! printf '%s\n' "$release_tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  fail "GitHub returned an invalid latest release tag: $release_tag"
fi

release_version="${release_tag#v}"
appimage_name="Strata-Linux-x86_64-${release_version}.AppImage"
appimage_url="https://github.com/Cx188/strata/releases/download/${release_tag}/${appimage_name}"
checksums_url="https://github.com/Cx188/strata-updates/releases/download/${release_tag}/SHA256SUMS"

checksums="$(curl -fsSL \
  --retry 3 \
  --connect-timeout 10 \
  --max-time 60 \
  -H 'User-Agent: Strata-Linux-Installer' \
  "$checksums_url")"
expected_digest="$(printf '%s\n' "$checksums" | awk -v name="$appimage_name" '
  $2 == name && length($1) == 64 && $1 !~ /[^0-9a-fA-F]/ { print $1; exit }
')"

if [ -z "$expected_digest" ]; then
  fail "release $release_tag is missing a valid checksum for $appimage_name."
fi

temporary_appimage="$(mktemp "${TMPDIR:-/tmp}/strata-appimage.XXXXXX")"
cleanup() {
  rm -f "$temporary_appimage"
}
trap cleanup EXIT HUP INT TERM

printf '\n%s\n' 'Strata installer'
printf 'Destination: %s\n' "$install_dir"
printf '%s\n' 'Downloading the latest stable AppImage...'

curl -fL \
  --retry 3 \
  --connect-timeout 10 \
  --max-time 900 \
  -H 'Accept: application/octet-stream' \
  -H 'User-Agent: Strata-Linux-Installer' \
  "$appimage_url" \
  -o "$temporary_appimage"

printf '%s\n' 'Verifying download...'
if command -v sha256sum >/dev/null 2>&1; then
  actual_digest="$(sha256sum "$temporary_appimage" | awk '{ print $1 }')"
elif command -v shasum >/dev/null 2>&1; then
  actual_digest="$(shasum -a 256 "$temporary_appimage" | awk '{ print $1 }')"
else
  printf '%s\n' 'SHA-256 verification requires sha256sum or shasum.' >&2
  exit 1
fi

if [ "$(printf '%s' "$actual_digest" | tr 'A-F' 'a-f')" != "$(printf '%s' "$expected_digest" | tr 'A-F' 'a-f')" ]; then
  fail 'the downloaded AppImage failed SHA-256 verification. Nothing was installed.'
fi

elf_magic="$(od -An -tx1 -N4 "$temporary_appimage" | tr -d '[:space:]')"
elf_machine="$(dd if="$temporary_appimage" bs=1 skip=18 count=2 2>/dev/null | od -An -tx1 | tr -d '[:space:]')"
if [ "$elf_magic" != '7f454c46' ] || [ "$elf_machine" != '3e00' ]; then
  fail 'the verified download is not a Linux x86_64 executable. Nothing was installed.'
fi

appimage_path="${install_dir}/Strata.AppImage"
mv "$temporary_appimage" "$appimage_path"
chmod 755 "$appimage_path"
trap - EXIT HUP INT TERM

bin_dir="${HOME}/.local/bin"
ensure_directory "$bin_dir" 'command shortcut'
ln -sfn "$appimage_path" "${bin_dir}/strata"

icon_dir="${HOME}/.local/share/icons/hicolor/256x256/apps"
icon_path="${icon_dir}/strata.png"
ensure_directory "$icon_dir" 'icon'
curl -fsSL \
  -H 'User-Agent: Strata-Linux-Installer' \
  'https://raw.githubusercontent.com/Cx188/strata/main/assets/strata.png' \
  -o "$icon_path" || rm -f "$icon_path"

applications_dir="${HOME}/.local/share/applications"
desktop_entry="${applications_dir}/strata.desktop"
ensure_directory "$applications_dir" 'application shortcut'
escaped_appimage_path="$(printf '%s' "$appimage_path" |
  sed 's/\\/\\\\/g; s/"/\\"/g; s/`/\\`/g; s/\$/\\$/g; s/%/%%/g')"

{
  printf '%s\n' '[Desktop Entry]'
  printf '%s\n' 'Type=Application'
  printf '%s\n' 'Name=Strata'
  printf '%s\n' 'Comment=Minecraft launcher'
  printf 'Exec="%s"\n' "$escaped_appimage_path"
  if [ -f "$icon_path" ]; then
    printf 'Icon=%s\n' "$icon_path"
  else
    printf '%s\n' 'Icon=strata'
  fi
  printf '%s\n' 'Terminal=false'
  printf '%s\n' 'Categories=Game;'
  printf '%s\n' 'StartupNotify=true'
} >"$desktop_entry"
chmod 644 "$desktop_entry"

desktop_dir="${HOME}/Desktop"
if [ -d "$desktop_dir" ]; then
  cp "$desktop_entry" "${desktop_dir}/Strata.desktop"
  chmod 755 "${desktop_dir}/Strata.desktop"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
fi

if [ "${STRATA_SKIP_LAUNCH:-0}" = '1' ]; then
  printf '%s\n' 'Done. Strata is installed and its shortcuts are ready.'
else
  state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/strata"
  ensure_directory "$state_dir" 'launcher log'
  launch_log="${state_dir}/install-launch.log"
  printf '%s\n' 'Launching Strata...'
  nohup "$appimage_path" >"$launch_log" 2>&1 &
  printf '%s\n' 'Done. Strata is installed and its shortcuts are ready.'
  printf 'If no window appears, run %s or inspect %s.\n' "$appimage_path" "$launch_log"
fi
