# 8 Limitations

## 8.1 Range of validity

The evaluation assumes:

- **Taylor flow** with alternating bubbles and slugs across the full image
  width. Bubble swarms, bubbles without a slug between them or annular flow
  are not detected meaningfully.
- **Flow from right to left** in the image. With the camera reversed,
  velocities become negative and are discarded.
- **Fixed camera and illumination** during a video: the channel model is
  estimated from the first 10 frames and not adapted afterwards.
- **A ruler with 0.525 mm tick spacing** in the first frame of the
  calibration video, in the central image area (30–80 % of the image
  height).
- **Velocities below 5 m/s** (`cfg.physik.v_max_m_s`) and displacements
  below 50 px per frame (`cfg.tracking.max_sprung_px`). At 200 fps and
  about 0.055 mm/px this corresponds to about 0.55 m/s; faster bubbles
  require a higher frame rate or a larger value.
- **Water as the continuous phase** for the entrance length
  (`cfg.einlauf`).

## 8.2 Known limitations

- **Bin width varies.** If the mean bubble length is larger than
  `cfg.physik.bin_mm`, the bin width is increased to ceil(2 · L_B)/2 mm.
  Results of different measurement series then have different bin grids.
- **`VoidFraction` is a length ratio** L_B/L_UC, not a volume fraction;
  the shape of the bubble caps and the liquid film are not considered.
- **Dependence on the sensitivity.** The adaptive threshold
  (`cfg.detektion.sens`) noticeably affects bubble lengths. For new
  channels or illumination, a sweep (e.g. 0.85:0.05:0.95) and a comparison
  of the plots is worthwhile.
- **Stable measurement zone.** Bins at the image edge with few data points
  are discarded; for short videos or few bubbles the zone can be empty
  (warning "Keine stabile Messzone gefunden", no rows for that video).
- **Reflections.** Strong light reflections can split a bubble into two
  parts, which are then counted as two short bubbles. The experimental
  option `cfg.detektion.fragmente_verbinden` (off by default) joins such
  parts, but in some videos it also joins real bubbles; check with the live
  view before using it.

## 8.3 Data that cannot be evaluated

- **`Glaskanal/Messungen`** (94 videos, March 2026): old naming scheme
  (`0,07_0,04_Position_1`) without a calibration group `Pos_<n>_Kal_<k>`,
  partly at 120 or 500 fps. The batch skips these videos. To evaluate them,
  the folders would have to be renamed according to chapter 2 and assigned
  to a calibration.
- The duplicate lab notebook entry `0.15_0.06_Position_1` also belongs to
  this old data.
