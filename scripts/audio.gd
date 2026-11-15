class_name GameAudio
extends Node
## Plays sound effects and background music. Main adds one instance; everything else uses
## the static helpers (GameAudio.play("build"), GameAudio.set_music("boss")), which do
## nothing when no instance exists (e.g. unit tests that build towers without a Main). Every sound is generated
## by tools/gen_audio.py into res://audio (no external assets).
##
## Sound effects use a small pool of players per sound and are throttled, so fifty towers
## firing at once never stack into noise. Music crossfades between the calm main loop and
## the boss loop. Music and effects can be switched off separately; the choice is saved.

const SFX: Dictionary = {
	# name: [volume_db, voices, min_gap_seconds, pitch_jitter]
	"shot_basic": [-17.0, 4, 0.05, 0.08],
	"shot_tesla": [-16.0, 3, 0.07, 0.06],
	"shot_cannon": [-12.0, 3, 0.09, 0.06],
	"enemy_die": [-14.0, 4, 0.04, 0.12],
	"boss_die": [-4.0, 1, 0.5, 0.0],
	"escape": [-8.0, 2, 0.15, 0.0],
	"wave_start": [-9.0, 1, 0.3, 0.0],
	"wave_clear": [-8.0, 1, 0.3, 0.0],
	"boss_spawn": [-5.0, 1, 0.5, 0.0],
	"build": [-8.0, 2, 0.05, 0.05],
	"upgrade": [-8.0, 2, 0.05, 0.0],
	"sell": [-9.0, 2, 0.05, 0.0],
	"click": [-14.0, 2, 0.03, 0.0],
	"error": [-12.0, 1, 0.15, 0.0],
	"unlock": [-7.0, 1, 0.1, 0.0],
	"defeat": [-6.0, 1, 0.5, 0.0],
}
const MUSIC: Dictionary = {"main": "res://audio/music_main.wav", "boss": "res://audio/music_boss.wav"}
const MUSIC_DB: float = -13.0
const SILENT_DB: float = -60.0
const FADE_SECONDS: float = 1.2

static var instance: GameAudio = null

var sfx_enabled: bool = true
var music_enabled: bool = true
## Number of play() calls that produced a sound, per name (used by tests).
var play_counts: Dictionary = {}

var _players: Dictionary = {}  # name -> Array[AudioStreamPlayer]
var _last_played: Dictionary = {}  # name -> seconds
var _music_players: Dictionary = {}  # track -> AudioStreamPlayer
var _music_track: String = ""
var _clock: float = 0.0
## No one can hear a headless run (tests, servers), and its dummy driver never mixes, so
## nothing is actually played there (sound effects are still counted).
var _headless: bool = DisplayServer.get_name() == "headless"


static func play(sound_name: String, pitch: float = 1.0) -> bool:
	return instance != null and instance.play_sound(sound_name, pitch)


static func set_music(track: String) -> void:
	if instance != null:
		instance._music_track = track


static func current_music() -> String:
	return instance._music_track if instance != null else ""


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # music and UI sounds keep going while paused
	for sound_name: String in SFX:
		var stream: AudioStream = load("res://audio/%s.wav" % sound_name)
		var pool: Array[AudioStreamPlayer] = []
		for i in int(SFX[sound_name][1]):
			var player: AudioStreamPlayer = AudioStreamPlayer.new()
			player.stream = stream
			player.volume_db = SFX[sound_name][0]
			add_child(player)
			pool.append(player)
		_players[sound_name] = pool
	for track: String in MUSIC:
		var music: AudioStreamWAV = load(MUSIC[track]) as AudioStreamWAV
		if music != null:
			music = music.duplicate() as AudioStreamWAV
			music.loop_mode = AudioStreamWAV.LOOP_FORWARD
			music.loop_begin = 0
			music.loop_end = int(music.get_length() * music.mix_rate)
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = music
		player.volume_db = SILENT_DB
		add_child(player)
		_music_players[track] = player
	var settings: Dictionary = ProgressStore.load_settings()
	sfx_enabled = settings["sfx"]
	music_enabled = settings["music"]


func _exit_tree() -> void:
	if instance == self:
		instance = null
	# Stop playbacks before shutdown so none outlive their streams.
	for player: Node in get_children():
		(player as AudioStreamPlayer).stop()
		player.stream = null


func _process(delta: float) -> void:
	_clock += delta
	# Crossfade: the current track rises to MUSIC_DB, the others fade out and stop.
	var step: float = (MUSIC_DB - SILENT_DB) * delta / FADE_SECONDS
	for track: String in _music_players:
		var player: AudioStreamPlayer = _music_players[track]
		var wanted: bool = music_enabled and track == _music_track and not _headless
		if wanted:
			if not player.playing:
				player.play()
			player.volume_db = move_toward(player.volume_db, MUSIC_DB, step)
		elif player.playing:
			player.volume_db = move_toward(player.volume_db, SILENT_DB, step)
			if player.volume_db <= SILENT_DB + 0.01:
				player.stop()


## Plays a sound effect by name. Returns true if it actually played (not muted/throttled).
func play_sound(sound_name: String, pitch: float = 1.0) -> bool:
	if not sfx_enabled or not _players.has(sound_name):
		return false
	var def: Array = SFX[sound_name]
	if _clock - float(_last_played.get(sound_name, -100.0)) < float(def[2]):
		return false
	var chosen: AudioStreamPlayer = null
	for player: AudioStreamPlayer in _players[sound_name]:
		if not player.playing:
			chosen = player
			break
	if chosen == null:
		return false  # every voice busy: skip rather than cut one off
	_last_played[sound_name] = _clock
	play_counts[sound_name] = int(play_counts.get(sound_name, 0)) + 1
	if _headless:
		return true  # counted (tests check it) but nothing to hear or mix
	var jitter: float = float(def[3])
	chosen.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	chosen.play()
	return true


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	if not enabled:
		for sound_name: String in _players:
			for player: AudioStreamPlayer in _players[sound_name]:
				player.stop()
	_save()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	_save()


func _save() -> void:
	ProgressStore.save_settings({"sfx": sfx_enabled, "music": music_enabled})
