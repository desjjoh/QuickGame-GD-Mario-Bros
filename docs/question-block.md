# Animated question block

QuestionBlock inherits BaseBlock and uses its 16-by-16 solid body, top-left origin, shadow participation, and entity shutdown. It adds an AnimationPlayer with an autoplay `active` animation; the inherited state machine remains empty. On/off states, rewards, used-block appearance, and physical block bounce are not implemented. Mario's existing solid-ceiling collision produces the bump response.

Open scenes/entities/blocks/question/question_block.tscn and select AnimationPlayer to inspect `active`. The external animations/active.tres resource uses a discrete Sprite2D:texture track, leaving physics untouched. The three supplied assets are question-block.png (bright), question-block-2.png (medium), and question-block-3.png (dark), under assets/Overworld (Palette 1)/interactibles/blocks/.

The loop is bright for 24/60 seconds, medium for 8/60, dark for 8/60, then medium for 8/60: 0.8 seconds total. This follows SMB's ColorRotatePalette sequence ($27, $27, $27, $17, $07, $17), updated every eighth frame by ColorRotation. Reference: https://gist.github.com/1wErt3r/4048722 . We approximate its palette cycling with authored textures and physics-timed animation, without reproducing VRAM update delays or the global NES palette clock. Blocks spawned together start together; later spawns start their own phase.

EntityLayout's question marker uses source 1, custom entity_id `question_block`. TestLevel maps it to QuestionBlock and paints two examples at cells (4, 9) and (6, 9), retaining existing brick cells. Select EntityLayout and the question-block palette source to paint more.

Verification covers scene generation, phase durations, loop wrap, live playback, solid-body inheritance, and animation shutdown. Inspect the rendered game for visual preference.
