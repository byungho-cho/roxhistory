# D0061 screen assets

Provided ZIP: Drive 1HIJ6g-1VdPozGCOGyUSGyWDaMKkngjvQ.

- meadow-clean.png = 02-meadow-clean-plate.png, unchanged.
- tent.png = 03-tent-transparent.png, unchanged.
- camp-min.png is an engineering matte reference, not a runtime background or video. Derivation: decode the existing hunt-meadow-idle-loop.ogv at 6 fps, crop x40/y100/w200/h300, retain the RGB triplet with the lowest R+G+B per pixel across 28 samples, losslessly encode the result. Runtime uses the original video with this minimum plate to remove stationary pixels. Brightness/chroma/spatial masks suppress residue; the actual video bytes are untouched.

The supplied placement composite, bag reference and tent-position comparison are QA-only and are not imported as runtime scenery.
