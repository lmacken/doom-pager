#!/usr/bin/env python3
"""
DOOM Server Monitor
Queries Chocolate Doom servers and displays their status using a rich console dashboard.

Usage:
    ./monitor-servers.py                    # Query default servers
    ./monitor-servers.py -w                 # Watch mode (refresh every 5s)
    ./monitor-servers.py -s 192.168.1.100   # Custom server IP
    ./monitor-servers.py -p 2342 -n 10      # Custom base port, 10 servers

Requirements:
    pip install rich
"""

import socket
import struct
import argparse
import time
import sys
from datetime import datetime

from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.layout import Layout
from rich.live import Live
from rich.text import Text
from rich.style import Style
from rich import box

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

console = Console()


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
    except Exception:
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


def get_state_style(state, num_players):
    """Return rich style for state."""
    if state == SERVER_STATE_IN_GAME:
        return "bold yellow"
    elif num_players > 0:
        return "bold green"
    return "cyan"


def query_all_servers(ip, base_port, num_servers):
    """Query all servers and return results."""
    results = []
    total_players = 0
    online_count = 0
    in_game_count = 0
    
    for i in range(num_servers):
        port = base_port + i
        info = query_server(ip, port)
        results.append((port, info))
        
        if info['online']:
            online_count += 1
            total_players += info['num_players']
            if info['state'] == SERVER_STATE_IN_GAME:
                in_game_count += 1
    
    return results, online_count, total_players, in_game_count


def create_server_table(results):
    """Create a rich table with server information."""
    table = Table(
        box=box.ROUNDED,
        header_style="bold white on dark_red",
        title_style="bold",
        show_lines=False,
        padding=(0, 1),
    )
    
    table.add_column("Port", style="bold", width=6, justify="right")
    table.add_column("Description", width=28)
    table.add_column("Players", width=10, justify="center")
    table.add_column("State", width=12, justify="center")
    table.add_column("Ping", width=8, justify="right")
    table.add_column("Version", width=12)
    
    for port, info in results:
        if not info['online']:
            table.add_row(
                str(port),
                Text("(offline)", style="dim"),
                Text("-", style="dim"),
                Text("-", style="dim"),
                Text("-", style="dim"),
                Text("-", style="dim"),
            )
        else:
            style = get_state_style(info['state'], info['num_players'])
            players = f"{info['num_players']}/{info['max_players']}"
            state = state_str(info['state'])
            ping = f"{info['ping']}ms"
            desc = info['description'][:27]
            version = info['version'][:11]
            
            # Player count styling
            if info['num_players'] > 0:
                players_text = Text(players, style="bold green")
            else:
                players_text = Text(players, style="dim")
            
            # Ping color based on latency
            if info['ping'] < 50:
                ping_style = "green"
            elif info['ping'] < 100:
                ping_style = "yellow"
            else:
                ping_style = "red"
            
            table.add_row(
                Text(str(port), style=style),
                Text(desc, style=style),
                players_text,
                Text(state, style=style),
                Text(ping, style=ping_style),
                Text(version, style="dim"),
            )
    
    return table


def create_dashboard(args, results, online, total_players, in_game):
    """Create the full dashboard layout."""
    # Create header
    header_text = Text()
    header_text.append("🎮 ", style="bold")
    header_text.append("DOOM Server Monitor", style="bold red")
    
    # Server info line
    info_text = Text()
    info_text.append("Server: ", style="dim")
    info_text.append(f"{args.server}", style="bold cyan")
    info_text.append("  │  ", style="dim")
    info_text.append("Ports: ", style="dim")
    info_text.append(f"{args.port}-{args.port + args.num - 1}", style="bold cyan")
    info_text.append("  │  ", style="dim")
    info_text.append(datetime.now().strftime('%Y-%m-%d %H:%M:%S'), style="dim italic")
    
    header_panel = Panel(
        info_text,
        title=header_text,
        title_align="left",
        border_style="red",
        padding=(0, 1),
    )
    
    # Create server table
    table = create_server_table(results)
    
    # Create summary panel
    summary_text = Text()
    summary_text.append("📡 Servers: ", style="dim")
    summary_text.append(f"{online}", style="bold green" if online > 0 else "bold red")
    summary_text.append(f"/{args.num} online", style="dim")
    summary_text.append("  │  ", style="dim")
    summary_text.append("👥 Players: ", style="dim")
    summary_text.append(f"{total_players}", style="bold green" if total_players > 0 else "dim")
    summary_text.append("  │  ", style="dim")
    summary_text.append("🎮 In Game: ", style="dim")
    summary_text.append(f"{in_game}", style="bold yellow" if in_game > 0 else "dim")
    
    if args.watch:
        summary_text.append("  │  ", style="dim")
        summary_text.append(f"↻ {args.interval}s", style="dim italic")
    
    summary_panel = Panel(
        summary_text,
        border_style="dim",
        padding=(0, 1),
    )
    
    return header_panel, table, summary_panel


def run_once(args):
    """Run a single query and display results."""
    results, online, total_players, in_game = query_all_servers(
        args.server, args.port, args.num
    )
    
    header, table, summary = create_dashboard(args, results, online, total_players, in_game)
    
    console.print()
    console.print(header)
    console.print(table)
    console.print(summary)
    console.print()


def run_watch(args):
    """Run in watch mode with live updates."""
    def generate_display():
        results, online, total_players, in_game = query_all_servers(
            args.server, args.port, args.num
        )
        header, table, summary = create_dashboard(args, results, online, total_players, in_game)
        
        # Combine into a single renderable group
        from rich.console import Group
        return Group(
            Text(),  # Empty line
            header,
            table,
            summary,
            Text(),  # Empty line
        )
    
    console.print("\n[dim italic]Starting watch mode... Press Ctrl+C to exit[/]\n")
    
    with Live(generate_display(), console=console, refresh_per_second=0.5, screen=True) as live:
        try:
            while True:
                live.update(generate_display())
                time.sleep(args.interval)
        except KeyboardInterrupt:
            pass
    
    console.print("\n[dim]Exiting...[/]\n")


def main():
    parser = argparse.ArgumentParser(
        description="DOOM Server Monitor - A rich console dashboard for Chocolate Doom servers"
    )
    parser.add_argument("-s", "--server", default=DEFAULT_SERVER_IP,
                        help=f"Server IP address (default: {DEFAULT_SERVER_IP})")
    parser.add_argument("-p", "--port", type=int, default=DEFAULT_BASE_PORT,
                        help=f"Base port number (default: {DEFAULT_BASE_PORT})")
    parser.add_argument("-n", "--num", type=int, default=DEFAULT_NUM_SERVERS,
                        help=f"Number of servers to query (default: {DEFAULT_NUM_SERVERS})")
    parser.add_argument("-w", "--watch", action="store_true",
                        help="Watch mode - refresh periodically")
    parser.add_argument("-i", "--interval", type=int, default=5,
                        help="Refresh interval in seconds (default: 5)")
    args = parser.parse_args()
    
    try:
        if args.watch:
            run_watch(args)
        else:
            run_once(args)
    except KeyboardInterrupt:
        console.print("\n[dim]Exiting...[/]\n")
        sys.exit(0)


if __name__ == "__main__":
    main()
