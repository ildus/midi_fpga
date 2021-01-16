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
async def test_btn_assign(dut):
    """ Test MIDI and assigning to button """

    await setup_dut(dut)

    status = await send_command(dut, is_status = True)
    data1 = await send_command(dut)
    data2 = await send_command(dut, and_wait=True)

    assert dut.midi_cmd_completed.value == 1
    assert dut.midi_in_state == 1

    # check for default values
    assert dut.btn1_status.value == dut.STATUS
    assert dut.btn1_data1.value == dut.FIRST_CC_MSG.value;
    assert dut.btn1_data2.value == dut.CC_VALUE.value;
    assert dut.btn1_bits_cnt.value == 30;

    await FallingEdge(dut.clk)
    dut.btn1_raise <= True
    await FallingEdge(dut.clk)
    dut.btn1_raise <= False

    for i in range(2):
        await FallingEdge(dut.baud_clk)

    assert dut.btn1_status == status
    assert dut.btn1_data1 == data1
    assert dut.btn1_data2 == data2
    assert dut.btn1_bits_cnt.value == 30
