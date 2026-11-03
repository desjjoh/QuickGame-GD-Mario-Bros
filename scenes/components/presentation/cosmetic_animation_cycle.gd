class_name CosmeticAnimationCycle
extends Resource
## Shared durations in 60Hz physics ticks; artwork remains on each target.

@export var phase_ticks := PackedInt32Array([24, 8, 8, 8])

func total_ticks() -> int:
	var total := 0
	for duration in phase_ticks:
		if duration <= 0: return 0
		total += duration
	return total

func phase_at(tick: int) -> int:
	var total := total_ticks()
	if total <= 0: return 0
	var cursor := posmod(tick, total)
	for phase in range(phase_ticks.size()):
		if cursor < phase_ticks[phase]: return phase
		cursor -= phase_ticks[phase]
	return 0

func phase_time(phase: int) -> float:
	var ticks := 0
	for index in range(phase): ticks += phase_ticks[index]
	# Packed animation key times can be slightly above exact tick fractions.
	return float(ticks) / 60.0 + 0.000001
