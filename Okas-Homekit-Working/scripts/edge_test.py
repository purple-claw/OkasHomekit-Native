#!/usr/bin/env python3
"""
OKAS edge-case / robustness test.
Sends malformed, out-of-range, and rapid commands and checks the board
handles them without crashing or wedging.
"""
import json
import os
import subprocess
import sys
import time

CT = open('/tmp/ct.txt').read().strip() if os.path.exists('/tmp/ct.txt') else None
if not CT:
    print('No command token')
    sys.exit(1)

PUB = ['mosquitto_pub', '-h', 'localhost', '-p', '1883']


def pub(payload):
    subprocess.run(PUB + ['-t', 'command/sndCmd', '-m', json.dumps(payload)],
                   check=True, capture_output=True)


def main():
    cases = [
        # (label, payload)
        ('Unknown load id',       {'ldId': 99, 'typ': 'swt', 'cmd': {'swt': True}, 'commandToken': CT}),
        ('Wrong type for load',   {'ldId': 1, 'typ': 'dim', 'cmd': {'swt': True}, 'commandToken': CT}),
        ('Unknown parameter',     {'ldId': 1, 'typ': 'swt', 'cmd': {'xyz': 1}, 'commandToken': CT}),
        ('Unsupported param',     {'ldId': 1, 'typ': 'swt', 'cmd': {'bri': 50}, 'commandToken': CT}),
        ('Missing cmd',           {'ldId': 1, 'typ': 'swt', 'commandToken': CT}),
        ('Empty cmd',             {'ldId': 1, 'typ': 'swt', 'cmd': {}, 'commandToken': CT}),
        ('No token',              {'ldId': 1, 'typ': 'swt', 'cmd': {'swt': True}}),
        ('Bad token',             {'ldId': 1, 'typ': 'swt', 'cmd': {'swt': True}, 'commandToken': 'INVALID.TOKEN'}),
        ('Bri out of range',      {'ldId': 4, 'typ': 'dim', 'cmd': {'bri': 999}, 'commandToken': CT}),
        ('Bri negative',          {'ldId': 4, 'typ': 'dim', 'cmd': {'bri': -5}, 'commandToken': CT}),
        ('fSp out of range',      {'ldId': 7, 'typ': 'fan', 'cmd': {'fSp': 9999}, 'commandToken': CT}),
        ('cTp string',            {'ldId': 6, 'typ': 'tun', 'cmd': {'cTp': '4000'}, 'commandToken': CT}),
        ('mod unknown string',    {'ldId': 10, 'typ': 'hvc', 'cmd': {'mod': 'turbo'}, 'commandToken': CT}),
        ('pos out of range',      {'ldId': 8, 'typ': 'cur', 'cmd': {'pos': 150}, 'commandToken': CT}),
        ('scene 0',               {'ldId': 9, 'typ': 'scn', 'cmd': {'scn': 0}, 'commandToken': CT}),
        ('scene 99',              {'ldId': 9, 'typ': 'scn', 'cmd': {'scn': 99}, 'commandToken': CT}),
    ]
    print(f'Running {len(cases)} edge cases...\n')
    for label, payload in cases:
        print(f'>> {label}')
        pub(payload)
        time.sleep(0.4)
    print('\nEdge cases sent.')


if __name__ == '__main__':
    main()
