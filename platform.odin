package pohja

import "core:log"
import "base:runtime"
import "core:mem"

when ODIN_OS == .Darwin {
	DEFAULT_PLATFORM_API :: DARWIN_PLATFORM_API
} else when ODIN_OS == .Windows {
	DEFAULT_PLATFORM_API :: nil
}

PLATFORM_API :: DEFAULT_PLATFORM_API

@(private="package")
platform: Platform

Platform :: struct {

	platform_arena: mem.Arena,

	is_active: bool,
	registry: ^Window_Registry,

	window_states: []byte,
	state_size: int,
	max_windows: int,
	ctx: runtime.Context,
	frame_allocator: runtime.Allocator,

	keys_press_started: #sparse [Input_Keyboard_Key]bool,
	keys_held: #sparse [Input_Keyboard_Key]bool,
	keys_released: #sparse [Input_Keyboard_Key]bool,

	mouse_press_started: #sparse [Input_Mouse_Button]bool,
	mouse_held: #sparse [Input_Mouse_Button]bool,
	mouse_released: #sparse [Input_Mouse_Button]bool,

	mouse_position: [2]f32,
	mouse_move_delta: [2]f32,
	mouse_scroll_delta: [2]f32,

	events: [MAX_INPUT_EVENTS_PER_FRAME]Input_Event,
	event_count: int,

	shutdown_requested: bool,
}

// Callback type for per-frame updates. The user_data is passed through from the platform.
FrameCallback :: proc(user_data: rawptr)

// Initializes the platform. Call before any other platform procedures.
init :: proc(max_windows: int = 1) {
	assert(max_windows >= 1, "Need at least 1 window!")

	platform.ctx = context

	backing := make([]byte, mem.Kilobyte)
	mem.arena_init(&platform.platform_arena, backing)
	arena_allocator := mem.arena_allocator(&platform.platform_arena)

	state_size := PLATFORM_API.window_state_size()
	platform.window_states = make([]byte, state_size * max_windows, arena_allocator)
	platform.state_size = state_size
	platform.max_windows = max_windows

	platform.registry = new(Window_Registry, arena_allocator)
	platform.registry^ = Window_Registry {
		handle_to_id = make(map[Window_Handle]Window_ID, arena_allocator),
		id_to_handle = make(map[Window_ID]Window_Handle, arena_allocator),
	}

	platform.frame_allocator = context.temp_allocator
}

Window_Registry :: struct {
	handle_to_id: map[Window_Handle]Window_ID,
	id_to_handle: map[Window_ID]Window_Handle,
}

// Creates a new window and returns its ID.
open_window :: proc(desc: Window_Description) -> Window_ID {
	return PLATFORM_API.window_open(desc)
}

// Register window to the platform
register_window :: proc(window: Window_Handle, id: Window_ID) {
	platform.registry.handle_to_id[window] = id
	platform.registry.id_to_handle[id] = window
}

// Window_ID from Window_Handle
lookup_window_id :: proc(window: Window_Handle) -> (Window_ID, bool) {
	return platform.registry.handle_to_id[window]
}

// Closes the window with the given ID.
close_window :: proc(id: Window_ID) {
	assert(int(id) < platform.max_windows && int(id) >= 0, "Invalid WindowID")
	PLATFORM_API.window_close(id)
}

// Signals the platform to exit the main loop after the current frame.
application_request_shutdown :: #force_inline proc() {
	platform.shutdown_requested = true
}

// Sets a callback to be invoked each frame. External libraries (e.g., renderers)
// can use this to hook into the platform's main loop.
set_frame_callback :: proc(id: Window_ID, callback: FrameCallback, user_data: rawptr) {
	header := cast(^Window_State_Header)get_state_from_id(id)
	header.frame_callback = callback
	header.user_data = user_data
}

// Changes the window title.
set_window_title :: proc(id: Window_ID, title: string) {
	header := cast(^Window_State_Header)get_state_from_id(id)
	header.title = title
	PLATFORM_API.set_window_title(id, title)
}

// Shows or hides the window.
set_window_visible :: proc(id: Window_ID, visible: bool) {
	header := cast(^Window_State_Header)get_state_from_id(id)
	header.is_visible = visible
	PLATFORM_API.set_window_visible(id, visible)
}

// Sets the window display mode (windowed, maximized, fullscreen, etc.)
set_window_mode :: proc(id: Window_ID, mode: Window_Display_Mode) {
	header := cast(^Window_State_Header)get_state_from_id(id)
	header.window_mode = mode
	PLATFORM_API.set_window_mode(id, mode)
}

// Brings the window to front and gives it input focus.
focus_window :: proc(id: Window_ID) {
	PLATFORM_API.focus_window(id)
}

// Returns the native window handle for use with external libraries.
get_native_window_handle :: proc(id: Window_ID) -> Window_Handle {
	return PLATFORM_API.get_native_window_handle(id)
}

// Releases all platform resources.
cleanup :: proc() {
	for i := platform.max_windows - 1; i >= 0; i -= 1 {
		header := cast(^Window_State_Header)get_state_from_id(Window_ID(i))
        
		if !header.is_alive {
			continue
        }
		PLATFORM_API.window_close(Window_ID(i))
    }

	delete(platform.platform_arena.data)
}

platform_should_close :: proc() -> bool {
	return platform.shutdown_requested
}

platform_update :: proc() {
	free_all(platform.frame_allocator)

	input_reset_state()
	PLATFORM_API.process_events()
	defer platform.event_count = 0

	// Update windows
	window_close_requested := make(map[Window_ID]bool, allocator=platform.frame_allocator)
	for i in 0..<platform.max_windows {
		header := cast(^Window_State_Header)get_state_from_id(Window_ID(i))

		if !header.is_alive {
			continue
		}

		if header.close_requested {
			window_close_requested[Window_ID(i)] = true
		}
	
		if header.frame_callback != nil {
			header.frame_callback(header.user_data)
		}
	}

	// Close windows that requested shutdown
	for id, state in window_close_requested {
		header := cast(^Window_State_Header)get_state_from_id(id)

		if .MainWindow in header.flags {
			application_request_shutdown()
		}

		PLATFORM_API.window_close(id)
		header.close_requested = false
	}
}

Platform_API :: struct {
	window_state_size: proc() -> int,

	window_open:  proc(desc: Window_Description) -> Window_ID,
	window_close: proc(id: Window_ID),
	
	get_native_window_handle: proc(id: Window_ID) -> Window_Handle,
	
	set_window_position: proc(id: Window_ID, x, y: int),
	set_window_size: proc(id: Window_ID, w, h: int),
	set_window_title: proc(id: Window_ID, title: string),
	set_window_visible: proc(id: Window_ID, visible: bool),
	set_window_minimized: proc(id: Window_ID, minimized: bool),
	set_window_mode: proc(id: Window_ID, mode: Window_Display_Mode),
	focus_window: proc(id: Window_ID),

	process_events: proc(),

	get_window_size: proc(id: Window_ID) -> [2]int,
	get_window_width: proc(id: Window_ID) -> int,
	get_window_height: proc(id: Window_ID) -> int,
}

Window_ID :: distinct u32
Window_Handle :: distinct uintptr

Window_Display_Mode :: enum {
	Windowed,
	Fullscreen,
	BorderlessFullscreen,
}

Window_Description :: struct {
	x: int,
	y: int,
	width: int,
	height: int,
	title: string,
	flags: Window_Flags,

	// Size constraints (0 = no constraint)
	min_width: int,
	min_height: int,
	max_width: int,
	max_height: int,

	// Aspect ratio constraint (0 = no constraint). Expressed as width/height ratio.
	aspect_ratio: f32,
}

Window_Flags :: bit_set[Window_Flag]
Window_Flag :: enum {
	MainWindow,      // Closing this window shuts down the application
	CenterOnOpen,    // Center window on screen when opened
	Resizable,       // Window can be resized by user
	Decorated,       // Window has title bar and borders
	Visible,         // Window is visible on open
	Focused,         // Window is focused on open
	Maximized,       // Window is maximized on open
	AlwaysOnTop,     // Window stays above other windows
}

Window_State_Header :: struct {
	id: Window_ID,
	is_alive: bool,
	close_requested: bool,
	
	title: string,
	
	width: int,
	height: int,
	x: int,
	y: int,

	is_visible: bool,
	is_focused: bool,
	is_minimized: bool,
	window_mode: Window_Display_Mode,
	flags: Window_Flags,
	
	// User-provided callback invoked each frame. External libraries
	// can set this to hook into the platform's main loop.
	frame_callback: FrameCallback,
	user_data: rawptr,
}

// Returns true if the window state is currently in use.
is_state_alive :: proc(state: rawptr) -> bool {
	header := cast(^Window_State_Header)state
	return header.is_alive
}

// Returns the first alive window state and its ID. Panics if none exist.
get_first_alive_state :: proc() -> (state: rawptr, id: Window_ID) {
	for i in 0..<platform.max_windows {
		state_ptr := get_state_from_id(Window_ID(i))
		if is_state_alive(state_ptr) {
			return state_ptr, Window_ID(i)
        }
    }
	log.panic("All window states are dead!")
}

// Returns an unused window state slot and its ID. Panics if all slots are in use.
get_free_state :: proc() -> (state: rawptr, id: Window_ID) {
	for i in 0..<platform.max_windows {
		state_ptr := get_state_from_id(Window_ID(i))
		if !is_state_alive(state_ptr) {
			return state_ptr, Window_ID(i)
        }
    }
	log.panic("All window states are in use!")
}

// Returns the window state for the given ID.
get_state_from_id :: proc(id: Window_ID) -> rawptr {
	assert(int(id) < platform.max_windows && int(id) >= 0, "Invalid WindowID")
    
	offset := platform.state_size * int(id)
	return raw_data(platform.window_states[offset:])
}

/////////////////////////////////////////////////////

// Reset input state for a frame.
input_reset_state :: proc() {
	platform.keys_press_started = {}
	platform.keys_released = {}
	
	platform.mouse_press_started = {}
	platform.mouse_released = {}
	
	platform.mouse_scroll_delta = {}
	platform.mouse_move_delta = {}
}

// Returns true if the key was pressed this frame.
input_key_went_down :: proc "contextless" (key: Input_Keyboard_Key) -> bool {
	return platform.keys_press_started[key]
}

// Returns true if the key was released this frame.
input_key_went_up :: proc "contextless" (key: Input_Keyboard_Key) -> bool {
	return platform.keys_released[key]
}

// Returns true if the key is currently held down.
input_key_is_held :: proc "contextless" (key: Input_Keyboard_Key) -> bool {
	return platform.keys_held[key]
}

// Returns true if the mouse button was pressed this frame.
input_mouse_button_went_down :: proc "contextless" (button: Input_Mouse_Button) -> bool {
	return platform.mouse_press_started[button]
}

// Returns true if the mouse button was released this frame.
input_mouse_button_went_up :: proc "contextless" (button: Input_Mouse_Button) -> bool {
	return platform.mouse_released[button]
}

// Returns true if the mouse button is currently held down.
input_mouse_button_is_held :: proc "contextless" (button: Input_Mouse_Button) -> bool {
	return platform.mouse_held[button]
}

// Returns the scroll delta magnitude for the given direction this frame.
input_scroll_magnitude :: proc "contextless" (direction: Input_Scroll_Direction) -> f32 {
	if direction == .X {
		return f32(platform.mouse_scroll_delta.x)
	} else if direction == .Y {
		return f32(platform.mouse_scroll_delta.y)
	} else {
		return f32(platform.mouse_scroll_delta.x) + f32(platform.mouse_scroll_delta.y)
	}
}

// Returns the scroll delta as a 2D vector for the given direction this frame.
input_scroll_vector :: proc "contextless" (direction: Input_Scroll_Direction) -> [2]f32 {
	if direction == .X {
		return {1, 0} * f32(platform.mouse_scroll_delta.x)
	} else if direction == .Y {
		return {0, 1} * f32(platform.mouse_scroll_delta.y)
	} else {
		return {f32(platform.mouse_scroll_delta.x), f32(platform.mouse_scroll_delta.y)}
	}	
}

// Returns the current mouse position.
input_mouse_position :: proc "contextless" () -> [2]f32 {
	return {f32(platform.mouse_position.x), f32(platform.mouse_position.y)}
}

// Returns the mouse movement delta magnitude for the given direction this frame.
input_mouse_delta :: proc "contextless" (direction: Input_Scroll_Direction) -> f32 {
	if direction == .X {
		return f32(platform.mouse_move_delta.x)
	} else if direction == .Y {
		return f32(platform.mouse_move_delta.y)
	} else {
		return f32(platform.mouse_move_delta.x) + f32(platform.mouse_move_delta.y)
	}	
}

// Returns the mouse movement delta as a 2D vector for the given direction this frame.
input_mouse_delta_vector :: proc "contextless" (direction: Input_Scroll_Direction) -> [2]f32 {
	if direction == .X {
		return {1, 0} * f32(platform.mouse_move_delta.x)
	} else if direction == .Y {
		return {0, 1} * f32(platform.mouse_move_delta.y)
	} else {
		return {f32(platform.mouse_move_delta.x), f32(platform.mouse_move_delta.y)}
	}
}

Input_Scroll_Direction :: enum {
	X,
	Y,
	Both,
}

MAX_INPUT_EVENTS_PER_FRAME :: 128

// Pushes a new event to the event queue. Used internally by platform backends.
Input_Event :: union {
	Key_Pressed_Event,
	Key_Released_Event,

	Mouse_Pressed_Event,
	Mouse_Released_Event,
	Mouse_Position_Event,
	Mouse_Scroll_Event,
}

Key_Pressed_Event    :: struct { key: Input_Keyboard_Key }
Key_Released_Event   :: struct { key: Input_Keyboard_Key }
Mouse_Pressed_Event  :: struct { button: Input_Mouse_Button }
Mouse_Released_Event :: struct { button: Input_Mouse_Button }
Mouse_Position_Event :: struct { x, y: f64 }
Mouse_Scroll_Event   :: struct { x, y: f64 }

emit_input_event :: proc "contextless" (event: Input_Event) {
	if platform.event_count == MAX_INPUT_EVENTS_PER_FRAME - 1 {
		return
	}

	platform.events[platform.event_count] = event
	platform.event_count += 1

	switch e in event {

		case Key_Pressed_Event:
			platform.keys_press_started[e.key] = platform.keys_held[e.key] ~ true
			platform.keys_held[e.key] = true
		case Key_Released_Event:
			platform.keys_released[e.key] = true
			platform.keys_held[e.key] = false
			
		case Mouse_Pressed_Event:
			platform.mouse_press_started[e.button] = platform.mouse_held[e.button] ~ true
			platform.mouse_held[e.button] = true
		case Mouse_Released_Event:
			platform.mouse_released[e.button] = true
			platform.mouse_held[e.button] = false

		case Mouse_Position_Event:
			platform.mouse_move_delta = {f32(e.x) - platform.mouse_position.x, f32(e.y) - platform.mouse_position.y}
			platform.mouse_position = {f32(e.x), f32(e.y)}
		
		case Mouse_Scroll_Event:
			platform.mouse_scroll_delta = {f32(e.x), f32(e.y)}
	}
}

Platform_Event :: enum {
	DidBecomeActive,
	DidResignActive,
	ShouldTerminate,
	TerminateAfterLastWindowClosed,
	DidHide,
	DidUnhide,
}

Platform_Event_Reply :: union {
	bool,
}

emit_platform_event :: proc(event: Platform_Event) -> (reply: Platform_Event_Reply) {
	switch event {
		case .DidBecomeActive:
			platform.is_active = true
		case .DidResignActive:
			platform.is_active = false
		case .ShouldTerminate:
			platform.shutdown_requested = true
			return false
		case .TerminateAfterLastWindowClosed:
			return true
		case .DidHide:
		case .DidUnhide:
	}

	return
}

Window_Event :: union {
	Window_Did_Change_Occlusion_State,
	Window_Should_Close,
	Window_Did_Resize,
	Window_Did_Move,
	Window_Change_Key_State,
	Window_Change_Miniaturize_State,
	Window_Change_Full_Screen_State,
}

Window_Did_Change_Occlusion_State :: struct { sender: Window_ID, state: bool }
Window_Should_Close               :: struct { sender: Window_ID }
Window_Did_Resize                 :: struct { sender: Window_ID, size: [2]int }
Window_Did_Move                   :: struct { sender: Window_ID, position: [2]int }
Window_Change_Key_State           :: struct { sender: Window_ID, state: bool }
Window_Change_Miniaturize_State   :: struct { sender: Window_ID, state: bool }
Window_Change_Full_Screen_State   :: struct { sender: Window_ID, state: bool }

emit_window_event :: proc(event: Window_Event) {
	switch e in event {
		case Window_Did_Change_Occlusion_State:
			state := cast(^Window_State_Header)get_state_from_id(e.sender)
			state.is_visible = e.state
		case Window_Should_Close:
			state := cast(^Window_State_Header)get_state_from_id(e.sender)
			state.close_requested = true
		case Window_Did_Resize:
			state := cast(^Window_State_Header)get_state_from_id(e.sender)
			state.width = e.size.x
			state.height = e.size.y
		case Window_Did_Move:
			state := cast(^Window_State_Header)get_state_from_id(e.sender)
			state.x = e.position.x
			state.y = e.position.y
		case Window_Change_Key_State:
			state := cast(^Window_State_Header)get_state_from_id(e.sender)
			state.is_focused = e.state
		case Window_Change_Miniaturize_State:
			state := cast(^Window_State_Header)get_state_from_id(e.sender)
			state.is_minimized = e.state
		case Window_Change_Full_Screen_State:
			state := cast(^Window_State_Header)get_state_from_id(e.sender)
			state.window_mode = .Fullscreen if e.state else .Windowed
	}
}

Input_Mouse_Button :: enum {
	Left 	= 0,
	Right 	= 1,
	Middle 	= 2,

	MouseOther_1  = 3,
	MouseOther_2  = 4,
	MouseOther_3  = 5,
	MouseOther_4  = 6,
	MouseOther_5  = 7,
	MouseOther_6  = 8,
	MouseOther_7  = 9,
	MouseOther_8  = 10,
	MouseOther_9  = 11,
	MouseOther_10 = 12,
	MouseOther_11 = 13,
	MouseOther_12 = 14,
	MouseOther_13 = 15,
	MouseOther_14 = 16,
	MouseOther_15 = 17,
	MouseOther_16 = 18,
	MouseOther_17 = 19,
	MouseOther_18 = 20,
	MouseOther_19 = 21,
	MouseOther_20 = 22,
	MouseOther_21 = 23,
	MouseOther_22 = 24,
	MouseOther_23 = 25,
	MouseOther_24 = 26,
	MouseOther_25 = 27,
	MouseOther_26 = 28,
	MouseOther_27 = 29,
	MouseOther_28 = 30,
	MouseOther_29 = 31,
}

Input_Keyboard_Key :: enum {
	None				= 0x00,
	N0					= 0x01,
	N1					= 0x02,
	N2					= 0x03,
	N3					= 0x04,
	N4					= 0x05,
	N5					= 0x06,
	N6					= 0x07,
	N7					= 0x08,
	N8					= 0x09,
	N9					= 0x0A,
	A					= 0x0B,
	B					= 0x0C,
	C					= 0x0D,
	D					= 0x0E,
	E					= 0x0F,
	F					= 0x10,
	G					= 0x11,
	H					= 0x12,
	I					= 0x13,
	J					= 0x14,
	K					= 0x15,
	L					= 0x16,
	M					= 0x17,
	N					= 0x18,
	O					= 0x19,
	P					= 0x1A,
	Q					= 0x1B,
	R					= 0x1C,
	S					= 0x1D,
	T					= 0x1E,
	U					= 0x1F,
	V					= 0x20,
	W					= 0x21,
	X					= 0x22,
	Y					= 0x23,
	Z					= 0x24,
	F1					= 0x25,
	F2					= 0x26,
	F3					= 0x27,
	F4					= 0x28,
	F5					= 0x29,
	F6					= 0x2A,
	F7					= 0x2B,
	F8					= 0x2C,
	F9					= 0x2D,
	F10					= 0x2E,
	F11					= 0x2F,
	F12					= 0x30,
	F13					= 0x31,
	F14					= 0x32,
	F16					= 0x33,
	F17					= 0x34,
	F18					= 0x35,
	F19					= 0x36,
	F15					= 0x37,
	F20					= 0x38,
	LeftArrow			= 0x39,
	RightArrow			= 0x3A,
	UpArrow				= 0x3B,
	DownArrow			= 0x3C,
	NPad0				= 0x3D,
	NPad1				= 0x3E,
	NPad2				= 0x3F,
	NPad3				= 0x40,
	NPad4				= 0x41,
	NPad5				= 0x42,
	NPad6				= 0x43,
	NPad7				= 0x44,
	NPad8				= 0x45,
	NPad9				= 0x46,
	NPadDecimal			= 0x47,
	NPadDivide			= 0x48,
	NPadMultiply		= 0x49,
	NPadMinus			= 0x4A,
	NPadPlus			= 0x4B,
	NPadEnter			= 0x4C,
	NPadEquals			= 0x4D,
	LeftShift			= 0x4E,
	LeftControl			= 0x4F,
	LeftAlt				= 0x50,
	LeftSuper			= 0x51,
	RightShift			= 0x52,
	RightControl		= 0x53,
	RightAlt			= 0x54,
	RightSuper			= 0x55,
	Apostrophe			= 0x56,
	Comma				= 0x57,
	Minus				= 0x58,
	Period				= 0x59,
	Slash				= 0x5A,
	Semicolon			= 0x5B,
	Equal				= 0x5C,
	LeftBracket			= 0x5D,
	Backslash			= 0x5E,
	RightBracket		= 0x5F,
	GraveAccent			= 0x60,
	Space				= 0x61,
	Escape				= 0x62,
	Enter				= 0x63,
	Tab					= 0x64,
	Backspace			= 0x65,
	PageUp				= 0x66,
	PageDown			= 0x67,
	Home				= 0x68,
	End					= 0x69,
	CapsLock			= 0x6A,
	VolumeUp			= 0x6B,
	VolumeDown			= 0x6C,
	Mute				= 0x6D,

	// Windows
	Insert				= 0x6E,
	Scroll_Lock			= 0x70,
	Num_Lock			= 0x71,
	Print_Screen		= 0x72,
	Pause				= 0x73,
	
	// Mac
	NPadClear			= 0x74,
	ForwardDelete		= 0x75,
	Function			= 0x76,
	Help				= 0x77,
	JIS_Yen				= 0x78,
	JIS_Underscore		= 0x79,
	JIS_KeypadComma		= 0x7A,
	JIS_Eisu			= 0x7B,
	JIS_Kana			= 0x7C,
	ISO_Section			= 0x7D,
}
