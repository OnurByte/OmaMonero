# Supplied logo and native SVG compatibility

`original-logo.svg` is the user's supplied file, preserved byte for byte.
`qml/v0_4_2/assets/OmaMonero-logo.svg` renders the same artwork using explicit
filled paths for its five orange bands. QtSvg ignores the original `clipPath`
and otherwise paints five solid full-width rectangles. Each native band is the
original polygon intersected with the original rectangle's horizontal bounds.
The graphite path, gradient and colors are retained.

Verification used Qt6Svg with `QT_QPA_PLATFORM=offscreen` and librsvg at
1090 × 1080. The flattened file rendered in librsvg has identical alpha to the
original. Qt's flattened render has alpha mean absolute error 0.00352 / 255,
compared with 71.62467 before the fix. Only 10 of 1,177,200 pixels differ in alpha
by more than 16 after the fix, due to renderer edge rasterization. The canvas
corner is transparent (previously opaque). No window is created.

`render-qt-svg.cpp` is the small real-renderer reproduction utility: compile
with the Qt6Svg and Qt6Gui pkg-config flags and pass an SVG input and PNG output.
