module ser2par #(
    parameter DATA_WIDTH = 8,
    parameter SERIAL_WIDTH = 1,
    parameter PARALLEL_WIDTH = DATA_WIDTH / SERIAL_WIDTH
) (
    input                          i_clk,
    input                          i_rstn,
    input logic [SERIAL_WIDTH-1:0] i_data,
    input logic                    i_load,
    output logic [DATA_WIDTH-1:0]  o_data,
    output logic                   o_ready
);

    // Error checking for parameter validity
    initial begin
        if (DATA_WIDTH % SERIAL_WIDTH != 0) begin
            $error("Error: DATA_WIDTH must be a multiple of SERIAL_WIDTH.");
            $finish;
        end
    end

    logic [DATA_WIDTH-1:0] shift_register;
    logic [$clog2(PARALLEL_WIDTH)-1:0] count;
    logic internal_data_ready;

    always_ff @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            shift_register <= '0;
            count <= '0;
            internal_data_ready <= 1'b0;
        end else begin
            if (i_load) begin
                shift_register <= '0;
                count <= '0;
                internal_data_ready <= 1'b0;
            end else if (count < PARALLEL_WIDTH) begin
                shift_register[count*SERIAL_WIDTH +: SERIAL_WIDTH] <= i_data;
                count <= count + 1'b1;
                if (count == PARALLEL_WIDTH - 1) begin
                    internal_data_ready <= 1'b1;
                end
            end else begin
                internal_data_ready <= 1'b0;
            end
        end
    end

    assign o_data  = shift_register;
    assign o_ready = internal_data_ready;

endmodule
