# By Ear Mac App

## Goal

Ship a working minimalist macOS practice app for local audio files. Users can load MP3/FLAC/WAV, optionally isolate a piano stem, slow playback while preserving pitch, loop a selected section, detect the source key, and transpose to a target key such as Bb.

## Non-goals

- No App Store sandboxing or notarization.
- No cloud stem processing in v1.
- No notation, chord chart, or note-by-note transcription.
- No promise that Demucs piano output is artifact-free.

## Success Criteria

- [ ] A Swift package builds a launchable macOS app bundle.
- [ ] The app accepts MP3, FLAC, and WAV via file picker or drag/drop, plus native AVFoundation formats such as AIFF and M4A when available.
- [ ] No app workflow uploads audio; network use is limited to optional Demucs dependency/model download initiated by the user.
- [ ] Playback supports play/pause, seek, 0.1x-1.5x speed with `AVAudioUnitTimePitch.rate`, and transpose pitch shift of `semitones * 100` cents.
- [ ] Users can create, adjust, enable, disable, and clear an A-B loop from the waveform.
- [ ] Keyboard shortcuts cover Space, arrows, `[`, `]`, `L`, `-`, and `+`.
- [ ] Key detection returns C major and A minor for chroma fixtures, returns a displayed estimate or Unknown for decoded audio, and target-key transpose updates pitch cents.
- [ ] Piano isolation runs local Demucs with `-n htdemucs_6s --two-stems piano` when installed, loads `piano.wav`, and can install a local Demucs virtualenv.
- [ ] Unit tests cover musical key math, loop validation, key-profile detection, and Demucs command construction.

## Approach

Native SwiftUI + AVFoundation + local MLX/Demucs CLI — see `docs/design/transcribee-mac-app.md`.

## Checkpoints

| # | Checkpoint | Files/areas | Agent | Est. files | Verifies |
|---|---|---|---|---:|---|
| 1 | Musical domain, loop, and speed core | `Sources/TranscribeeCore`, `Sources/TranscribeeCoreTests` | atomic-implementer (mode: feature) | ~4 | `swift run TranscribeeCoreTests` |
| 2 | Key detection and Demucs command core | `Sources/TranscribeeCore`, `Sources/TranscribeeCoreTests` | atomic-implementer (mode: feature) | ~4 | `swift run TranscribeeCoreTests`, Demucs smoke command on a generated WAV |
| 3 | Native app playback surface | `Sources/TranscribeeApp` | atomic-implementer (mode: feature) | ~6 | `swift build`, app launches, load/drop/play/loop/shortcut paths compile against the controller |
| 4 | Packaging and setup scripts | `scripts`, `README.md` | atomic-implementer (mode: surgical) | ~3 | release bundle exists, executable is ad-hoc signed, setup script dry path is documented |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Demucs install is slow or fails on Python versions unsupported by torch/torchaudio. | Medium | Prefer `uv` with Python 3.11/3.12, isolate dependencies in app support, and report missing ffmpeg when Demucs cannot decode compressed input. |
| Piano stem quality has bleed. | High | Surface status honestly and keep original-file playback fully usable. |
| Full-file decoding uses memory on long songs. | Medium | Accept for v1; waveform/key analysis can be optimized later. |
| SwiftUI package app bundle lacks Xcode project niceties. | Low | Package manually into `.app` with Info.plist and ad-hoc signing. |

## Change log
