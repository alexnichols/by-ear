#!/usr/bin/env bash
set -euo pipefail

APP_SUPPORT="$HOME/Library/Application Support/Transcribee"
VENV="$APP_SUPPORT/demucs-venv"

mkdir -p "$APP_SUPPORT"

if command -v uv >/dev/null 2>&1; then
    if command -v python3.11 >/dev/null 2>&1; then
        uv venv "$VENV" --allow-existing --python "$(command -v python3.11)"
    elif command -v python3.12 >/dev/null 2>&1; then
        uv venv "$VENV" --allow-existing --python "$(command -v python3.12)"
    elif uv venv "$VENV" --allow-existing --python 3.11; then
        :
    elif uv venv "$VENV" --allow-existing --python 3.12; then
        :
    else
        echo "python3.11 or python3.12 is required for the local Demucs environment" >&2
        exit 1
    fi
    uv pip install --python "$VENV/bin/python" -U demucs torchcodec
else
    if command -v python3.11 >/dev/null 2>&1; then
        PYTHON="$(command -v python3.11)"
    elif command -v python3.12 >/dev/null 2>&1; then
        PYTHON="$(command -v python3.12)"
    else
        echo "python3.11 or python3.12 is required for the local Demucs environment" >&2
        exit 1
    fi
    "$PYTHON" -m venv "$VENV"
    "$VENV/bin/python" -m pip install -U pip
    "$VENV/bin/python" -m pip install -U demucs torchcodec
fi

"$VENV/bin/python" -m demucs --help >/dev/null

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "warning: ffmpeg not found; Demucs may fail to decode some compressed formats"
fi

echo "$VENV/bin/python"
