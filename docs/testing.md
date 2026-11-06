# Testing

## Run regression scenes

From the project root in PowerShell, run:

```powershell
./scripts/run_tests.ps1 -GodotPath 'C:\path\to\Godot_console.exe'
```

The runner discovers `tests/*_test.tscn` and writes logs under `.godot/validation`. It requires a PASS marker and a successful exit, and treats errors and warnings as failures. To investigate one scenario, run its scene directly with the Godot console executable:

```powershell
& 'C:\path\to\Godot_console.exe' --headless --path . res://tests/transition_test.tscn --max-fps 60 --quit-after 1800
```

## Manual checks

- Start 1-1 from the title, enter and exit the secret area, and verify camera, theme, HUD, and music handoffs.
- Test jumping and running with keyboard and controller. Check pipe and ledge contacts, especially at high refresh rates.
- Die in a pit and by timeout. Verify life loss, progress policy, restart, and return to title after game over.
- Bonk a painted question block in-game and check the immediate HUD reward, coin arc, and floating 200. Revisit the used block and verify it grants no second reward.
- Finish at the flagpole. Check the score popup, time conversion, music, and castle flag.
- Compare generated audio with Mesen at the same playback level. Check note period, duty cycle, attack, decay, cutoff, and retrigger timing before changing pitch or gain. Area loops and jingles use different envelope rules.

Headless regressions check playback routing and lifecycle. Use a rendered run and listening comparison for frame pacing and audio fidelity. See [backlog](backlog.md) for known verification gaps.
