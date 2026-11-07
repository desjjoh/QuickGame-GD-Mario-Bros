# Timed coin rewards - reference investigation

Date: 2026-11-07. The source investigation was followed by approval and implementation of independent 231-tick rewards. See [implementation and verification](timed-coins.md). The original research pass made no gameplay changes.

## Disassembly findings

Source: [SMB disassembly](https://gist.github.com/1wErt3r/4048722).

- `StartBTmr` loads BrickCoinTimer with $0b on the first qualifying hit. Later hits do not renew it while BrickCoinTimerFlag is set.
- The interrupt timer loop decrements interval timers every 21 eligible frames. Eleven decrements take 211-231 frames depending on the shared interval phase: about 3.52-3.85 seconds at nominal 60 Hz. Pause skips these decrements; TimerControl can also suppress them.
- `ContBTmr` retains the reward metatile while time remains. Once expired, the next hit still reaches `CoinBlock` but schedules the used metatile. Expiry alone does not visibly empty the block. No fixed ten-coin counter appears in this reward path.
- BrickCoinTimer and its flag are global. `BrickWithCoins` clears the flag when the area parser generates another such object. A later hit can therefore restart the shared timer. This is not independent per-block timing.
- `BlockBounceTimer` imposes a 16-frame head-hit gate; `CoinBlock` uses the ordinary coin award and pop path. Timed reward bricks remain unbreakable even for the large player while their reward metatile is present.

## Implications for this project

Current QuestionBlock releases a coin or power-up on Bouncing entry and returns to Inactive. BaseBlock snapshots the logical return state during a bounce. Timed rewards will need a repeatable Active return until the final hit, plus saved reward timing state; saving the visual state alone is insufficient.

Existing persistent reward blocks survive area changes and death according to the global progress-reset policy. Ordinary bricks currently opt out of persistence. The new reward-brick scenes should follow reward-block persistence rather than ordinary-brick defaults. Applying this reward to question and hidden question blocks is an intentional authoring extension.

## Approved version difference

On 2026-11-07, the user approved independent timing per block and explicitly requested that it be documented as a known version difference. Starting or loading another timed block will not restart, shorten, or otherwise change an existing block's reward window. We deliberately omit the NES's parser-dependent shared timer/start-flag quirk. This supersedes the unapproved proposal recorded in the initial investigation.

The user subsequently approved a fixed 231-physics-tick countdown from the first hit. This is implemented without the NES shared interval phase. It deliberately removes both shared-block interference and the phase-dependent 211-231-frame window.

The accepted persistence direction is to save whether the reward has started, its remaining timing state, and its exhausted state with existing area progress. Freeze remaining time while the area is unloaded, then restore it without refilling. Death follows the existing reset-progress policy. Preserve an unstarted state separately from expired-but-awaiting-final-hit. These rules are implemented; see the linked walkthrough.

## Evidence limits and next verification

The interval-range calculation was checked with a small arithmetic script. No Godot tests were needed because gameplay code was not edited. No running Mesen process was found during this pass; no ROM playback, memory watch, or frame capture was performed. Source findings are not a claim of observed Mesen parity.

For a later Mesen check, watch $079d (BrickCoinTimer), $06bc (start flag), and $077f (interval phase). Capture first hit, repeated hits without renewal, pause, expiry without a hit, and the final coin/used-block hit. A modified fixture with two nearby multi-coin blocks would be needed to directly compare the shared-timer edge case. Area-revisit and death behavior also remain unverified in the emulator; the implemented persistence behavior above follows this project's existing policy rather than claiming an NES match.
