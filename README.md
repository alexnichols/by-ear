# By Ear

Minimal macOS practice app for loading local audio, separating practice stems, slowing down without pitch drift, looping sections, detecting key, and transposing to a target key.

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

## Stem Separation

The app uses local `mlx-audio-separator` on Apple Silicon. Install the local dependencies with:

```bash
./scripts/install-local-ai.sh
```

The local MLX path runs specialist models for each selectable stem:

| Stem | MLX model |
|---|---|
| Piano | `BS-Roformer-SW.ckpt` |
| Voice | `vocals_mel_band_roformer.ckpt` |
| Bass | `kuielab_a_bass.onnx` |
| Drums | `kuielab_b_drums.onnx` |

After processing, choose any generated stems with the checkboxes. By Ear reloads the selected mix automatically and keeps processed stems under Application Support while the source song remains in Recents. Clearing Recents, losing a recent file, or pushing a song out of the recent list removes its cached stems.

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
