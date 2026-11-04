# GDScript style and cleanup checks

Use UTF-8, tab indentation (display width four), spaces around operators and after commas, and blank lines between methods and logical declaration groups. Expand single-line control flow into indented blocks. Separate property getter/setter declarations so their boundaries are clear. Prefer a 100-character line length; long diagnostics and comments may need manual reflow. Do not reorder initializers or restructure gameplay solely to satisfy a style rule.

.editorconfig records editor defaults. gdformatrc enables formatter safety checks and the 100-character target. tools/requirements-dev.txt pins gdtoolkit 4.5.0, a development-only dependency; it is not part of the Godot game runtime.

## Running the formatter

From the project folder in PowerShell, install the tools once into the ignored validation directory:

```powershell
python -m pip install --target .godot/validation/format-tools -r tools/requirements-dev.txt
$env:PYTHONPATH = Join-Path (Get-Location) '.godot/validation/format-tools'
```

Check formatting without writing files:

```powershell
python -m gdtoolkit.formatter --check scenes scripts tests tools
```

Apply formatting, with syntax-tree, comment-preservation and stability checks enabled:

```powershell
python -m gdtoolkit.formatter scenes scripts tests tools
```

The formatter covers game scripts, test scenes/fixtures and diagnostic tools. It does not rewrite scenes, resources, artwork, imports or Project Settings. Run the existing Godot regression runner after a broad cleanup; a Python parser check is not a substitute for Godot execution.

## Lint inspection and existing debt

```powershell
python -m gdtoolkit.linter scenes scripts tests tools
```

Default gdtoolkit lint is an inspection tool here, not an established green project gate. The 2026-11-04 cleanup reduced its findings from 416 to 135: 76 declaration-order findings, 40 long lines (mainly diagnostic strings/comments), 15 repeated test loads, three return-count findings and one GameHandler public-method-count finding. Formatting passes for all 111 scripts; the stricter lint command still exits with failure. No rules were disabled to hide remaining debt.

Declaration reordering can affect initialization, so review it in small changes. Keep useful guard clauses rather than flattening safety checks merely to meet a return quota. Consider splitting session/status and flow coordination out of GameHandler only as a separate discussed refactor. Repeated test loads can be deliberate resource-isolation checks; inspect the test before deduplicating them.

## Runtime finding fixed during the review

HUD listened to level/area session changes but not BaseLevelArea.area_theme_changed. Live theme selection could update title artwork while leaving the HUD coin on the previous atlas. hud_test previously masked this with explicit calls to the private refresh helper. HUD now binds the active area's theme signal, rebinds on area/level changes and disconnects during cleanup. The regression test checks automatic refresh and removal of the old area's subscription; shared coin phase and private SpriteFrames behavior remain.

Standalone F6 pit-death restart and intermittent native engine shutdown failures remain tracked in the [backlog](backlog.md). This cleanup does not resolve them. See [verification](verification.md) for actual regression outcomes.

## Title background activity

The editable TestLevel now contains painted block entities, so the title test no longer requires an empty WorldObjects container. Title mode now gameplay-suspends every existing BaseEntity under its background, rather than Mario alone. Cosmetic animations remain independent. New enemies/spawners and dynamic background insertion still require their own lifecycle coverage when introduced; this change does not add a demo mode or remove user scenery.

Godot rejected gdformat 4.5.0's multiline formatting of two inline lambdas nested inside assertions in transition_test. Those identical callbacks now share a named covered_operation helper. Keep actual Godot execution in the verification workflow even when formatter syntax-tree checks pass.
