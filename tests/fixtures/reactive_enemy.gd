extends BaseEnemy
## Test-only reactions; no production health or shell system is introduced.

var reactions := 0
var nested_hit_accepted := false


func _accept_hit(hit: EntityHit) -> bool:
	match hit.maneuver:
		&"react", &"shell":
			reactions += 1
			nested_hit_accepted = receive_hit(hit)
			return true
		&"defeat":
			return mark_defeated(hit)
	return false
