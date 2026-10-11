#!/usr/bin/env python3
"""
Starmax TUI Wizard — fun modern guided rescue flow.
Inspired by tools like OpenCode / OpenClaw style interactive CLIs.

Requires: pip install rich (optional but recommended)
Falls back to plain input if rich is missing.
"""
import os
import sys
import subprocess
import json
from pathlib import Path

try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.prompt import Prompt, Confirm, IntPrompt
    from rich.table import Table
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich.markdown import Markdown
    RICH = True
except ImportError:
    RICH = False
    print("Tip: pip install rich for the full modern TUI experience.")

console = Console() if RICH else None

def banner():
    art = r'''
  ____  _                             
 / ___|| |_ __ _ _ __ _ __ ___   __ _ 
 \___ \| __/ _` | '__| '_ ` _ \ / _` |
  ___) | || (_| | |  | | | | | | (_| |
 |____/ \__\__,_|_|  |_| |_| |_|\__,_|
                                       
    '''
    if RICH:
        console.print(Panel(art, title="[bold cyan]Starmax Rescue Wizard[/]", border_style="cyan", subtitle="Insert disc. Rescue the past."))
    else:
        print(art)
        print("=== Starmax Rescue Wizard ===")

def run_cmd(cmd, check=True):
    if RICH:
        with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"), transient=True) as progress:
            progress.add_task(description="Running...", total=None)
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    else:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(result.stderr or result.stdout)
    return result

def detect_drives():
    result = subprocess.run("drutil list", shell=True, capture_output=True, text=True)
    lines = [l.strip() for l in result.stdout.splitlines() if l.strip() and not l.startswith("Vendor")]
    drives = []
    for line in lines:
        parts = line.split()
        if len(parts) >= 3:
            drives.append({"id": parts[0], "product": " ".join(parts[1:-2]), "bus": parts[-2] if len(parts)>3 else "USB"})
    return drives

def main():
    banner()
    if RICH:
        console.print("[bold green]Welcome to the Starmax optical rescue wizard.[/]")
        console.print("We'll guide you through imaging and sorting an old Mac CD.\n")
    else:
        print("Welcome. Let's rescue an old Mac CD.\n")

    # Step 1: Insert disc
    if RICH:
        Confirm.ask("[yellow]Have you inserted the disc into the drive?[/]", default=True)
    else:
        input("Press Enter when the disc is inserted...")

    # Step 2: Detect drives
    if RICH:
        console.print("\n[bold]Scanning for optical drives...[/]")
    drives = detect_drives()
    if not drives:
        print("No drives found. Check connection and try again.")
        return

    if RICH:
        table = Table(title="Detected Drives")
        table.add_column("ID")
        table.add_column("Product")
        table.add_column("Bus")
        for d in drives:
            table.add_row(d["id"], d["product"], d["bus"])
        console.print(table)
        choice = IntPrompt.ask("Select drive number", default=1)
    else:
        print("Drives:")
        for i, d in enumerate(drives, 1):
            print(f"  {i}. {d['product']}")
        choice = int(input("Select number: ") or "1")

    drive = drives[choice-1] if 1 <= choice <= len(drives) else drives[0]

    # Step 3: Name
    if RICH:
        name = Prompt.ask("[cyan]Archive name[/]", default="Starmax-Rescue")
    else:
        name = input("Archive name [Starmax-Rescue]: ") or "Starmax-Rescue"

    # Step 4: Options with explanations
    if RICH:
        console.print("\n[bold]Options[/] (defaults are usually fine)")
        do_rip = Confirm.ask("Rip / image the disc first? (creates .iso + extracts)", default=True)
        do_sanitize = Confirm.ask("Sanitize filenames? (replaces : / special chars / long names with safe _ versions)", default=True)
        do_modern = Confirm.ask("Create modern export? (copies keepers into modern/fonts images qxd other with clean names)", default=True)
        do_verify = Confirm.ask("Run checksum verification? (SHA-256 every keepers file — slower)", default=False)
        do_notify = Confirm.ask("Notify when done? (macOS notification)", default=True)
    else:
        print("\nOptions:")
        do_rip = input("Rip / image the disc first? [Y/n]: ").lower() != "n"
        do_sanitize = input("Sanitize filenames? (safe renames) [Y/n]: ").lower() != "n"
        do_modern = input("Create modern export? [Y/n]: ").lower() != "n"
        do_verify = input("Run checksum verification? [y/N]: ").lower() == "y"
        do_notify = input("Notify when done? [Y/n]: ").lower() != "n"

    # Build commands
    script_dir = Path(__file__).parent
    rescue_cmd = f"{script_dir}/rescue-cd.sh --src ~/Desktop/{name} --name \"{name}\" --go"
    if do_sanitize:
        rescue_cmd += " --sanitize"
    if do_modern:
        rescue_cmd += " --export-modern"
    if do_verify:
        rescue_cmd += " --verify"
    if do_notify:
        rescue_cmd += " --notify"

    if RICH:
        console.print(Panel(f"Ready to run:\n\nRip: {do_rip}\nRescue: {rescue_cmd}", title="Summary", border_style="green"))
        if not Confirm.ask("Proceed?", default=True):
            console.print("[red]Aborted.[/]")
            return
    else:
        print("Ready. Press Enter to start or Ctrl-C to abort.")
        input()

    # Execute
    if do_rip:
        rip_cmd = f"{script_dir}/rip-old-mac-cd.sh --device /dev/disk{drive['id']} \"{name}\""
        if RICH:
            console.print(f"\n[bold yellow]Ripping with drive {drive['product']}...[/]")
        run_cmd(rip_cmd)

    if RICH:
        console.print("\n[bold yellow]Running rescue...[/]")
    run_cmd(rescue_cmd)

    # Done
    archive = Path.home() / "Desktop" / "CD-Archive" / name
    if RICH:
        console.print(Panel(f"Done!\n\nArchive: {archive}\n\nCheck keepers/, modern/, fonts.md, verification.json", title="[bold green]Success[/]", border_style="green"))
    else:
        print(f"\nDone. Results in {archive}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.")
        sys.exit(1)
