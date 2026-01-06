package main

import "core:log"
import "base:runtime"

when ODIN_OS == .Darwin {
	DEFAULT_PLATFORM_API :: DARWIN_PLATFORM_API
} else when ODIN_OS == .Windows {
	DEFAULT_PLATFORM_API :: nil
}

PLATFORM_API :: DEFAULT_PLATFORM_API

@(private="package")
platform: Platform

Platform :: struct {
	window_states: []byte,
	state_size: int,
	max_windows: int,
    ctx: runtime.Context,
    frame_allocator: runtime.Allocator,

	keys_press_started: #sparse [InputKeyboardKey]bool,
	keys_held: #sparse [InputKeyboardKey]bool,
	keys_released: #sparse [InputKeyboardKey]bool,

	mouse_press_started: #sparse [InputMouseButton]bool,
	mouse_held: #sparse [InputMouseButton]bool,
	mouse_released: #sparse [InputMouseButton]bool,

	mouse_position: [2]f32,
	mouse_move_delta: [2]f32,
	mouse_scroll_delta: [2]f32,

	events: [MAX_INPUT_EVENTS_PER_FRAME]InputEvent,
	event_count: int,

    shutdown_requested: bool,
}

init :: proc(max_windows: int = 1) {
	assert(max_windows >= 1, "Need at least 1 window!")

	state_size := PLATFORM_API.window_state_size()
    platform.window_states = make([]byte, state_size * max_windows)
    platform.state_size = state_size
    platform.max_windows = max_windows
    platform.frame_allocator = context.temp_allocator
}

open_window :: proc(desc: WindowDescription) -> WindowID {
    return PLATFORM_API.window_open(desc)
}

close_window :: proc(id: WindowID) {
    assert(int(id) < platform.max_windows && int(id) >= 0, "Invalid WindowID")
    PLATFORM_API.window_close(id)
}

application_request_shutdown :: #force_inline proc() {
	platform.shutdown_requested = true
}

cleanup :: proc() {
    for i := platform.max_windows - 1; i >= 0; i -= 1 {
        header := cast(^WindowStateHeader)_get_state(WindowID(i))
        
        if !header.is_alive {
            continue
        }
        PLATFORM_API.window_close(WindowID(i))
    }

    delete(platform.window_states)
}

run :: proc() {
    defer cleanup()
    for !platform.shutdown_requested { 
        free_all(platform.frame_allocator)

        input_reset_state()
		PLATFORM_API.process_events()
		input_update_state()
		defer PLATFORM_API.clear_events()

        for i := platform.max_windows - 1; i >= 0; i -= 1 {
            header := cast(^WindowStateHeader)_get_state(WindowID(i))
            
            if !header.is_alive {
                continue
            }
            
            if header.close_requested {
                if .MainWindow in header.flags {
                    application_request_shutdown()
                }

                PLATFORM_API.window_close(WindowID(i))
                header.close_requested = false
            }
        }
    }
}

PlatformAPI :: struct {
	window_state_size: proc() -> int,

	window_open:  proc(desc: WindowDescription) -> WindowID,
	window_close: proc(id: WindowID),
	
	get_native_window_handle: proc(id: WindowID) -> WindowHandle,
	
	set_window_position: proc(id: WindowID, x, y: int),
	set_window_size: proc(id: WindowID, w, h: int),

	process_events: proc(),
	get_events: proc() -> []InputEvent,
	clear_events: proc(),

	get_window_width: proc(id: WindowID) -> int,
	get_window_height: proc(id: WindowID) -> int,
}

WindowID :: distinct u32
WindowHandle :: distinct uintptr
WindowDescription :: struct {
	x: int,
	y: int,
	width: int,
	height: int,
	title: string,
    window_flags: WindowFlags,
}

WindowFlags :: bit_set[WindowFlag]
WindowFlag :: enum {
    MainWindow,
    CenterOnOpen,
}

WindowStateHeader :: struct {
    id: WindowID,
    width: int,
	height: int,
	title: string,
	x: int,
	y: int,
	is_alive: bool,
    close_requested: bool,
    is_visible: bool,
    is_focused: bool,
    is_minimized: bool,
    flags: WindowFlags
}

_is_state_alive :: proc(state: rawptr) -> bool {
    header := cast(^WindowStateHeader)state
    return header.is_alive
}

_get_first_alive :: proc() -> (state: rawptr, id: WindowID) {
	for i in 0..<platform.max_windows {
        state_ptr := _get_state(WindowID(i))
        if _is_state_alive(state_ptr) {
        	return state_ptr, WindowID(i)
        }
    }
    log.panic("All window states are dead!")
}

_get_free_state :: proc() -> (state: rawptr, id: WindowID) {
    for i in 0..<platform.max_windows {
        state_ptr := _get_state(WindowID(i))
        if !_is_state_alive(state_ptr) {
            return state_ptr, WindowID(i)
        }
    }
    log.panic("All window states are in use!")
}

_get_state :: proc(id: WindowID) -> rawptr {
    assert(int(id) < platform.max_windows && int(id) >= 0, "Invalid WindowID")
    
    offset := platform.state_size * int(id)
    return raw_data(platform.window_states[offset:])
}

/////////////////////////////////////////////////////

MAX_INPUT_EVENTS_PER_FRAME :: 128

input_update_state :: proc() {
	events := PLATFORM_API.get_events()

	for event in events {
		switch e in event {
			case WindowEventCloseRequested:
                header := cast(^WindowStateHeader)_get_state(e.id)
				header.close_requested = true

			case KeyPressedEvent:
				platform.keys_press_started[e.key] = platform.keys_held[e.key] ~ true
				platform.keys_held[e.key] = true
			case KeyReleasedEvent:
				platform.keys_released[e.key] = true
				platform.keys_held[e.key] = false

			case WindowResizeEvent:

			
			case WindowMinimizeStartEvent:
                header := cast(^WindowStateHeader)_get_state(e.id)
				header.is_minimized = true
			case WindowMinimizeEndEvent:
                header := cast(^WindowStateHeader)_get_state(e.id)
				header.is_minimized = false
				
			case WindowBecameVisibleEvent:
                header := cast(^WindowStateHeader)_get_state(e.id)
				header.is_visible = true
			case WindowBecameHiddenEvent:
                header := cast(^WindowStateHeader)_get_state(e.id)
				header.is_visible = false
			
			case WindowEnterFullscreenEvent:
			case WindowExitFullscreenEvent:
			case WindowMoveEvent:

			case WindowDidBecomeKey:
                header := cast(^WindowStateHeader)_get_state(e.id)
				header.is_focused = true
			case WindowDidResignKey:
                header := cast(^WindowStateHeader)_get_state(e.id)
				header.is_focused = false

			case MousePressedEvent:
				platform.mouse_press_started[e.button] = platform.mouse_held[e.button] ~ true
				platform.mouse_held[e.button] = true
			case MouseReleasedEvent:
				platform.mouse_released[e.button] = true
				platform.mouse_held[e.button] = false

			case MousePositionEvent:
				platform.mouse_move_delta = {f32(e.x) - platform.mouse_position.x, f32(e.y) - platform.mouse_position.y}
				platform.mouse_position = {f32(e.x), f32(e.y)}

			case MouseScrollEvent:
				platform.mouse_scroll_delta = {f32(e.x), f32(e.y)}
		}
	}
}

input_reset_state :: proc() {
	platform.keys_press_started = {}
	platform.keys_released = {}
	
	platform.mouse_press_started = {}
	platform.mouse_released = {}
	
	platform.mouse_scroll_delta = {}
	platform.mouse_move_delta = {}
}

input_key_went_down :: proc "contextless" (key: InputKeyboardKey) -> bool {
	return platform.keys_press_started[key]
}

input_key_went_up :: proc "contextless" (key: InputKeyboardKey) -> bool {
	return platform.keys_released[key]
}

input_key_is_held :: proc "contextless" (key: InputKeyboardKey) -> bool {
	return platform.keys_held[key]
}

input_mouse_button_went_down :: proc "contextless" (button: InputMouseButton) -> bool {
	return platform.mouse_press_started[button]
}

input_mouse_button_went_up :: proc "contextless" (button: InputMouseButton) -> bool {
	return platform.mouse_released[button]
}

input_mouse_button_is_held :: proc "contextless" (button: InputMouseButton) -> bool {
	return platform.mouse_held[button]
}

input_scroll_magnitude :: proc "contextless" (direction: InputScrollDirection) -> f32 {
	if direction == .X {
		return f32(platform.mouse_scroll_delta.x)
	} else if direction == .Y {
		return f32(platform.mouse_scroll_delta.y)
	} else {
		return f32(platform.mouse_scroll_delta.x) + f32(platform.mouse_scroll_delta.y)
	}
}

input_scroll_vector :: proc "contextless" (direction: InputScrollDirection) -> [2]f32 {
	if direction == .X {
		return {1, 0} * f32(platform.mouse_scroll_delta.x)
	} else if direction == .Y {
		return {0, 1} * f32(platform.mouse_scroll_delta.y)
	} else {
		return {f32(platform.mouse_scroll_delta.x), f32(platform.mouse_scroll_delta.y)}
	}	
}

input_mouse_position :: proc "contextless" () -> [2]f32 {
	return {f32(platform.mouse_position.x), f32(platform.mouse_position.y)}
}

input_mouse_delta :: proc "contextless" (direction: InputScrollDirection) -> f32 {
	if direction == .X {
		return f32(platform.mouse_move_delta.x)
	} else if direction == .Y {
		return f32(platform.mouse_move_delta.y)
	} else {
		return f32(platform.mouse_move_delta.x) + f32(platform.mouse_move_delta.y)
	}	
}

input_mouse_delta_vector :: proc "contextless" (direction: InputScrollDirection) -> [2]f32 {
	if direction == .X {
		return {1, 0} * f32(platform.mouse_move_delta.x)
	} else if direction == .Y {
		return {0, 1} * f32(platform.mouse_move_delta.y)
	} else {
		return {f32(platform.mouse_move_delta.x), f32(platform.mouse_move_delta.y)}
	}
}

input_new_event :: proc "contextless" (event: InputEvent) {
	if platform.event_count == MAX_INPUT_EVENTS_PER_FRAME - 1 {
		return
	}

	platform.events[platform.event_count] = event
	platform.event_count += 1
}

InputScrollDirection :: enum {
	X,
	Y,
	Both,
}

InputEvent :: union {
	WindowEventCloseRequested,

	KeyPressedEvent,
	KeyReleasedEvent,

	MousePressedEvent,
	MouseReleasedEvent,
	MousePositionEvent,
	MouseScrollEvent,

	WindowResizeEvent,

	WindowMinimizeStartEvent,
	WindowMinimizeEndEvent,

	WindowEnterFullscreenEvent,
	WindowExitFullscreenEvent,

	WindowMoveEvent,

	WindowDidBecomeKey,
	WindowDidResignKey,

	WindowBecameVisibleEvent,
	WindowBecameHiddenEvent,
}

WindowEventCloseRequested :: struct { id: WindowID }
WindowResizeEvent :: struct { id: WindowID, width, height: int}
WindowMinimizeStartEvent :: struct { id: WindowID }
WindowMinimizeEndEvent :: struct { id: WindowID }
WindowEnterFullscreenEvent :: struct { id: WindowID }
WindowExitFullscreenEvent :: struct { id: WindowID }
WindowMoveEvent :: struct { id: WindowID, x, y: int }
WindowDidBecomeKey :: struct { id: WindowID }
WindowDidResignKey :: struct { id: WindowID }
WindowBecameVisibleEvent :: struct { id: WindowID }
WindowBecameHiddenEvent :: struct { id: WindowID }

KeyPressedEvent :: struct { key: InputKeyboardKey }
KeyReleasedEvent :: struct { key: InputKeyboardKey }
MousePressedEvent :: struct { button: InputMouseButton }
MouseReleasedEvent :: struct { button: InputMouseButton }
MousePositionEvent :: struct { x, y: f64 }
MouseScrollEvent :: struct { x, y: f64 }

InputMouseButton :: enum {
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
	MouseOther_29 = 31
}

InputKeyboardKey :: enum {
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
