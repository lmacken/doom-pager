#!/usr/bin/env python3
"""
DOOM Server Monitor
Queries Chocolate Doom servers and displays their status.

Usage:
    ./monitor-servers.py                    # Query default servers
    ./monitor-servers.py -w                 # Watch mode (refresh every 5s)
    ./monitor-servers.py -s 192.168.1.100   # Custom server IP
    ./monitor-servers.py -p 2342 -n 10      # Custom base port, 10 servers
"""

import socket
import struct
import argparse
import time
import sys
from datetime import datetime

# Chocolate Doom packet types (from net_defs.h)
NET_PACKET_TYPE_QUERY = 13
NET_PACKET_TYPE_QUERY_RESPONSE = 14

# Server states
SERVER_STATE_WAITING = 0
SERVER_STATE_IN_GAME = 1

# Default configuration
DEFAULT_SERVER_IP = "64.227.99.100"
DEFAULT_BASE_PORT = 2342
DEFAULT_NUM_SERVERS = 10
QUERY_TIMEOUT = 1.0  # seconds


def send_query(sock, addr):
    """Send a query packet to a server."""
    # Query packet is just the packet type as uint16 big-endian
    # (Chocolate Doom uses big-endian for network packets)
    packet = struct.pack('>H', NET_PACKET_TYPE_QUERY)
    sock.sendto(packet, addr)


def read_string(data, offset):
    """Read a null-terminated string from data starting at offset."""
    end = data.find(b'\x00', offset)
    if end == -1:
        return None, offset
    return data[offset:end].decode('utf-8', errors='replace'), end + 1


def parse_response(data):
    """Parse a query response packet."""
    if len(data) < 8:
        return None
    
    # Read packet type (uint16 big-endian)
    packet_type = struct.unpack('>H', data[0:2])[0]
    if packet_type != NET_PACKET_TYPE_QUERY_RESPONSE:
        return None
    
    offset = 2
    
    # Read version string
    version, offset = read_string(data, offset)
    if version is None:
        return None
    
    # Read server state, num_players, max_players, gamemode, gamemission
    if offset + 5 > len(data):
        return None
    
    server_state = data[offset]
    num_players = data[offset + 1]
    max_players = data[offset + 2]
    gamemode = data[offset + 3]
    gamemission = data[offset + 4]
    offset += 5
    
    # Read description string
    description, offset = read_string(data, offset)
    if description is None:
        description = "Unknown"
    
    return {
        'version': version,
        'state': server_state,
        'num_players': num_players,
        'max_players': max_players,
        'gamemode': gamemode,
        'gamemission': gamemission,
        'description': description,
    }


def query_server(ip, port, timeout=QUERY_TIMEOUT):
    """Query a single server and return its info."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)
    
    addr = (ip, port)
    start_time = time.time()
    
    try:
        send_query(sock, addr)
        data, _ = sock.recvfrom(1024)
        ping = int((time.time() - start_time) * 1000)
        
        info = parse_response(data)
        if info:
            info['ping'] = ping
            info['online'] = True
            return info
    except socket.timeout:
        pass
    except Exception as e:
        pass
    finally:
        sock.close()
    
    return {'online': False}


def state_str(state):
    """Convert server state to string."""
    if state == SERVER_STATE_WAITING:
        return "WAITING"
    elif state == SERVER_STATE_IN_GAME:
        return "IN GAME"
    return "UNKNOWN"


def state_color(state, num_players):
    """Return ANSI color code for state."""
    if state == SERVER_STATE_IN_GAME:
        return "\033[33m"  # Yellow
    elif num_players > 0:
        return "\033[32m"  # Green
    return "\033[36m"  # Cyan


def print_header():
    """Print table header."""
    print("\033[1m" + "-" * 78 + "\033[0m")
    print("\033[1m{:<5} {:<25} {:<10} {:<12} {:<8} {:<10}\033[0m".format(
        "PORT", "DESCRIPTION", "PLAYERS", "STATE", "PING", "VERSION"
    ))
    print("\033[1m" + "-" * 78 + "\033[0m")


def print_server(port, info):
    """Print server info row."""
    if not info['online']:
        print("\033[90m{:<5} {:<25} {:<10} {:<12} {:<8} {:<10}\033[0m".format(
            port, "(offline)", "-", "-", "-", "-"
        ))
        return
    
    color = state_color(info['state'], info['num_players'])
    reset = "\033[0m"
    
    players = f"{info['num_players']}/{info['max_players']}"
    state = state_str(info['state'])
    ping = f"{info['ping']}ms"
    desc = info['description'][:24]
    version = info['version'][:10]
    
    print(f"{color}{port:<5} {desc:<25} {players:<10} {state:<12} {ping:<8} {version:<10}{reset}")


def query_all_servers(ip, base_port, num_servers):
    """Query all servers and return results."""
    results = []
    total_players = 0
    online_count = 0
    
    for i in range(num_servers):
        port = base_port + i
        info = query_server(ip, port)
        results.append((port, info))
        
        if info['online']:
            online_count += 1
            total_players += info['num_players']
    
    return results, online_count, total_players


def clear_screen():
    """Clear terminal screen."""
    print("\033[2J\033[H", end="")


def main():
    parser = argparse.ArgumentParser(description="DOOM Server Monitor")
    parser.add_argument("-s", "--server", default=DEFAULT_SERVER_IP,
                        help=f"Server IP address (default: {DEFAULT_SERVER_IP})")
    parser.add_argument("-p", "--port", type=int, default=DEFAULT_BASE_PORT,
                        help=f"Base port number (default: {DEFAULT_BASE_PORT})")
    parser.add_argument("-n", "--num", type=int, default=DEFAULT_NUM_SERVERS,
                        help=f"Number of servers to query (default: {DEFAULT_NUM_SERVERS})")
    parser.add_argument("-w", "--watch", action="store_true",
                        help="Watch mode - refresh every 5 seconds")
    parser.add_argument("-i", "--interval", type=int, default=5,
                        help="Refresh interval in seconds (default: 5)")
    args = parser.parse_args()
    
    try:
        while True:
            if args.watch:
                clear_screen()
            
            print(f"\n\033[1m🎮 DOOM Server Monitor\033[0m")
            print(f"   Server: {args.server}  Ports: {args.port}-{args.port + args.num - 1}")
            print(f"   Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            
            results, online, total_players = query_all_servers(
                args.server, args.port, args.num
            )
            
            print_header()
            for port, info in results:
                print_server(port, info)
            print("-" * 78)
            
            print(f"\n   \033[1mServers:\033[0m {online}/{args.num} online")
            print(f"   \033[1mPlayers:\033[0m {total_players} total")
            
            if not args.watch:
                break
            
            print(f"\n   Refreshing in {args.interval}s... (Ctrl+C to exit)")
            time.sleep(args.interval)
            
    except KeyboardInterrupt:
        print("\n\nExiting...")
        sys.exit(0)


if __name__ == "__main__":
    main()

