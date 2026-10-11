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
CONFIG_PATH = Path.home() / ".starmax-wizard.json"

def load_last_options():
    if CONFIG_PATH.exists():
        try:
            return json.loads(CONFIG_PATH.read_text())
        except Exception:
            pass
    return {}

def save_options(opts):
    try:
        CONFIG_PATH.write_text(json.dumps(opts, indent=2))
    except Exception:
        pass

def banner():
    art = r'''
  ____ _____  _    ____  __  __    _    __  __
 / ___|_   _|/ \  |  _ \|  \/  |  / \  \ \/ /
 \___ \ | | / _ \ | |_) | |\/| | / _ \  \  / 
  ___) || |/ ___ \|  _ <| |  | |/ ___ \ /  \ 
 |____/ |_/_/   \_\_| \_\_|  |_/_/   \_/_/\_\
                                             
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
    last = load_last_options()
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
    default_name = last.get("name", "Starmax-Rescue")
    if RICH:
        name = Prompt.ask("[cyan]Archive name[/]", default=default_name)
    else:
        name = input(f"Archive name [{default_name}]: ") or default_name

    # Step 4: Options with explanations + last defaults
    if RICH:
        console.print("\n[bold]Options[/] (defaults remembered from last run)")
        do_rip = Confirm.ask("Rip / image the disc first? (creates .iso + extracts to Desktop)", default=last.get("rip", True))
        do_sanitize = Confirm.ask("Sanitize filenames? (replaces : / special chars / long names with safe _ versions)", default=last.get("sanitize", True))
        do_modern = Confirm.ask("Create modern export? (sorts keepers into modern/fonts, modern/images, modern/qxd, modern/other with clean names for easy use on current Mac)", default=last.get("modern", True))
        do_quick = Confirm.ask("Quick-view previews? (PICT→PNG and .mov poster frames in modern/previews for easy browsing)", default=last.get("quick", True))
        do_fonts = Confirm.ask("Convert fonts? (copy suitcases/.dfont into modern/fonts and attempt basic conversion if tools available)", default=last.get("fonts", False))
        do_verify = Confirm.ask("Run checksum verification? (SHA-256 every keepers file — slower but stronger integrity check)", default=last.get("verify", False))
        do_notify = Confirm.ask("Notify when done? (macOS notification)", default=last.get("notify", True))
    else:
        print("\nOptions:")
        do_rip = input("Rip / image the disc first? [Y/n]: ").lower() != "n"
        do_sanitize = input("Sanitize filenames? (safe renames) [Y/n]: ").lower() != "n"
        do_modern = input("Create modern export? (sorted clean copies) [Y/n]: ").lower() != "n"
        do_quick = input("Quick-view previews? [Y/n]: ").lower() != "n"
        do_fonts = input("Convert fonts? [y/N]: ").lower() == "y"
        do_verify = input("Run checksum verification? [y/N]: ").lower() == "y"
        do_notify = input("Notify when done? [Y/n]: ").lower() != "n"

    # Save for next time
    save_options({
        "name": name,
        "rip": do_rip,
        "sanitize": do_sanitize,
        "modern": do_modern,
        "quick": do_quick,
        "fonts": do_fonts,
        "verify": do_verify,
        "notify": do_notify,
    })

    # Build commands
    script_dir = Path(__file__).parent
    rescue_cmd = f"{script_dir}/rescue-cd.sh --src ~/Desktop/{name} --name \"{name}\" --go"
    if do_sanitize:
        rescue_cmd += " --sanitize"
    if do_modern:
        rescue_cmd += " --export-modern"
    if do_quick:
        rescue_cmd += " --quick-view"
    if do_fonts:
        rescue_cmd += " --convert-fonts"
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
    success = True
    if do_rip:
        rip_cmd = f"{script_dir}/rip-old-mac-cd.sh --device /dev/disk{drive['id']} \"{name}\""
        if RICH:
            console.print(f"\n[bold yellow]Ripping with drive {drive['product']}...[/]")
        r = run_cmd(rip_cmd)
        if r.returncode != 0:
            success = False

    if RICH:
        console.print("\n[bold yellow]Running rescue...[/]")
    r = run_cmd(rescue_cmd)
    if r.returncode != 0:
        success = False

    # Done + summary
    archive = Path.home() / "Desktop" / "CD-Archive" / name
    summary_lines = [f"Archive: {archive}"]
    if archive.exists():
        keepers = len(list((archive / "keepers").rglob("*"))) if (archive / "keepers").exists() else 0
        modern = "yes" if (archive / "modern").exists() else "no"
        previews = "yes" if (archive / "modern" / "previews").exists() else "no"
        fonts_md = archive / "fonts.md"
        font_count = "?"
        if fonts_md.exists():
            font_count = sum(1 for line in fonts_md.read_text().splitlines() if line.startswith("-"))
        summary_lines.append(f"Keepers files: {keepers}")
        summary_lines.append(f"Modern export: {modern}")
        summary_lines.append(f"Quick-view previews: {previews}")
        summary_lines.append(f"Fonts catalogued: {font_count}")

    border = "green" if success else "red"
    title = "[bold green]Success[/]" if success else "[bold red]Finished with errors[/]"
    if RICH:
        console.print(Panel("\n".join(summary_lines), title=title, border_style=border))
    else:
        print("\n" + "\n".join(summary_lines))

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.")
        sys.exit(1)
