# Timed coin rewards

## Painting and reward data

Select EntityLayout, choose **Apply Timed Coins Reward**, and click a question block, hidden question block, Reward Brick, or Reward Brick Alt. The always-visible translucent stack distinguishes timed coins from the single-coin icon. It does not indicate a fixed coin count. Apply Coin Reward clears the override; Apply 1-Up Reward replaces it with a power-up. Undo/redo restores the complete prior reward dictionary. Clear overrides before moving, erasing, or replacing markers, as with existing rewards.

BaseLevelArea retains the existing question_block_rewards property, now Dictionary[Vector2i, Resource]. BlockReward supplies Coin, Timed Coins, and Power-Up configuration. A missing entry defaults to Coin. Existing PackedScene values still resolve as power-up rewards, preserving authored 1-Ups. New brush assignments use embedded BlockReward resources. The block copies configuration into its live reward fields; mutable countdown state never belongs to a shared resource. The authored 1-1 dictionary's value type was updated to Resource without changing its assignments.

## Hit and countdown lifecycle

The first accepted bounce releases one coin and starts 231 physics ticks. The start tick itself is not decremented. Later accepted hits release one coin without restarting the countdown. The reward uses the existing GameHandler.award_coin path, block-coin visual, score popup, sound, and 100-coin extra life.

While time remains, Bouncing preserves the current texture and returns to Active. Animated question blocks hold their current frame during the bounce, then rejoin the current global animation phase on returning to Active. The final reward switches to the depleted texture before its bounce and keeps that texture afterward. Expiry alone leaves the block available. The next accepted hit awards the final coin and selects Inactive as the bounce result. The return state is decided synchronously on bounce entry before publishing the reward. Expiring midway through a previous bounce does not retroactively exhaust it. A per-bounce claim guard prevents duplicate reward signals from crediting another coin.

Hidden timed blocks become solid on first hit, disable their bonk probe, and return to a visible static question texture while coins remain. Their original outline is not restored after each bounce or reload. Both reward-brick variants return to their respective static brick texture until exhausted.

## Timer ownership and persistence

QuestionBlock owns reward_started and reward_ticks_remaining. BaseLevel keeps weak registrations and advances them during normal level processing, before pipe motion. Camera activity suspension does not stop a loaded block's timer. Death, completion, and transition suspension stop level reward advancement; tree pause freezes it automatically. Area unloading removes the runtime blocks and saves their logical return state plus countdown. Time does not elapse in an unloaded area.

Restoration distinguishes unstarted (false/0), running (true/positive), expired awaiting final hit (true/0 with Active), and exhausted (Inactive). Saving during a bounce stores its logical destination rather than replaying the coin event. Existing progress-reset behavior controls death/recreation: preserved progress retains the timer and exhaustion; reset progress restores a fresh block. No disk save system is introduced.

## Known version differences

Approved on 2026-11-07: every block has an independent fixed 231-tick window. The NES uses a shared timer/start flag and a shared 21-frame decrement phase, yielding roughly 211-231 eligible frames. Loading another multi-coin block can reset the NES start flag; our blocks cannot alter each other's windows. Timed rewards on normal and hidden question blocks are also an intentional extension. See [source investigation](timed-coin-research.md).

## Verification

timed_coin_test reached PASS in Godot 4.7.2 headless at a real-time 60 FPS cap. It exercises serialized reward configuration, all four block appearances, 231-tick timing, staggered independent starts, repeated hits without renewal, duplicate-signal protection, final awards, 100-coin extra lives, pause, activity suspension, expiry during a bounce, area unload/restore, and preserve/reset recreation. Existing question-block, reward-brick, death, and pause regressions also reached PASS. The final expanded timed-coin run reported five ObjectDB leaks. Question-block and pause reported two each, death three, and bonk-contact four. Bonk-contact, 1-Up, and area-theme checks also reached PASS. No full suite or rendered reward-brush/undo playtest was performed.
