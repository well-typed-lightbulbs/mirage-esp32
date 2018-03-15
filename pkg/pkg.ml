#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
#require "ocb-stubblr.topkg"
open Topkg
open Ocb_stubblr_topkg

let opams = [
  Pkg.opam_file "opam" ~lint_deps_excluding:(Some ["ocaml-freestanding"])
]

let nowhere ?force ?built ?cond ?exts ?dst _ = Pkg.nothing

let () =
  Pkg.describe ~build:(Pkg.build ~cmd()) ~opams "mirage-esp32" @@ fun c ->
  Ok [
    Pkg.mllib ~cmxa:false ~cmxs:false "lib/oS.mllib" ;
    Pkg.clib ~dllfield:nowhere "lib/libmirage-esp32_bindings.clib";
    (* Should be lib/pkgconfig/ but workaround ocaml/opam#2153 *)
    Pkg.share_root ~dst:"pkgconfig/" "lib/bindings/mirage-esp32.pc"
  ]
