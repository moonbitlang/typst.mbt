# The Allotment Year

Notes for plot 14, kept in *Markdown* so that they can be read on the
phone, and typeset with __Typst__ for the notice board. Some things are
~no longer true~ and struck out; the soil has a pH<sub>water</sub> of 6.4,
the bed is 12 m<sup>2</sup>, and <mark>the gate must be locked</mark>.

"Smart" punctuation turns quotes around -- and dashes --- too... The
tool shed code is `4711`.

## Sowing calendar

1. Broad beans, as soon as the soil can be worked
2. Carrots and parsnips
   - 'Early Nantes' under fleece
   - 'Autumn King' in May
     1. thin to 5 cm
     2. cover against carrot fly
3. Leeks, in a seed bed first

* Courgettes do not go out before the last frost.
* Squash needs the compost heap.

+ A list with another marker

### Jobs this week

- [x] turn the compost
- [x] order seed potatoes
- [ ] mend the water butt
- [ ] sharpen the hoe
  - [x] find the file first

## Links

The society's site is at [allotments.example](https://allotments.example/plot/14),
the rules are [here][rules] and [the rules][rules] again, and the
[sowing calendar](#sowing-calendar) is above.
A bare address: <https://seed-swap.example>.

[rules]: https://allotments.example/rules "Rules of the society"

## What the old hands say

> Dig when the soil does not stick to your boots.
>
> > And never on a Sunday, said the one before him.
>
> Plant garlic on the shortest day, lift it on the longest.

A poem needs hard line breaks:  
*Sow dry,*  
*plant wet,*<br>
and you will not regret.

---

## Records

```python
def yield_per_metre(kilos, metres):
    """Harvest per metre of row."""
    return round(kilos / metres, 2)
```

```
plain block without a language
  keeps   its   spaces
```

| Crop        | Sown     | Harvest | kg   |
| :---------- | :------: | ------: | ---: |
| Broad beans | 2 March  | June    | 6.5  |
| Carrots     | 14 April | August  | 11.0 |
| Leeks       | 20 March | *winter* | 9.2 |
| **Total**   |          |         | 26.7 |

<table>
  <thead><tr><th>Bed</th><th colspan="2">Rotation</th></tr></thead>
  <tr><td>A</td><td>roots</td><td>then legumes</td></tr>
  <tr><td rowspan="2">B</td><td>brassicas</td><td>then roots</td></tr>
  <tr><td colspan="2">half of it lies fallow</td></tr>
  <tfoot><tr><td>C</td><td colspan="2">permanent: rhubarb, herbs</td></tr></tfoot>
</table>

The rainfall was measured with a jam jar[^jar] and the frost dates were
taken from the neighbour's diary[^diary].

[^jar]: Straight sides, 7 cm across.
[^diary]: Kept since 1987, with *very* few gaps.

<dl>
  <dt>Tilth</dt>
  <dd>The crumbly state of soil that is ready for seed.</dd>
  <dt>Bolting</dt>
  <dd>Running to seed too early.</dd>
</dl>

## The plot

<figure id="plan">
<svg version="1.1" width="220" height="90" xmlns="http://www.w3.org/2000/svg">
  <rect x="1" y="1" width="218" height="88" fill="#f4f1e6" stroke="#444" />
  <rect x="10" y="10" width="60" height="70" fill="#9bbf73" />
  <rect x="80" y="10" width="60" height="70" fill="#c9a66b" />
  <rect x="150" y="10" width="60" height="30" fill="#7fa7c9" />
  <circle cx="180" cy="62" r="14" fill="#8d6e63" />
</svg>
<figcaption>Beds A, B and C with the compost heap</figcaption>
</figure>

The plan is [@plan]; the beds are <bed name="A">roots</bed>,
<bed name="B">brassicas</bed> and <bed name="C">herbs</bed>, and the
water level is <gauge level="65">.

<!--raw-typst
#block(fill: luma(235), inset: 6pt, radius: 3pt)[
  This box is raw Typst inside an HTML comment; the season is #season and
  the plot number squared is #calc.pow(plot, 2).
]
-->

<!--typst-begin-exclude-->
This paragraph is only for readers of the Markdown file.
<!--typst-end-exclude-->

A paragraph with <unknown>an unknown tag</unknown> and an entity: &copy; &amp; &frac12;.
