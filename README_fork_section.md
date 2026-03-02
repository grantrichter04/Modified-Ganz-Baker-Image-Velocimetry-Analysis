# README — Fork

> **This is a heavily modified fork of [rplab/Ganz-Baker-Image-VelocimetryAnalysis](https://github.com/rplab/Ganz-Baker-Image-VelocimetryAnalysis)** developed for zebrafish gut motility research. For a detailed description of all changes, see [CHANGELOG.md](CHANGELOG.md). The original README is preserved below.

---

## What's New in This Fork

This fork extends the original pipeline with the following major capabilities:

**Dual-component analysis.** The GUI now lets you choose between Transverse and Longitudinal velocity components for all analysis steps. Transverse analysis uses the difference between dorsal and ventral half velocities to capture gut contraction directly. Longitudinal analysis captures peristaltic content flow.

**Improved visualization.** The PIV video has been completely rewritten. Each mesh cell is colored by contraction direction and magnitude (warm = squeeze/forward, cool = relax/backward), with an inline kymograph panel showing a live time cursor. A scale bar, timestamp, gut outline, and color legend are included. All outputs are saved as MP4 with descriptive filenames including sample identifiers.

**Percentile-based color scaling.** QSTMaps and video overlays scale to the 1st/99th percentile by default, robustly handling outlier velocity spikes that would otherwise compress the color range and obscure wave patterns.

**Individual wave tracing.** A new Waves checkbox enables interactive tracing of individual contraction events on the QSTMap, with metrics (amplitude, speed, duration, spatial extent) exported per-event to `WaveMetrics.csv`.

**QSTMap TIFF export.** A new TIFF checkbox exports both transverse and longitudinal QSTMaps as 32-bit calibrated TIFF files, enabling threshold-based motility index analysis in ImageJ or other tools.

**Batch collection.** `collectMotilityAnalysis.m` now aggregates wave metrics and QSTMap TIFFs from across the entire experiment into centralized output files.

**PIV grid preview.** The mask-drawing interface now shows a semi-transparent grid of PIV interrogation windows as you draw, so you can see exactly where velocity vectors will be sampled.

**Bug fixes.** A critical bug where the GUI checkbox columns were misaligned with analysis functions (causing the entire pipeline to silently skip computation) has been fixed. PIV output now correctly saves to the analysis directory.

---

## New Dependencies

No new external toolboxes are required beyond the original. The following files are included directly:

- `intersections.m` — Fast curve intersections by Douglas Schwarz (MathWorks File Exchange, license: BSD). Replaces the Mapping Toolbox dependency on `polyxpoly.m`.
- `imreadSubsampled.m` — Utility for consistent subsampled image reading.

---

## New Analysis Variables (analysisVariables)

| Index | Variable | Default | Description |
|---|---|---|---|
| `{8}` | Velocity component | `'Transverse'` | `'Transverse'` or `'Longitudinal'` |
| `{9}` | Global LUT min | `'auto'` | Fixed color range minimum, or `'auto'` |
| `{10}` | Global LUT max | `'auto'` | Fixed color range maximum, or `'auto'` |
| `{11}` | Temporal smoothing | `'5'` | Gaussian smoothing window in frames (0 = off) |

Existing saved analysis files with fewer variables are automatically migrated on load.

---

## New Checkbox Columns

| Column | Name | Description |
|---|---|---|
| 6 | Waves | Interactive wave tracing on QSTMap |
| 7 | TIFF | Export QSTMaps as 32-bit TIFF files |
| 8 | Use | Include in analysis (was column 6 in original) |

---

*Original README follows below.*

---
