## In-game developer console with command registration and help system.
##
## Supports commands with underscored names (e.g., physics_toggle) and allows
## users to look them up with spaces (e.g., "help physics toggle" finds "physics_toggle").
extends CanvasLayer
class_name DevConsole

signal command_executed(command_name: String, args: Array)

const CONSOLE_HEIGHT_RATIO := 0.4
const MAX_HISTORY := 50
const FONT_SIZE := 14

var _commands: Dictionary = {}  # command_name -> { callable, description, usage }
var _output_lines: PackedStringArray = PackedStringArray()
var _history: PackedStringArray = PackedStringArray()
var _history_index: int = -1
var _visible: bool = false

var _panel: Panel
var _output_label: RichTextLabel
var _input_field: LineEdit


func _ready() -> void:
	_build_ui()
	_register_builtin_commands()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:
		toggle()
		get_viewport().set_input_as_handled()


# ==========================================================================
# UI Construction
# ==========================================================================

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = CONSOLE_HEIGHT_RATIO
	_panel.visible = false
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 4.0
	vbox.offset_right = -4.0
	vbox.offset_top = 4.0
	vbox.offset_bottom = -4.0
	_panel.add_child(vbox)

	_output_label = RichTextLabel.new()
	_output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output_label.bbcode_enabled = true
	_output_label.scroll_following = true
	vbox.add_child(_output_label)

	_input_field = LineEdit.new()
	_input_field.placeholder_text = "Type 'help' for a list of commands"
	_input_field.text_submitted.connect(_on_input_submitted)
	vbox.add_child(_input_field)


# ==========================================================================
# Visibility
# ==========================================================================

func toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	visible = _visible
	if _visible:
		_input_field.grab_focus()
		_input_field.clear()


# ==========================================================================
# Command Registration
# ==========================================================================

## Register a command. [param name] should use underscores (e.g., "physics_toggle").
func register_command(name: String, callable: Callable, description: String = "", usage: String = "") -> void:
	_commands[name] = {
		"callable": callable,
		"description": description,
		"usage": usage,
	}


func unregister_command(name: String) -> void:
	_commands.erase(name)


# ==========================================================================
# Input Processing
# ==========================================================================

func _on_input_submitted(text: String) -> void:
	_input_field.clear()
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return

	_add_history(trimmed)
	_print_line("[color=gray]> " + trimmed + "[/color]")

	var parts := trimmed.split(" ", false)
	if parts.is_empty():
		return

	var cmd_name := parts[0].to_lower()
	var args: Array = []
	for i in range(1, parts.size()):
		args.append(parts[i])

	_execute(cmd_name, args)


func _execute(cmd_name: String, args: Array) -> void:
	if cmd_name == "help":
		_cmd_help(args)
		return

	if cmd_name == "commands":
		_cmd_list_commands()
		return

	if cmd_name == "clear":
		_cmd_clear()
		return

	# Try exact match first
	if _commands.has(cmd_name):
		_commands[cmd_name]["callable"].call(args)
		command_executed.emit(cmd_name, args)
		return

	# Try joining with underscores for multi-word commands
	# e.g., "physics toggle" -> "physics_toggle"
	var joined := cmd_name
	for arg in args:
		var candidate: String = joined + "_" + arg
		if _commands.has(candidate):
			var remaining_args: Array = args.slice(args.find(arg) + 1)
			_commands[candidate]["callable"].call(remaining_args)
			command_executed.emit(candidate, remaining_args)
			return
		joined = candidate

	_print_line("[color=red]Unknown command: '" + cmd_name + "'. Type 'commands' to list all commands.[/color]")


# ==========================================================================
# Help Command with Space Validation
# ==========================================================================

func _cmd_help(args: Array) -> void:
	if args.is_empty():
		_print_line("[color=yellow]AVAILABLE COMMANDS[/color]")
		_print_line("  [color=green]help[/color] [command]  - Show help for a command")
		_print_line("  [color=green]commands[/color]        - List all commands")
		_print_line("  [color=green]clear[/color]           - Clear console output")
		_print_line("")

		var names := _commands.keys()
		names.sort()
		for name in names:
			var desc: String = _commands[name]["description"]
			var padded := name + " " .repeat(max(1, 20 - name.length()))
			_print_line("  [color=green]" + name + "[/color]" + " ".repeat(max(1, 20 - name.length())) + desc)
		return

	# --- Space validation: join args with underscores and try to find a match ---
	var topic := _resolve_command_name(args)

	if topic.is_empty():
		var attempted := " ".join(args)
		_print_line("[color=red]help: no entry for '" + attempted + "'. Try 'commands' to list all commands.[/color]")
		_print_suggestion(attempted)
		return

	var entry: Dictionary = _commands[topic]
	_print_line("[color=yellow]" + topic.to_upper().replace("_", " ") + "[/color]")
	if not entry["description"].is_empty():
		_print_line("  " + entry["description"])
	if not entry["usage"].is_empty():
		_print_line("  [color=cyan]Usage:[/color] " + entry["usage"])


## Resolve a help topic from arguments, handling spaces in place of underscores.
## Returns the matched command name, or empty string if not found.
func _resolve_command_name(args: Array) -> String:
	# 1. Try joining all args with underscore: "physics toggle" -> "physics_toggle"
	var joined_all := "_".join(args).to_lower()
	if _commands.has(joined_all):
		return joined_all

	# 2. Try the first arg as-is (already underscored): "physics_toggle"
	var first := args[0].to_lower()
	if _commands.has(first):
		return first

	# 3. Try progressively joining args to find longest match
	#    e.g., args = ["dvd", "color", "reset"] tries "dvd", "dvd_color", "dvd_color_reset"
	var candidate := ""
	for i in args.size():
		if candidate.is_empty():
			candidate = args[i].to_lower()
		else:
			candidate += "_" + args[i].to_lower()
		if _commands.has(candidate):
			return candidate

	# 4. Case-insensitive search across all commands
	for name in _commands.keys():
		if name.to_lower() == joined_all:
			return name

	return ""


## Print suggestions for misspelled or close command names.
func _print_suggestion(attempted: String) -> void:
	var underscore_version := attempted.replace(" ", "_").to_lower()
	var suggestions: Array = []

	for name in _commands.keys():
		# Check if the command contains the attempted string
		if name.to_lower().contains(attempted.to_lower()) or name.to_lower().contains(underscore_version):
			suggestions.append(name)
		# Check if attempted string is a prefix
		elif name.to_lower().begins_with(underscore_version.split("_")[0]):
			suggestions.append(name)

	if not suggestions.is_empty():
		suggestions.sort()
		_print_line("[color=cyan]Did you mean: " + ", ".join(suggestions) + "?[/color]")


# ==========================================================================
# Built-in Commands
# ==========================================================================

func _register_builtin_commands() -> void:
	# Built-in commands (help, commands, clear) are handled directly in _execute
	pass


func _cmd_list_commands() -> void:
	_print_line("[color=yellow]ALL COMMANDS[/color]")
	var names := _commands.keys()
	names.sort()
	for name in names:
		var desc: String = _commands[name]["description"]
		_print_line("  [color=green]" + name + "[/color]  " + desc)

	_print_line("")
	_print_line("Type [color=green]help <command>[/color] to see details. Spaces and underscores are interchangeable.")


func _cmd_clear() -> void:
	_output_lines.clear()
	_output_label.clear()


# ==========================================================================
# Output
# ==========================================================================

func print_line(text: String) -> void:
	_print_line(text)


func _print_line(text: String) -> void:
	_output_lines.append(text)
	if _output_lines.size() > 200:
		_output_lines = _output_lines.slice(_output_lines.size() - 200)
	_output_label.append_text(text + "\n")


# ==========================================================================
# History
# ==========================================================================

func _add_history(text: String) -> void:
	if _history.is_empty() or _history[_history.size() - 1] != text:
		_history.append(text)
	if _history.size() > MAX_HISTORY:
		_history = _history.slice(_history.size() - MAX_HISTORY)
	_history_index = -1
