# Design system

Layout follows the structure of the supplied Sehhaty reference screenshot (greeting, search, notice card, summary card with three small metrics, "latest updates" row, five-tab bottom bar) using **original Sukkar Plus branding** — a droplet-with-plus mark drawn in code. No Sehhaty logo, name-as-brand or government endorsement is used; the screenshot itself is not bundled.

## Tokens (`app/lib/core/theme/tokens.dart`)

| Role | Value |
|------|-------|
| Background | `#F3F6F7` |
| Surface | `#FFFFFF`, muted `#F7FAFA`, border `#E2E9EC` |
| Teal (primary) | `#17958C`, deep `#0D6C66`, soft `#E3F3F1` |
| Ink | `#1C2A35`, secondary `#55636E`, muted `#85939D` |
| Notice card (taupe) | `#8A7261` |
| Status | warning `#9A6A00`, critical `#B23A3A`, neutral `#55636E` — always with icon + label |
| Demo banner | `#7A4E00` on `#FFF1CC` |

Typography: **IBM Plex Sans Arabic** (OFL, bundled in `app/assets/fonts`, also embedded in exported PDFs), weights 400/500/600/700, scale 11.5–34. Spacing 4/8/12/16/20/28; card radius 16, inner 12; one restrained shadow.

The one emphasised element is the "ملخصي الصحي" card: a large time-in-range figure over a slim five-band strip; everything else stays quiet.

## Data visualisation

Range-band colours were validated with the bundled dataviz palette validator (lightness band, chroma floor, CVD separation, normal-vision floor, 3:1 contrast on white) — all checks pass:

| Band | Colour |
|------|--------|
| Very low < 54 | `#A32E4E` |
| Low 54–69 | `#E0704E` |
| In range 70–180 | `#0089B8` |
| High 181–250 | `#B98200` |
| Very high > 250 | `#97470F` |

Trend series: HbA1c `#17958C` (circles, solid) and GMI `#B98200` (diamonds, dashed) — pair validated. Charts use one y-axis, 2 px lines, ≥ 8 px markers with a surface ring, a direct label on the latest point only, tap-to-inspect with a 28 px hit radius, and a table view so identity never depends on colour. Time runs in reading direction (right → left).

## Components

`SpCard`, `SectionHeader`, `StatusChip`, `OriginChip`, `SyntheticChip`, `InfoNote`, `EmptyState`, `LoadingView`, `KeyValueRow`, `MiniMetric`, `SpPage`, `confirmDialog`, `DemoBanner`, `SukkarLogo`, `RangeStrip`, `RangeLegend`, `TrendChart`.

## RTL rules

* `locale: ar`, global Material localisations, `Directionality.rtl` above every route.
* Dates in sentences use Arabic month names ("13 سبتمبر 2026"); ranges and changes use words ("من … إلى …") — ISO dates and arrows are reordered by the bidi algorithm.
* Numbers use Western digits for clinical clarity; inputs accept Arabic-Indic digits and normalise them.
