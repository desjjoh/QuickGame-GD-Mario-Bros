class_name SoundEffectMix
extends Resource
## Shared non-destructive gain trims; durations, pitch and timing stay intact.
@export var master_volume_db: float = -3.0
@export var stream_volume_db: Dictionary[String, float] = {}
const SOURCE_PATH = &"sound_mix_source_path"

func volume_for(sound: AudioStream) -> float:
 if sound == null: return master_volume_db
 var path := String(sound.get_meta(SOURCE_PATH, sound.resource_path))
 return master_volume_db + stream_volume_db.get(path, 0.0)

static func one_shot_copy(sound: AudioStream) -> AudioStream:
 if sound == null: return null
 var copy := sound.duplicate() as AudioStream
 copy.set_meta(SOURCE_PATH, sound.get_meta(SOURCE_PATH, sound.resource_path))
 if copy is AudioStreamWAV: copy.loop_mode = AudioStreamWAV.LOOP_DISABLED
 elif copy is AudioStreamMP3 or copy is AudioStreamOggVorbis: copy.loop = false
 return copy
