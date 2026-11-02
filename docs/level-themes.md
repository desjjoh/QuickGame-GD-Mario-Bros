# Level theme artwork

Environment artwork is organized by theme first:

```text
assets/
├── Overworld (Palette 1)/
│   ├── tileset/                 # ground.png, block.png
│   ├── enemies/
│   └── interactibles/blocks/    # brick and question-block sprites
├── Underground/
│   ├── tileset/
│   ├── enemies/
│   └── interactibles/
├── Castle/
│   ├── tileset/
│   ├── enemies/
│   └── interactibles/
├── tileset/                     # shared terrain.tres and entity_layout.tres
├── player/mario (small)/
└── sfx/
```

All existing environment sprites belong to Overworld (Palette 1). Underground, Castle, and the enemy artwork folders are currently empty; .gitkeep files preserve empty directories. No palette numbers are assigned to the unimplemented themes. Player artwork, sound effects, entity scenes, and shared TileSet resource locations are unchanged.

The terrain and entity-marker TileSets and block scenes/animation explicitly reference Overworld (Palette 1) artwork. This milestone only organizes assets: level-theme selection, alternate artwork, palette conversion, and automatic texture selection are not implemented.

Next discussion: decide how a level selects its theme and supplies terrain textures and entity animation frames while retaining shared behavior. Use matching relative asset names across themes when adding artwork; no runtime loading or fallback convention is implemented yet.

Each environment theme also has a decorations/ folder. Current Overworld (Palette 1)/decorations contains bush-left.png, bush.png, and bush-right.png. The shared assets/tileset/decorations.tres references these sprites for direct TileMap painting; Underground/Castle decorations folders are placeholders.

