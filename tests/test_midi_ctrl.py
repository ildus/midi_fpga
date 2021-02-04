import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge
from cocotb.binary import BinaryValue

async def setup_dut(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.fork(clock.start())

    # reset the system
    dut.rst <= 0
    await FallingEdge(dut.clk)
    dut.rst <= 1
    dut.midi_rx <= 1
    dut.spi_do <= 0

async def generate_midi_in_data(dut, is_status=False, and_wait=False):
    ''' send 8 bits of some data '''

    # start bit
    dut.midi_rx <= 0
    await RisingEdge(dut.din.baud_clk)
    await FallingEdge(dut.din.baud_clk)

    for i in range(10):
        await FallingEdge(dut.clk)

    assert dut.din.midi_in == 0
    assert dut.din.midi_reading_pos == 1
    assert dut.midi_in_state == 0
    assert dut.midi_cmd_completed == 0

    bindata = ''
    for i in range(8):
        # next val will be random
        if i == 6:
            # bit before status, for readability
            val = 0
        elif i == 7:
            # MSB
            val = 1 if is_status else 0
        else:
            val = random.randint(0, 1)

        dut.midi_rx <= val
        bindata = str(val) + bindata
        await FallingEdge(dut.din.baud_clk)

    # stop bit
    dut.midi_rx <= 1
    await FallingEdge(dut.dout.baud_clk)

    if and_wait:
        # just some empty period of data
        for i in range(30):
            dut.midi_rx <= 1
            await FallingEdge(dut.dout.baud_clk)

    return BinaryValue(bindata)

async def midi_out_data(dut):
    # wait for start bit
    await FallingEdge(dut.dout.midi_tx)
    await FallingEdge(dut.dout.baud_clk)

    bindata = ''
    for i in range(8):
        await FallingEdge(dut.dout.baud_clk)
        bindata = str(dut.midi_tx.value) + bindata

    # wait for stop bit
    await FallingEdge(dut.dout.baud_clk)
    return BinaryValue(bindata)


@cocotb.test()
async def test_midi_in(dut):
    """ Test MIDI IN, only status byte """

    await setup_dut(dut)

    # skip one baud_clk for readability of waveform
    await FallingEdge(dut.dout.baud_clk)

    status = await generate_midi_in_data(dut, True)

    assert dut.midi_cmd_completed.value == 0

    # just some empty period of data
    for i in range(30):
        dut.midi_rx <= 1
        await FallingEdge(dut.dout.baud_clk)

    assert dut.status_in == status
    assert dut.data1_in.value == 0
    assert dut.data2_in.value == 0
    assert dut.midi_cmd_completed.value == 1
    assert dut.bytes_cnt_in.value == 1
    assert dut.led2 == 1

@cocotb.test()
async def test_midi_in_2bytes(dut):
    """ Test MIDI IN, status and one data byte """

    await setup_dut(dut)

    # skip one baud_clk for readability of waveform
    await FallingEdge(dut.dout.baud_clk)
    status = await generate_midi_in_data(dut, True)
    data1 = await generate_midi_in_data(dut, False)

    assert dut.midi_cmd_completed.value == 0

    # just some empty period of data
    for i in range(30):
        dut.midi_rx <= 1
        await FallingEdge(dut.dout.baud_clk)

    assert dut.status_in == status
    assert dut.data1_in.value == data1
    assert dut.data2_in.value == 0
    assert dut.midi_cmd_completed.value == 1
    assert dut.bytes_cnt_in.value == 2
    assert dut.led2 == 1

@cocotb.test()
async def test_midi_in_3bytes(dut):
    """ Test MIDI IN, status and two data bytes """

    await setup_dut(dut)

    # skip one baud_clk for readability of waveform
    await FallingEdge(dut.dout.baud_clk)
    status = await generate_midi_in_data(dut, True)
    data1 = await generate_midi_in_data(dut, False)
    data2 = await generate_midi_in_data(dut, False)

    assert dut.midi_cmd_completed.value == 0

    # just some empty period of data
    for i in range(30):
        dut.midi_rx <= 1
        await FallingEdge(dut.dout.baud_clk)

    assert dut.status_in == status
    assert dut.data1_in.value == data1
    assert dut.data2_in.value == data2
    assert dut.midi_cmd_completed.value == 1
    assert dut.bytes_cnt_in.value == 3
    assert dut.led2 == 1

@cocotb.test()
async def test_btn_assign(dut):
    """ Test MIDI and assigning to button """

    await setup_dut(dut)

    # wait for spi initialization
    for i in range(2000):
        await FallingEdge(dut.clk)

    status = await generate_midi_in_data(dut, is_status=True)
    data1 = await generate_midi_in_data(dut)
    data2 = await generate_midi_in_data(dut, and_wait=True)

    assert dut.midi_cmd_completed.value == 1
    assert dut.midi_in_state == 1

    await FallingEdge(dut.clk)
    dut.but.btn1_raise <= True
    await FallingEdge(dut.clk)

    # after this clock btn_index will be set
    await FallingEdge(dut.clk)

    assert dut.btn_index == 1
    assert dut.midi_in_state == 2
    assert dut.btn_assigned == 1
    assert dut.save_mode == 1

    dut.but.btn1_raise <= False

    await FallingEdge(dut.clk)

    assert dut.memmap[0] == status
    assert dut.memmap[1] == data1
    assert dut.memmap[2] == data2
    assert dut.memmap[3].value == 30

    for i in range(1000):
        await FallingEdge(dut.clk)

@cocotb.test()
async def test_midi_out_on_button_after_assign(dut):
    await setup_dut(dut)

    # wait for spi initialization
    await FallingEdge(dut.spi_rst_o)

    for i in range(4):
        await FallingEdge(dut.spi_stb_o)

    status = await generate_midi_in_data(dut, is_status = True)
    data1 = await generate_midi_in_data(dut)
    data2 = await generate_midi_in_data(dut, and_wait=True)

    assert dut.midi_cmd_completed == 1
    assert dut.btn_assigned == 0
    assert dut.midi_in_state == 1

    await FallingEdge(dut.clk)
    dut.but.btn3_raise <= 1
    await FallingEdge(dut.clk)

    # after this clock btn_index will be set
    await FallingEdge(dut.clk)
    dut.but.btn3_raise <= False

    assert dut.btn_index == 2
    assert dut.save_mode == 1
    await FallingEdge(dut.clk)
    assert dut.btn_index == 0
    assert dut.cmd_trigger_out == 0
    assert dut.btn_assigned == 1

    assert dut.memmap[4] == status
    assert dut.memmap[5] == data1
    assert dut.memmap[6] == data2
    assert dut.memmap[7].value == 30

    # wait until the data goes to spi flash
    for i in range(5):
        await FallingEdge(dut.spi_stb_o)

    await FallingEdge(dut.clk)
    assert dut.mem_init[2] == 1

    await FallingEdge(dut.clk)
    assert dut.save_mode == 0
    dut.btn_index <= 2
    await FallingEdge(dut.clk)
    assert dut.cmd_trigger_out == 1
    await FallingEdge(dut.clk)

    assert dut.cmd_trigger_out == 1
    assert dut.status == status
    assert dut.data1 == data1
    assert dut.data2 == data2
    assert dut.cmd_bits_cnt == 30

    sent_status = await midi_out_data(dut)
    assert sent_status == status
    sent_data1 = await midi_out_data(dut)
    assert sent_data1 == data1
    sent_data2 = await midi_out_data(dut)
    assert sent_data2 == data2

    for i in range(2000):
        await FallingEdge(dut.clk)
