# Changelog: TIFF Export + Video Polish + Column Fix

## New Files (3)

### `exportQSTMapTIFF.m`
Core function that computes the transverse velocity QSTMap and writes it as a 32-bit floating-point TIFF. Pixel values directly encode velocity in µm/s — no colormap applied. Negative values (inward/squeezing) are preserved. Also generates a companion `_README.txt` with ImageJ/Fiji usage instructions.

### `performQSTMapTIFFExport.m`
Dispatcher that loops through directories and calls `exportQSTMapTIFF` for each dataset where the TIFF checkbox (column 7) and Use checkbox (column 8) are both checked.

### `performWaveTracing.m`
Dispatcher for the wave tracing module (was missing from the project). Loops through directories and calls `extractWaveMetrics` for each dataset where the Waves checkbox (column 6) and Use checkbox (column 8) are checked.

---

## Modified Files (9)

### `analyzeMotility.m`
- **Checkbox columns expanded** from 6 to 8: `PIV | Outline | Interp | Analyze | Video | Waves | TIFF | Use`
- Added GUI labels for "Waves" (col 6) and "TIFF" (col 7)
- Wired `performWaveTracing` and `performQSTMapTIFFExport` into the Analyze button callback
- **Backward-compatible migration**: automatically expands old 6-column or 7-column saved `.mat` files to the new 8-column layout on load, preserving all existing analysis-done flags

### `createPIVMovie.m` (Transverse)
- **Background**: changed from dark gray `[0.15 0.15 0.15]` to pure black `[0 0 0]`
- **Annotations moved below frame**: timestamp, scale bar, and color legend now sit in a dedicated annotation strip below the image, not overlaid on it
- Figure height increased slightly to accommodate the annotation strip
- Kymograph panel background also changed to black
- Fixed `Â±` encoding artifact in fprintf

### `createPIVMovie_Longitudinal.m`
- Same video polish as transverse version: black background, annotations below frame
- Figure height adjusted for annotation strip
- Kymograph background changed to black

### `performPIV.m`
- Fixed Use column reference: `bools(j,7)` → `bools(j,8)`

### `obtainMotilityMasks.m`
- Fixed Use column reference: `bools(j,7)` → `bools(j,8)`

### `performMaskInterpolation.m`
- Fixed Use column reference: `bools(j,6)` → `bools(j,8)`

### `performMotilityDataAnalysis.m`
- Fixed Use column reference: `bools(j,7)` → `bools(j,8)`

### `createAllChosenPIVMovies.m`
- Fixed Use column reference: `bools(j,6)` → `bools(j,8)`

### `collectMotilityAnalysis.m`
- Fixed Use column reference: `bools(j,6)` → `bools(j,8)`
- Added wave metrics aggregation: collects all `WaveMetrics.csv` files into a master `allWaveMetrics.csv`

---

## GUI Checkbox Layout (Final)

| Column | Label    | Function                          |
|--------|----------|-----------------------------------|
| 1      | PIV      | Run PIV analysis                  |
| 2      | Outline  | Draw gut mask                     |
| 3      | Interp   | Interpolate vectors onto mesh     |
| 4      | Analyze  | QSTMap, XCorr, FFT analysis       |
| 5      | Video    | Generate PIV overlay video        |
| 6      | Waves    | Interactive wave tracing          |
| 7      | TIFF     | Export 32-bit transverse QSTMap   |
| 8      | Use      | Include this dataset              |

---

## TIFF Export Details

**Filename format**: `QSTMap_Transverse_32bit_<X.XX>umPx_<Y.YYYY>sPx.tif`

**Metadata stored in TIFF ImageDescription tag**:
- Units (µm/s)
- Component (Transverse)
- Spatial resolution (µm/pixel)
- Temporal resolution (s/pixel)
- Formula used
- Source directory and export date

**ImageJ/Fiji workflow**:
1. File > Open (reads as 32-bit float automatically)
2. Image > Adjust > Threshold (set to e.g. -∞ to -0.5 for strong contractions)
3. Analyze > Measure to count thresholded pixels
4. Image > Properties to set physical scale from the README

---

## Deployment

Replace all 12 files in your toolbox directory. On first launch with existing data, the GUI will automatically migrate your saved `currentAnalysesPerformed.mat` to the new 8-column layout.
