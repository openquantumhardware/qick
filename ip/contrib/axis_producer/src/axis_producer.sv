//TODO: USAR start_address Y end_address EN READMEMB EN VEZ DE PARAMETROS
//START_ADDR_OFFSET Y END_ADDR

module axis_producer
#(
    parameter integer unsigned          MEM_NB_DATA       = 32,
    parameter integer unsigned          MEM_NB_ADDR       = 4,
    parameter string                    MEM_BIN_FILE      = "",
    parameter integer unsigned          NB_DATA           = 32,
    parameter logic   [MEM_NB_ADDR-1:0] START_ADDR_OFFSET = '0,
    parameter logic   [MEM_NB_ADDR-1:0] END_ADDR          = '1
)
(
    input  logic               i_clk,
    input  logic               i_rst,

    input  logic               i_maxi_ready,
    output logic               o_maxi_valid,
    output logic [NB_DATA-1:0] o_maxi_data,

    output logic               o_event_last_addr
);

    generate
        if (NB_DATA != MEM_NB_DATA) begin : g_check_parameter
            $fatal(1, "Different bus size for producer output NB_DATA=%0d and \
memory data bus MEM_NB_DATA=%0d currently not supported", NB_DATA, MEM_NB_DATA);
        end
    endgenerate

    localparam int unsigned DPATH_LATENCY = 2;

    logic [MEM_NB_ADDR-1:0]   mem_rd_addr;
    logic [MEM_NB_DATA-1:0]   mem_rd_data;
    logic                     mem_rd_enb;
    logic                     maxi_valid;
    logic                     transaction;
    logic                     init_state;
    logic [DPATH_LATENCY-1:0] last_addr_sr;

    bram#(.NB_DATA(MEM_NB_DATA),
          .NB_ADDR(MEM_NB_ADDR),
          .MEM_BIN_FILE(MEM_BIN_FILE)
    ) u_bram (
        .i_clk    (i_clk      ),
        .i_wr_enb (1'b0       ),
        .i_rd_enb (mem_rd_enb ),
        .i_wr_addr('0         ),
        .i_rd_addr(mem_rd_addr),
        .i_data   ('0         ),
        .o_data   (mem_rd_data)
    );

    assign init_state = (mem_rd_addr < START_ADDR_OFFSET + DPATH_LATENCY) & ~maxi_valid;
    assign transaction = (i_maxi_ready & o_maxi_valid) | init_state;
    assign mem_rd_enb = transaction;

    always_ff @ (posedge i_clk) begin
        if (i_rst) begin
            maxi_valid <= 1'b0;
            mem_rd_addr <= START_ADDR_OFFSET;
        end
        else begin
            maxi_valid <= ~init_state;
            if (transaction) begin
                if (mem_rd_addr < END_ADDR) begin
                    mem_rd_addr <= mem_rd_addr + $size(mem_rd_addr)'(1'b1);
                end
                else begin
                    mem_rd_addr <= START_ADDR_OFFSET;
                end
            end
        end
    end

    always_ff @ (posedge i_clk) begin
        if (i_rst) begin
            last_addr_sr <= '0;
        end
        else begin
            if (transaction) begin
                last_addr_sr <= {
                    last_addr_sr[$high(last_addr_sr)-1:0],
                    mem_rd_addr == END_ADDR
                };
            end
        end
    end

    always_ff @ (posedge i_clk) if (transaction) o_maxi_data       <= mem_rd_data;
    assign                                       o_maxi_valid       = maxi_valid;
    assign                                       o_event_last_addr  = last_addr_sr[$high(last_addr_sr)];

endmodule
