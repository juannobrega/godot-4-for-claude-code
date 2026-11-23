#!/usr/bin/env python3
"""Payload half of the godot-4 installer, shared by install.sh and install.ps1.

The shells resolve the destination and run the guards; everything that touches
files happens here, once, so the two platforms cannot drift apart.

    installer.py --src <package> --dest <project> [--dry-run] [--force]

Writes .claude/.godot-4-manifest.json recording the version, a hash of every
file delivered, and the hook groups added. Without that record an update cannot
tell a framework file from one the user wrote or edited, so it can only
overwrite and never clean up.
"""
import argparse
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone

PAYLOAD = ("skills", "commands", "agents", "scripts", "templates")
MANIFEST = ".godot-4-manifest.json"
IGNORE = ("__pycache__", ".pyc")


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def payload_files(src):
    """Relative paths of every file the package delivers under .claude/."""
    out = {}
    base = os.path.join(src, ".claude")
    for top in PAYLOAD:
        root = os.path.join(base, top)
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in IGNORE]
            for name in filenames:
                if name.endswith(IGNORE[1]):
                    continue
                full = os.path.join(dirpath, name)
                out[os.path.relpath(full, base).replace(os.sep, "/")] = full
    return out


def load_json(path, what):
    """Reads JSON, failing with a message that says nothing was installed."""
    try:
        with open(path) as fh:
            return json.load(fh)
    except FileNotFoundError:
        return None
    except Exception as exc:
        sys.exit(f"error: {path} is not valid JSON ({exc}).\n"
                 f"Nothing was installed. Fix the {what} and run again.")


def hook_group_key(group):
    """Identifies a hook group by the commands it runs.

    The matcher may be hand-edited and the event may gain entries, but the
    scripts a group runs are what make it this framework's group.
    """
    return tuple(sorted(h.get("command", "") for h in group.get("hooks", [])))


def classify(src_files, dest_base, old_manifest):
    """Sorts every path into exactly one bucket.

    A file is only safe to overwrite or delete when the manifest says we wrote
    it and its hash still matches. Anything else is the user's.
    """
    recorded = (old_manifest or {}).get("files", {})
    plan = {"new": [], "update": [], "unchanged": [], "conflict": [], "stale": []}

    for rel in sorted(src_files):
        target = os.path.join(dest_base, rel)
        if not os.path.exists(target):
            plan["new"].append(rel)
            continue
        current = digest(target)
        if current == digest(src_files[rel]):
            plan["unchanged"].append(rel)
        elif rel in recorded and recorded[rel] != current:
            # We delivered it, and it has changed since. Someone edited it.
            plan["conflict"].append(rel)
        elif rel in recorded:
            plan["update"].append(rel)
        else:
            # Present, not ours. Treat as the user's own file.
            plan["conflict"].append(rel)

    for rel, recorded_hash in sorted(recorded.items()):
        if rel in src_files:
            continue
        target = os.path.join(dest_base, rel)
        if not os.path.exists(target):
            continue
        if digest(target) == recorded_hash:
            plan["stale"].append(rel)
        else:
            # Dropped from the package and edited locally: leave it alone and
            # say so, rather than deleting someone's work.
            plan["conflict"].append(rel)
    return plan


def report(plan, dest_base, old_manifest, version, dry_run, force):
    was = (old_manifest or {}).get("version")
    verb = "would install" if dry_run else "installing"
    # A working copy has no VERSION file, so say that rather than print the
    # word "unknown" where a version belongs.
    what = version if version != "unknown" else "a working copy"
    if was and was != version:
        print(f"{verb} {what} over {was} in {dest_base}/")
    elif was:
        print(f"{verb} {what} over the same version in {dest_base}/")
    else:
        print(f"{verb} {what} into {dest_base}/")

    for bucket, label in (("new", "new"), ("update", "updated"),
                          ("unchanged", "unchanged"), ("stale", "removed")):
        if plan[bucket]:
            print(f"  {len(plan[bucket])} {label}")
    if plan["stale"] and dry_run:
        for rel in plan["stale"]:
            print(f"    - {rel}")
    if plan["conflict"]:
        kept = "overwritten" if force else "kept"
        print(f"  {len(plan['conflict'])} locally modified, {kept}:")
        for rel in plan["conflict"]:
            print(f"    ! {rel}")
        if not force:
            print("  Re-run with --force to replace them, or diff them first.")


def apply_files(plan, src_files, dest_base, force):
    for bucket in ("new", "update", "unchanged"):
        for rel in plan[bucket]:
            target = os.path.join(dest_base, rel)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            shutil.copy2(src_files[rel], target)

    for rel in plan["conflict"]:
        if rel not in src_files:
            continue
        target = os.path.join(dest_base, rel)
        if force:
            shutil.copy2(src_files[rel], target)
        else:
            # Keep a copy of what the package would have written, so the user
            # can diff without re-downloading.
            shutil.copy2(src_files[rel], target + ".new")

    for rel in plan["stale"]:
        target = os.path.join(dest_base, rel)
        try:
            os.remove(target)
        except OSError:
            continue
        parent = os.path.dirname(target)
        while parent.startswith(dest_base) and parent != dest_base:
            try:
                os.rmdir(parent)
            except OSError:
                break
            parent = os.path.dirname(parent)


def merge_hooks(src, dest_base, old_manifest, force):
    """Replaces this framework's hook groups, keeping the user's own.

    Removing the groups the previous manifest recorded is what makes a renamed
    or deleted hook work: without it the old group survives, pointing at a
    script that no longer exists, and fails on every write.
    """
    incoming = (load_json(os.path.join(src, ".claude", "settings.json"),
                          "package") or {}).get("hooks", {})
    dest_path = os.path.join(dest_base, "settings.json")
    existing = load_json(dest_path, "project's settings.json") or {}
    if not isinstance(existing, dict):
        sys.exit(f"error: {dest_path} must contain a JSON object. "
                 "Nothing was installed.")
    hooks = existing.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        sys.exit(f"error: {dest_path} has a 'hooks' entry that is not an "
                 "object. Nothing was installed.")

    ours = {tuple(k) for k in (old_manifest or {}).get("hook_groups", [])}
    removed = 0
    for event in list(hooks):
        if not isinstance(hooks[event], list):
            continue
        kept = [g for g in hooks[event] if hook_group_key(g) not in ours]
        removed += len(hooks[event]) - len(kept)
        hooks[event] = kept

    added, keys = 0, []
    for event, groups in incoming.items():
        current = hooks.setdefault(event, [])
        for group in groups:
            key = hook_group_key(group)
            keys.append(list(key))
            if any(hook_group_key(g) == key for g in current):
                continue
            current.append(group)
            added += 1

    for event in [e for e, g in hooks.items() if isinstance(g, list) and not g]:
        del hooks[event]

    with open(dest_path, "w") as fh:
        json.dump(existing, fh, indent=2)
        fh.write("\n")
    return added, removed, keys


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--version", default="unknown")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    dest_base = os.path.join(args.dest, ".claude")
    old_manifest = load_json(os.path.join(dest_base, MANIFEST), "manifest")
    # Validate the project's settings.json before touching anything, so a
    # failed install never leaves half a framework behind.
    load_json(os.path.join(dest_base, "settings.json"),
              "project's settings.json")

    src_files = payload_files(args.src)
    if not src_files:
        sys.exit(f"error: {args.src}/.claude has no payload to install.")
    plan = classify(src_files, dest_base, old_manifest)
    report(plan, dest_base, old_manifest, args.version, args.dry_run, args.force)

    if args.dry_run:
        print("  settings.json: hooks would be merged, your own entries kept")
        return 0

    os.makedirs(dest_base, exist_ok=True)
    apply_files(plan, src_files, dest_base, args.force)
    added, removed, keys = merge_hooks(args.src, dest_base, old_manifest,
                                       args.force)
    print(f"  settings.json: {added} hook group(s) added, {removed} replaced")

    delivered = {rel: digest(os.path.join(dest_base, rel))
                 for rel in src_files
                 if os.path.exists(os.path.join(dest_base, rel))
                 and rel not in plan["conflict"]}
    with open(os.path.join(dest_base, MANIFEST), "w") as fh:
        json.dump({"version": args.version,
                   "installed_at": datetime.now(timezone.utc)
                                   .isoformat(timespec="seconds"),
                   "files": delivered,
                   "hook_groups": keys}, fh, indent=2)
        fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
