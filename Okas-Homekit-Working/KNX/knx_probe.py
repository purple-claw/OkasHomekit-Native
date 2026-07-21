#!/usr/bin/env python3
"""Standalone KNX connectivity probe. Reuses knx_bridge's config loading to
connect to the interface (no MQTT), report the live connection state, and dump
any bus traffic. Run on the host:  python3 KNX/knx_probe.py

Force a mode without editing loadData:  KNX_CONN=tcp python3 KNX/knx_probe.py
KNX Secure:  KNX_DEVICE_AUTH=secret  python3 KNX/knx_probe.py
"""
import asyncio
import logging
import sys

from xknx import XKNX
from xknx.io import ConnectionConfig

import knx_bridge  # same directory


async def main():
    logging.basicConfig(level=logging.DEBUG,
                        format="[%(levelname)s] %(name)s: %(message)s")
    cfg = knx_bridge.load_config()
    conn = cfg["connection"]
    print(
        f"Connecting: type={conn['type'].name} gateway={conn.get('gateway_ip')}:{conn.get('gateway_port')}")
    if conn.get("secure_config"):
        print("  KNX IP Secure enabled (device_authentication_password set).")
    else:
        print("  KNX IP Secure: disabled (plain tunnelling).")

    # xknx calls these synchronously — must be plain `def`, not `async def`.
    def on_state(state):
        print(f">>> CONNECTION STATE: {getattr(state, 'name', state)}")

    def on_telegram(tg):
        print(f">>> BUS: {tg.destination_address} {tg.payload}")

    xknx = XKNX(
        connection_config=ConnectionConfig(
            connection_type=conn["type"],
            gateway_ip=conn.get("gateway_ip"),
            gateway_port=conn.get("gateway_port", 3671),
            individual_address=conn.get("individual_address"),
            auto_reconnect=True,
            auto_reconnect_wait=3,
            secure_config=conn.get("secure_config"),
        ),
        connection_state_changed_cb=on_state,
        telegram_received_cb=on_telegram,
    )
    async with xknx:
        print("Connected context entered. Watching for 30s (Ctrl+C to stop)...")
        await asyncio.sleep(30)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
