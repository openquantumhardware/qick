module clk_gen
#(
    parameter    FREQ       = 100000000,
    parameter    PHASE      =         0,
    parameter    DUTY_CYCLE =        50
)
(
    input  logic i_enable             ,
    output logic o_clk
);

logic generated_clk = 1'b0;
logic start_clk     = 1'b0;

real CLOCK_FREQ_MHZ = FREQ/1e6                       ;
real CLOCK_PERIOD   = 1e9 * 1.0/FREQ                 ;
real CLOCK_ON_TIME  = DUTY_CYCLE/100.0 * CLOCK_PERIOD;
real CLOCK_OFF_TIME = CLOCK_PERIOD - CLOCK_ON_TIME   ;
real START_DELAY    = CLOCK_PERIOD * PHASE/360       ;

initial begin
    $display("");
    $display(" == Simulation clock generator parameters ==");
    $display("Frequency:  %0d MHz",  CLOCK_FREQ_MHZ);
    $display("Phase:      %0d deg",  PHASE         );
    $display("Duty cycle: %0d %%",   DUTY_CYCLE    );
    $display("Period:     %0.3f ns", CLOCK_PERIOD  );
    $display("");
end

always @ (posedge i_enable or negedge i_enable) begin
    if (i_enable)
        #(START_DELAY) start_clk = 1'b1;
    else
        #(START_DELAY) start_clk = 1'b0;
end

always @ (posedge start_clk) begin
    if (start_clk) begin
        generated_clk = 1'b1;

        while (start_clk) begin
            #(CLOCK_ON_TIME)  generated_clk = 1'b0;
            #(CLOCK_OFF_TIME) generated_clk = 1'b1;
        end

        generated_clk = 1'b0;
    end
end

assign o_clk = generated_clk;

endmodule
