#!/bin/sh

set -eu

if [ "$(uname -s)" != "Linux" ]; then
  printf '%s\n' 'This installer is for Linux. Use install.ps1 on Windows or download the macOS package from GitHub Releases.' >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  printf '%s\n' 'Strata installation requires curl.' >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64|amd64) ;;
  *)
    printf '%s\n' 'The current Strata Linux release is built for x86_64 systems.' >&2
    exit 1
    ;;
esac

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

release_api='https://api.github.com/repos/Cx188/strata/releases/latest'
release_json="$(curl -fsSL \
  -H 'Accept: application/vnd.github+json' \
  -H 'User-Agent: Strata-Linux-Installer' \
  "$release_api")"

appimage_metadata="$(printf '%s\n' "$release_json" | awk '
  /"name":[[:space:]]*"Strata-Linux-.*\.AppImage"/ { in_asset = 1 }
  in_asset && /"digest":[[:space:]]*"sha256:[a-fA-F0-9]{64}"/ {
    digest = $0
    sub(/^.*"digest":[[:space:]]*"/, "", digest)
    sub(/".*$/, "", digest)
  }
  in_asset && /"browser_download_url":[[:space:]]*"[^"]*\.AppImage"/ {
    url = $0
    sub(/^.*"browser_download_url":[[:space:]]*"/, "", url)
    sub(/".*$/, "", url)
    print digest
    print url
    exit
  }
')"
appimage_digest="$(printf '%s\n' "$appimage_metadata" | sed -n '1p')"
appimage_url="$(printf '%s\n' "$appimage_metadata" | sed -n '2p')"

if [ -z "$appimage_url" ] || [ -z "$appimage_digest" ]; then
  printf '%s\n' 'The latest Strata release is missing a verifiable Linux AppImage.' >&2
  exit 1
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
  -H 'Accept: application/octet-stream' \
  -H 'User-Agent: Strata-Linux-Installer' \
  "$appimage_url" \
  -o "$temporary_appimage"

printf '%s\n' 'Verifying download...'
expected_digest="${appimage_digest#sha256:}"
if command -v sha256sum >/dev/null 2>&1; then
  actual_digest="$(sha256sum "$temporary_appimage" | awk '{ print $1 }')"
elif command -v shasum >/dev/null 2>&1; then
  actual_digest="$(shasum -a 256 "$temporary_appimage" | awk '{ print $1 }')"
else
  printf '%s\n' 'SHA-256 verification requires sha256sum or shasum.' >&2
  exit 1
fi

if [ "$(printf '%s' "$actual_digest" | tr 'A-F' 'a-f')" != "$(printf '%s' "$expected_digest" | tr 'A-F' 'a-f')" ]; then
  printf '%s\n' 'The downloaded AppImage failed SHA-256 verification. Nothing was installed.' >&2
  exit 1
fi

mkdir -p "$install_dir"
appimage_path="${install_dir}/Strata.AppImage"
mv "$temporary_appimage" "$appimage_path"
chmod 755 "$appimage_path"
trap - EXIT HUP INT TERM

bin_dir="${HOME}/.local/bin"
mkdir -p "$bin_dir"
ln -sfn "$appimage_path" "${bin_dir}/strata"

icon_dir="${HOME}/.local/share/icons/hicolor/256x256/apps"
icon_path="${icon_dir}/strata.png"
mkdir -p "$icon_dir"
curl -fsSL \
  -H 'User-Agent: Strata-Linux-Installer' \
  'https://raw.githubusercontent.com/Cx188/strata/main/assets/strata.png' \
  -o "$icon_path" || rm -f "$icon_path"

applications_dir="${HOME}/.local/share/applications"
desktop_entry="${applications_dir}/strata.desktop"
mkdir -p "$applications_dir"
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

printf '%s\n' 'Launching Strata...'
nohup "$appimage_path" >/dev/null 2>&1 &
printf '%s\n' 'Done. Strata is installed and its shortcuts are ready.'
