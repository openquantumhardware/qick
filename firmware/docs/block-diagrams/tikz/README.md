# Hand-drawn block diagrams

`circuitikz`/TikZ sources for the block diagrams used in the general docs
(`docs/source/images/firmware/*.svg`). Build with `make tikz-diagrams` (or
`make tikz-diagram NAME=<name>`) from `firmware/fusesoc/` — see the Makefile
for details. Requires `pdflatex`, `ghostscript` (`gs`), and `pdftocairo`
(poppler-utils) on `PATH`.

- `firmware-overview.tex` — the general system diagram (tProc / signal
  generators / readouts / Zynq / PS-PL split). Originally drawn for QICK
  talks and seminars; reused here unchanged.
- `sg_v6.tex`, `dyn_readout.tex`, `sg_int4_v2.tex` — per-core diagrams,
  drawn in the same style but for the current `sgv6_top` /
  `readout_top_dynro` / `sg_int4_top` RTL specifically. Each block name and
  connection was checked by hand against the real source (not just redrawn
  from an earlier diagram) — see the commit that added them for what was
  verified.

These are deliberately *not* extracted from the RTL (unlike
`scripts/gen_block_diagram.py`, in the parent directory): a diagram drawn to
teach the architecture and one that dumps every port and wire are different
things, and the auto-generated version reads like the latter. Keep these in
sync by hand when a core's real top-level structure changes.
