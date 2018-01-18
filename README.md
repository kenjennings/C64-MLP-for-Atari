# C64-MLP-for-Atari

Atari port of C64 Machine Language Project: https://github.com/smorrow8859/C64-Machine_Language_Project
(Note that the current version of MLP is 1.3 and this port is for the earlier 1.0)

---

[![AtariMLPScreen](https://github.com/kenjennings/C64-MLP-for-Atari/blob/master/AtariMLP.png)](#features)

Video of animation and collision detection testing on YouTube: https://www.youtube.com/watch?v=L3D9Z8X0SMI

---

Includes all files duplicated from original C64 MLP with edits specific to Atari.  Intent is to port from C64 to Atari with the MINIMAL amount of necessary changes.  In some cases the less Atari-like choices are made to make this appear more like the C64 original.

Extra files not relevant to Atari are still included here, but are not actually used by the Atari assembly. e.g. C64 sprite files.

NOTE that there are TWO release versions here.  1.03a is an earlier version with more bugs.   1.03b is current and works better.

---

Features implemented in demo...
- Custom character set
- Playfield (text character) horizontal/Vertical line drawing
- Simple text printing.
- Byte value to Hex text conversion and display.
- Joystick input
- Animated player/missile graphics
- Player/Missile to Playfield (text character) collision **anticipation**.
- Vertical blank interrupt controls player/missile animation.
- Display List Interrupt changes background color for the bottom of the screen.
