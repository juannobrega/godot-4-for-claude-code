#!/usr/bin/env python3
"""Validates the godot-4 kit before it is released.

This repository ships a .claude/ framework, not a Claude Code plugin, so
`claude plugin validate` does not apply. These are the equivalent checks.

Exit 0 clean, 1 with findings.
"""
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CLAUDE = ROOT / ".claude"
MAX_SKILL_LINES = 500
MAX_DESCRIPTION = 1024
RESERVED = ("anthropic", "claude")

errors, warnings = [], []


def frontmatter(path):
    text = path.read_text()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None, text
    data = {}
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith((" ", "\t")):
            k, v = line.split(":", 1)
            data[k.strip()] = v.strip()
    return data, text


def check_skills():
    skills = sorted(CLAUDE.glob("skills/*/SKILL.md"))
    if not skills:
        errors.append("no skills found under .claude/skills/")
    for p in skills:
        rel = p.relative_to(ROOT)
        fm, text = frontmatter(p)
        if fm is None:
            errors.append(f"{rel}: missing YAML frontmatter")
            continue
        name = fm.get("name", "")
        if name != p.parent.name:
            errors.append(f"{rel}: name '{name}' does not match directory '{p.parent.name}'")
        if not re.fullmatch(r"[a-z0-9-]{1,64}", name):
            errors.append(f"{rel}: name must be lowercase letters, digits and hyphens")
        if any(w in name.lower() for w in RESERVED):
            errors.append(f"{rel}: name contains a reserved word")
        desc = fm.get("description", "")
        if not desc:
            errors.append(f"{rel}: description is required")
        elif len(desc) > MAX_DESCRIPTION:
            errors.append(f"{rel}: description is {len(desc)} chars (max {MAX_DESCRIPTION})")
        elif not re.search(r"\bUse (when|only when|at|before|for)\b", desc):
            # The description decides whether the skill is ever selected.
            warnings.append(f"{rel}: description does not say when to use the skill")
        n = len(text.splitlines())
        if n > MAX_SKILL_LINES:
            errors.append(f"{rel}: {n} lines (max {MAX_SKILL_LINES})")
        # Progressive disclosure: references must be one level from SKILL.md.
        for target in re.findall(r"\]\((?!https?:)([^)]+)\)", text):
            if not (p.parent / target).exists() and not (ROOT / target).exists():
                warnings.append(f"{rel}: link to missing file '{target}'")


def check_agents():
    for p in sorted(CLAUDE.glob("agents/*.md")):
        rel = p.relative_to(ROOT)
        fm, _ = frontmatter(p)
        if not fm:
            errors.append(f"{rel}: missing frontmatter")
            continue
        if fm.get("name") != p.stem:
            errors.append(f"{rel}: name does not match filename")
        if not fm.get("description"):
            errors.append(f"{rel}: description is required")


def check_commands():
    cmds = sorted(CLAUDE.glob("commands/godot-4/*.md"))
    if not cmds:
        errors.append("no commands found under .claude/commands/godot-4/")
    for p in cmds:
        fm, _ = frontmatter(p)
        if not fm or not fm.get("description"):
            errors.append(f"{p.relative_to(ROOT)}: description is required")


def check_hooks():
    settings = CLAUDE / "settings.json"
    if not settings.exists():
        errors.append(".claude/settings.json is missing")
        return
    try:
        data = json.loads(settings.read_text())
    except json.JSONDecodeError as exc:
        errors.append(f".claude/settings.json: invalid JSON: {exc}")
        return
    for event, groups in (data.get("hooks") or {}).items():
        for group in groups:
            for hook in group.get("hooks", []):
                cmd = hook.get("command", "")
                m = re.search(r"/\.claude/scripts/([\w.]+)", cmd)
                if not m:
                    warnings.append(f"hook {event}: command does not reference .claude/scripts/")
                    continue
                script = CLAUDE / "scripts" / m.group(1)
                if not script.exists():
                    errors.append(f"hook {event}: {m.group(1)} does not exist")
                elif not script.stat().st_mode & 0o111:
                    errors.append(f"hook {event}: {m.group(1)} is not executable")


def check_scripts():
    for p in sorted((CLAUDE / "scripts").glob("*.sh")):
        r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        if r.returncode:
            errors.append(f"{p.relative_to(ROOT)}: syntax error: {r.stderr.strip()}")
        # macOS ships bash 3.2, which has no ${var,,} or ${var^^}.
        if re.search(r"\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^)\}", p.read_text()):
            errors.append(f"{p.relative_to(ROOT)}: uses bash 4 case expansion; breaks on macOS")
    for p in sorted((CLAUDE / "scripts").glob("*.py")):
        r = subprocess.run([sys.executable, "-m", "py_compile", str(p)],
                           capture_output=True, text=True)
        if r.returncode:
            errors.append(f"{p.relative_to(ROOT)}: does not compile: {r.stderr.strip()}")


def _strip_ps_comments(text):
    """Drops PowerShell comments so prose about a variable is not read as code.

    Handles line comments outside quotes and <# block comments #>. Good enough
    for the collision scan: a false negative there is a missed finding, while a
    false positive would flag documentation.
    """
    text = re.sub(r"<#.*?#>", "", text, flags=re.S)
    out = []
    for line in text.splitlines():
        quote = None
        for i, ch in enumerate(line):
            if quote:
                if ch == quote:
                    quote = None
            elif ch in "\"'":
                quote = ch
            elif ch == "#":
                line = line[:i]
                break
        out.append(line)
    return "\n".join(out)


def check_powershell():
    """PowerShell variable names are case-insensitive.

    A local named `$here` therefore assigns to a `[switch]$Here` parameter, and
    assigning a string to a switch throws. That shipped in v1.0.0 and broke the
    no-argument install path on Windows entirely, so the check exists to stop a
    reviewer's attention from being the only thing between it and a release.
    """
    for p in sorted(ROOT.glob("*.ps1")) + sorted((ROOT / "tools").glob("*.ps1")):
        rel = p.relative_to(ROOT)
        text = _strip_ps_comments(p.read_text())
        # Parameters declared in a param(...) block, typed or not.
        params = re.findall(r"^\s*(?:\[[\w.]+\]\s*)?\$(\w+)\s*[,)]", text, re.M)
        if not params:
            continue
        seen = {}
        for m in re.finditer(r"\$(\w+)", text):
            seen.setdefault(m.group(1).lower(), set()).add(m.group(1))
        for name in set(params):
            others = seen.get(name.lower(), set()) - {name}
            if others:
                errors.append(
                    f"{rel}: parameter ${name} is also spelled "
                    f"{', '.join('$' + o for o in sorted(others))}; PowerShell "
                    f"variable names are case-insensitive, so these are one "
                    f"variable and the parameter is overwritten"
                )


def check_templates():
    for name in ("spec.md", "plan.md", "tasks.md", "contract.md",
                 "constitution.md", "config.yml"):
        if not (CLAUDE / "templates" / name).exists():
            errors.append(f".claude/templates/{name} is missing")
    # new_system.sh substitutes these; a template without them scaffolds wrong.
    for name in ("spec.md", "plan.md", "tasks.md", "contract.md"):
        p = CLAUDE / "templates" / name
        if p.exists() and "{{SLUG}}" not in p.read_text():
            warnings.append(f".claude/templates/{name}: no {{{{SLUG}}}} placeholder")


def main():
    for check in (check_skills, check_agents, check_commands,
                  check_hooks, check_scripts, check_powershell, check_templates):
        check()
    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error: {e}")
    print(f"\n{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
