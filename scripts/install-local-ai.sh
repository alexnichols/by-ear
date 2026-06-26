#!/usr/bin/env bash
set -euo pipefail

APP_SUPPORT="$HOME/Library/Application Support/Transcribee"
LOCAL_VENV="$APP_SUPPORT/local-separators-venv"

mkdir -p "$APP_SUPPORT"

create_uv_venv() {
    local target="$1"
    shift

    for python_version in "$@"; do
        if uv venv "$target" --allow-existing --python "$python_version"; then
            return 0
        fi
    done

    return 1
}

if command -v uv >/dev/null 2>&1; then
    if ! create_uv_venv "$LOCAL_VENV" 3.12 3.11 3.10 3.14; then
        echo "python3.10+ is required for the local MLX separator environment" >&2
        exit 1
    fi
    uv pip install --python "$LOCAL_VENV/bin/python" -U mlx-audio-separator torch
else
    if command -v python3.12 >/dev/null 2>&1; then
        PYTHON="$(command -v python3.12)"
    elif command -v python3.11 >/dev/null 2>&1; then
        PYTHON="$(command -v python3.11)"
    elif command -v python3.10 >/dev/null 2>&1; then
        PYTHON="$(command -v python3.10)"
    elif command -v python3 >/dev/null 2>&1; then
        PYTHON="$(command -v python3)"
    else
        echo "python3.10+ is required for the local MLX separator environment" >&2
        exit 1
    fi

    "$PYTHON" -m venv "$LOCAL_VENV"
    "$LOCAL_VENV/bin/python" -m pip install -U pip
    "$LOCAL_VENV/bin/python" -m pip install -U mlx-audio-separator torch
fi

"$LOCAL_VENV/bin/python" -m mlx_audio_separator --help >/dev/null

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "warning: ffmpeg not found; selected stem mixing and some audio decoding may fail"
fi

echo "$LOCAL_VENV/bin/mlx-audio-separator"
