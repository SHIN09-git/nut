# V1 R15 production audio manifest

R15 uses a project-owned deterministic synthesis pass. No external sample,
music library, voice, plugin, or production dependency is used.

## Source and reproduction

- Generator: `tools/audio/generate_r15_audio.gd`
- Command:
  `Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tools/audio/generate_r15_audio.gd`
- Format: mono PCM WAV, 44.1 kHz, 16-bit
- Integration: `scripts/audio/audio_director.gd`
- Buses: `Master`, `Ambient`, and `SFX`

The ambience is a quiet 16-second glass-room bed designed to loop. The finite
effect set reinforces controls, environment actions, facilities, gates,
journal opening, chapter completion, and the final report. Every cue has an
existing visual or textual equivalent and is never the sole information path.

## Frozen hashes

| Asset | SHA-256 |
|---|---|
| `ambient_glass_observation.wav` | `b7c40e073c1ffe3a9131c1d0e502075ac122cbbc0ad67c947545a093f30ce3e3` |
| `ui_soft_confirm.wav` | `966d1962f010ac240e5617fdcdd15d325f3acc4f83dd189724683976f85153b2` |
| `glass_tap.wav` | `cfa4bdb44bf4b249a40fbd298e6ca71885ba696e4de0064f1d9f1e0490761002` |
| `water_drop.wav` | `cc02570776eba2d4915e4b40014a75250943058e890a8ac3239000fd64a09330` |
| `facility_place.wav` | `e401dead28da3ec84c913d11b5b0ac174324cbb0e6902e67ce96a43c367a166b` |
| `gate_toggle.wav` | `8909a26b7cf4a10ee54aba1d88ae43e7f637c557dca850cb9e1ac552add55c9b` |
| `journal_open.wav` | `569f5bccaa5192d4da181f58c8ca5b7ec6341130de5ce96bac0ac82c43e68fa9` |
| `chapter_complete.wav` | `6f76dd02c691b4a822c1972e258eedf5269f4a4867d7b808540d62a84634d7c2` |
| `report_reveal.wav` | `99923ccac681f0aad4db42ac998f50fc7c8159d129fc202f409bcd458ae0860c` |

## Rights

All source waveforms are generated from original project code. Commercial game
use, modification, marketing use, and build redistribution are approved for
this repository. The generator remains in source control for reproducibility
but is excluded from exported builds.
