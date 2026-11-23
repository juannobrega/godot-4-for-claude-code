---
description: Break a plan into ordered, reviewable tasks with explicit file check-out sets
argument-hint: <system-slug>
---

Break the plan for **$1** into tasks.

## Shape of a good task

One reviewable change. States the files it touches and what "done" means in a
way someone else could check.

```
- [ ] T-012 — Add DashConfig resource with the four tuning values
      files: `scripts/config/dash_config.gd` (new)
      done when: class_name DashConfig, four typed @export_range matching the
                 ranges in spec.md, project imports clean (V1)
```

Order: foundation (resources, contracts) → behaviour → verification. Tests are
tasks, not an afterthought — every AC at V2–V4 gets a task that writes it.

The last task of every system is running `/godot-4:verify` at the highest rung
the plan declares, and filing the evidence.

## Rules

- A task that cannot state its file set is too vague to start.
- A task touching `project.godot` or an autoload is marked **sequential** — it
  can never run in parallel with another task.
- Carry any `[DESIGN DECISION]` into the task where it bites, so implementation
  stops there instead of guessing.
