# Changelog

All notable changes to the QICK FuseSoC environment are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com).

## [Unreleased]

### Added
- The firmware flow moves to fusesoc and Hog: RTL sources in `firmware/rtl_lib`, one core per IP or building block in
  `firmware/fusesoc/cores`, projects in `firmware/Top/<board>/<project>`. `firmware/README.md` maps the names of the old
  `firmware/projects` directory to the new paths.
