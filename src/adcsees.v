module adcsees (
input			clk50,        // 50MHz clock
input			adc_in,       // serial input from ADC chip
input 			rst,          // active low reset
input	[2:0]	adc_addr,     // 3-bit parallel channel select
output			adc_cs_n,     // chip select ADC
output			adc_out,      // ADC channel (hard-wired to 0)
output			adc_clk,      // ADC chip clock (frequency divider)
output	[7:0]   adc_8b_o      // 8-bit output
);

wire 		    clk_2M8_w;    // PPL 2.8MHz clock output

adc_ctrl adc_ctrl_u1 (     	// adc_ctrl instance 
	.adc_sdat	(adc_in),  	// serial input from ADC chip
	.rst_n		(rst),      // active low reset
	.clk_i		(clk_2M8_w),// 2.8MHz clock from PLL
	.adc_addr	(adc_addr), // 3-bit parallel channel select
	.adc_saddr	(adc_out), 	// serial ADC channel select
	.adc_sclk	(adc_clk),  // ADC chip clock
	.adc_cs_n	(adc_cs_n), // chip select (ADC enable)
	.adc_8b_o	(adc_8b_o)  // 8-bit output
	); 

clkdiv clkdiv_u1 (			// clkdiv instance
	.clk50		(clk50),    // 50MHz input
	.rst		(rst),      // active low reset
	.clk_2M8	(clk_2M8_w)	// 2.8MHz output
	);

endmodule

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module adc_ctrl (
	input        	adc_sdat,	// serial input from adc
	input        	rst_n,		// active low reset
	input        	clk_i,      // 2.8Mhz clock input from PLL
	input	[2:0]	adc_addr,	// 3-bit parallel channel select
	output       	adc_saddr, 	// serial ADC channel select
	output       	adc_sclk,  	// clock output driving ADC
	output       	adc_cs_n,  	// chip select (active low ADC enable)
	output	[7:0]	adc_8b_o	// 8-bit output 
);

wire    	    dclk_w;         // divided clock wire (44.1 kHz)
wire    [2:0]   adc_addr_w;     // parallel ADC channel select wire
wire    [2:0]   data_addr_w;
wire    [11:0]  adc_pdata_w;    // 12-bit wire (output from adc_interface)
wire    [7:0]   adc_data_w8;    // 8-bit wire (output from adc_interface)
wire    	    clk_addr_w;


assign adc_sclk = clk_i;       	// PLL clock (2.8 MHz)

assign adc_addr_w = adc_addr;   // ADC Channel select

assign adc_cs_n = ~rst_n;		// chip select (active low enable)

// Interface with ADC 
//   - addr and data are parrallel interface 
//   - din/dout are serial interface with ADC chip
adc_interface adc_interface_u1 (
	.clk_i    	(clk_i),      	// 2.8Mhz clock input from PLL
	.rst_n    	(rst_n),		// active low reset
	.sdata_i  	(adc_sdat),		// serial data input ADC chip -> adc_interface
	.data_addr	(data_addr_w),	// parallel channel select -> data_ram
	.adc_saddr	(adc_saddr),	// serial data output (channel selection) adc_interface -> ADC chip
	.pdata_o	(adc_pdata_w),	// 12-bit parallel wire adc_interface -> adc_output driver
	.clk_addr	(clk_addr_w)
);			
     
// 8-bit data conversion
assign adc_data_w8 = adc_pdata_w[11:4];

// Data ram
data_ram	data_ram_u1 (
	.clk_i    (clk_addr_w),     // clock
	.addr_wr  (data_addr_w),    // address write
	.addr_rd  (adc_addr_w),     // address read
	.data_i   (adc_data_w8),    // data in
	.data_o   (adc_8b_o)      	// data out
);
	  
endmodule

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module clkdiv (
    input       clk50,        // 50MHz input
    input       rst,          // active low reset
    output wire  clk_2M8       // 2.8MHz output
);

reg [5:0] counter_r;

always @(posedge clk50 or negedge rst) begin
    if (!rst)
        counter_r <= 6'b0;
    else if (counter_r == 6'd17)
        counter_r <= 6'b0;
    else
        counter_r <= counter_r + 6'b1;
end

assign clk_2M8 = (counter_r >= 6'd9) ? 1'b1 : 1'b0;

endmodule

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 module adc_interface (
	input 				clk_i,          // 2.8Mhz clock input from PLL
	input 				rst_n,          // active low reset
	input 				sdata_i,        // serial data input ADC chip -> adc_interface

	output 	reg	[11:0]	pdata_o,        // 12-bit parallel wire adc_interface -> adc_output driver
	output 	reg			adc_saddr,		// serial data output (channel selection) adc_interface -> ADC chip
	output				clk_addr,
	output 	reg	[2:0]	data_addr		// incremental channel selection bus -> data RAM
);

reg 	[3:0]	sclk_count;					// clk counter 0 to 15
reg		[11:0] 	din_ff;						// ff register to deserialize serial input

wire 	[3:0] 	sclk_count_w;
assign 			sclk_count_w = sclk_count;

/* Handle clock counting */
always @ (negedge clk_i or negedge rst_n)  // 16-cycle counter
  if (!rst_n) 
    sclk_count <= 4'b0000;
  else
    sclk_count <= sclk_count + 1'b1;

// serialize adc channel selection
always@(*)
begin						
	case (sclk_count) 
		4'b0010:	adc_saddr = ~data_addr[2]; //adc_addr[2];
		4'b0011:	adc_saddr = ~data_addr[1]; //adc_addr[1];
		4'b0100:	adc_saddr = ~data_addr[0]; //adc_addr[0];
		default:	begin adc_saddr = 1'b0; end
	endcase
end	

assign clk_addr = (sclk_count == 4'b0001);

/* Handle address incrementing to cycle through reading
   bytes from the ADC device input pins */
always @ (negedge clk_addr or negedge rst_n)
  if (!rst_n) 
    data_addr <= 3'b000;
  else
    data_addr <= data_addr + 1'b1;

//	DeSerialize input data into a 12-bit register during clock cycles 4 -> 15
always @ (negedge clk_i or negedge rst_n)
  if (!rst_n)
      din_ff <= 12'd0;
  else
    casez (sclk_count)
			4'b01??, 4'b1???: din_ff <= {din_ff[10:0],sdata_i};	
    endcase

// Parallel data out every 16 clock cycles
always @ (negedge clk_i) begin
  if (sclk_count == 4'b0000) 
	  begin
		  pdata_o <= din_ff;
	  end
  end

endmodule

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module data_ram	(
    input		    clk_i,
	input	[2:0]	addr_wr,
	input	[2:0]	addr_rd,
	input	[7:0]   data_i,
	output	[7:0]   data_o
);
	//Register file structure
	reg		[7:0] 	data_ram	[0:7]; //depth 8 addresses 8-bit word each
	
	//write port
	always @(negedge clk_i)
	begin
		data_ram[addr_wr - 1'b1] <= data_i; 
	end
	
	//read port
	assign	data_o = data_ram[addr_rd];
	wire _unused2 = &{dclk_w, adc_pdata_w[3:0], sclk_count_w, 1'b0};
endmodule
