#!/usr/bin/env python3
"""Quick KNX/IP gateway scanner."""
import socket

SEARCH = bytes.fromhex('06100201000e0801ffffffff0e57')
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.settimeout(5)
sock.sendto(SEARCH, ('224.0.23.12', 3671))
print('Scanning for KNX gateways...')

try:
    while True:
        data, addr = sock.recvfrom(1024)
        if len(data) >= 20:
            svc = (data[2] << 8) | data[3]
            if svc == 0x0202:
                ip = '.'.join(str(b) for b in data[8:12])
                port = (data[12] << 8) | data[13]
                # Check service type at byte 74
                if len(data) > 74:
                    svc_type = 'TunnelUDP' if data[74] == 4 else 'Multicast' if data[74] == 5 else f'Unknown({data[74]})'
                else:
                    svc_type = 'Unknown'
                print(f'Gateway found: {ip}:{port} ({svc_type})')
except socket.timeout:
    print('Scan complete')
sock.close()
