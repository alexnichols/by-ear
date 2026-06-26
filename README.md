# By Ear

Minimal macOS practice app for loading local audio, extracting keyboard stems, slowing down without pitch drift, looping sections, detecting key, and transposing to a target key.

By Ear is local-first: source audio stays on your Mac unless you explicitly use the optional MVSep integration.

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
open "dist/By Ear.app"
```

## YouTube Audio

The app can open a YouTube link by using local `yt-dlp` and `ffmpeg`, converting the downloaded audio to MP3, and loading it into the practice view.

## Stem Extraction

The app prefers local `mlx-audio-separator` on Apple Silicon with `BS-Roformer-SW.ckpt`, then falls back to local Demucs if MLX is unavailable. Install the local dependencies with:

```bash
./scripts/install-demucs.sh
```

The local MLX path runs:

```bash
mlx-audio-separator <audio> -m BS-Roformer-SW.ckpt --single_stem Piano --output_format WAV
```

The optional MVSep Digital Piano button uploads to MVSep with a user-provided API token and uses separation type `79`.

## Shortcuts

| Key | Action |
|---|---|
| Space | Play/pause |
| Left / Right | Seek 5 seconds |
| Shift + Left / Right | Seek 1 second |
| `[` / `]` | Set loop start/end at playhead |
| `L` | Toggle loop |
| `-` / `+` | Speed down/up by 0.01x |
