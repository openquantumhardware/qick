# Hog: traceability, hooks and the nested layout

Companion of [HOG_QICK_Integration_Guide.md](HOG_QICK_Integration_Guide.md) (how to add and build a project). This document is about
what a build records and why you can trust its name, the pre-push hook, the `GetSHA` limitation of keeping Hog under `firmware/`,
and the practices that keep all of that working.

---

## Pre-push Hook (Automatic Safety Checks)

A pre-push hook automatically validates your changes before pushing to remote.

**What it does:**
1. Runs `./Hog/Do CHECKCI` — validates project configuration
2. Runs `./Hog/Do CHECKLIST` — validates list file syntax
3. Validates `.gitmodules` is not corrupted

**Hook location:** `.git/hooks/pre-push` (auto-installed on first setup)

**If it fails:**
```bash
# Fix the issues reported by CHECKCI or CHECKLIST
cd firmware && ./Hog/Do CHECKCI

# Then retry push
git push origin feature-branch
```

**To bypass (not recommended):**
```bash
git push --no-verify origin feature-branch
```
---

## Traceability: what a build records and how to rebuild it

A clean build (committed tree, `CHECKLIST` with no differences) leaves in
`bin/<group>/<project>-v<version>-<SHA>/` the `.bit`, the `.hwh` (same base name), the
`.xsa`, `versions.txt` (the commit and version of every file set of the project),
`timing_ok.txt` (or `timing_error.txt`), `timing_summary.md`, `reports/timing_summary_routed.rpt`
and `utilization.txt`. Check before handing a bitstream over:

- the folder name has no `-dirty`;
- `versions.txt`: the `Global` line has the build's commit and a version other than 0.0.0;
- there is no `diff_list_and_conf.txt` in the folder.

To rebuild it: check out the SHA, `./Hog/Do CREATE <group>/<project>` (pre-creation packages
the IPs from that commit), `./Hog/Do W <group>/<project>`.

**What the version follows.** Hog takes the project's version and SHA (the folder name, `versions.txt`, the
`GLOBAL_SHA` generics) from the newest commit among: `hog.conf`, `sim.conf`, `pre-creation.tcl` and
`post-creation.tcl` of the project directory; the files named in `list/*.src`; the constraints in `list/*.con`;
the IP repository (`ip/`). Nothing else moves it. Two consequences:

- **The block design must be listed.** `proj.tcl` sources `bd_*.tcl` itself, so without an entry a BD-only
  change leaves the version where it was and the bitstream gets the name of an older commit (it happened on
  2026-10-07: built from 3330560, named 9BA68F2). Every project lists its BD in `list/others.src` with
  `nosynth noimpl nosim` (tracked by Hog, used by no run). When you add a project, rename its BD script or
  point the project at another project's BD (`qick_bd_dir` in pre-creation.tcl), add or update that line
  ([section 3.9](HOG_QICK_Integration_Guide.md#39-create-the-list-files)). Verified on a 4x2 debug bench:
  `CHECKLIST` matches, and a commit that only touches the BD moves the Global and `others` SHAs.
- **The RTL of the BD's qick:ip IPs is listed too.** The pre-creation hook packages it from `rtl_lib` and
  `fusesoc/cores`, outside the hand-written lists, so on its own an RTL-only commit would not move the version
  (the build would carry the SHA of an older commit, whose checkout gives older RTL: seen on 2026-10-08,
  a build from 5f9caace named 8019A4C). `scripts/hog/gen_qick_ip_lists.py` writes, per project, the exact files
  the packager takes for each qick:ip of the BD that proj.tcl sources:
  - `list/qick_ip_rtl.src`: HDL, `nosynth noimpl nosim` (in the Vivado project, disabled; `nosynth nosim` for VHDL,
    whose files have no `used_in_implementation` and make Hog's CREATE stop with `Common 17-54`). In `versions.txt`
    Hog reports the Verilog/SystemVerilog under `OTHERS` and only the VHDL under `QICK_IP_RTL`; the global
    SHA follows both;
  - `list/qick_ip_xdc.con`: the IPs' XDC, `nosynth noimpl` (in `constrs_1`, disabled; the packaged IP carries
    the copy that is used).
  What cannot be listed goes into an inputs hash in the header, so a change there rewrites the list file: the
  IPs' `.core` files, the packager (`ip_packager.py`, `package_ip.tcl.j2`, `package_bd_ips.tcl`) and the
  packaged non-HDL files (sub-IP `.xci`, which Hog would instantiate in the top project if listed, and memory
  images). The lists are generated but **tracked**, like the BD script, and pre-creation **refuses to build
  while they are stale**:
  ```
  make -C fusesoc hog-lists PROJ=216/phase_ctrl_sys_dma          # regenerate one project
  make -C fusesoc hog-lists-all                                  # every project with a pre-creation.tcl
  make -C fusesoc hog-lists PROJ=216/phase_ctrl_sys_dma CHECK=1  # what pre-creation runs
  ```
  So commit the regenerated lists with the RTL change (or right after it). This is independent of where Hog
  is installed: Hog follows listed files only, wherever its root is; see GetSHA #512 below for the layout.
---

## GetSHA Issue #512 (Known Limitation)

**Status:** Hog expects `Hog/` and `Top/` at the git root (its documented layout; the
maintainer confirmed on [issue #512](https://gitlab.com/hog-cern/Hog/-/work_items/512):
`GetSHA` needs the git root to compute submodule SHAs). We keep them under `firmware/`
on purpose (decision of 2026-10-05: the firmware stays self-contained, mirroring the public
QICK repository), with the Hog submodule **pinned at Hog2026.1-4**, where this layout works:
SHAs per file set, version, `bin/` and the dirty flag are correct.

**Limits of the nested layout:**
- Do not update the Hog submodule: from 2026.2, `GetSHA` returns empty SHAs (#512).
- `Top/repo.conf` would be read at the git root (`<root>/Top/repo.conf`), not from
  `firmware/Top/`; we have none.
- Hog's CI templates assume Hog at the root.

Moving Hog/Top to the repository root, or making `firmware/` a repository of its own, are
the alternatives, to be evaluated later; we have asked upstream whether a Hog root that is
not the git top level could be supported.

**Reading the commit directly** works whatever the layout:

```bash
git log --format=%h --abbrev=7 -1   # the SHA, for scripts that need it
```

(There used to be a `Do-wrapper` and a `validate_getssha.sh` that only warned about this; with Hog pinned at 2026.1-4 they were not needed and were removed.)

---

## Troubleshooting GetSHA Errors

**"GetSHA returned empty" when running Hog commands**

This is likely Hog issue #512 (subdirectory issue) or a dirty repository.

```bash
# 1. Check git status
git status

# 2. Commit or stash any uncommitted changes
git add <the files you changed>   # explicit paths, never `git add .`
git commit -m "#<issue> work in progress"  # or: git stash

# 3. Verify branch state
git branch -v

# 4. If still broken, check git integrity
git fsck --full
```
---

## Best Practices

**1. Use relative paths in list files**
```ini
✅ GOOD:   ../../../rtl_lib/my_module.sv
❌ BAD:    /home/user/qick/rtl_lib/my_module.sv
```

**2. File naming matches fusesoc core name**
- If you have `firmware/fusesoc/cores/ip/my_ip/my_ip.sv`
- Reference it in hog.conf list files as:
  ```
  ../../../firmware/fusesoc/cores/ip/my_ip/my_ip.core
  ```

**3. Always validate before pushing**
```bash
cd firmware
./Hog/Do CHECKCI                    # ~10 seconds
./Hog/Do CHECKLIST                  # ~5 seconds
git push origin feature-branch      # Pre-push hook validates
```

**4. Keep projects modular**
- One project per board-variant combination
- Reuse common constraint files when possible
- Don't duplicate sources across projects

**5. Commit files before `CREATE` or `WORKFLOW`**
HOG only processes committed files. If a file is not tracked by git, it's silently ignored.

```bash
git status firmware/Top/216/my_project/  # Check for untracked
git ls-files -o --exclude-standard firmware/Top/216/my_project | xargs git add --
git commit -m "#<issue> ..."
./Hog/Do CREATE 216 my_project            # Now it works
```
