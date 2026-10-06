// codly 1.3.0: an annotated block followed by a block with `ranges` and `smart-skip`. The
// package resets annotations one introspection iteration late, so in the second iteration
// the later block builds a grid whose cells do not fit and layout fails inside the package.
// Engine: an error that only exists in an intermediate iteration must still be fatal.
#import "@preview/codly:1.3.0": *

#set page(width: 110mm, height: 90mm, margin: 10mm)
#show: codly-init

#codly(annotations: ((start: 3, end: 5, content: [read]),))
```py
import csv
rows = []
seen = set()
with open("catch.csv") as f:
    for row in csv.reader(f):
        rows.append(row)
```

#codly(ranges: ((1, 1), (5, 6)), smart-skip: true)
```py
import csv
rows = []
seen = set()
with open("catch.csv") as f:
    for row in csv.reader(f):
        rows.append(row)
```
