`include "_qproc_defines.svh"
   
module qproc_dispatcher # (
   parameter DEBUG          =  0 ,
   parameter FIFO_DEPTH     =  8 ,
   parameter IN_PORT_QTY    =  1 ,
   parameter OUT_TRIG_QTY   =  1 ,
   parameter OUT_DPORT_QTY  =  1 ,
   parameter OUT_DPORT_DW   =  4 ,
   parameter OUT_WPORT_QTY  =  1 
)(
   input  wire          c_clk_i        ,
   input  wire          c_rst_ni       ,
   input  wire          t_clk_i        ,
   input  wire          t_rst_ni       ,
//Port
   input  wire          core_en        ,
   input  wire          core_rst       ,
   input  wire          time_en        ,
   input  wire          time_rst       ,
   input  wire  [47:0]  c_time_ref_dt  ,
   input  wire  [47:0]  time_abs_i     ,
   input  wire          port_we        ,
   input  PORT_DT       out_port_data  ,
   output wire          all_fifo_full  ,
   output wire          some_fifo_full ,
// TRIGGERS 
   output wire          port_trig_o  [OUT_TRIG_QTY] ,
// DATA OUTPUT INTERFACE
   output wire                    port_tvalid_o[OUT_DPORT_QTY] ,
   output wire [OUT_DPORT_DW-1:0] port_tdata_o [OUT_DPORT_QTY] ,
// WAVE OUTPUT INTERFACE
   output wire [167:0]   m_axis_tdata  [OUT_WPORT_QTY] ,
   output wire           m_axis_tvalid [OUT_WPORT_QTY] ,
   input  wire           m_axis_tready [OUT_WPORT_QTY] , 
   output wire [31:0]    fifo_dt_do    , 
   output wire [31:0]    axi_fifo_do   , 
   output wire [15:0]    c_fifo_do     , 
   output wire [15:0]    t_fifo_do 
);


// FIFOS & DISPATCHER
 
// .p_type > Select between WAVE or DATA (TRIG is DATA with high address)
// .p_addr > Select Port Addr (Bit 3 select between DATA and TRIGGER (Addr 0 to 7 are Data, Addr 8 to 15 are Trigger)
// .p_time > c_fifo_time_in_r 
// .p_data > c_fifo_data_in_r

reg  [ 47:0]               c_fifo_time_in_r ; // TIME from the CORE > To the FIFOs
reg  [167:0]               c_fifo_data_in_r ; // DATA from the CORE > To the FIFOs

wire [47:0]                t_fifo_wave_time  [OUT_WPORT_QTY-1:0]; // TIME from the FIFO > To the Comparator
wire [167:0]               t_fifo_wave_dt    [OUT_WPORT_QTY-1:0]; // DATA from the FIFO > TO the WPORT
wire [47:0]                W_RESULT          [OUT_WPORT_QTY-1:0]; // Comparison between t_fifo_wave_time and time_abs_i
reg  [OUT_WPORT_QTY-1:0]   wave_t_gr;                             // Sign bit of W_RESULT
reg  [OUT_WPORT_QTY-1:0]   c_fifo_wave_push, c_fifo_wave_push_r, c_fifo_wave_push_s; 
reg  [OUT_WPORT_QTY-1:0]   wave_pop, wave_pop_prev;
reg  [OUT_WPORT_QTY-1:0]   wave_pop_r, wave_pop_r2, wave_pop_r3, wave_pop_r4;

wire [47:0]                t_fifo_data_time  [OUT_DPORT_QTY-1:0]; // TIME from the FIFO > To the Comparator
wire [OUT_DPORT_DW-1 :0]   t_fifo_data_dt    [OUT_DPORT_QTY-1:0]; // DATA from the FIFO > TO the DPORT
wire [47:0]                D_RESULT          [OUT_DPORT_QTY-1:0]; // Comparison between t_fifo_data_time and time_abs_i
reg  [OUT_DPORT_QTY-1:0]   data_t_gr;                             // Sign bit of D_RESULT
reg  [OUT_DPORT_QTY-1:0]   c_fifo_data_push, c_fifo_data_push_r, c_fifo_data_push_s ; 
reg                        data_pop[OUT_DPORT_QTY], data_pop_prev[OUT_DPORT_QTY];
reg                        data_pop_r[OUT_DPORT_QTY], data_pop_r2[OUT_DPORT_QTY], data_pop_r3[OUT_DPORT_QTY], data_pop_r4[OUT_DPORT_QTY];

wire [47:0]                t_fifo_trig_time  [OUT_TRIG_QTY]; // TIME from the FIFO > To the Comparator
wire                       t_fifo_trig_dt    [OUT_TRIG_QTY]; // DATA from the FIFO > TO the WPORT
wire [47:0]                T_RESULT          [OUT_TRIG_QTY]; // Comparison between t_fifo_trig_time and time_abs_i
reg  [OUT_TRIG_QTY-1:0]    trig_t_gr; // Sign bit of T_RESULT
reg  [OUT_TRIG_QTY-1:0]    c_fifo_trig_push, c_fifo_trig_push_r, c_fifo_trig_push_s ; 
reg                        trig_pop[OUT_TRIG_QTY], trig_pop_prev[OUT_TRIG_QTY];
reg                        trig_pop_r[OUT_TRIG_QTY], trig_pop_r2[OUT_TRIG_QTY], trig_pop_r3[OUT_TRIG_QTY], trig_pop_r4[OUT_TRIG_QTY];

reg  [OUT_TRIG_QTY-1:0]    c_fifo_trig_empty ;
wire [OUT_TRIG_QTY-1:0]    t_fifo_trig_empty, c_fifo_trig_full ;
reg  [OUT_DPORT_QTY-1:0]   c_fifo_data_empty ;
wire [OUT_DPORT_QTY-1:0]   t_fifo_data_empty, c_fifo_data_full ;
reg  [OUT_WPORT_QTY-1:0]   c_fifo_wave_empty;
wire [OUT_WPORT_QTY-1:0]   t_fifo_wave_empty , c_fifo_wave_full   ;
wire                       dfifo_full, wfifo_full;

///////////////////////////////////////////////////////////////////////////////
/// FIFO & DISPATCHER
///////////////////////////////////////////////////////////////////////////////
assign all_tfifo_empty = &c_fifo_trig_empty ;
assign all_dfifo_empty = &c_fifo_data_empty ;
assign all_wfifo_empty = &c_fifo_wave_empty ;
assign all_fifo_empty  = all_tfifo_empty & all_dfifo_empty & all_wfifo_empty ;   

assign all_tfifo_full = &c_fifo_trig_full ;
assign all_dfifo_full = &c_fifo_data_full ;
assign all_wfifo_full = &c_fifo_wave_full ;
assign all_fifo_full  = all_dfifo_full & all_wfifo_full & all_tfifo_full;   

assign tfifo_full = |c_fifo_trig_full ;
assign dfifo_full = |c_fifo_data_full ; 
assign wfifo_full = |c_fifo_wave_full ; 
assign some_fifo_full = tfifo_full | dfifo_full | wfifo_full ;

// CLOCK DOMAIN CHANGE
(* ASYNC_REG = "TRUE" *) reg [OUT_TRIG_QTY-1:0] fifo_trig_empty_cdc;
(* ASYNC_REG = "TRUE" *) reg [OUT_DPORT_QTY-1:0] fifo_data_empty_cdc;
(* ASYNC_REG = "TRUE" *) reg [OUT_WPORT_QTY-1:0] fifo_wave_empty_cdc;
always_ff @(posedge c_clk_i) begin
   fifo_trig_empty_cdc      <= t_fifo_trig_empty;
   fifo_data_empty_cdc      <= t_fifo_data_empty;
   fifo_wave_empty_cdc      <= t_fifo_wave_empty;
   c_fifo_trig_empty        <= fifo_trig_empty_cdc;
   c_fifo_data_empty        <= fifo_data_empty_cdc;
   c_fifo_wave_empty        <= fifo_wave_empty_cdc;
end

///////////////////////////////////////////////////////////////////////////////
/// FIFO CTRL-REG
always_comb begin
   c_fifo_wave_push    = 0;
   c_fifo_data_push    = 0;
   c_fifo_trig_push    = 0;
   if (port_we)
      if (out_port_data.p_type)
         if ( out_port_data.p_addr[5] == 1'b1 ) //TRIGGER Selection Bit
            c_fifo_trig_push [out_port_data.p_addr[4:0] ] = 1'b1 ; //32 Possible Port Address
         else // DATA
            c_fifo_data_push [out_port_data.p_addr[4:0] ] = 1'b1 ; //32 Possible Port Address
      else
         c_fifo_wave_push [out_port_data.p_addr] = 1'b1 ;
   if (core_en) begin 
      c_fifo_trig_push_s = c_fifo_trig_push_r;
      c_fifo_data_push_s = c_fifo_data_push_r;
      c_fifo_wave_push_s = c_fifo_wave_push_r;
   end else begin
      c_fifo_trig_push_s = '{default:'0} ;
      c_fifo_data_push_s = '{default:'0} ;
      c_fifo_wave_push_s = '{default:'0} ;
   end
end  

always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni) begin
      c_fifo_data_in_r       <= '{default:'0} ;
      c_fifo_time_in_r       <= '{default:'0} ;
      c_fifo_trig_push_r     <= '{default:'0} ;
      c_fifo_data_push_r     <= '{default:'0} ;
      c_fifo_wave_push_r     <= '{default:'0} ;
   end else if (core_en) begin
      c_fifo_trig_push_r     <= c_fifo_trig_push ;
      c_fifo_data_push_r     <= c_fifo_data_push ;
      c_fifo_wave_push_r     <= c_fifo_wave_push ;
         if (c_fifo_trig_push | c_fifo_data_push | c_fifo_wave_push) begin
         c_fifo_data_in_r       <= out_port_data.p_data ;
         //c_fifo_time_in_r       <= {16'd0, out_port_data.p_time} + c_time_ref_dt;
         c_fifo_time_in_r       <= { {16{out_port_data.p_time[31]}} , out_port_data.p_time} + c_time_ref_dt;
      end
   end
end


always_ff @ (posedge t_clk_i, negedge t_rst_ni) begin
   if (!t_rst_ni) begin
      trig_pop_r     <= '{default:'0} ;
      trig_pop_r2    <= '{default:'0} ;
      trig_pop_r3    <= '{default:'0} ;
      trig_pop_r4    <= '{default:'0} ;
      data_pop_r     <= '{default:'0} ;
      data_pop_r2    <= '{default:'0} ;
      data_pop_r3    <= '{default:'0} ;
      data_pop_r4    <= '{default:'0} ;
      wave_pop_r     <= '{default:'0} ;
      wave_pop_r2    <= '{default:'0} ;
      wave_pop_r3    <= '{default:'0} ;
      wave_pop_r4    <= '{default:'0} ;
   end else begin
      trig_pop_r     <= trig_pop;
      trig_pop_r2    <= trig_pop_r;
      trig_pop_r3    <= trig_pop_r2;
      trig_pop_r4    <= trig_pop_r3;
      data_pop_r     <= data_pop;
      data_pop_r2    <= data_pop_r;
      data_pop_r3    <= data_pop_r2;
      data_pop_r4    <= data_pop_r3;
      wave_pop_r     <= wave_pop;
      wave_pop_r2    <= wave_pop_r;
      wave_pop_r3    <= wave_pop_r2;
      wave_pop_r4    <= wave_pop_r3;
   end
end


///////////////////////////////////////////////////////////////////////////////
/// TRIGGER PORT
///////////////////////////////////////////////////////////////////////////////
genvar ind_tfifo;
generate
   for (ind_tfifo=0; ind_tfifo < OUT_TRIG_QTY; ind_tfifo=ind_tfifo+1) begin: TRIG_FIFO
      // TRIGGER FIFO
      BRAM_FIFO_DC_2 # (
         .FIFO_DW (1+48) , 
         .FIFO_AW (FIFO_DEPTH) 
      ) trig_fifo_inst ( 
         .wr_clk_i   ( c_clk_i      ) ,
         .wr_rst_ni  ( c_rst_ni     ) ,
         .wr_en_i    ( 1'b1     ) ,
         .push_i     ( c_fifo_trig_push_s[ind_tfifo] ) ,
         .data_i     ( {c_fifo_data_in_r[0],c_fifo_time_in_r}  ) ,
         .rd_clk_i   ( t_clk_i      ) ,
         .rd_rst_ni  ( t_rst_ni     ) ,
         .rd_en_i    ( time_en    ) ,
         .pop_i      ( trig_pop        [ind_tfifo] ) ,
         .data_o     ( {t_fifo_trig_dt[ind_tfifo], t_fifo_trig_time[ind_tfifo]} ) ,
         .flush_i    ( core_rst     ),
         .async_empty_o ( t_fifo_trig_empty [ind_tfifo] ) , // SYNC with RD_CLK
         .async_full_o  ( c_fifo_trig_full  [ind_tfifo] ) ); // SYNC with WR_CLK
      // Time Comparator
      ADDSUB_MACRO #(
            .DEVICE     ("7SERIES"),        // Target Device: "7SERIES" 
            .LATENCY    ( 1   ),            // Desired clock cycle latency, 0-2
            .WIDTH      ( 48  )             // Input / output bus width, 1-48
         ) ADDSUB_MACRO_inst (
            .CARRYOUT   (                             ), // 1-bit carry-out output signal
            .RESULT     ( T_RESULT[ind_tfifo]         ), // Add/sub result output, width defined by WIDTH parameter
            .B          ( time_abs_i[47:0]            ), // Input A bus, width defined by WIDTH parameter
            .ADD_SUB    ( 1'b0                        ), // 1-bit add/sub input, high selects add, low selects subtract
            .A          ( t_fifo_trig_time[ind_tfifo] ), // Input B bus, width defined by WIDTH parameter
            .CARRYIN    ( 1'b0                        ), // 1-bit carry-in input
            .CE         ( 1'b1                        ), // 1-bit clock enable input
            .CLK        ( t_clk_i                     ), // 1-bit clock input
            .RST        ( ~t_rst_ni                   )  // 1-bit active high synchronous reset
         );
      // POP Generator
      always_comb begin : TRIG_DISPATCHER
         trig_t_gr[ind_tfifo]  = T_RESULT[ind_tfifo][47];
         trig_pop[ind_tfifo] = 0;
         trig_pop_prev[ind_tfifo] = trig_pop_r[ind_tfifo] | trig_pop_r2[ind_tfifo] | trig_pop_r3[ind_tfifo] | trig_pop_r4[ind_tfifo];
         if (time_en & ~t_fifo_trig_empty[ind_tfifo] )
            if ( trig_t_gr[ind_tfifo] & ~trig_pop_prev[ind_tfifo] ) 
               trig_pop      [ind_tfifo] = 1'b1 ;
      end //ALWAYS
   end //FOR      
endgenerate      


///////////////////////////////////////////////////////////////////////////////
/// WAVE PORT
///////////////////////////////////////////////////////////////////////////////
genvar ind_wfifo;
generate
   for (ind_wfifo=0; ind_wfifo < OUT_WPORT_QTY; ind_wfifo=ind_wfifo+1) begin: WAVE_FIFO
      // WaveForm FIFO
      BRAM_FIFO_DC_2 # (
         .FIFO_DW (168+48) , 
         .FIFO_AW (FIFO_DEPTH) 
      ) wave_fifo_inst ( 
         .wr_clk_i   ( c_clk_i   ) ,
         .wr_rst_ni  ( c_rst_ni  ) ,
         .wr_en_i    ( 1'b1   ) ,
         .push_i     ( c_fifo_wave_push_s   [ind_wfifo] ) ,
         .data_i     ( {c_fifo_data_in_r,c_fifo_time_in_r}     ) ,
         .rd_clk_i   ( t_clk_i   ) ,
         .rd_rst_ni  ( t_rst_ni  ) ,
         .rd_en_i    ( time_en ) ,
         .pop_i      ( wave_pop         [ind_wfifo] ) ,
         .data_o     ( {t_fifo_wave_dt[ind_wfifo],t_fifo_wave_time[ind_wfifo]} ) ,
         .flush_i    ( core_rst ),
         .async_empty_o ( t_fifo_wave_empty [ind_wfifo] ) , // SYNC with RD_CLK
         .async_full_o  ( c_fifo_wave_full  [ind_wfifo] ) ); // SYNC with WR_CLK
      // Time Comparator
         ADDSUB_MACRO #(
            .DEVICE     ( "7SERIES" ),                   // Target Device: "7SERIES" 
            .LATENCY    ( 1         ),                   // Desired clock cycle latency, 0-2
            .WIDTH      ( 48        )                    // Input / output bus width, 1-48
         ) ADDSUB_MACRO_inst (
            .CARRYOUT   (                             ), // 1-bit carry-out output signal
            .RESULT     ( W_RESULT[ind_wfifo]         ), // Add/sub result output, width defined by WIDTH parameter
            .B          ( time_abs_i[47:0]            ), // Input A bus, width defined by WIDTH parameter
            .A          ( t_fifo_wave_time[ind_wfifo] ), // Input B bus, width defined by WIDTH parameter
            .ADD_SUB    ( 1'b0                        ), // 1-bit add/sub input, high selects add, low selects subtract
            .CARRYIN    ( 1'b0                        ), // 1-bit carry-in input
            .CE         ( 1'b1                        ), // 1-bit clock enable input
            .CLK        ( t_clk_i                     ), // 1-bit clock input
            .RST        ( ~t_rst_ni                   )  // 1-bit active high synchronous reset
         );
      // POP Generator
      always_comb begin : WAVE_DISPATCHER
         wave_t_gr[ind_wfifo]  = W_RESULT[ind_wfifo][47];
         wave_pop[ind_wfifo]   = 0;
         wave_pop_prev[ind_wfifo] = wave_pop_r[ind_wfifo] | wave_pop_r2[ind_wfifo] | wave_pop_r3[ind_wfifo]| wave_pop_r4[ind_wfifo];
         if (time_en & ~t_fifo_wave_empty[ind_wfifo])
            if ( wave_t_gr[ind_wfifo] & ~wave_pop_prev[ind_wfifo] ) 
               wave_pop      [ind_wfifo] = 1'b1 ;
      end //ALWAYS
   end // FOR
endgenerate

///////////////////////////////////////////////////////////////////////////////
/// DATA PORT
///////////////////////////////////////////////////////////////////////////////
genvar ind_dfifo;
generate
   for (ind_dfifo=0; ind_dfifo < OUT_DPORT_QTY; ind_dfifo=ind_dfifo+1) begin: DATA_FIFO
      // DATA FIFO
      BRAM_FIFO_DC_2 # (
         .FIFO_DW (OUT_DPORT_DW+48) , 
         .FIFO_AW (FIFO_DEPTH) 
      ) data_fifo_inst ( 
         .wr_clk_i   ( c_clk_i      ) ,
         .wr_rst_ni  ( c_rst_ni     ) ,
         .wr_en_i    ( 1'b1      ) ,
         .push_i     ( c_fifo_data_push_s[ind_dfifo] ) ,
         .data_i     ( {c_fifo_data_in_r[OUT_DPORT_DW-1:0],c_fifo_time_in_r}  ) ,
         .rd_clk_i   ( t_clk_i      ) ,
         .rd_rst_ni  ( t_rst_ni     ) ,
         .rd_en_i    ( time_en    ) ,
         .pop_i      ( data_pop        [ind_dfifo] ) ,
         .data_o     ( {t_fifo_data_dt[ind_dfifo], t_fifo_data_time[ind_dfifo]} ) ,
         .flush_i    ( core_rst     ),
         .async_empty_o ( t_fifo_data_empty [ind_dfifo] ) , // SYNC with RD_CLK
         .async_full_o  ( c_fifo_data_full  [ind_dfifo] ) ); // SYNC with WR_CLK
      // Time Comparator
      ADDSUB_MACRO #(
            .DEVICE     ("7SERIES"),        // Target Device: "7SERIES" 
            .LATENCY    ( 1   ),            // Desired clock cycle latency, 0-2
            .WIDTH      ( 48  )             // Input / output bus width, 1-48
         ) ADDSUB_MACRO_inst (
            .CARRYOUT   (                             ), // 1-bit carry-out output signal
            .RESULT     ( D_RESULT[ind_dfifo]         ), // Add/sub result output, width defined by WIDTH parameter
            .B          ( time_abs_i[47:0]            ), // Input A bus, width defined by WIDTH parameter
            .ADD_SUB    ( 1'b0                        ), // 1-bit add/sub input, high selects add, low selects subtract
            .A          ( t_fifo_data_time[ind_dfifo] ), // Input B bus, width defined by WIDTH parameter
            .CARRYIN    ( 1'b0                        ), // 1-bit carry-in input
            .CE         ( 1'b1                        ), // 1-bit clock enable input
            .CLK        ( t_clk_i                     ), // 1-bit clock input
            .RST        ( ~t_rst_ni                   )  // 1-bit active high synchronous reset
         );
      // POP Generator
      always_comb begin : DATA_DISPATCHER
         data_t_gr[ind_dfifo]  = D_RESULT[ind_dfifo][47];
         data_pop[ind_dfifo] = 0;
         data_pop_prev[ind_dfifo] = data_pop_r[ind_dfifo] | data_pop_r2[ind_dfifo] | data_pop_r3[ind_dfifo] | data_pop_r4[ind_dfifo];
         if (time_en & ~t_fifo_data_empty[ind_dfifo] )
            if ( data_t_gr[ind_dfifo] & ~data_pop_prev[ind_dfifo] ) 
               data_pop      [ind_dfifo] = 1'b1 ;
      end //ALWAYS
   end //FOR      
endgenerate


///////////////////////////////////////////////////////////////////////////////
// OUTPUTS
///////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////
// OUT TRIGGERS
reg port_trig_r [OUT_TRIG_QTY];
integer ind_tport;
always_ff @ (posedge t_clk_i, negedge t_rst_ni) begin
   for (ind_tport=0; ind_tport < OUT_TRIG_QTY; ind_tport=ind_tport+1) begin: OUT_TRIG_PORT
      if (!t_rst_ni) 
         port_trig_r[ind_tport]   <= 1'b0;
      else if (time_rst) 
         port_trig_r[ind_tport]   <= 1'b0;
      else 
        if (trig_pop_r[ind_tport]) port_trig_r[ind_tport] <= t_fifo_trig_dt[ind_tport] ;
   end
end
assign port_trig_o  = port_trig_r;

///////////////////////////////////////////////////////////////////////////////
// OUT DATA
reg [OUT_DPORT_DW-1:0]  port_dt_r [OUT_DPORT_QTY];
integer ind_dport;
always_ff @ (posedge t_clk_i, negedge t_rst_ni) begin
   for (ind_dport=0; ind_dport < OUT_DPORT_QTY; ind_dport=ind_dport+1) begin: OUT_DATA_PORT
      if (!t_rst_ni) 
         port_dt_r[ind_dport]   <= '{default:'0} ;
      else if (time_rst) 
         port_dt_r[ind_dport]   <= '{default:'0} ;
      else 
        if (data_pop_r[ind_dport]) port_dt_r[ind_dport] <= t_fifo_data_dt[ind_dport] ;
   end
end
assign port_tvalid_o = data_pop_r;
assign port_tdata_o  = port_dt_r;


///////////////////////////////////////////////////////////////////////////////
// OUT WAVES
// REGISTERED OUTPUT
reg               m_axis_tvalid_r  [ OUT_WPORT_QTY] ;
reg [167:0]       m_axis_tdata_r   [ OUT_WPORT_QTY] ;
integer ind_wport;
always_ff @ (posedge t_clk_i, negedge t_rst_ni) begin
   for (ind_wport=0; ind_wport < OUT_WPORT_QTY; ind_wport=ind_wport+1) begin: OUT_WAVE_PORT
      if (!t_rst_ni) begin
         m_axis_tvalid_r[ind_wport]  <= 1'b0 ;
         m_axis_tdata_r [ind_wport]  <= '{default:'0} ;
      end else if (time_rst) begin 
         m_axis_tvalid_r[ind_wport]  <= 1'b0 ;
         m_axis_tdata_r [ind_wport]  <= '{default:'0} ;
      end else begin  
         m_axis_tvalid_r[ind_wport] <= wave_pop_r      [ind_wport] ;
         m_axis_tdata_r[ind_wport]  <= t_fifo_wave_dt [ind_wport] ;
      end
   end
end

assign m_axis_tvalid   = m_axis_tvalid_r ;
assign m_axis_tdata    = m_axis_tdata_r  ;

///// DEBUG
   assign fifo_dt_do           = {t_fifo_data_time[0][27:0], t_fifo_data_dt[0][3:0]} ;

   assign axi_fifo_do[31:28]   = t_fifo_data_dt[0][3:0] ;
   assign axi_fifo_do[27:12]   = t_fifo_data_time[0][15:0] ;
   assign axi_fifo_do[11: 8]   = { some_fifo_full , wfifo_full     , dfifo_full    , tfifo_full };
   assign axi_fifo_do[ 7: 4]   = { all_fifo_full , all_wfifo_full , all_dfifo_full, all_tfifo_full };
   assign axi_fifo_do[ 3: 0]   = { all_fifo_empty, all_wfifo_empty, all_dfifo_empty, all_tfifo_empty };

   assign c_fifo_do[15:11]   = { c_fifo_wave_push_s[0],c_fifo_data_push_s[1],c_fifo_data_push_s[0],c_fifo_trig_push_s[1],c_fifo_trig_push_s[0]};
   assign c_fifo_do[10: 9]   = { c_fifo_wave_full[1], c_fifo_wave_full[0] };
   assign c_fifo_do[ 8: 7]   = { c_fifo_data_full[1], c_fifo_data_full[0] };
   assign c_fifo_do[ 6: 5]   = { c_fifo_trig_full[1], c_fifo_trig_full[0] };
   assign c_fifo_do[ 4: 0]   = { all_fifo_full, all_wfifo_full, all_dfifo_full, all_tfifo_full, 1'b0 };

   assign t_fifo_do[15:11]   = { wave_pop_r2[0], data_pop_r2[1], data_pop_r2[0], trig_pop_r2[1], trig_pop_r2[0]  } ;
   assign t_fifo_do[10: 9]   = { c_fifo_wave_empty[1], c_fifo_wave_empty[0] };
   assign t_fifo_do[ 8: 7]   = { c_fifo_data_empty[1], c_fifo_data_empty[0] };
   assign t_fifo_do[ 6: 5]   = { c_fifo_trig_empty[1], c_fifo_trig_empty[0] };
   assign t_fifo_do[ 4: 0]   = { all_fifo_empty, all_wfifo_empty, all_dfifo_empty, all_tfifo_empty, 1'b0 };
endmodule
   
