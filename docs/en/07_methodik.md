# 7 Method

This chapter describes the evaluation chain from the camera image to the
result table. All parameters are in `config.m`; the names in brackets refer
to the entries there.

In the image, the flow runs **from right to left**. The right image edge is
located in the reactor at the position *Offset* from the lab notebook.

## 7.1 Scale from the calibration video

Function: `videoauswertung.kern.kalibriere_Massstab`

The first frame of the calibration video shows a ruler with a tick
spacing of 0.525 mm (`kalibrierung.rasterweite_mm`).

1. Within the search strip between 30 % and 80 % of the image height
   (`kalibrierung.suchbereich_rel`), the row with the most vertical edges
   (Sobel) is located. It lies on the ruler.
2. The intensity profile is averaged over a band around this row,
   inverted and smoothed. Its peaks are the ruler ticks.
3. The longest chain of ticks with even spacing (at most 25 % deviation
   from the median) gives

   L_px = x_last − x_first and L_mm = n · 0.525 mm,

   i.e. the scale s = L_mm / L_px in mm/px.

If fewer than 10 ticks are found (`kalibrierung.min_striche`), the
evaluation of the video stops.

## 7.2 Bubble detection per frame

Function: `videoauswertung.kern.erkenne_Blasen`

1. **Contrast and binarisation.** Contrast equalisation (CLAHE) and median
   filter, followed by an adaptive threshold with the sensitivity
   `detektion.sens`. Small cracks in the bubbles are closed with a
   morphological closing (5 px × 5 px).
2. **Channel walls.** During the first 10 frames (`kanal.init_frames`), the
   upper and lower wall are estimated at support points 20 px apart. After
   that, the median is used as a fixed channel model. Implausible support
   points (width, jump, curvature, scatter across frames) are replaced from
   the opposite wall or by interpolation. The centre line lies between both
   walls.
3. **Edges on the centre line.** Every black segment on the centre line is
   an edge between a bubble and a slug. For each edge, vertical rays are
   cast to the left and right up to the next black pixel. If the free path
   on the right is shorter, the edge is curved to the left: the left edge
   of a bubble (bubble nose). If it is shorter on the left, it is the left
   edge of a slug.
4. **Alternating edge types.** In Taylor flow, bubble and slug edges
   alternate. Undecided edges receive the opposite type of their
   neighbour. If two edges of the same type follow each other, the edge
   whose removal better restores the typical spacing rhythm is removed.
5. **Filling the bubbles.** Starting from seed points next to the edges, a
   region growing fills the bubbles; the edge columns limit the growth.
6. **Bubbles and unit cells.** Black segments on the centre line of the
   filled image are bubbles (at least 6 px long, not at the image edge). A
   unit cell extends from the nose of one bubble to the nose of the
   following upstream bubble; it thus comprises one bubble and the slug
   behind it.
7. **Optional: joining fragments** (`detektion.fragmente_verbinden`, off by
   default). An apparent slug shorter than 0.7 × the typical slug length of
   the frame is treated as a reflection; the two bubble parts are joined.
   See chapter 8 for its effect.

## 7.3 Tracking across frames

Function: `videoauswertung.kern.verfolge_Blasen`

A bubble takes over the number of the bubble in the previous frame that
travelled the smallest plausible distance downstream: between −2 px
(noise, `tracking.rueckwaerts_px`) and 50 px (`tracking.max_sprung_px`).
Without a match, it receives a new number. Bubbles found in fewer than
10 frames (`tracking.min_frames`) are discarded.

## 7.4 Velocity, lengths and position

Function: `videoauswertung.kern.berechne_Physik`

Between two frames i and i+1 of a bubble:

    u_B = −(x_{i+1} − x_i) · s · f / 1000      [m/s]

with the scale s [mm/px] and the frame rate f [1/s]. Only values with
0 < u_B < 5 m/s (`physik.v_max_m_s`) are kept. Lengths and position are
the means of both frames:

- bubble length L_B, unit cell length L_UC, slug length L_S = L_UC − L_B
- length fraction of the bubble ε = L_B / L_UC (column `VoidFraction`; a
  length ratio, not a volume fraction)
- position in the reactor x = Offset + (image width − x_px) · s, with x_px
  the centre of the measured bubble

Velocity and position belong to neighbouring bubbles of the same unit
cell: the upstream bubble is tracked, the downstream one is measured
(length, position). Since all bubbles of a unit cell chain travel at the
same velocity, this is equivalent.

Data points before the hydrodynamic entrance length are discarded:

    Re = ρ · (j_G + j_L) · d_h / μ,   L_ein = 0.05 · Re · d_h

with ρ = 1000 kg/m³ and μ = 1 mPa·s (water, `einlauf.*`), the superficial
velocities j_G and j_L and the channel size d_h from the folder name.

## 7.5 Bins and stable measurement zone

The positions are divided into bins of width `physik.bin_mm` (4 mm). If
the mean bubble length is larger than the bin width, the width is
increased to ceil(2 · L_B)/2 mm so that every bin contains enough data
points. The bin width can therefore differ between measurement series.

At the image edge, bubbles enter and leave; detection is less reliable
there. The stable measurement zone is the longest contiguous range of bins
that reach at least 50 % (`physik.plateau_schwelle`) of the median number
of data points in the central 60 % of the bins (`physik.plateau_rel`).
Only bins inside this zone appear in the result table, each with mean,
standard deviation and count.
