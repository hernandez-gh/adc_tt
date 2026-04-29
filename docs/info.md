<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a simple ADC interface controller. It generates the required clock and control signals to communicate with an external ADC and captures the resulting digital data.

The design uses the system clock (clk) and divides it down to generate the ADC clock. A small state machine controls the ADC transaction, including chip select and bit shifting. The incoming serial data from the ADC is sampled and assembled into an 8-bit parallel value.

The final converted value is presented on the uo_out pins, while control signals such as adc_clk, adc_out, and adc_cs_n are driven through the uio pins.

## How to test

1. Provide a clock signal to the design (Tiny Tapeout provides this automatically).
2. Use ui_in to:
- Select the ADC channel (if applicable)
- Provide the serial input bit (adc_in)
3. Observe:
- uio_out[2] → ADC clock
- uio_out[1] → data output to ADC
- uio_out[0] → chip select (active low)
4. The converted 8-bit value will appear on uo_out[7:0].

For simulation:

- Use the provided Cocotb testbench
- Run make to execute the test
- Verify that ADC data is correctly shifted and appears on the output

## External hardware

This design is intended to interface with an external SPI-like ADC device.

Required hardware:

1. An ADC chip with:
- Serial data output (MISO)
- Serial clock input
- Chip select input
2. Optional:
- Signal source connected to the ADC input

Connections:

- uio_out[2] → ADC clock
- uio_out[1] → ADC data input (MOSI)
- uio_out[0] → ADC chip select
- ui_in[0] → ADC data output (MISO)
