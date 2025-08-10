#!/usr/bin/env python3
"""Format a single Cursor prompt log markdown into a cleaner numbered list.
Usage: python3 scripts/format_single_prompt_log.py <input_md> <output_md>
Produces output as markdown with numbered User / Cursor blocks.
"""
import pathlib, re, sys
from typing import List, Tuple

USER_RE = re.compile(r"^\*\*User\*\*")
CURSOR_RE = re.compile(r"^\*\*Cursor\*\*")
SEPARATOR_RE = re.compile(r"^---+$")


def parse_blocks(path: pathlib.Path) -> List[Tuple[str, str]]:
    blocks: List[Tuple[str, str]] = []
    role = None
    buf: List[str] = []
    with path.open(encoding="utf-8") as f:
        for line in f:
            if USER_RE.match(line):
                if role and buf:
                    blocks.append((role, "".join(buf).strip()))
                    buf = []
                role = "User"
                continue
            if CURSOR_RE.match(line):
                if role and buf:
                    blocks.append((role, "".join(buf).strip()))
                    buf = []
                role = "Cursor"
                continue
            if SEPARATOR_RE.match(line.strip()):
                # skip separator lines
                continue
            if role:
                buf.append(line)
    if role and buf:
        blocks.append((role, "".join(buf).strip()))
    return blocks


def render_markdown(blocks: List[Tuple[str, str]], user_only: bool = False) -> str:
    """Render blocks to markdown. If user_only is True, include only User prompts."""
    md_lines: List[str] = ["# Formatted Prompt Log", ""]
    out_idx = 0
    for idx, (role, text) in enumerate(blocks, 1):
        if user_only and role != "User":
            continue
        out_idx += 1
        md_lines.append(f"## {out_idx}. {role} Prompt")
        md_lines.append("")
        for line in text.splitlines():
            md_lines.append(f"> {line.rstrip()}")
        md_lines.append("")
    return "\n".join(md_lines)


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 scripts/format_single_prompt_log.py <input_md> <output_md> [--user-only]")
        sys.exit(1)
    inp = pathlib.Path(sys.argv[1])
    outp = pathlib.Path(sys.argv[2])
    user_only_flag = "--user-only" in sys.argv
    blocks = parse_blocks(inp)
    outp.write_text(render_markdown(blocks, user_only=user_only_flag), encoding="utf-8")
    print(f"Formatted log written to {outp}")


if __name__ == "__main__":
    main()
