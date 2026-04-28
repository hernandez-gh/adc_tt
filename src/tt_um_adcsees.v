/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_adcsees (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

wire [7:0] ui_in_w;
wire [7:0] uo_out_w;
wire [7:0] uio_out_w;
wire       ena_w;
wire       clk_w;
wire       rst_n_w;

assign ui_in_w = ui_in;
assign uo_out = uo_out_w;
assign uio_out = uio_out_w;
assign clk_w = clk;
assign rst_n_w = rst_n;

adcsees adcsees_u1(
    .clk50(clk_w),
    .rst(rst_n_w),
    .adc_in(ui_in_w[0]),
    .adc_addr(ui_in_w[3:1]),
    .adc_cs_n(uio_out_w[0]),
    .adc_out(uio_out_w[1]),
    .adc_clk(uio_out_w[2]),
    .adc_8b_o(uo_out_w)
);

    wire _unused = &{uio_oe, ui_in_w[4:7], uio_in, uio_out_w[3:7], ena, 1'b0};

endmodule
