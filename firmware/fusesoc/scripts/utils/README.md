# scripts/utils

Environment setup, run by `make setup_environment` from `firmware/fusesoc/` (see
[`firmware/fusesoc/README.md`](../../README.md)):

| Script | What it does |
|---|---|
| `build_virtualenv.sh` | The project venv at `<repository>/.venv`, shared with the Sphinx docs build |
| `build_fusesocenv.sh` | The FuseSoC libraries in that venv; SVUnit from `lharnaldi/svunit` |
| `install_verilator.sh` | Builds the Verilator the Makefile pins (`VERILATOR_VERSION`) into `~/.local`, no root (`make install_verilator`) |
| `build_verilator.sh` | Checks the Verilator on `PATH` against that pin; never fails the setup |
| `create_symlinks.sh` | The `hdl/` links of the cores |
