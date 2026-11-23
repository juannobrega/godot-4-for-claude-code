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
        # macOS ships bash 3.2 as /bin/bash. These all need 4+, and catching
        # them here is worth more than a macOS CI job: the job takes minutes to
        # get a runner, and its `run:` steps resolve bash from PATH, where the
        # runner has Homebrew bash 5 -- so it does not even test 3.2.
        text = p.read_text()
        for pattern, what in (
            (r"\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^)[\}:]", "case expansion ${var,,} / ${var^^}"),
            (r"^\s*declare\s+-[A-Za-z]*A", "associative array (declare -A)"),
            (r"^\s*(readarray|mapfile)\b", "readarray / mapfile"),
            (r"\|&", "|& pipe shorthand"),
            (r"&>>", "&>> append redirect"),
        ):
            if re.search(pattern, text, re.M):
                errors.append(f"{p.relative_to(ROOT)}: uses {what}, which needs "
                              f"bash 4; macOS ships 3.2 as /bin/bash")
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


def check_engine_pin_parses():
    """The constitution template must yield a bare version to session_context.sh.

    A trailing annotation on the Engine line made the pin a non-prefix of the
    binary's version, so the mismatch warning fired on every prompt in every
    freshly initialised project. A warning that always fires is a warning
    everyone learns to ignore, which disables the check without disabling it.
    """
    template = CLAUDE / "templates" / "constitution.md"
    script = CLAUDE / "scripts" / "session_context.sh"
    if not template.exists() or not script.exists():
        return
    m = re.search(r"^[-*]\s*Engine:\s*(.*)$", template.read_text(), re.M)
    if not m:
        errors.append(".claude/templates/constitution.md: no '- Engine:' line")
        return
    # Extract with the shell pipeline the hook actually runs, not a Python
    # lookalike: a reimplementation here would drift from the script and the
    # check would end up testing itself.
    body = script.read_text()
    m_sed = re.search(r"PIN=\"\$\((.*?)\)\"", body, re.S)
    if not m_sed:
        errors.append(
            ".claude/scripts/session_context.sh: no PIN extraction found; "
            "check_engine_pin_parses cannot verify the template against it"
        )
        return
    pipeline = m_sed.group(1).replace("\\\n", " ")
    pipeline = pipeline.replace('"$GODOTSPEC/constitution.md"', str(template))
    try:
        pin = subprocess.run(["bash", "-c", pipeline], capture_output=True,
                             text=True, timeout=10).stdout.strip()
    except Exception as exc:
        errors.append(f"session_context.sh PIN pipeline did not run: {exc}")
        return

    if not re.fullmatch(r"\d+\.\d+(\.\d+)?", pin):
        errors.append(
            f"the Engine line in .claude/templates/constitution.md yields "
            f"{pin!r} through session_context.sh's own extraction, which is not "
            f"a bare version. It is compared as a prefix of the binary's "
            f"version, so anything else makes the mismatch warning fire on "
            f"every prompt in every freshly initialised project"
        )


# Routes that were removed. A message or template still pointing at one sends
# an agent somewhere that does not exist -- and the worst offender was the
# scene guard's own blocking message, which is the first thing read when an edit
# is refused. A reviewer caught that once; this makes it fail instead.
REMOVED_ROUTES = {
    "tools/scenes/build_": "use .claude/scripts/build_scene.sh with a scene contract",
}


def check_removed_routes():
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or ".git/" in str(path):
            continue
        if path.suffix not in (".md", ".py", ".sh", ".json", ".gd", ".yml"):
            continue
        rel = path.relative_to(ROOT)
        if str(rel).startswith("docs/research/"):
            continue  # a record of what other projects do, not our own routes
        if path.resolve() == pathlib.Path(__file__).resolve():
            continue  # this file names the routes in order to look for them
        try:
            text = path.read_text()
        except (UnicodeDecodeError, OSError):
            continue
        for route, advice in REMOVED_ROUTES.items():
            if route in text:
                line = next((i for i, l in enumerate(text.splitlines(), 1)
                             if route in l), 0)
                errors.append(f"{rel}:{line}: references the removed route "
                              f"'{route}' — {advice}")


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
                  check_hooks, check_scripts, check_powershell,
                  check_engine_pin_parses, check_removed_routes,
                  check_templates):
        check()
    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error: {e}")
    print(f"\n{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
