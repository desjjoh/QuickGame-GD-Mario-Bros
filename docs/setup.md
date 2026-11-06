# Setup

## Run the project

1. Open `project.godot` in Godot 4.7. Local regression runs use Godot 4.7.2.
2. Press **F5** to run the game from the title screen.
3. Press **Enter** or controller **Start** to load 1-1.

Open `scenes/levels/test_level.tscn` and press **F6** to run the one-screen sandbox. The same scene serves as the title backdrop with gameplay disabled.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | Left and Right arrows | D-pad |
| Jump | Space | A / bottom face button |
| Run | Left Shift | X / left face button |
| Enter a vertical pipe | Down | D-pad Down |
| Start | Enter | Start / Menu |

Hold Jump for a higher jump. Press the opposite direction while moving to skid. Sideways pipe entrances activate when you walk into their opening.

## Edit a level

Open `scenes/levels/worlds/world 1/1-1.tscn`. Expand **Areas → MainArea → Layouts**. Use **GroundLayout** for solid terrain, **DecorationLayout** for scenery, and **EntityLayout** for entity stamps. Each layer uses the same 16×16 grid. Keep nested areas editable so scene overrides survive saving.

Paint a pipe stamp, then configure its destination on the area. To test area switching, enter the vertical pipe in 1-1 and walk into the sideways pipe in the secret area. See [configuration](configuration.md#areas-and-pipe-routes).
