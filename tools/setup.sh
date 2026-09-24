#!/usr/bin/env bash
# Installs the pinned toolchain for Emberwake into ./.tools (git-ignored).
#
#   tools/setup.sh            # Godot + Blender (bpy)
#   tools/setup.sh godot      # Godot only
#   tools/setup.sh blender    # Blender (bpy) only
#
# Afterwards:  export PATH="$PWD/.tools/bin:$PATH"
#
# Sources, in order of preference:
#   Godot   1. github.com/godotengine/godot-builds releases (official)
#           2. Docker Hub image barichello/godot-ci:<ver> (contains the official
#              binary at /usr/local/bin/godot) — used when GitHub downloads are
#              blocked by the sandbox network policy.
#   Blender 1. `bpy` wheel from PyPI (Blender-as-a-Python-module, needs Python 3.13)
#           2. download.blender.org tarball
# Keep versions in sync with docs/TECH.md.
set -euo pipefail

GODOT_VERSION="4.7.2"
GODOT_RELEASE="stable"
BPY_VERSION="5.2.2"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$ROOT/.tools"
BIN="$TOOLS/bin"
mkdir -p "$BIN"

log() { printf '[setup] %s\n' "$*"; }

install_godot() {
	local target="$BIN/godot"
	if [[ -x "$target" ]] && "$target" --version 2>/dev/null | grep -q "^${GODOT_VERSION}.${GODOT_RELEASE}"; then
		log "Godot $GODOT_VERSION already installed"
		return 0
	fi
	local zip="Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64.zip"
	local url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/${zip}"
	local tmp
	tmp="$(mktemp -d)"
	log "Trying official release: $url"
	if curl -fsSL -m 600 -o "$tmp/$zip" "$url" 2>/dev/null; then
		unzip -q -o "$tmp/$zip" -d "$tmp"
		mv "$tmp/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64" "$target"
	else
		log "Official download blocked; falling back to Docker Hub barichello/godot-ci:${GODOT_VERSION}"
		python3 "$ROOT/tools/fetch_godot_from_docker.py" "$GODOT_VERSION" "$target"
	fi
	chmod +x "$target"
	rm -rf "$tmp"
	log "Installed $("$target" --version)"
}

install_blender() {
	local venv="$TOOLS/bpy-venv"
	if [[ -x "$venv/bin/python" ]] && "$venv/bin/python" -c "import bpy" 2>/dev/null; then
		log "bpy already installed"
	else
		local py
		py="$(command -v python3.13 || true)"
		if [[ -z "$py" ]]; then
			log "python3.13 not found; Blender (bpy) unavailable — asset scripts will be skipped"
			return 0
		fi
		log "Installing bpy==$BPY_VERSION into $venv (~400 MB)"
		"$py" -m venv "$venv"
		"$venv/bin/pip" install -q "bpy==$BPY_VERSION" || {
			log "bpy install failed; Blender unavailable — asset scripts will be skipped"
			return 0
		}
	fi
	# `blender-py script.py [args]` runs a tools/blender script with bpy importable.
	cat >"$BIN/blender-py" <<EOF
#!/usr/bin/env bash
exec "$venv/bin/python" "\$@"
EOF
	chmod +x "$BIN/blender-py"
	log "Blender module ready: $("$venv/bin/python" -c 'import bpy; print(bpy.app.version_string)')"
}

case "${1:-all}" in
	godot) install_godot ;;
	blender) install_blender ;;
	all) install_godot; install_blender ;;
	*) echo "usage: $0 [all|godot|blender]" >&2; exit 2 ;;
esac
