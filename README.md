# Transcribee

Minimal macOS practice app for loading local audio, isolating piano with local Demucs, slowing down without pitch drift, looping sections, detecting key, and transposing to a target key.

## Build

```bash
swift run TranscribeeCoreTests
swift build
```

## Run

```bash
swift run Transcribee
```

## Package

```bash
./scripts/package-app.sh
open dist/Transcribee.app
```

## Piano Isolation

The app uses local Demucs, not uploads. For the free local path:

```bash
./scripts/install-demucs.sh
```

The app looks first for `~/Library/Application Support/Transcribee/demucs-venv/bin/python`, then common `demucs` and `python3` locations. The installer adds `demucs` plus `torchcodec`, which current `torchaudio` needs for WAV output. It runs:

```bash
python -m demucs -n htdemucs_6s --two-stems piano --float32 --segment 7
```

Demucs' own docs flag the piano model as experimental, so expect some bleed on dense mixes.

## Shortcuts

| Key | Action |
|---|---|
| Space | Play/pause |
| Left / Right | Seek 5 seconds |
| Shift + Left / Right | Seek 1 second |
| `[` / `]` | Set loop start/end at playhead |
| `L` | Toggle loop |
| `-` / `+` | Speed down/up by 0.01x |
