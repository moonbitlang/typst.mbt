---
title: Worked example
surveyor: R. Aalto
date: 2019-05-14
instrument:
  model: NA2
  sigma0_mm: 0.7
loop_km: 2.4
---
# Worked example

For a loop of $L = 2.4\,\mathrm{km}$ and $\sigma_0 = 0.7\,\mathrm{mm}$ the bound is
$2 \cdot 0.7 \cdot \sqrt{2.4} \approx 2.2\,\mathrm{mm}$.

## Error budget

This heading has the same title as one in the main text; the label
prefix keeps the two apart. Inside this file, [@error-budget] still
means the local one.

| Set-up | $b_i$ / m | $f_i$ / m | $\Delta h_i$ / m |
| :----: | --------: | --------: | ---------------: |
| 1      | 1.482     | 1.105     | +0.377           |
| 2      | 1.317     | 1.690     | −0.373           |
| 3      | 0.954     | 1.221     | −0.267           |
| 4      | 1.776     | 1.510     | +0.266           |

$$ w = \sum_i \Delta h_i = +0.003\,\mathrm{m} $$
