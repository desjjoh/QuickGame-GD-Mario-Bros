# Shared cosmetic animation clock

GameHandler owns one CosmeticAnimationClock child named AnimationClock. Its tick_count advances once per physics tick, at priority -90 (after input collection and before entity physics). The project currently uses 60Hz physics. This is a deterministic tick clock, not a separate Timer per object or an elapsed-time accumulator per animation.

The clock does not reset on area changes, level reloads, death, or clear_session. Entity gameplay suspension leaves it running, so cosmetic palette animation continues during death. Ordinary SceneTree pausing would pause the inherited clock processing; no pause-menu behavior is added here.

## Shared cycle and targets

scenes/components/presentation/palette_pulse.tres is a CosmeticAnimationCycle with phase_ticks=[24,8,8,8]. The four phases are bright, medium, dark, medium; total 48 ticks (0.8 seconds at 60Hz). A different cycle resource can supply different positive durations while sampling the same clock. Optional authored phase offsets are normalized within the cycle.

SynchronizedAnimation is a presentation component with no independent frame/physics callback. It registers a target and cycle with the clock. The clock groups subscriptions by resource and offset, evaluates each group once per tick and notifies clients only when the phase changes. Subscription immediately applies the current phase, so newly created objects never wait for the next boundary or restart at frame zero.

Targets retain their own artwork:

- AnimatedSprite2D: SpriteFrames contains four entries for the four phases (the medium texture is reused). The component pauses native playback and sets frame from the global phase.
- AnimationPlayer: the component assigns/pauses the selected animation and seeks to phase boundaries. Texture keys remain in each entity's private, theme-remapped animation library. A tiny seek epsilon accounts for packed floating-point key times.

Use cosmetic-only texture/frame tracks. Do not attach gameplay method calls, movement, damage or spawning to this clock. Walking cadence, jumps, pipe motion and block bouncing remain local action/state behavior.

## Current bindings

HUD/Coin/Synchronization starts enabled and drives the active area's HUD coin atlas, falling back to Overworld. Native autoplay is off. QuestionBlock/Presentation/PaletteAnimation starts disabled; its Active state's Synchronized Animation property enables it on activation and disables it before exit. Bouncing and Inactive therefore retain exclusive control of the used sprite and cannot be overwritten by a later clock phase.

BaseState supports the optional synchronized_animation reference for reuse by other state-driven objects. Choose this ownership instead of independent playback for the same cosmetic target. BaseEntity.shutdown disables all descendant synchronization components, including always-on components without a state binding; tree exit also unsubscribes. Empty subscription groups release their resources. Gameplay suspension does not unsubscribe cosmetic clients.

## Reuse for future world coins

1. Add a SynchronizedAnimation node under the coin's Presentation branch.
2. Assign palette_pulse.tres and its AnimatedSprite2D or AnimationPlayer target.
3. Supply a four-entry bright/medium/dark/medium frame sequence, or matching timeline keys at 0, 24/60, 32/60 and 40/60 seconds.
4. Remove native autoplay. Use Start Enabled for always-on cosmetics, or bind the component to the owning state's Synchronized Animation property with Start Enabled=false.
5. Configure any offset before activation. Runtime cycle/offset changes require disabling and enabling the component again to re-register.

No world coin entity, pickup logic, counter updates or coin persistence is implemented by this milestone. HUD coin artwork now switches between Overworld and Underground without restarting the clock. Edit the cycle resource to change runtime cadence; SpriteFrames speed/durations and the AnimationPlayer resource alone are not the global clock's source of timing.

## Reference and verification

ColorRotatePalette/ColorRotation in the [disassembly](https://gist.github.com/1wErt3r/4048722) uses three bright slots followed by medium/dark/medium, advancing every eight frames. This project adapts shared palette timing to independent sprite/texture assets. Continuing the cosmetic clock during death is our chosen policy, not a claim of complete NES update-order equivalence.

animation_clock_test checks exact phase boundaries and wrapping, late joins, Underground artwork, suspension, bounce/used ownership, shutdown/unsubscribe and continuity across area, level and session changes. Its rendered branch spawns a question block in the dark phase and verifies agreement with the HUD during normal rendered updates. Existing HUD, theme, question-block and death checks use global phase assertions where appropriate. See [verification](verification.md) for complete scope.
