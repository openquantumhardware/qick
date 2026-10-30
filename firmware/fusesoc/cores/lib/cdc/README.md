# Library cores: cdc

Clock domain crossing modules.

Each core is its own FuseSoC core (`qick:cdc:<name>:<version>`, the version is in the `name:` of its `.core` file); the RTL is in `firmware/rtl_lib/` and `hdl/` links to it.
Simulate one with `make sim IP=<name>`, lint it with `make lint IP=<name>`. How to create a core: [NEW_CORE.md](../../../../docs/developer/NEW_CORE.md).

| Core | What it is | Tests |
|---|---|---|
| [`cdc_bit_sync`](cdc_bit_sync/) | 2 FF, NB-bit data synchronizer | yes |
| [`cdc_gray_sync`](cdc_gray_sync/) | Parametrizable N stages by M data width register synchronizer core | yes |
| [`cdc_handshake`](cdc_handshake/) | Multi-bit CDC via 4-phase req/ack toggle handshake (for infrequent control/status words, not streaming) | yes |
| [`cdc_reg_sync`](cdc_reg_sync/) | cdc_reg_sync (cdc library core) | yes |
| [`gcc`](gcc/) | gcc (cdc library core) | yes |
| [`sync_ab_en`](sync_ab_en/) | sync_ab_en (cdc library core) | yes |
| [`sync_pulse`](sync_pulse/) | sync_pulse (cdc library core) | yes |
| [`xcom_cdc`](xcom_cdc/) | XCOM clock domain crossing core synchronizer | yes |

8 cores. The list is checked by `make doc-check`: a core added here must be added to this table.
