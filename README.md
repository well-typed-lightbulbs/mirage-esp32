# mirage-impl-esp32 -- ESP32 core platform libraries for MirageOS

This package provides the MirageOS `OS` library for
esp32 targets, which handles the main loop and timers. It also provides
the low level C startup code and C stubs required by the OCaml code.


The OCaml runtime and C runtime required to support it are provided separately
by the [ocaml-esp32][2] package.

[2]: https://github.com/TheLortex/ocaml-esp32