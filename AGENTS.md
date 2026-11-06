# Project working agreements

- Update documentation for important milestones, major implementations, architectural decisions, and deliberate settings changes. Routine code edits, small fixes, and internal refactors do not require a documentation or history entry unless they materially change documented behavior.
- Keep current behavior and ownership in the relevant guide. For significant milestones, append a dated entry to `docs/history.md` describing what changed, why, affected paths, verification performed, and limitations. Group related work into meaningful entries.
- Record architectural decisions and their tradeoffs in `docs/decisions.md`. Mark proposals as proposed; do not present planned lifecycle methods or other unimplemented features as available.
- Ask the user before changing project settings, Input Map bindings, import settings, or established scene configuration outside the requested work. Approval of a specific setting change authorizes that change; do not ask again for the same approved scope.
- For approved settings changes, update `docs/settings.md` with the setting path, old/new values when known, reason, scope, and approval context. Distinguish project settings from scene properties and engine defaults.
- Preserve historical entries. When a decision changes, append the replacement decision and identify the superseded one; update current guides to match the implementation.
- Do not invent dates, approvals, or verification results. Label reconstructed history, unknown prior values, and checks not performed explicitly.
- Keep changes small and explain their purpose. The user is learning Godot and values walkthroughs; follow the current request about whether to implement or guide.
- Do not change behavior merely to match an external reference. Discuss significant architectural changes before implementing them.

- For every new sound effect, measure its audible portion against comparable effects, set a per-stream gain trim in `assets/audio/sound_effect_mix.tres`, and verify playback uses the shared mix. Preserve the source recording and document the chosen trim in `docs/audio.md`.
