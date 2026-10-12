#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sing-box Configuration Formatter
Directly compresses and formats sing-box configs into compact, clean single-line objects.
"""

import argparse
import json
import os
import sys
from pathlib import Path

# --- 1. Automatic Virtualenv Switcher ---
_REPO_ROOT = Path(__file__).resolve().parent.parent
_VENV_PYTHON = _REPO_ROOT / ".venv" / "bin" / "python"
if sys.prefix == getattr(sys, "base_prefix", sys.prefix) and _VENV_PYTHON.is_file():
    os.execv(str(_VENV_PYTHON), [str(_VENV_PYTHON)] + sys.argv)

try:
    from rich import box
    from rich.console import Console
    from rich.panel import Panel
    from rich.table import Table
    from rich.text import Text
except ImportError:
    print("[!] 'rich' library is required. Please run: pip install -r tools/requirements.txt")
    sys.exit(1)


# --- 2. Compact Serialization Core ---

def is_primitive(val) -> bool:
    """Check if value is a JSON primitive."""
    return isinstance(val, (str, int, float, bool)) or val is None


def is_primitive_list(val) -> bool:
    """Check if value is a list consisting solely of primitives."""
    return isinstance(val, list) and all(is_primitive(x) for x in val)


def format_singbox_json(val, path: tuple = (), indent: int = 0, indent_str: str = "  ") -> str:
    """
    Recursively format sing-box configuration with compact styling:
    - Root and complex blocks: 2-space indentation.
    - dns.servers, dns.rules, outbounds, http_clients, route.rules, route.rule_set: single-line per item.
    - Small inline mappings (optimistic, default_domain_resolver) and primitive lists: single-line.
    """
    cur_indent = indent_str * indent
    next_indent = indent_str * (indent + 1)

    compact_list_paths = {
        ("dns", "servers"),
        ("dns", "rules"),
        ("outbounds",),
        ("http_clients",),
        ("route", "rules"),
        ("route", "rule_set"),
        ("endpoints",),
    }

    parent_path = path[:-1]
    if parent_path in compact_list_paths and isinstance(val, dict):
        return json.dumps(val, ensure_ascii=False, separators=(", ", ": "))

    if is_primitive_list(val):
        return json.dumps(val, ensure_ascii=False, separators=(", ", ": "))

    if isinstance(val, dict):
        if len(path) > 0 and path[-1] in ("optimistic", "default_domain_resolver"):
            return json.dumps(val, ensure_ascii=False, separators=(", ", ": "))

        if not val:
            return "{}"

        lines = ["{"]
        items = list(val.items())
        for idx, (k, v) in enumerate(items):
            comma = "," if idx < len(items) - 1 else ""
            formatted_v = format_singbox_json(v, path + (k,), indent + 1, indent_str)
            lines.append(f'{next_indent}"{k}" : {formatted_v}{comma}'.replace('" : ', '": '))
        lines.append(f"{cur_indent}}}")
        return "\n".join(lines)

    if isinstance(val, list):
        if not val:
            return "[]"
        lines = ["["]
        for idx, item in enumerate(val):
            comma = "," if idx < len(val) - 1 else ""
            formatted_item = format_singbox_json(item, path + (idx,), indent + 1, indent_str)
            lines.append(f"{next_indent}{formatted_item}{comma}")
        lines.append(f"{cur_indent}]")
        return "\n".join(lines)

    return json.dumps(val, ensure_ascii=False)


# --- 3. Terminal CLI & Formatting Runner ---

def format_file_size(num_bytes: int) -> str:
    for unit in ("B", "KB", "MB"):
        if abs(num_bytes) < 1024.0:
            return f"{num_bytes:3.1f} {unit}"
        num_bytes /= 1024.0
    return f"{num_bytes:.1f} GB"


def main():
    parser = argparse.ArgumentParser(
        description="Format sing-box configuration directly into compact JSON style.",
    )
    parser.add_argument(
        "file",
        nargs="?",
        default="sing-box/config/config_sub.json",
        help="Path to sing-box JSON configuration file (default: sing-box/config/config_sub.json)",
    )
    parser.add_argument(
        "-o", "--output",
        help="Save formatted output to a different path instead of overwriting the original file",
    )

    args = parser.parse_args()
    console = Console()

    target_path = Path(args.file)
    if not target_path.is_file():
        console.print(f"[bold red]✘ File not found:[/bold red] {target_path}")
        sys.exit(1)

    # Read original file
    with open(target_path, "r", encoding="utf-8") as f:
        original_raw = f.read()

    try:
        data = json.loads(original_raw)
    except json.JSONDecodeError as err:
        console.print(f"[bold red]✘ Invalid JSON in {target_path}:[/bold red] {err}")
        sys.exit(1)

    # Perform formatting
    formatted_raw = format_singbox_json(data) + "\n"

    # Strict semantic verification
    try:
        reparsed_data = json.loads(formatted_raw)
        if reparsed_data != data:
            console.print("[bold red]✘ Verification failed:[/bold red] Formatted JSON is not semantically equal to original!")
            sys.exit(1)
    except json.JSONDecodeError as err:
        console.print(f"[bold red]✘ Verification failed (parse error):[/bold red] {err}")
        sys.exit(1)

    # Statistics
    orig_lines = original_raw.splitlines()
    new_lines = formatted_raw.splitlines()
    orig_len = len(orig_lines)
    new_len = len(new_lines)
    line_diff = new_len - orig_len
    line_pct = (line_diff / orig_len) * 100 if orig_len else 0

    orig_bytes = len(original_raw.encode("utf-8"))
    new_bytes = len(formatted_raw.encode("utf-8"))
    byte_diff = new_bytes - orig_bytes
    byte_pct = (byte_diff / orig_bytes) * 100 if orig_bytes else 0

    # Write output
    output_target = Path(args.output) if args.output else target_path
    output_target.parent.mkdir(parents=True, exist_ok=True)
    with open(output_target, "w", encoding="utf-8") as f:
        f.write(formatted_raw)

    # Banner
    banner_text = Text()
    banner_text.append("⚡ sing-box Config Formatter\n", style="bold cyan")
    banner_text.append("Compact JSON Serialization · Optimized Layout", style="dim white")
    console.print(Panel(banner_text, box=box.ROUNDED, border_style="cyan", padding=(0, 2)))

    # Metrics Table
    table = Table(
        title=f"✨ Formatted: [bold white]{output_target}[/bold white]",
        box=box.ROUNDED,
        border_style="bright_blue",
        header_style="bold cyan",
    )
    table.add_column("Metric", style="bold white")
    table.add_column("Original", justify="right", style="yellow")
    table.add_column("Formatted", justify="right", style="green")
    table.add_column("Change", justify="right", style="bold")

    change_style = "green" if line_diff < 0 else "dim white"
    table.add_row(
        "Line Count",
        f"{orig_len:,} lines",
        f"{new_len:,} lines",
        f"[{change_style}]{line_diff:+,} ({line_pct:+.1f}%)[/{change_style}]",
    )
    table.add_row(
        "File Size",
        format_file_size(orig_bytes),
        format_file_size(new_bytes),
        f"[{change_style}]{format_file_size(byte_diff)} ({byte_pct:+.1f}%)[/{change_style}]",
    )
    table.add_row(
        "Semantic Equivalence",
        "—",
        "—",
        "[bold green]✓ 100% Identical[/bold green]",
    )
    console.print(table)
    console.print(f"[bold green]✔ Successfully formatted & saved:[/bold green] [cyan]{output_target}[/cyan]\n")


if __name__ == "__main__":
    main()
