# By Ear Mac App

## Goal

Ship a working minimalist macOS practice app for local audio files. Users can load MP3/FLAC/WAV, separate practice stems, slow playback while preserving pitch, loop a selected section, detect the source key, and transpose to a target key such as Bb.

## Non-goals

- No App Store sandboxing or notarization.
- No cloud stem processing in v1.
- No notation, chord chart, or note-by-note transcription.
- No promise that local stem models are artifact-free.

## Success Criteria

- [ ] A Swift package builds a launchable macOS app bundle.
- [ ] The app accepts MP3, FLAC, and WAV via file picker or drag/drop, plus native AVFoundation formats such as AIFF and M4A when available.
- [ ] No app workflow uploads audio unless the user explicitly runs optional MVSep; local model downloads are initiated by the user.
- [ ] Playback supports play/pause, seek, 0.1x-1.5x speed with `AVAudioUnitTimePitch.rate`, and transpose pitch shift of `semitones * 100` cents.
- [ ] Users can create, adjust, enable, disable, and clear an A-B loop from the waveform.
- [ ] Keyboard shortcuts cover Space, arrows, `[`, `]`, `L`, `-`, and `+`.
- [ ] Key detection returns C major and A minor for chroma fixtures, returns a displayed estimate or Unknown for decoded audio, and target-key transpose updates pitch cents.
- [ ] Stem separation runs local `mlx-audio-separator` models for piano, voice, bass, and drums, then lets users choose stems to mix.
- [ ] Unit tests cover musical key math, loop validation, key-profile detection, MLX command construction, and selected-stem mix commands.

## Approach

Native SwiftUI + AVFoundation + local MLX CLI — see `docs/design/transcribee-mac-app.md`.

## Checkpoints

| # | Checkpoint | Files/areas | Agent | Est. files | Verifies |
|---|---|---|---|---:|---|
| 1 | Musical domain, loop, and speed core | `Sources/TranscribeeCore`, `Sources/TranscribeeCoreTests` | atomic-implementer (mode: feature) | ~4 | `swift run TranscribeeCoreTests` |
| 2 | Key detection and MLX stem command core | `Sources/TranscribeeCore`, `Sources/TranscribeeCoreTests` | atomic-implementer (mode: feature) | ~4 | `swift run TranscribeeCoreTests`, MLX model-list smoke command |
| 3 | Native app playback surface | `Sources/TranscribeeApp` | atomic-implementer (mode: feature) | ~6 | `swift build`, app launches, load/drop/play/loop/shortcut paths compile against the controller |
| 4 | Packaging and setup scripts | `scripts`, `README.md` | atomic-implementer (mode: surgical) | ~3 | release bundle exists, executable is ad-hoc signed, setup script dry path is documented |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| MLX install is slow or fails on unsupported Python versions. | Medium | Prefer `uv`, isolate dependencies in app support, and report missing ffmpeg for stem mixing or compressed decoding. |
| Stem quality has bleed. | High | Use specialist MLX models per stem, surface status honestly, and keep original-file playback fully usable. |
| Full-file decoding uses memory on long songs. | Medium | Accept for v1; waveform/key analysis can be optimized later. |
| SwiftUI package app bundle lacks Xcode project niceties. | Low | Package manually into `.app` with Info.plist and ad-hoc signing. |

## Change log
