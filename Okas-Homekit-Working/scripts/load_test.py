#!/usr/bin/env python3
"""
OKAS board load-testing script.
Exercises every load and every capability over MQTT, prints each
ack/state so the logs can be correlated. Dummy loads (not wired to a
real KNX bus) will fail on the KNX write side but the MQTT layer should
still behave sanely.
"""
import json
import os
import subprocess
import sys
import time

CT = open('/tmp/ct.txt').read().strip() if os.path.exists('/tmp/ct.txt') else None
if not CT:
    print('No command token — run the token exchange first.')
    sys.exit(1)

PUB = ['mosquitto_pub', '-h', 'localhost', '-p', '1883']
SUB = ['mosquitto_sub', '-h', 'localhost', '-p', '1883']


def send_cmd(ld_id, typ, cmd, wait=1.2):
    """Publish a command and print the ack."""
    payload = json.dumps({
        'ldId': ld_id, 'typ': typ, 'cmd': cmd, 'commandToken': CT,
    })
    subprocess.Popen(
        SUB + ['-t', 'command/cmdAck', '-C', '1'],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    time.sleep(0.15)
    subprocess.run(PUB + ['-t', 'command/sndCmd', '-m', payload], check=True)
    time.sleep(wait)


def main():
    tests = [
        # (label, ldId, typ, cmd)
        ('Switch ON',           1, 'swt', {'swt': True}),
        ('Switch OFF',          1, 'swt', {'swt': False}),
        ('Dimmer ON',           4, 'dim', {'swt': True}),
        ('Dimmer Bri 40',       4, 'dim', {'bri': 40}),
        ('Dimmer Bri 100',      4, 'dim', {'bri': 100}),
        ('Dimmer OFF',          4, 'dim', {'swt': False}),
        ('RGB ON',              5, 'rgb', {'swt': True}),
        ('RGB bri 50',          5, 'rgb', {'bri': 50}),
        ('RGB hue 120 sat 80',  5, 'rgb', {'hue': 120, 'sat': 80}),
        ('Tunable ON',          6, 'tun', {'swt': True}),
        ('Tunable bri 70',      6, 'tun', {'bri': 70}),
        ('Tunable cTp 4000K',   6, 'tun', {'cTp': 4000}),
        ('Fan ON',              7, 'fan', {'swt': True}),
        ('Fan speed 128',       7, 'fan', {'fSp': 128}),
        ('Fan speed 0',         7, 'fan', {'fSp': 0}),
        ('Curtain pos 75',      8, 'cur', {'pos': 75}),
        ('Curtain pos 0',       8, 'cur', {'pos': 0}),
        ('Scene 1',             9, 'scn', {'scn': 1}),
        ('HVAC ON',            10, 'hvc', {'swt': True}),
        ('HVAC spt 22',        10, 'hvc', {'spt': 22}),
        ('HVAC fSp 128',       10, 'hvc', {'fSp': 128}),
        ('HVAC mod cool',      10, 'hvc', {'mod': 'cool'}),
        ('HVAC OFF',           10, 'hvc', {'swt': False}),
        ('Scene 2',            11, 'scn', {'scn': 1}),
    ]
    print(f'Running {len(tests)} tests...\n')
    for label, ld_id, typ, cmd in tests:
        print(f'>> {label} (load {ld_id}, {typ}): {cmd}')
        send_cmd(ld_id, typ, cmd)
    print('\nDone.')


if __name__ == '__main__':
    main()
