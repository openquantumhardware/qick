module common_counter
#(
    parameter integer unsigned              NB_MAX_COUNT            = 32,
    parameter integer unsigned              REGISTER_START_COUNT    =  0,
    parameter integer unsigned              INCLUSIVE_COUNT         =  0,
    parameter bit                           MUTE_WHEN_DISABLED      =  1
)
(
    input   logic                           i_clk,
    input   logic                           i_rst,
    input   logic                           i_start_count,
    input   logic                           i_enable,
    input   logic   [NB_MAX_COUNT-1   : 0]  i_rf_max_count,

    output  logic   [NB_MAX_COUNT-1   : 0]  o_counter,
    output  logic                           o_count_done,
    output  logic                           o_count_in_process
);

    logic           [NB_MAX_COUNT-1   : 0]  counter;
    logic           [NB_MAX_COUNT-1   : 0]  counter_next;
    logic                                   count_in_process;
    logic                                   count_done;
    logic                                   run_counter;
    logic                                   start_count_muxed;

    generate
        logic                               start_count_d;

        always @(posedge i_clk) begin
            if (i_enable)   start_count_d <= i_start_count;

            if (i_rst)      start_count_d <= 1'b0;
        end

        if(REGISTER_START_COUNT) begin: gen_start_count_reg
            assign start_count_muxed = start_count_d;
        end
        else begin
            assign start_count_muxed = i_start_count;
        end
    endgenerate

    generate
        if(INCLUSIVE_COUNT) begin: gen_inclusive_counter
            assign count_done = (counter == i_rf_max_count) & run_counter;
        end
        else begin
            assign count_done = (counter == i_rf_max_count-1) & run_counter;
        end
    endgenerate

    assign run_counter          = (start_count_muxed || count_in_process);

    assign counter_next         = ~run_counter ? counter :
                                  count_done   ? '0      :
                                  counter + NB_MAX_COUNT'(1'b1);

    assign count_in_process = |counter;

    always @(posedge i_clk) begin
        if (i_enable) counter   <= counter_next;

        if(i_rst) begin
            counter             <= {NB_MAX_COUNT{1'b0}};
        end
    end

    assign o_counter            = counter;

    generate
        if (MUTE_WHEN_DISABLED) begin
            assign o_count_done         = count_done    & i_enable;
            assign o_count_in_process   = run_counter   & i_enable;
        end
        else begin
            assign o_count_done         = count_done ;
            assign o_count_in_process   = run_counter;
        end
    endgenerate

endmodule
