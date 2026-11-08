# Super Mario damage

Implemented 2026-11-07. Ordinary enemy damage shrinks Super Mario instead of charging a life. Small Mario still dies. This connects the [shrinking presentation](mario-form-presentations.md). [Super Mushroom collection](super-mushroom.md) is implemented separately; other power-ups remain future work.

## Damage and lifecycle ownership

`BaseEnemy` delivers ordinary damage through `BasePlayer.receive_damage(source)`. Its default implementation finds the owning level and requests the existing death path. Mario overrides this entry point: dead/shutdown/suspended actors, active form presentations, and injury protection reject another hit; Super starts shrinking; Small delegates to the existing death behavior. The return value means an injury/death request was accepted, not that the actor necessarily died.

Mario's `Damage` child owns protection and flashing independently of `FormPresentation`. Session form becomes Small when shrinking is accepted; the existing presentation applies the live Small contact profile at its reference threshold. Neither a life nor enemy score is awarded for injury. Protection is established synchronously before another enemy contact can be processed.

Damage contacts do not keep the enemy interaction latch set. The player owns repeated-damage rejection, so an uninterrupted overlap becomes dangerous again when protection expires. Stomps and shell kicks retain their existing interaction latches and scoring. Protection does not turn an ordinary descending stomp into damage or prevent the stomp.

Falling, timeout, and other explicit lethal level events retain direct `BaseLevel.on_death()` calls. They bypass injury protection. Death and shutdown clear the protection and restore visibility after cancelling the form presentation. Area arrival preserves protection on the same live actor and reapplies its current flashing phase.

## Timer, flashing, and sound

The source's `ForceInjury` starts `InjuryTimer` at 8; normal interval timers decrement every 21 eligible ticks and stop under the transformation master timer. `MarioDamage` likewise maintains a 21-tick cadence before injury, starts eight protection intervals on acceptance, and holds its cadence throughout the form presentation. It resumes on the tick after presentation completion, giving 148–168 eligible physics ticks after completion depending on the local interval phase. User pause stops the component, cadence, and animation clock. Gameplay suspension holds the cadence too.

This cadence is local to the live Mario instance. It reproduces the phase-dependent eight-interval protection rather than introducing a fixed wall-clock grace, but is not aligned to the NES's shared interval counter across title/death/recreation. That global-counter alignment is not claimed. The existing [Mesen research](growth-damage-bricks-research.md) measured one original-game fixture at 153 frames after routine completion.

While protection is active, visibility follows alternating ticks of the existing global animation clock, including the shrinking sequence. Presentation completion does not end protection flashing. Expiry restores the visibility captured at injury entry. No alpha fade, positional audio, pitch adjustment, or gain change was added.

`SoundHandler` exposes `injury` as the same generated stream as `pipe`. The disassembly's `Sfx_PipeDown_Injury` selects one shared Square 1 routine for both events. Mario plays it through the existing non-positional `AudioStreamPlayer` path at default gain/pitch. This reuses the existing synthesis; no new audible Mesen comparison was performed in this pass.

## Verification

Focused `mario_damage_test`, `mario_form_presentation_test`, `koopa_contact_test`, `shell_interaction_test`, `death_test`, `pause_test`, and `sound_mix_test` passed without engine errors or warnings. After tightening the accepted-injury latch behavior, the three affected contact scenes (`mario_damage_test`, `koopa_contact_test`, `shell_interaction_test`) passed again.

The new regression covers Super injury without life loss, session form change, cue identity and default gain/pitch, protection throughout shrinking and after completion, alternating visibility, pause, persistent real Area2D overlap becoming lethal after expiry, protected stomping, walking Koopa/moving-shell damage, duplicate-death rejection, and timeout bypass. Existing collision boxes, stomp/kick behavior, and Small damage integration retain their focused tests. The full regression suite and a rendered manual gameplay/audio comparison were not run.

Affected paths: BasePlayer and BaseEnemy damage routing; Mario scene/script; `scripts/player/mario_damage.gd`; SoundHandler cue alias; `tests/mario_damage_test.*`. Project settings, Input Map bindings, and import options are unchanged.
