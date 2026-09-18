# App Store screenshots

Each dated folder is one finished set, ready to upload to App Store Connect.

```
2026-09-18/
  cream/   the app's own paper background
  ink/     the same slides on a warm dark background
    6.5/   1284 x 2778, the 6.5 inch iPhone size
    6.9/   1320 x 2868, the 6.9 inch iPhone size
```

Six slides per set, numbered in upload order. PNG, no alpha channel, exact
pixel sizes, which is what App Store Connect checks.

`raw/` holds the simulator captures the slides are built from, taken on the
review account at 9:41 with a full battery. `make.py` lays each one out with
the app's own fonts and renders it with headless Chrome. To make a new set,
replace the captures in `raw/` and run:

```
python3 store/screenshots/make.py
```

The captions are in `make.py`, written in the product voice: no exclamation
marks, no dashes, nothing the app does not do.
