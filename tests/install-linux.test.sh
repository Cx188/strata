#!/bin/sh

set -eu

repository_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
installer="${repository_root}/install.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/strata-installer-test.XXXXXX")"
cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT HUP INT TERM

fixture="${test_root}/Strata-Linux-x86_64-9.8.7.AppImage"
dd if=/dev/zero of="$fixture" bs=1 count=64 2>/dev/null
printf '\177ELF' | dd of="$fixture" bs=1 seek=0 conv=notrunc 2>/dev/null
printf '\076\000' | dd of="$fixture" bs=1 seek=18 conv=notrunc 2>/dev/null
fixture_digest="$(sha256sum "$fixture" | awk '{ print $1 }')"

mock_bin="${test_root}/bin"
mkdir -p "$mock_bin"
cat >"${mock_bin}/curl" <<'MOCK_CURL'
#!/bin/sh
set -eu

output=''
url=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o|--output|-w|--write-out|-H|--header|--retry|--connect-timeout|--max-time)
      option="$1"
      shift
      [ "$#" -gt 0 ] || exit 2
      if [ "$option" = '-o' ] || [ "$option" = '--output' ]; then
        output="$1"
      fi
      ;;
    -*) ;;
    *) url="$1" ;;
  esac
  shift
done

case "$url" in
  https://github.com/Cx188/strata/releases/latest)
    printf '%s' 'https://github.com/Cx188/strata/releases/tag/v9.8.7'
    ;;
  https://github.com/Cx188/strata-updates/releases/download/v9.8.7/SHA256SUMS)
    printf '%s  %s\n' "$TEST_FIXTURE_DIGEST" 'Strata-Linux-x86_64-9.8.7.AppImage'
    ;;
  https://github.com/Cx188/strata/releases/download/v9.8.7/Strata-Linux-x86_64-9.8.7.AppImage)
    cp "$TEST_FIXTURE" "$output"
    ;;
  https://raw.githubusercontent.com/Cx188/strata/main/assets/strata.png)
    exit 22
    ;;
  *)
    printf 'Unexpected URL: %s\n' "$url" >&2
    exit 2
    ;;
esac
MOCK_CURL
chmod 755 "${mock_bin}/curl"

export TEST_FIXTURE="$fixture"
export TEST_FIXTURE_DIGEST="$fixture_digest"
test_home="${test_root}/home"
install_dir="${test_home}/.local/opt/strata"

HOME="$test_home" \
PATH="${mock_bin}:$PATH" \
STRATA_INSTALL_DIR="$install_dir" \
STRATA_SKIP_LAUNCH=1 \
sh "$installer"

cmp "$fixture" "${install_dir}/Strata.AppImage"
test -x "${install_dir}/Strata.AppImage"
test -L "${test_home}/.local/bin/strata"
test -f "${test_home}/.local/share/applications/strata.desktop"

relative_home="${test_root}/relative-home"
mkdir -p "$relative_home"
(
  cd "$test_root"
  HOME="$relative_home" \
  PATH="${mock_bin}:$PATH" \
  STRATA_INSTALL_DIR='custom/location' \
  STRATA_SKIP_LAUNCH=1 \
  sh "$installer"
)
test -x "${test_root}/custom/location/Strata.AppImage"

blocked_path="${test_root}/not-a-directory"
printf '%s\n' 'occupied' >"$blocked_path"
if HOME="$test_home" \
  PATH="${mock_bin}:$PATH" \
  STRATA_INSTALL_DIR="$blocked_path" \
  STRATA_SKIP_LAUNCH=1 \
  sh "$installer" >"${test_root}/blocked.out" 2>"${test_root}/blocked.err"; then
  printf '%s\n' 'Installer unexpectedly accepted a file as its destination.' >&2
  exit 1
fi
grep -F 'exists but is not a directory' "${test_root}/blocked.err" >/dev/null

printf '%s\n' 'Linux installer tests passed.'
