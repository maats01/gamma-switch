# ICC profiles — credits

The `sRGB-*G.icc` profiles, `calib-pow.py` and `LICENSE` in this folder are **not** part of
gamma-switch. They are copied unchanged from
[**ien646/gamma-icc**](https://github.com/ien646/gamma-icc) ("Gamma correcting ICC profiles"),
created by [ien646](https://github.com/ien646). All credit for them goes to the original author.

They are bundled here only so people don't have to download them separately. Upstream released
them into the public domain under the [Unlicense](LICENSE) (kept here as-is).

## How they were made

`calib-pow.py` (from upstream) raises the DisplayCAL sRGB preset's calibration curve to a power
and builds a new profile with ArgyllCMS `iccvcgt`. To generate a value that isn't included, see
the upstream repository.
