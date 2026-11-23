#!/usr/bin/env python3
"""PreToolUse guard for Godot scene and resource files.

.tscn, .tres and project.godot look like editable INI and are not. Rewriting
one as text desynchronises uid:// references, miscounts load_steps, collides
sub_resource ids and leaves signal connections dangling -- all silently, with
the breakage surfacing much later as a scene that will not load.

This hook blocks structural edits and allows the two kinds that are safe:
scalar property values and [connection] lines.

Exit 0 allows the call. Exit 2 blocks it and shows stderr to Claude.
Set GODOT4_GUARD_OFF=1 to disable, for the rare deliberate surgery.
"""
import json
import os
import re
import sys

# Headers and fields that carry cross-file identity. Changing any of them as
# text is what corrupts the project.
STRUCTURAL = re.compile(
    r"""^\s*(
          \[gd_scene\b | \[gd_resource\b | \[ext_resource\b |
          \[sub_resource\b | \[node\b | \[editable\b
        )""",
    re.VERBOSE,
)
UID_OR_STEPS = re.compile(r"\buid://|^\s*load_steps\s*=", re.MULTILINE)
# Changing this rewrites which engine version the project declares itself as.
PROJECT_PINS = re.compile(r"^\s*config/features\s*=", re.MULTILINE)

GUARDED_SUFFIX = (".tscn", ".tres", ".godot")


def structural_lines(text):
    """Lines in `text` that define structure rather than hold a value."""
    out = []
    for line in (text or "").splitlines():
        if STRUCTURAL.match(line) or UID_OR_STEPS.search(line):
            out.append(line.strip())
    return out


def find_project(path):
    d = os.path.dirname(os.path.abspath(path))
    while d != "/":
        if os.path.isfile(os.path.join(d, "project.godot")):
            return d
        d = os.path.dirname(d)
    return None


def block(reason, how):
    sys.stderr.write(
        "Blocked: structural edit to a Godot scene/resource file.\n\n"
        f"{reason}\n\n"
        "Editing these as text desynchronises uid:// references, load_steps and\n"
        "sub_resource ids. The breakage is silent until the scene fails to load.\n\n"
        f"How to proceed:\n{how}\n\n"
        "Scalar property values and [connection] lines are allowed and need no "
        "workaround.\nTo override deliberately: GODOT4_GUARD_OFF=1\n"
    )
    sys.exit(2)


def main():
    if os.environ.get("GODOT4_GUARD_OFF") == "1":
        return
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return  # never break a session because the guard itself failed

    tool = payload.get("tool_name", "")
    ti = payload.get("tool_input", {}) or {}
    path = ti.get("file_path") or ti.get("notebook_path") or ""
    if not path or not path.endswith(GUARDED_SUFFIX):
        return
    base = os.path.basename(path)
    if path.endswith(".godot") and base != "project.godot":
        return  # the .godot/ cache directory, not a project file
    if not find_project(path):
        return  # not inside a Godot project: this kit stays inert

    if tool == "Write":
        if os.path.exists(path):
            block(
                f"Write replaces the whole file: {base}",
                "- Change one property? Use Edit on that line instead.\n"
                "- Need structural change? Generate the scene from "
                "tools/scenes/build_<name>.gd, or make it in the Godot editor.",
            )
        return  # creating a new file is fine

    # Edit / MultiEdit: compare the structure on both sides of the change.
    edits = ti.get("edits") or [{"old_string": ti.get("old_string", ""),
                                 "new_string": ti.get("new_string", "")}]
    for e in edits:
        old, new = e.get("old_string", ""), e.get("new_string", "")
        if base == "project.godot":
            if PROJECT_PINS.search(old) or PROJECT_PINS.search(new):
                block(
                    "config/features declares the engine version of the project.",
                    "- Change the Godot version by opening the project in the "
                    "target editor version and letting it migrate.",
                )
            continue
        so, sn = structural_lines(old), structural_lines(new)
        if so != sn:
            changed = sorted(set(so) ^ set(sn))[:4]
            detail = "\n".join("    " + c for c in changed) or "    (lines reordered)"
            block(
                f"{base}: the edit changes structural lines:\n{detail}",
                "- Add or remove a node, resource or uid? Do it in the Godot "
                "editor, or regenerate from tools/scenes/build_<name>.gd.\n"
                "- Rewiring a signal? Edit the [connection] line alone; that is "
                "allowed.",
            )


if __name__ == "__main__":
    main()
