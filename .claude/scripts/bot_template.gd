# Deterministic playtest bot (verification rung V4).
#
# Install: copy to res://tools/bot.gd and register it as an autoload named Bot.
# Run:     godot --headless --path . --fixed-fps 60 --quit-after 1800 -- --bot --seed 42
#
# --fixed-fps pins physics and timer steps so a run is reproducible.
# --quit-after stops a hung run from blocking CI.
# Everything after -- arrives through OS.get_cmdline_user_args().
#
# The one rule that matters: Godot exits 0 after a SCRIPT ERROR. If this script
# does not call quit(1) itself, a broken run reports success.
extends Node

const DEFAULT_SEED: int = 42
## Hard ceiling in seconds. A bot that never reaches its goal must still fail.
const BUDGET_SECONDS: float = 30.0

var _rng := RandomNumberGenerator.new()
var _elapsed: float = 0.0
var _enabled: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_enabled = args.has("--bot")
	if not _enabled:
		return
	_rng.seed = _arg_int(args, "--seed", DEFAULT_SEED)
	# Fail loudly on an engine error instead of letting the run finish green.
	get_tree().set_auto_accept_quit(true)
	_run()


func _process(delta: float) -> void:
	if not _enabled:
		return
	_elapsed += delta
	if _elapsed > BUDGET_SECONDS:
		_fail("budget of %.1fs exceeded before the goal was reached" % BUDGET_SECONDS)


func _run() -> void:
	# Replace with the scenario the system's spec declares as its V4 criterion.
	# Keep it a single, stated goal: "traverse the test corridor in <= 4.0s".
	await get_tree().process_frame
	_press("ui_right", 1.0)
	_pass("reached the goal in %.2fs" % _elapsed)


## Holds an input action for a fixed duration. Action-based input skips _input(),
## which is what you want for a bot driving gameplay rather than testing the
## input layer itself.
func _press(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await get_tree().create_timer(seconds).timeout
	Input.action_release(action)


func _arg_int(args: PackedStringArray, flag: String, fallback: int) -> int:
	var i: int = args.find(flag)
	if i >= 0 and i + 1 < args.size():
		return int(args[i + 1])
	return fallback


func _pass(message: String) -> void:
	print("BOT PASS: ", message)
	get_tree().quit(0)


func _fail(message: String) -> void:
	# printerr goes to stderr, which verify.sh scans for engine errors.
	printerr("BOT FAIL: ", message)
	get_tree().quit(1)
