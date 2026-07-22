import asyncio

from xknx import XKNX
from xknx.io import ConnectionConfig, ConnectionType
from xknx.tools import group_value_write


async def main():
    connection_config = ConnectionConfig(
        connection_type=ConnectionType.TUNNELING,
        gateway_ip="192.168.1.60",
        gateway_port=3671,
        individual_address="1.1.202",   # Optional
    )

    async with XKNX(connection_config=connection_config) as xknx:
        await asyncio.sleep(2)
        group_value_write(
            xknx,
            "1/0/0",
            True,
            value_type="DPT-1.001",
        )

        await asyncio.sleep(5)

        group_value_write(
            xknx,
            "1/0/0",
            False,
            value_type="DPT-1.001",
        )

asyncio.run(main())
