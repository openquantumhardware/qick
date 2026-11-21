///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qproc_dispatcher
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qproc_dispatcher.sv
//!
//! @brief   Timed output dispatcher for the QICK tProcessor v2 core: queues
//!          core-issued trigger/data/wave events in per-channel async FIFOs
//!          (c_clk_i domain) and fires each one on the t_clk_i time base
//!          once its timestamp has elapsed.
//!
//! @details
//!
//!
//! `out_port_data` (from qcore_cpu's port write) is decoded by
//! `.p_type`/`.p_addr` into one of three channel kinds (an address at or past
//! the kind's channel count is dropped; guard from openquantumhardware/qick ceefee4f, Diego
//! Martin):
//! * TRIGGER (`.p_type`=1, `.p_addr[5]`=1): 1-bit trigger, `OUT_TRIG_QTY`
//!   channels, addressed by `.p_addr[4:0]`.
//! * DATA    (`.p_type`=1, `.p_addr[5]`=0): `OUT_DPORT_DW`-bit data word,
//!   `OUT_DPORT_QTY` channels, addressed by `.p_addr[4:0]`.
//! * WAVE    (`.p_type`=0): 168-bit waveform-parameter word,
//!   `OUT_WPORT_QTY` channels, addressed by `.p_addr`.
//!
//! Each channel has its own dual-clock FIFO (`{data, time}` packed word,
//! `c_time_ref_dt`-offset absolute time). On the t_clk_i side, a per-channel
//! comparator watches the FIFO head against the running `time_abs_i` and
//! pops it (firing the output) once elapsed, gated so at most one pop is in
//! flight per channel at a time (`*_pop_prev`, tracked over 2 cycles to
//! cover the FIFO's read latency).
//!
//! Ported from firmware/ip/qick_processor/src/qproc_dispatcher.sv (FSM/CDC
//! structure and per-channel dispatch logic unchanged). `BRAM_FIFO_DC_2`
//! (an `xpm_fifo_async` wrapper with a `push_i`/`pop_i`/`flush_i` interface)
//! was replaced by the already-ported `fifo_async` core (same
//! `xpm_fifo_async` primitive, READ_MODE="fwft"): the write side's
//! `flush_i` (`core_rst`) has no direct equivalent on `fifo_async`, so it is
//! folded into `wr_rstn` instead (`c_rst_ni & ~core_rst`) -- `fifo_async`'s
//! `rst = ~wr_rstn | ~rd_rstn` reproduces the original's
//! `rst = ~wr_rst_ni | flush_i` exactly, since `rd_rstn` is held at
//! `t_rst_ni` (not pulsed) here. `fifo_async`'s single `wr_en`/`rd_en` fold
//! in what were separate `wr_en_i`/`push_i` and `rd_en_i`/`pop_i` pairs
//! (the dispatcher always drove `wr_en_i`=1, so `push_i` alone was already
//! the effective write-enable; `rd_en_i & pop_i` is now ANDed externally).
//! The hand-rolled 2-flop empty-flag synchronizer (c_clk_i domain) was
//! replaced by the shared `cdc_reg_sync` core. All previously implicit nets
//! were made explicit.
//!
//! NOTE (carried over unchanged from the legacy file): the debug buses
//! `c_fifo_do`/`t_fifo_do` hard-code indices `[1]`/`[0]`, i.e. they only
//! make sense for the default `OUT_TRIG_QTY=OUT_DPORT_QTY=OUT_WPORT_QTY=2`.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

`include "tpv2_pkg.sv"

module qproc_dispatcher #(
    parameter int FIFO_DEPTH    = 8,
    parameter int IN_PORT_QTY   = 1,
    parameter int OUT_TRIG_QTY  = 1,
    parameter int OUT_DPORT_QTY = 1,
    parameter int OUT_DPORT_DW  = 4,
    parameter int OUT_WPORT_QTY = 1
) (
    input  logic         c_clk_i,
    input  logic         c_rst_ni,
    input  logic         t_clk_i,
    input  logic         t_rst_ni,
    // Port
    input  logic         core_en,
    input  logic         core_rst,
    input  logic         time_en,
    input  logic         time_rst,
    input  logic [47:0]  c_time_ref_dt,
    input  logic [47:0]  time_abs_i,
    input  logic         port_we,
    input  tpv2_pkg::PORT_DT out_port_data,
    output logic          all_fifo_full,
    output logic          some_fifo_full,
    // Triggers
    output logic          port_trig_o [OUT_TRIG_QTY],
    // Data output interface
    output logic                    port_tvalid_o [OUT_DPORT_QTY],
    output logic [OUT_DPORT_DW-1:0] port_tdata_o  [OUT_DPORT_QTY],
    // Wave output interface
    output logic [167:0] m_axis_tdata  [OUT_WPORT_QTY],
    output logic          m_axis_tvalid [OUT_WPORT_QTY],
    input  logic          m_axis_tready [OUT_WPORT_QTY],
    // Debug outputs
    output logic [31:0] fifo_dt_do,
    output logic [31:0] axi_fifo_do,
    output logic [15:0] c_fifo_do,
    output logic [15:0] t_fifo_do
);

    // Fifos & dispatcher

    // .p_type > select between WAVE or DATA (TRIG is DATA with high address)
    // .p_addr > select port addr (bit 5 selects DATA vs TRIGGER)
    // .p_time > c_fifo_time_in_r
    // .p_data > c_fifo_data_in_r
    logic [47:0]  time_abs_r;

    logic [47:0]  c_fifo_time_in_r; // Time from the core -> to the FIFOs
    logic [167:0] c_fifo_data_in_r; // Data from the core -> to the FIFOs

    logic [47:0]  t_fifo_wave_time [OUT_WPORT_QTY]; // Time from the FIFO -> to the comparator
    logic [167:0] t_fifo_wave_dt   [OUT_WPORT_QTY]; // Data from the FIFO -> to the wport
    logic [OUT_WPORT_QTY-1:0] wave_t_gr_r;               // Abs time greater than time from W FIFO
    logic [OUT_WPORT_QTY-1:0] c_fifo_wave_push, c_fifo_wave_push_r, c_fifo_wave_push_s;
    logic [OUT_WPORT_QTY-1:0] wave_pop, wave_pop_prev;
    logic [OUT_WPORT_QTY-1:0] wave_pop_r, wave_pop_r2;

    logic [47:0]              t_fifo_data_time [OUT_DPORT_QTY]; // Time from the FIFO -> to the comparator
    logic [OUT_DPORT_DW-1:0]  t_fifo_data_dt   [OUT_DPORT_QTY]; // Data from the FIFO -> to the dport
    logic [OUT_DPORT_QTY-1:0] data_t_gr_r;                          // Abs time greater than time from D FIFO
    logic [OUT_DPORT_QTY-1:0] c_fifo_data_push, c_fifo_data_push_r, c_fifo_data_push_s;
    logic data_pop     [OUT_DPORT_QTY], data_pop_prev[OUT_DPORT_QTY];
    logic data_pop_r   [OUT_DPORT_QTY], data_pop_r2   [OUT_DPORT_QTY];

    logic [47:0] t_fifo_trig_time [OUT_TRIG_QTY]; // Time from the FIFO -> to the comparator
    logic        t_fifo_trig_dt   [OUT_TRIG_QTY]; // Data from the FIFO -> to the wport
    logic [OUT_TRIG_QTY-1:0] trig_t_gr_r;          // Abs time greater than time from T FIFO
    logic [OUT_TRIG_QTY-1:0] c_fifo_trig_push, c_fifo_trig_push_r, c_fifo_trig_push_s;
    logic trig_pop     [OUT_TRIG_QTY], trig_pop_prev[OUT_TRIG_QTY];
    logic trig_pop_r   [OUT_TRIG_QTY], trig_pop_r2   [OUT_TRIG_QTY];

    logic [OUT_TRIG_QTY-1:0]  c_fifo_trig_empty;
    logic [OUT_TRIG_QTY-1:0]  t_fifo_trig_empty, c_fifo_trig_full;
    logic [OUT_TRIG_QTY-1:0]  t_fifo_trig_empty_r;

    logic [OUT_DPORT_QTY-1:0] c_fifo_data_empty;
    logic [OUT_DPORT_QTY-1:0] t_fifo_data_empty, c_fifo_data_full;
    logic [OUT_DPORT_QTY-1:0] t_fifo_data_empty_r;

    logic [OUT_WPORT_QTY-1:0] c_fifo_wave_empty;
    logic [OUT_WPORT_QTY-1:0] t_fifo_wave_empty, c_fifo_wave_full;
    logic [OUT_WPORT_QTY-1:0] t_fifo_wave_empty_r;

    logic dfifo_full, wfifo_full, tfifo_full;
    logic all_tfifo_empty, all_dfifo_empty, all_wfifo_empty, all_fifo_empty;
    logic all_tfifo_full, all_dfifo_full, all_wfifo_full;

    // Write-side reset folded with a core-restart flush: fifo_async has no
    // separate flush_i, so pulsing wr_rstn low reproduces
    // `rst = ~wr_rst_ni | flush_i` from the legacy BRAM_FIFO_DC_2 (its
    // `rst = ~wr_rstn | ~rd_rstn`, with rd_rstn held at t_rst_ni).
    logic c_fifo_wr_rstn;
    assign c_fifo_wr_rstn = c_rst_ni & ~core_rst;

    ///////////////////////////////////////////////////////////////////////////////
    /// Fifo & dispatcher
    ///////////////////////////////////////////////////////////////////////////////
    assign all_tfifo_empty = &c_fifo_trig_empty;
    assign all_dfifo_empty = &c_fifo_data_empty;
    assign all_wfifo_empty = &c_fifo_wave_empty;
    assign all_fifo_empty  = all_tfifo_empty & all_dfifo_empty & all_wfifo_empty;

    assign all_tfifo_full = &c_fifo_trig_full;
    assign all_dfifo_full = &c_fifo_data_full;
    assign all_wfifo_full = &c_fifo_wave_full;
    assign all_fifo_full  = all_dfifo_full & all_wfifo_full & all_tfifo_full;

    assign tfifo_full     = |c_fifo_trig_full;
    assign dfifo_full     = |c_fifo_data_full;
    assign wfifo_full     = |c_fifo_wave_full;
    assign some_fifo_full = tfifo_full | dfifo_full | wfifo_full;

    // Clock domain change (2-flop sync of each FIFO's t_clk_i-domain empty
    // flag into c_clk_i, reusing the shared cdc_reg_sync core).
    cdc_reg_sync #(.DW (OUT_TRIG_QTY)) cdc_trig_empty_i (
        .clk_i  (c_clk_i),
        .rst_ni (c_rst_ni),
        .dt_i   (t_fifo_trig_empty),
        .dt_o   (c_fifo_trig_empty)
    );
    cdc_reg_sync #(.DW (OUT_DPORT_QTY)) cdc_data_empty_i (
        .clk_i  (c_clk_i),
        .rst_ni (c_rst_ni),
        .dt_i   (t_fifo_data_empty),
        .dt_o   (c_fifo_data_empty)
    );
    cdc_reg_sync #(.DW (OUT_WPORT_QTY)) cdc_wave_empty_i (
        .clk_i  (c_clk_i),
        .rst_ni (c_rst_ni),
        .dt_i   (t_fifo_wave_empty),
        .dt_o   (c_fifo_wave_empty)
    );

    logic time_en_r, time_rst_r;
    always_ff @(posedge t_clk_i) begin
        time_en_r  <= time_en;
        time_rst_r <= time_rst;
    end

    ///////////////////////////////////////////////////////////////////////////////
    /// Fifo ctrl-reg
    always_comb begin
        c_fifo_wave_push = 0;
        c_fifo_data_push = 0;
        c_fifo_trig_push = 0;
        // An address past the configured channel count is dropped explicitly.
        // Vivado and xsim ignore an out-of-range bit write, but Verilator
        // truncates the index to the vector width (WIDTHTRUNC), so without the
        // guard address 2 of a 2-channel kind aliases to channel 0 there.
        if (port_we)
            if (out_port_data.p_type)
                if (out_port_data.p_addr[5] == 1'b1) begin // Trigger selection bit
                    if (32'(out_port_data.p_addr[4:0]) < OUT_TRIG_QTY)
                        c_fifo_trig_push[out_port_data.p_addr[4:0]] = 1'b1;
                end else begin // Data
                    if (32'(out_port_data.p_addr[4:0]) < OUT_DPORT_QTY)
                        c_fifo_data_push[out_port_data.p_addr[4:0]] = 1'b1;
                end
            else if (32'(out_port_data.p_addr) < OUT_WPORT_QTY)
                c_fifo_wave_push[out_port_data.p_addr] = 1'b1;
        if (core_en) begin
            c_fifo_trig_push_s = c_fifo_trig_push_r;
            c_fifo_data_push_s = c_fifo_data_push_r;
            c_fifo_wave_push_s = c_fifo_wave_push_r;
        end else begin
            c_fifo_trig_push_s = '{default: '0};
            c_fifo_data_push_s = '{default: '0};
            c_fifo_wave_push_s = '{default: '0};
        end
    end

    always_ff @(posedge c_clk_i, negedge c_rst_ni) begin
        if (!c_rst_ni) begin
            c_fifo_data_in_r   <= '{default: '0};
            c_fifo_time_in_r   <= '{default: '0};
            c_fifo_trig_push_r <= '{default: '0};
            c_fifo_data_push_r <= '{default: '0};
            c_fifo_wave_push_r <= '{default: '0};
        end else if (core_en) begin
            c_fifo_trig_push_r <= c_fifo_trig_push;
            c_fifo_data_push_r <= c_fifo_data_push;
            c_fifo_wave_push_r <= c_fifo_wave_push;
            if (c_fifo_trig_push | c_fifo_data_push | c_fifo_wave_push) begin
                c_fifo_data_in_r <= out_port_data.p_data;
                c_fifo_time_in_r <= {{16{out_port_data.p_time[31]}}, out_port_data.p_time} + c_time_ref_dt;
            end
        end
    end


    always_ff @(posedge t_clk_i, negedge t_rst_ni) begin
        if (!t_rst_ni) begin
            time_abs_r          <= '{default: '0};
            trig_pop_r          <= '{default: '0};
            trig_pop_r2         <= '{default: '0};
            data_pop_r          <= '{default: '0};
            data_pop_r2         <= '{default: '0};
            wave_pop_r          <= '{default: '0};
            wave_pop_r2         <= '{default: '0};
            t_fifo_trig_empty_r <= '{default: '0};
            t_fifo_data_empty_r <= '{default: '0};
            t_fifo_wave_empty_r <= '{default: '0};
        end else begin
            time_abs_r          <= time_abs_i;
            trig_pop_r          <= trig_pop;
            trig_pop_r2         <= trig_pop_r;
            data_pop_r          <= data_pop;
            data_pop_r2         <= data_pop_r;
            wave_pop_r          <= wave_pop;
            wave_pop_r2         <= wave_pop_r;
            t_fifo_trig_empty_r <= t_fifo_trig_empty;
            t_fifo_data_empty_r <= t_fifo_data_empty;
            t_fifo_wave_empty_r <= t_fifo_wave_empty;
        end
    end


    ///////////////////////////////////////////////////////////////////////////////
    /// Trigger port
    ///////////////////////////////////////////////////////////////////////////////
    for (genvar ind_tfifo = 0; ind_tfifo < OUT_TRIG_QTY; ind_tfifo++) begin : gen_trig_port
        logic trig_rd_en;
        // Trigger FIFO
        fifo_async #(
            .B          (1 + 48),
            .N          (2 ** FIFO_DEPTH),
            .READ_MODE  ("fwft")
        ) trig_fifo_i (
            .wr_rstn (c_fifo_wr_rstn),
            .wr_clk  (c_clk_i),
            .wr_en   (c_fifo_trig_push_s[ind_tfifo]),
            .din     ({c_fifo_data_in_r[0], c_fifo_time_in_r}),
            .full    (c_fifo_trig_full[ind_tfifo]),
            .wr_err  (),
            .rd_rstn (t_rst_ni),
            .rd_clk  (t_clk_i),
            .rd_en   (trig_rd_en),
            .dout    ({t_fifo_trig_dt[ind_tfifo], t_fifo_trig_time[ind_tfifo]}),
            .empty   (t_fifo_trig_empty[ind_tfifo]),
            .data_valid ()
        );
        assign trig_rd_en = time_en_r & trig_pop_r[ind_tfifo];

        // Time comparator
        always_ff @(posedge t_clk_i) begin
            trig_t_gr_r[ind_tfifo] <= $signed({1'b0, time_abs_r}) > $signed({1'b0, t_fifo_trig_time[ind_tfifo]});
        end
        // Pop generator
        always_comb begin : trig_dispatcher
            trig_pop[ind_tfifo]      = 0;
            trig_pop_prev[ind_tfifo] = |({trig_pop_r[ind_tfifo], trig_pop_r2[ind_tfifo]});
            if (time_en_r & ~t_fifo_trig_empty_r[ind_tfifo])
                if (trig_t_gr_r[ind_tfifo] & ~trig_pop_prev[ind_tfifo])
                    trig_pop[ind_tfifo] = 1'b1;
        end
    end


    ///////////////////////////////////////////////////////////////////////////////
    /// Wave port
    ///////////////////////////////////////////////////////////////////////////////
    for (genvar ind_wfifo = 0; ind_wfifo < OUT_WPORT_QTY; ind_wfifo++) begin : gen_wave_port
        logic wave_rd_en;
        // Waveform FIFO
        fifo_async #(
            .B          (168 + 48),
            .N          (2 ** FIFO_DEPTH),
            .READ_MODE  ("fwft")
        ) wave_fifo_i (
            .wr_rstn (c_fifo_wr_rstn),
            .wr_clk  (c_clk_i),
            .wr_en   (c_fifo_wave_push_s[ind_wfifo]),
            .din     ({c_fifo_data_in_r, c_fifo_time_in_r}),
            .full    (c_fifo_wave_full[ind_wfifo]),
            .wr_err  (),
            .rd_rstn (t_rst_ni),
            .rd_clk  (t_clk_i),
            .rd_en   (wave_rd_en),
            .dout    ({t_fifo_wave_dt[ind_wfifo], t_fifo_wave_time[ind_wfifo]}),
            .empty   (t_fifo_wave_empty[ind_wfifo]),
            .data_valid ()
        );
        assign wave_rd_en = time_en_r & wave_pop_r[ind_wfifo];

        // Time comparator
        always_ff @(posedge t_clk_i) begin
            wave_t_gr_r[ind_wfifo] <= $signed({1'b0, time_abs_r}) > $signed({1'b0, t_fifo_wave_time[ind_wfifo]});
        end
        // Pop generator
        always_comb begin : wave_dispatcher
            wave_pop[ind_wfifo]      = 0;
            wave_pop_prev[ind_wfifo] = |({wave_pop_r[ind_wfifo], wave_pop_r2[ind_wfifo]});
            if (time_en & ~t_fifo_wave_empty_r[ind_wfifo])
                if (wave_t_gr_r[ind_wfifo] & ~wave_pop_prev[ind_wfifo])
                    wave_pop[ind_wfifo] = m_axis_tready[ind_wfifo];
        end
    end

    ///////////////////////////////////////////////////////////////////////////////
    /// Data port
    ///////////////////////////////////////////////////////////////////////////////
    for (genvar ind_dfifo = 0; ind_dfifo < OUT_DPORT_QTY; ind_dfifo++) begin : gen_data_port
        logic data_rd_en;
        // Data FIFO
        fifo_async #(
            .B          (OUT_DPORT_DW + 48),
            .N          (2 ** FIFO_DEPTH),
            .READ_MODE  ("fwft")
        ) data_fifo_i (
            .wr_rstn (c_fifo_wr_rstn),
            .wr_clk  (c_clk_i),
            .wr_en   (c_fifo_data_push_s[ind_dfifo]),
            .din     ({c_fifo_data_in_r[OUT_DPORT_DW-1:0], c_fifo_time_in_r}),
            .full    (c_fifo_data_full[ind_dfifo]),
            .wr_err  (),
            .rd_rstn (t_rst_ni),
            .rd_clk  (t_clk_i),
            .rd_en   (data_rd_en),
            .dout    ({t_fifo_data_dt[ind_dfifo], t_fifo_data_time[ind_dfifo]}),
            .empty   (t_fifo_data_empty[ind_dfifo]),
            .data_valid ()
        );
        assign data_rd_en = time_en_r & data_pop_r[ind_dfifo];

        // Time comparator
        always_ff @(posedge t_clk_i) begin
            data_t_gr_r[ind_dfifo] <= $signed({1'b0, time_abs_r}) > $signed({1'b0, t_fifo_data_time[ind_dfifo]});
        end
        // Pop generator
        always_comb begin : data_dispatcher
            data_pop[ind_dfifo]      = 0;
            data_pop_prev[ind_dfifo] = |({data_pop_r[ind_dfifo], data_pop_r2[ind_dfifo]});
            if (time_en_r & ~t_fifo_data_empty_r[ind_dfifo])
                if (data_t_gr_r[ind_dfifo] & ~data_pop_prev[ind_dfifo])
                    data_pop[ind_dfifo] = 1'b1;
        end
    end


    ///////////////////////////////////////////////////////////////////////////////
    // Outputs
    ///////////////////////////////////////////////////////////////////////////////


    ///////////////////////////////////////////////////////////////////////////////
    // Out triggers
    logic port_trig_r [OUT_TRIG_QTY];
    always_ff @(posedge t_clk_i, negedge t_rst_ni) begin
        for (int ind_tport = 0; ind_tport < OUT_TRIG_QTY; ind_tport++) begin
            if (!t_rst_ni)
                port_trig_r[ind_tport] <= 1'b0;
            else if (time_rst_r)
                port_trig_r[ind_tport] <= 1'b0;
            else if (trig_pop[ind_tport])
                port_trig_r[ind_tport] <= t_fifo_trig_dt[ind_tport];
        end
    end
    assign port_trig_o = port_trig_r;

    ///////////////////////////////////////////////////////////////////////////////
    // Out data
    logic [OUT_DPORT_DW-1:0] port_dt_r [OUT_DPORT_QTY];
    always_ff @(posedge t_clk_i, negedge t_rst_ni) begin
        for (int ind_dport = 0; ind_dport < OUT_DPORT_QTY; ind_dport++) begin
            if (!t_rst_ni)
                port_dt_r[ind_dport] <= '{default: '0};
            else if (time_rst_r)
                port_dt_r[ind_dport] <= '{default: '0};
            else if (data_pop[ind_dport])
                port_dt_r[ind_dport] <= t_fifo_data_dt[ind_dport];
        end
    end
    assign port_tvalid_o = data_pop_r;
    assign port_tdata_o  = port_dt_r;


    ///////////////////////////////////////////////////////////////////////////////
    // Out waves (registered output)
    logic         m_axis_tvalid_r [OUT_WPORT_QTY];
    logic [167:0] m_axis_tdata_r  [OUT_WPORT_QTY];
    always_ff @(posedge t_clk_i, negedge t_rst_ni) begin
        for (int ind_wport = 0; ind_wport < OUT_WPORT_QTY; ind_wport++) begin
            if (!t_rst_ni) begin
                m_axis_tvalid_r[ind_wport] <= 1'b0;
                m_axis_tdata_r[ind_wport]  <= '{default: '0};
            end else if (time_rst_r) begin
                m_axis_tvalid_r[ind_wport] <= 1'b0;
                m_axis_tdata_r[ind_wport]  <= '{default: '0};
            end else begin
                if (wave_pop[ind_wport])
                    m_axis_tvalid_r[ind_wport] <= 1'b1;
                else if (m_axis_tready[ind_wport])
                    m_axis_tvalid_r[ind_wport] <= 1'b0;
                m_axis_tdata_r[ind_wport] <= t_fifo_wave_dt[ind_wport];
            end
        end
    end

    assign m_axis_tvalid = m_axis_tvalid_r;
    assign m_axis_tdata  = m_axis_tdata_r;

    ///// Debug
    assign fifo_dt_do = {t_fifo_data_time[0][27:0], t_fifo_data_dt[0][3:0]};

    assign axi_fifo_do[31:28] = t_fifo_data_dt[0][3:0];
    assign axi_fifo_do[27:12] = t_fifo_data_time[0][15:0];
    assign axi_fifo_do[11:8]  = {some_fifo_full, wfifo_full, dfifo_full, tfifo_full};
    assign axi_fifo_do[7:4]   = {all_fifo_full, all_wfifo_full, all_dfifo_full, all_tfifo_full};
    assign axi_fifo_do[3:0]   = {all_fifo_empty, all_wfifo_empty, all_dfifo_empty, all_tfifo_empty};

    // NOTE: hard-codes indices [1]/[0] -- only meaningful for QTY=2 (see header).
    assign c_fifo_do[15:11] = {c_fifo_wave_push_s[0], c_fifo_data_push_s[1], c_fifo_data_push_s[0],
                                c_fifo_trig_push_s[1], c_fifo_trig_push_s[0]};
    assign c_fifo_do[10:9]  = {c_fifo_wave_full[1], c_fifo_wave_full[0]};
    assign c_fifo_do[8:7]   = {c_fifo_data_full[1], c_fifo_data_full[0]};
    assign c_fifo_do[6:5]   = {c_fifo_trig_full[1], c_fifo_trig_full[0]};
    assign c_fifo_do[4:0]   = {all_fifo_full, all_wfifo_full, all_dfifo_full, all_tfifo_full, 1'b0};

    assign t_fifo_do[15:11] = {wave_pop_r[0], data_pop_r[1], data_pop_r[0], trig_pop_r[1], trig_pop_r[0]};
    assign t_fifo_do[10:9]  = {c_fifo_wave_empty[1], c_fifo_wave_empty[0]};
    assign t_fifo_do[8:7]   = {c_fifo_data_empty[1], c_fifo_data_empty[0]};
    assign t_fifo_do[6:5]   = {c_fifo_trig_empty[1], c_fifo_trig_empty[0]};
    assign t_fifo_do[4:0]   = {all_fifo_empty, all_wfifo_empty, all_dfifo_empty, all_tfifo_empty, 1'b0};

endmodule
