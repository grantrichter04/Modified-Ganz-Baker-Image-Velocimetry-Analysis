# Changelog — Fork
### Based on: [rplab/Ganz-Baker-Image-VelocimetryAnalysis](https://github.com/rplab/Ganz-Baker-Image-VelocimetryAnalysis)

This fork extends the original Ganz-Baker Image Velocimetry Analysis pipeline with enhanced visualization, dual-component analysis (transverse and longitudinal), individual wave tracing, QSTMap TIFF export, and a range of bug fixes and workflow improvements.

---

## New Files Added

### `obtainMotilityParameters_Transverse.m`
Explicit transverse analysis version. Cross-correlation, autocorrelation, and FFT are all computed from the transverse (DV) velocity component using the top/bottom half difference formula (`2 * (mean_ventral - mean_dorsal)`) to capture gut contraction. Percentile-based scaling added to handle outlier velocity spikes. Both QSTMap (longitudinal and transverse) are displayed side-by-side for comparison. XCorr and FFT panels repositioned to sit adjacent to the transverse QSTMap. Figure saved with `_Transverse_` suffix.

### `obtainMotilityParameters_Longitudinal.m`
Explicit longitudinal analysis version. Cross-correlation, autocorrelation, and FFT computed from the longitudinal (AP) velocity component (`-mean` of component 1 across all rows). Mirrors the structure of the transverse version for consistent comparison.

### `performWaveTracing.m`
New pipeline step for interactive wave tracing on QSTMaps. Called from `analyzeMotility.m` when the Waves checkbox is enabled. Allows the user to manually trace individual contraction wave events on the spatiotemporal map and save their properties.

### `performQSTMapTIFFExport.m`
New pipeline step for exporting QSTMaps as 32-bit floating-point TIFF files. Called from `analyzeMotility.m` when the TIFF checkbox is enabled. Supports both transverse and longitudinal components.

### `exportQSTMapTIFF.m`
Core function for generating and saving QSTMap TIFF files. Outputs both transverse and longitudinal QSTMaps as calibrated 32-bit TIFFs, with an accompanying README text file describing units, scaling, and metadata. File naming convention includes sample identifier (parent folder + subfolder).

### `extractWaveMetrics.m`
Extracts quantitative properties from individual traced wave events: amplitude, duration, speed, and spatial extent. Saves results to `WaveMetrics.csv` in each analysis subdirectory.

### `savePIVParametersFigure.m`
Saves the PIV parameters figure (including mask and grid preview) to disk as a PNG for record-keeping.

### `imreadSubsampled.m`
Utility function for reading images with subsampling (resolution reduction). Replaces direct `imread` calls with `PixelRegion` syntax throughout the pipeline for cleaner, more consistent image loading.

### `intersections.m`
External utility by Douglas Schwarz (MathWorks File Exchange) for fast curve intersection calculations. Included directly to remove the dependency on the Mapping Toolbox `polyxpoly.m`.

---

## Modified Files

### `analyzeMotility.m` — Major Changes

**New analysis variables:**
- `analysisVariables{8}`: Velocity component selector (`'Transverse'` or `'Longitudinal'`), default `'Transverse'`
- `analysisVariables{9}` and `{10}`: Global color LUT range (min/max), default `'auto'`
- `analysisVariables{11}`: Temporal smoothing window in frames, default `'5'`

**New GUI controls:**
- Velocity component dropdown (Transverse / Longitudinal)
- Global color range fields (min / max, or `'auto'` for percentile-based auto-detect)
- Temporal smoothing frames field

**New analysis checkboxes (expanded from 6 to 8):**
- Column 6: Waves (interactive wave tracing)
- Column 7: TIFF (QSTMap TIFF export)
- Column 8: Use (unchanged, shifted from column 6)

**Backward-compatibility migration:**
- On load, existing saved `.mat` files with 6-column checkbox arrays are automatically migrated to the 8-column layout. The former Use column (col 6) is remapped to column 8. Waves and TIFF columns default to `false`.
- `analysisVariables` arrays with fewer than 11 entries are extended with defaults.

**Pipeline dispatch:**
- Analysis and video steps now dispatch to component-specific functions based on `analysisVariables{8}`
- `performWaveTracing` and `performQSTMapTIFFExport` called as new pipeline steps
- Mask creation now performed before PIV computation (reduces unnecessary computation on full-frame images)

**Video file lookup:**
- Improved fallback logic: searches for descriptive `PIVAnimation_*.avi` / `PIVAnimation_*.mp4` filenames first, then falls back to legacy `PIVOutputName`

**GUI layout:**
- Checkbox spacing increased (25 → 32 px)
- Subfolder panel width increased to accommodate new columns

---

### `createPIVMovie.m` — Complete Rewrite

The original function has been fully rewritten into a unified video generator supporting both transverse and longitudinal components. The component is determined at runtime from `analysisVariables{8}`.

**Key additions:**

- **Discrete colored mesh cell patches:** Each mesh cell is colored by the same metric used in the kymograph (not just arrow direction). Warm (orange) = positive (squeeze/forward), cool (blue) = negative (relax/backward). Alpha encodes magnitude.
- **Kymograph panel:** A live kymograph is displayed alongside the video with a time-tracking cursor line and arrow markers.
- **Percentile-based kymograph scaling:** 1st/99th percentile scaling by default; overridden by global LUT if set.
- **Global LUT support:** If `analysisVariables{9}`/`{10}` are set to numeric values, both the overlay and kymograph use the same fixed color range across all videos (essential for cross-sample comparison).
- **Gut outline overlay:** User-drawn mask polygon rendered as a boundary overlay.
- **Optional mesh grid lines:** Configurable via `showMeshGrid` flag.
- **Scale bar:** 100 µm scale bar with tick marks.
- **Timestamp:** Current time (s) shown in corner.
- **Color legend bar:** Gradient legend with directional labels (Relax/Squeeze or bwd/fwd).
- **Temporal smoothing of raw vectors:** Applied when `analysisVariables{11}` > 0, using a Gaussian kernel.
- **Descriptive output filename:** `PIVAnimation_<Component>_<FolderName>_<SubFolder>.mp4` (replaces generic `PIVAnimation.avi`).
- **MP4 output:** MPEG-4 at 95% quality (replaces uncompressed AVI).
- **Memory management:** Large arrays explicitly cleared after each video; periodic Java GC calls every 100 frames.
- **Helper function:** `computeColumnMetric` extracted as a local function to ensure the overlay color exactly matches the kymograph signal.

---

### `obtainMotilityParameters.m` — Renamed to Transverse Analysis Version

Formerly computed the longitudinal QSTMap and derived all metrics from the longitudinal component. Now:

- Both QSTMaps (longitudinal and transverse) computed upfront and displayed side-by-side
- All analysis metrics (XCorr, autocorrelation, FFT) derive from the **transverse** component
- Percentile-based scaling (1st/99th for QSTMaps, 2nd/98th for XCorr) replaces MATLAB auto-scaling to handle outlier spikes
- Optional shared scale between both QSTMaps for direct comparison
- Velocity correctly converted to µm/s throughout (`velocityScale = scale * fps`)
- Figure and saved PNG named `Figures_Transverse_<date>.png`
- GUI window title updated to `Motility Analysis GUI - TRANSVERSE`

---

### `performPIV.m` — Critical Bug Fix

- **Fixed:** Checkbox column index corrected from `bools(j,6)` to `bools(j,8)` (the Use column). This was the root cause of the pipeline silently skipping all PIV computation when run through the GUI.
- **Fixed:** PIV output now saves to the analysis directory (`curAnDir`) rather than the experiment directory (`curDir`), matching the expected location for downstream functions.
- Separate `curExpDir` and `curAnDir` variables now explicitly defined.

---

### `collectMotilityAnalysis.m` — Bug Fix + New Collection Capabilities

- **Fixed:** Checkbox column index corrected from `bools(j,6)` to `bools(j,8)`.
- **New:** Collects individual wave metrics from all `WaveMetrics.csv` files across the experiment into a single `allWaveMetrics.csv` in the main analysis directory.
- **New:** Collects all QSTMap TIFF files (`QSTMap_*_32bit_*.tif`) from across the experiment into a centralized `QSTMap_TIFFs_Collected/` subfolder for batch analysis.

---

### `obtainMotilityMask.m` — Enhanced with PIV Grid Preview

- Accepts optional 4th argument `templateSize` (PIV interrogation window size in pixels)
- When `templateSize` is provided, a semi-transparent PIV window grid overlay is drawn on the image during mask drawing, showing the user exactly where interrogation windows will be placed
- Configurable grid appearance: `gridAlpha`, `gridColor`, `highlightColor` for windows inside the mask
- Uses `imreadSubsampled` instead of raw `imread` with `PixelRegion` for consistency
- Function signature unchanged for backward compatibility (4th arg is optional)

---

## Summary of Key Themes

| Theme | Description |
|---|---|
| **Dual-component analysis** | Pipeline fully supports both transverse and longitudinal analysis, selectable from GUI |
| **Percentile-based scaling** | Robust visualization that handles outlier spikes without manual LUT adjustment |
| **Individual wave analysis** | New wave tracing and metrics extraction pipeline |
| **TIFF export** | 32-bit QSTMap TIFFs for downstream threshold analysis (squeeziness factor) |
| **Descriptive file naming** | Output files include sample identifiers for unambiguous batch processing |
| **Critical bug fixes** | GUI checkbox alignment (col 6 → 8) causing silent pipeline failure; PIV output directory correction |
| **Backward compatibility** | Automatic migration of old saved analysis state to new format |
