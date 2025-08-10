import pathlib, re, sys
from typing import List, Tuple

PROMPT_DIR = pathlib.Path(__file__).resolve().parent.parent / "docs" / "prompt_logs"

USER_HEADER = re.compile(r"^\*\*User\*\*")
CURSOR_HEADER = re.compile(r"^\*\*Cursor\*\*")


def extract_prompts(md_path: pathlib.Path) -> List[Tuple[str, str]]:
    """Return list of (role, text) tuples extracted from markdown prompt log."""
    prompts = []
    current_role = None
    buffer = []
    with md_path.open("r", encoding="utf-8") as f:
        for line in f:
            if USER_HEADER.match(line):
                # flush previous buffer
                if current_role and buffer:
                    prompts.append((current_role, "".join(buffer).strip()))
                    buffer = []
                current_role = "User"
                continue
            if CURSOR_HEADER.match(line):
                if current_role and buffer:
                    prompts.append((current_role, "".join(buffer).strip()))
                    buffer = []
                current_role = "Cursor"
                continue
            if current_role:
                # skip markdown separators that immediately follow header
                if line.strip() == "---":
                    continue
                buffer.append(line)
        # flush remainder
        if current_role and buffer:
            prompts.append((current_role, "".join(buffer).strip()))
    return prompts


def main(directory: pathlib.Path = PROMPT_DIR):
    for md_path in directory.rglob("*.md"):
        prompts = extract_prompts(md_path)
        if not prompts:
            continue
        print(f"===== {md_path.relative_to(directory.parent)} =====")
        for role, text in prompts:
            print(f"[{role}]\n{text}\n")
        print()


if __name__ == "__main__":
    dir_arg = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else PROMPT_DIR
    if not dir_arg.exists():
        print(f"Directory {dir_arg} does not exist", file=sys.stderr)
        sys.exit(1)
    main(dir_arg)
