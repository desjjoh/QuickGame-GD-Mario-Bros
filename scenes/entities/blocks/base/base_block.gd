class_name BaseBlock
extends BaseEntity
## Solid grid-aligned block. Its origin is the tile's top-left corner.
## Concrete block scenes supply presentation; interactive reactions come later.

@onready var body: StaticBody2D = $Body
