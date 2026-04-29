# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.utils import get_sim_time


async def reset_dut(dut, cycles=5):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await Timer(1, unit="ns")
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.clk)


async def wait_adc_sclk_falling(dut, n=1):
    """Espera flancos de bajada del reloj ADC expuesto en uio_out[2]."""
    last = int(dut.uio_out.value) & 0b100
    seen = 0
    while seen < n:
        await FallingEdge(dut.clk)
        now = int(dut.uio_out.value) & 0b100
        if last and not now:
            seen += 1
        last = now


async def drive_adc_frame(dut, value12):
    """
    Maneja ui_in[0] como dato serial del ADC.
    El RTL captura bits cuando sclk_count está en 4..15, es decir 12 bits.
    Esta función alinea el patrón con esos 12 flancos útiles.
    """
    bits = [(value12 >> i) & 1 for i in range(11, -1, -1)]

    # Esperar inicio de trama: adc_saddr/uio_out[1] tiene actividad en counts 2..4;
    # la captura útil empieza después. Usamos 4 flancos de adc_clk para alinearnos.
    await wait_adc_sclk_falling(dut, 4)

    for bit in bits:
        current_ui = int(dut.ui_in.value)
        dut.ui_in.value = (current_ui & 0xFE) | bit
        await wait_adc_sclk_falling(dut, 1)


@cocotb.test()
async def test_reset_and_uio_oe(dut):
    """Prueba básica del wrapper: reset, dirección de uio y CS."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())  # 50 MHz

    await reset_dut(dut)

    # Esperado para Tiny Tapeout si uio[2:0] son salidas.
    # Esta prueba fallará con el RTL original porque uio_oe no está asignado.
    assert int(dut.uio_oe.value) == 0b00000111, \
        f"uio_oe debe ser 00000111, obtuve {int(dut.uio_oe.value):08b}"

    # adc_cs_n = ~rst_n, así que fuera de reset debe ser 0.
    assert (int(dut.uio_out.value) & 0b001) == 0, "adc_cs_n debe estar bajo fuera de reset"


@cocotb.test()
async def test_adc_serial_to_parallel_channel0(dut):
    """Inyecta una muestra ADC serial y revisa que aparezca truncada a 8 bits."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

    await reset_dut(dut)

    # Leer canal 0: ui_in[3:1] = 000, ui_in[0] se usa como dato serial.
    dut.ui_in.value = 0x00

    sample12 = 0xAB0
    expected8 = sample12 >> 4

    # Mandamos varias tramas porque el diseño cicla internamente los canales 0..7
    # y la RAM se actualiza con retardo de una trama.
    for _ in range(12):
        await drive_adc_frame(dut, sample12)

    got = int(dut.uo_out.value)
    assert got == expected8, f"uo_out esperado 0x{expected8:02X}, obtuve 0x{got:02X}"


@cocotb.test()
async def test_adc_channel_address_outputs_activity(dut):
    """Verifica que adc_clk, adc_out y adc_cs_n estén conectados al bus uio_out."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

    await reset_dut(dut)

    # Selección externa de canal 5 para lectura de RAM: ui_in[3:1] = 101.
    dut.ui_in.value = 0b00001010

    seen_clk_high = False
    seen_clk_low = False
    seen_saddr_high = False

    for _ in range(2000):
        await RisingEdge(dut.clk)
        uio = int(dut.uio_out.value)
        seen_clk_high |= bool(uio & 0b100)
        seen_clk_low |= not bool(uio & 0b100)
        seen_saddr_high |= bool(uio & 0b010)

    assert seen_clk_high and seen_clk_low, "uio_out[2]/adc_clk no está conmutando"
    assert seen_saddr_high, "uio_out[1]/adc_out no tuvo actividad alta"
    assert (int(dut.uio_out.value) & 0b001) == 0, "uio_out[0]/adc_cs_n debe seguir bajo"
