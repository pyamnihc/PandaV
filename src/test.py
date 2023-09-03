import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


@cocotb.test()
async def test_spi_register_map(dut):
    dut._log.info("start")
    await Timer(1000000, "us")
    print(dut.finish.value)
