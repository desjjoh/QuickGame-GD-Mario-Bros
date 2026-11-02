class_name BaseBlock
extends BaseEntity
## Solid grid-aligned block. Its origin is the tile's top-left corner.
## Concrete block scenes supply presentation and optional hit-reactive states.

@onready var body: StaticBody2D = $Body

@onready var bounce: BlockBounce = $Presentation/Bounce


func receive_hit(hit: EntityHit) -> bool:
	if is_shutdown or not state_machine.current_state is EntityState:
		return false
	return (state_machine.current_state as EntityState).receive_hit(hit)
