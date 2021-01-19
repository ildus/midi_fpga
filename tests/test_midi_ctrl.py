import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge
from cocotb.binary import BinaryValue

async def setup_dut(dut):
    clock = Clock(dut.clk, 1, units="us")
    cocotb.fork(clock.start())

    # reset the system
    dut.rst <= 0
    await FallingEdge(dut.clk)
    dut.rst <= 1

async def send_command(dut, is_status=False, and_wait=False):
    ''' send 8 bits of some data '''

    # start bit
    dut.midi_rx <= 0
    await FallingEdge(dut.baud_clk)

    assert dut.midi_in == 0
    assert dut.midi_reading_pos == 1
    assert dut.midi_cmd_completed == 0
    assert dut.midi_in_state == 0

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
        await FallingEdge(dut.baud_clk)

    # stop bit
    dut.midi_rx <= 1
    await FallingEdge(dut.baud_clk)

    if and_wait:
        # just some empty period of data
        for i in range(30):
            dut.midi_rx <= 1
            await FallingEdge(dut.baud_clk)

    return BinaryValue(bindata)

async def read_midi_command(dut):
    # wait for start bit
    await FallingEdge(dut.midi_tx)
    await FallingEdge(dut.baud_clk)

    bindata = ''
    for i in range(8):
        await FallingEdge(dut.baud_clk)
        bindata = str(dut.midi_tx.value) + bindata

    # wait for stop bit
    await FallingEdge(dut.baud_clk)
    return BinaryValue(bindata)


@cocotb.test()
async def test_midi_in(dut):
    """ Test MIDI IN, only status byte """

    await setup_dut(dut)

    # skip one baud_clk for readability of waveform
    await FallingEdge(dut.baud_clk)

    status = await send_command(dut, True)

    assert dut.midi_cmd_completed.value == 0

    # just some empty period of data
    for i in range(30):
        dut.midi_rx <= 1
        await FallingEdge(dut.baud_clk)

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
    await FallingEdge(dut.baud_clk)
    status = await send_command(dut, True)
    data1 = await send_command(dut, False)

    assert dut.midi_cmd_completed.value == 0

    # just some empty period of data
    for i in range(30):
        dut.midi_rx <= 1
        await FallingEdge(dut.baud_clk)

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
    await FallingEdge(dut.baud_clk)
    status = await send_command(dut, True)
    data1 = await send_command(dut, False)
    data2 = await send_command(dut, False)

    assert dut.midi_cmd_completed.value == 0

    # just some empty period of data
    for i in range(30):
        dut.midi_rx <= 1
        await FallingEdge(dut.baud_clk)

    assert dut.status_in == status
    assert dut.data1_in.value == data1
    assert dut.data2_in.value == data2
    assert dut.midi_cmd_completed.value == 1
    assert dut.bytes_cnt_in.value == 3
    assert dut.led2 == 1

@cocotb.test()
async def test_midi_out_on_button(dut):
    await setup_dut(dut)

    dut.btn1 <= False
    await FallingEdge(dut.clk)
    dut.btn1 <= True

    status = await read_midi_command(dut)
    data1 = await read_midi_command(dut)
    data2 = await read_midi_command(dut)

    assert status == dut.CC_MSG
    assert data1 == dut.FIRST_CC_MSG
    assert data2 == dut.CC_VALUE

@cocotb.test()
async def test_btn_assign(dut):
    """ Test MIDI and assigning to button """

    await setup_dut(dut)

    status = await send_command(dut, is_status = True)
    data1 = await send_command(dut)
    data2 = await send_command(dut, and_wait=True)

    assert dut.midi_cmd_completed.value == 1
    assert dut.midi_in_state == 1

    await FallingEdge(dut.clk)
    dut.btn1_raise <= True
    await FallingEdge(dut.clk)

    # after this clock btn_index will be set
    await FallingEdge(dut.clk)

    assert dut.btn_index == 1
    assert dut.midi_in_state == 2
    assert dut.btn_assigned == 1
    assert dut.we == 1

    dut.btn1_raise <= False

    for i in range(2):
        await FallingEdge(dut.baud_clk)

    assert dut.smem[0] == status
    assert dut.smem[1] == data1
    assert dut.smem[2] == data2
    assert dut.smem[3].value == 30

@cocotb.test()
async def test_midi_out_on_button_after_assign(dut):
    await setup_dut(dut)

    status = await send_command(dut, is_status = True)
    data1 = await send_command(dut)
    data2 = await send_command(dut, and_wait=True)

    assert dut.midi_cmd_completed == 1
    assert dut.btn_assigned == 0
    assert dut.midi_in_state == 1

    await FallingEdge(dut.clk)
    dut.btn_index <= 2
    dut.we <= 1
    await FallingEdge(dut.clk)
    assert dut.btn_index == 0
    assert dut.btn_pressed == 0
    assert dut.btn_assigned == 1

    assert dut.smem[4] == status
    assert dut.smem[5] == data1
    assert dut.smem[6] == data2
    assert dut.smem[7].value == 30

    await FallingEdge(dut.clk)
    assert dut.we == 0
    dut.btn_index <= 2
    await FallingEdge(dut.clk)
    assert dut.btn_pressed == 1
    await FallingEdge(dut.clk)

    assert dut.cmd_set == 1
    assert dut.status == status
    assert dut.data1 == data1
    assert dut.data2 == data2
    assert dut.cmd_bits_cnt == 30

    sent_status = await read_midi_command(dut)
    assert sent_status == status
    sent_data1 = await read_midi_command(dut)
    assert sent_data1 == data1
    sent_data2 = await read_midi_command(dut)
    assert sent_data2 == data2
