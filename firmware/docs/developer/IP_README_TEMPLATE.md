# <ip_name> (<ip_name>)

<!--
This is the README every packaged IP under cores/ip/<ip>/ must have. `make new-ip` copies it to
cores/ip/<ip_name>/README.md; fill it in and delete these comments. The rules are in
firmware/docs/developer/NEW_CORE.md ("Documenting an IP").

Write Part I for the person who USES the IP: someone who will drop it into a block design and drive it from
Python and who has not read the RTL. Everything that is not obvious from the port names belongs there: what the
IP does, the rules it follows (state machines, thresholds, what happens at the limits), the formats of its data,
what to set in the block design. Part II is for the person who maintains it.

Do not put this explanation only in a bring-up project's README, a notebook or a driver docstring: those are
logs and API notes. Link to this file from them.

Write what was observed, and say what was NOT verified. Put numbers that were measured on hardware in a table
with the setup they came from.
-->

One or two sentences: what the IP produces or measures, in terms of what the user sees.

- Project / issue:
- VLNV: `qick:ip:<ip_name>:1.0.0` (module `<ip_name>`)
- Driver: `<Class>` in `cores/ip/<ip_name>/driver/<ip_name>.py` (or the monolithic module it lives in)
- Hardware bring-up: `firmware/Top/<board>/<project>` (status in U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference (ports,
registers, verification, files).

---

# Part I -- Using the IP

## U1. What it does

The behaviour in the user's terms, with a small diagram of the data path (input, processing, output, memories).

## U2. How it works, and the rules that are not obvious

The part people get wrong. For each rule say what happens and what to do about it. Typical content:

- state machines and what triggers each transition (arm, re-arm, dead time, hold-off);
- comparators and thresholds: level or edge, signed or unsigned, before or after offset/filter;
- registers with special semantics (strobe bits and whether they are edge- or level-sensitive, self-clearing or
  not, write order, shared registers that apply to every channel);
- what happens at the limits (memory full, counter wrap, overflow, saturation);
- units (MHz or Hz, clocks or samples, signed or unsigned).

## U3. Data formats

Word layouts (bit fields), how to decode them into physical quantities, a working decoding function, resolution
and range.

## U4. Memories, throughput and limits

What is stored where, how much, what is dropped and when, maximum rates.

## U5. Python quick start

A short example that works on hardware, using the driver API (not raw register writes), with realistic values.

## U6. Using it in a block design

Which ports connect to what, which clock each port needs (say which clock exactly, not "a clock"), parameters
and their defaults in the packaged IP, timing constraints to add, known warnings.

## U7. Gotchas

A table: symptom, cause, what to do. Include every mistake made during bring-up.

## U8. Validation status

What was verified on hardware (board, project, date, the measured numbers), what was only simulated, what is
not verified yet.

---

# Part II -- Reference

## Ports

Table of ports, direction, width, clock domain.

## Registers

Table: address, register, fields, access, description (generated from `rdl/<ip_name>_regmap.rdl`; keep the RDL
descriptions accurate, they are the source of the driver documentation).

## Verification

Simulation testbenches and what each test covers; register-layer driver tests.

## Files

```
cores/ip/<ip_name>/
  README.md
  <ip_name>.core
  hdl/<ip_name>.sv -> ../../../../rtl_lib/ip/<ip_name>.sv
  rdl/<ip_name>_regmap.rdl
  driver/<ip_name>.py
  tests/
  demo/                # notebooks, models
```

## Open items

Known gaps, planned changes.
