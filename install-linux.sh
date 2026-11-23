#!/bin/sh
set -eu

version=v1.1.0
release_url="https://github.com/Caraveo/openresearch/releases/download/$version"
data_dir=${XDG_DATA_HOME:-"$HOME/.local/share"}
install_dir="$data_dir/openresearch"

if [ "$(id -u)" -eq 0 ]; then
    echo "Run the installer as your desktop user. It uses sudo for Ubuntu packages." >&2
    exit 1
fi
case "${1:-}" in
    "") archive="" ;;
    --archive)
        if [ "$#" -ne 2 ] || [ ! -f "$2" ]; then
            echo "Usage: $0 [--archive /path/to/openresearch-linux.tar.gz]" >&2
            exit 2
        fi
        archive=$(realpath -- "$2")
        ;;
    *) echo "Usage: $0 [--archive /path/to/openresearch-linux.tar.gz]" >&2; exit 2 ;;
esac

command -v apt-get >/dev/null || { echo "This installer requires Ubuntu or an APT-compatible distribution." >&2; exit 1; }
case "$(dpkg --print-architecture)" in
    amd64|arm64) ;;
    *) echo "This release requires 64-bit x86 or ARM." >&2; exit 1 ;;
esac

missing=""
for package in ca-certificates curl python3-venv libxcb-cursor0 libxkbcommon-x11-0 libnss3 libegl1 libgl1 libopengl0 graphviz pandoc desktop-file-utils; do
    if ! dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -qx installed; then
        missing="$missing $package"
    fi
done
if [ -n "$missing" ]; then
    sudo apt-get update </dev/tty
    # The package names above are fixed, one word apiece.
    sudo apt-get install -y $missing </dev/tty
fi

mkdir -p "$install_dir/releases"
work=$(mktemp -d "$install_dir/.install.XXXXXXXX")
stage=$(mktemp -d "$install_dir/releases/$version.XXXXXXXX")
installed=false
cleanup() {
    rm -rf -- "$work"
    if [ "$installed" = false ]; then
        rm -rf -- "$stage"
    fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

if [ -z "$archive" ]; then
    curl --fail --silent --show-error --location "$release_url/openresearch-linux.tar.gz" -o "$work/openresearch-linux.tar.gz"
    curl --fail --silent --show-error --location "$release_url/SHA256SUMS" -o "$work/SHA256SUMS"
    (cd "$work" && sha256sum --check --status SHA256SUMS)
    archive="$work/openresearch-linux.tar.gz"
fi

tar -xzf "$archive" -C "$stage" --strip-components=1 --no-same-owner
python3 -m venv "$stage/.venv"
"$stage/.venv/bin/python" -m pip install --disable-pip-version-check -r "$stage/requirements.txt"

# Prepare and validate all entries before activating the new version.
"$stage/.venv/bin/python" - "$work" "$install_dir/current" <<'PY'
import sys
from pathlib import Path

output, root = map(Path, sys.argv[1:])
applications = {
    "OpenPaper": ("Read and publish research papers", root / "OpenPaper.png"),
    "OpenWriter": ("Write and edit research papers", root / "openresearch-mac@3x.png"),
    "OpenDeveloper": ("Edit and validate research paper source", "applications-development"),
}


def desktop_value(value):
    return str(value).replace("\\", "\\\\")


def executable(value):
    quoted = str(value).replace("%", "%%")
    for special in ('\\', '"', '$', '`'):
        quoted = quoted.replace(special, "\\" + special)
    return desktop_value(f'"{quoted}"')


for name, (description, icon) in applications.items():
    category = "Development" if name == "OpenDeveloper" else "Office"
    entry = (
        "[Desktop Entry]\n"
        "Type=Application\n"
        f"Name={name}\n"
        f"Comment={description}\n"
        f"Exec={executable(root / name / 'run-qt')} %f\n"
        f"Icon={desktop_value(icon)}\n"
        f"StartupWMClass={name}\n"
        "Terminal=false\n"
        f"Categories={category};\n"
    )
    (output / f"org.openresearch.{name}.desktop").write_text(entry, encoding="utf-8")
PY
for entry in "$work"/*.desktop; do
    desktop-file-validate "$entry"
done

mkdir -p "$data_dir/applications"
ln -s -- "$stage" "$work/current"
mv -Tf -- "$work/current" "$install_dir/current"
installed=true
for entry in "$work"/*.desktop; do
    filename=${entry##*/}
    install -m 644 -- "$entry" "$data_dir/applications/.$filename.new"
    mv -f -- "$data_dir/applications/.$filename.new" "$data_dir/applications/$filename"
done
update-desktop-database "$data_dir/applications"

printf 'Installed OpenResearch %s. Open OpenPaper, OpenWriter, or OpenDeveloper from Show Apps.\n' "$version"
