#+build darwin
#+private file

package pohja

import NS "core:sys/darwin/Foundation"
import C "core:sys/darwin/CoreFoundation"

import "core:math"

@(private="package")
DARWIN_PLATFORM_API :: Platform_API {
	window_state_size = window_state_size_darwin,

	get_window_handle = get_native_window_handle_darwin,

	window_open = window_open_darwin,
	window_close = window_close_darwin,
	
	is_window_flag_on = is_window_flag_on,
	set_window_flag = set_window_flag,
	clear_window_flag = clear_window_flag,
	is_window_property_on = is_window_property_on,

	minimize_window = minimize_window,
	maximize_window = maximize_window,

	set_window_title = set_window_title,
	set_window_position = set_window_position_darwin,
	set_window_size = set_window_size_darwin,
	set_window_focused = set_window_focused_darwin,
	set_window_opacity = set_window_opacity_darwin,
	set_window_mode = set_window_mode,

	get_window_size = get_window_size_darwin,
	get_window_position = get_window_position_darwin,
	get_window_scale = get_window_scale,

	get_monitor_count = get_monitor_count_darwin,
	get_monitor_name = get_monitor_name_darwin,
	get_monitor_size = get_monitor_size_darwin,

	set_clipboard_text = set_clipboard_text_darwin,
	get_clipboard_text = get_clipboard_text_darwin,

	set_window_min_size = set_window_min_size_darwin,
	set_window_max_size = set_window_max_size_darwin,

	process_events = process_events_darwin,

	show_cursor = show_cursor_darwin,
	hide_cursor = hide_cursor_darwin,
	cursor_lock_to_window = cursor_lock_to_window_darwin,
	cursor_unlock_from_window = cursor_unlock_from_window_darwin,
	is_cursor_on_window = is_cursor_on_window_darwin,
	closest_point_within_window = closest_point_within_window_darwin,
	force_cursor_move_to = force_cursor_move_to_darwin,
}

cursor_lock_to_window_darwin :: proc(id: Window_ID) {
	platform.is_cursor_locked = true
	platform.cursor_locked_window = id
}

cursor_unlock_from_window_darwin :: proc(id: Window_ID) {
	platform.is_cursor_locked = false
	platform.cursor_locked_window = 0
}

is_cursor_on_window_darwin :: proc(id: Window_ID, extras: Vec4) -> bool {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	rect := state.window->frame()
	mouse_pos := platform.mouse_position

	return mouse_pos.x >= f32(rect.x) && mouse_pos.x < f32(rect.x + rect.width ) &&
	       mouse_pos.y >= f32(rect.y) && mouse_pos.y < f32(rect.y + rect.height)
}

show_cursor_darwin :: proc() {
	if platform.is_cursor_hidden {
		NS.Cursor_unhide()
		NS.Cursor_arrowCursor()->set()
		platform.is_cursor_hidden = false
	}
}

hide_cursor_darwin :: proc() {
	if !platform.is_cursor_hidden {
		NS.Cursor_hide()
		NS.Cursor_arrowCursor()->set()

		platform.is_cursor_hidden = true
	}
}

set_clipboard_text_darwin :: proc(text: string) {
	pasteboard := NS.Pasteboard_generalPasteboard()
	if pasteboard == nil {
		return
	}
	pasteboard->clearContents()
		
	ns_string := NS.String_alloc()->initWithOdinString(text)
	result := pasteboard->setString(ns_string, NS.Pasteboard_type_utf8())
}

get_clipboard_text_darwin :: proc() -> string {
	pasteboard := NS.Pasteboard_generalPasteboard()
	
	if pasteboard == nil {
		return ""
	}
	
	ns_string := pasteboard->stringForType(NS.Pasteboard_type_utf8())
	
	if ns_string == nil {
		return ""
	}
	
	return string(ns_string->UTF8String())
}

is_window_flag_on :: proc(id: Window_ID, flag: Window_Flag) -> bool {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	return flag in state.flags
}

import "core:fmt"
is_window_property_on :: proc(id: Window_ID, property: Window_Property) -> bool {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	return property in state.properties
}

flag_to_ns_flag :: proc(flag: Window_Flag) -> NS.WindowStyleFlag {
	#partial switch flag {
		case .Resizable:           return NS.WindowStyleFlag.Resizable
		case .Decorated:           return NS.WindowStyleFlag.Titled
		case .Closable:            return NS.WindowStyleFlag.Closable
		case .Miniaturizable:      return NS.WindowStyleFlag.Miniaturizable
		case .Titled:              return NS.WindowStyleFlag.Titled
		case .FullSizeContentView: return NS.WindowStyleFlag.FullSizeContentView
	}
	panic("No NS flag for given platform flag")
}

set_window_flag :: proc(id: Window_ID, flag: Window_Flag) {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	state.flags += {flag}

	switch flag {
		case .Resizable, .Decorated, .Closable, .Miniaturizable, .Titled, .FullSizeContentView:
			current := state.window->styleMask()
			new_mask := current | (1 << NS.UInteger(flag_to_ns_flag(flag)))
			mask_bitset := transmute(NS.WindowStyleMask)new_mask
			state.window->setStyleMask(mask_bitset)
	}
}

clear_window_flag :: proc(id: Window_ID, flag: Window_Flag) {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	state.flags -= {flag}

	switch flag {			
		case .Resizable, .Decorated, .Closable, .Miniaturizable, .Titled, .FullSizeContentView:
			current := state.window->styleMask()
			new_mask := current ~ (1 << NS.UInteger(flag_to_ns_flag(flag)))
			mask_bitset := transmute(NS.WindowStyleMask)new_mask
			state.window->setStyleMask(mask_bitset)
	}
}

set_window_mode :: proc(id: Window_ID, flags: Window_Flags) {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	state.flags = {}

	current: int

	for flag in flags {
		state.flags += {flag}
		current = current | (1 << NS.UInteger(flag_to_ns_flag(flag)))
	}

	mask_bitset := transmute(NS.WindowStyleMask)current
	state.window->setStyleMask(mask_bitset)
}

get_window_size_darwin :: proc(id: Window_ID) -> Vec2i {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	rect := state.window->contentLayoutRect()
	return {int(rect.width), int(rect.height)}
}

get_monitor_count_darwin :: proc() -> int {
	screens := NS.Screen_screens()
	return int(screens->count())
}

get_monitor_name_darwin :: proc(monitor_index: int) -> string {
	screens := NS.Screen_screens()

	// Maybe assert this..
	if monitor_index < 0 || monitor_index >= int(screens->count()) {
		return ""
	}
	
	screen := screens->objectAs(NS.UInteger(monitor_index), ^NS.Screen)
	screen_name := screen->localizedName()

	return screen_name->odinString()
}

get_monitor_size_darwin :: proc(monitor_index: int) -> Vec2i {
	screens := NS.Screen_screens()
	
	if monitor_index < 0 || monitor_index >= int(screens->count()) {
		return {0, 0}
	}
	
	screen := screens->objectAs(NS.UInteger(monitor_index), ^NS.Screen)
	frame := screen->frame()
	
	return {int(frame.size.width), int(frame.size.height)}
}

closest_point_within_window_darwin :: proc(id: Window_ID, pos: Vec2, extra_space: Vec4) -> Vec2 {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	rect := state.window->contentLayoutRect()
	rect = state.window->convertRectToScreen(rect)

	return {
		math.clamp(pos.x, f32(rect.origin.x) + 1 - extra_space.x, f32(rect.origin.x + rect.size.width  - 1) + extra_space.y),
		math.clamp(pos.y, f32(rect.origin.y) + 1 - extra_space.z, f32(rect.origin.y + rect.size.height - 1) + extra_space.w)
	}
}

force_cursor_move_to_darwin :: proc(pos: Vec2) {
	main_screen := NS.Screen_mainScreen()
	screen_height := main_screen->frame().size.height

	C.CGWarpMouseCursorPosition({
		x = C.Float(pos.x),
		y = C.Float(screen_height) - C.Float(pos.y)
	})
}

set_window_opacity_darwin :: proc(id: Window_ID, value: f32) {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	state.window->setAlphaValue(NS.Float(value))
}

process_events_darwin :: proc() {
	event: ^NS.Event
	
	application := NS.Application.sharedApplication()

	for {
		event = application->nextEventMatchingMask(NS.EventMaskAny, NS.Date_distantPast(), NS.DefaultRunLoopMode, true)
		if event == nil { break }
		
		#partial switch event->type() {
			case .KeyDown:
				emit_input_event(Key_Pressed_Event{key=code_to_keyboard_key[event->keyCode()]})
			case .KeyUp:
				emit_input_event(Key_Released_Event{key=code_to_keyboard_key[event->keyCode()]})
			
			case .LeftMouseDown, .RightMouseDown, .OtherMouseDown:
				btn_n := event->buttonNumber()
				emit_input_event(Mouse_Pressed_Event{button=code_to_mouse_button[int(btn_n)]})
			case .LeftMouseUp, .RightMouseUp, .OtherMouseUp:
				btn_n := event->buttonNumber()
				emit_input_event(Mouse_Released_Event{button=code_to_mouse_button[int(btn_n)]})

			case .MouseMoved, .LeftMouseDragged, .RightMouseDragged, .OtherMouseDragged:
				position := NS.Event_mouseLocation()			
				emit_input_event(Mouse_Position_Event{x=f64(position.x), y=f64(position.y)})
			case .ScrollWheel:
				scroll_x, scroll_y := event->scrollingDelta()
				emit_input_event(Mouse_Scroll_Event{x=f64(scroll_x), y=f64(scroll_y)})
		}
		application->sendEvent(event)
	}
}

code_to_mouse_button := [64]Input_Mouse_Button {
	0  = .Left,
	1  = .Right,
	2  = .Middle,
	3  = .MouseOther_1,
	4  = .MouseOther_2,
	5  = .MouseOther_3,
	6  = .MouseOther_4,
	7  = .MouseOther_5,
	8  = .MouseOther_6,
	9  = .MouseOther_7,
	10 = .MouseOther_8,
	11 = .MouseOther_9,
	12 = .MouseOther_10,
	13 = .MouseOther_11,
	14 = .MouseOther_12,
	15 = .MouseOther_13,
	16 = .MouseOther_14,
	17 = .MouseOther_15,
	18 = .MouseOther_16,
	19 = .MouseOther_17,
	20 = .MouseOther_18,
	21 = .MouseOther_19,
	22 = .MouseOther_20,
	23 = .MouseOther_21,
	24 = .MouseOther_22,
	25 = .MouseOther_23,
	26 = .MouseOther_24,
	27 = .MouseOther_25,
	28 = .MouseOther_26,
	29 = .MouseOther_27,
	30 = .MouseOther_28,
	31 = .MouseOther_29,
}

code_to_keyboard_key := [255]Input_Keyboard_Key {
	NS.kVK.ANSI_1 				= .N1,
	NS.kVK.ANSI_2 				= .N2,
	NS.kVK.ANSI_3 				= .N3,
	NS.kVK.ANSI_4 				= .N4,
	NS.kVK.ANSI_5 				= .N5,
	NS.kVK.ANSI_6 				= .N6,
	NS.kVK.ANSI_7 				= .N7,
	NS.kVK.ANSI_8 				= .N8,
	NS.kVK.ANSI_9 				= .N9,
	NS.kVK.ANSI_0 				= .N0,
	NS.kVK.ANSI_Keypad1 		= .NPad1,
	NS.kVK.ANSI_Keypad2 		= .NPad2,
	NS.kVK.ANSI_Keypad3 		= .NPad3,
	NS.kVK.ANSI_Keypad4 		= .NPad4,
	NS.kVK.ANSI_Keypad5 		= .NPad5,
	NS.kVK.ANSI_Keypad6 		= .NPad6,
	NS.kVK.ANSI_Keypad7 		= .NPad7,
	NS.kVK.ANSI_Keypad8 		= .NPad8,
	NS.kVK.ANSI_Keypad9 		= .NPad9,
	NS.kVK.ANSI_Keypad0 		= .NPad0,
	NS.kVK.ANSI_KeypadClear 	= .NPadClear,
	NS.kVK.ANSI_KeypadDecimal 	= .NPadDecimal,
	NS.kVK.ANSI_KeypadDivide 	= .NPadDivide,
	NS.kVK.ANSI_KeypadMultiply 	= .NPadMultiply,
	NS.kVK.ANSI_KeypadMinus 	= .NPadMinus,
	NS.kVK.ANSI_KeypadPlus 		= .NPadPlus,
	NS.kVK.ANSI_KeypadEnter 	= .NPadEnter,
	NS.kVK.ANSI_KeypadEquals 	= .NPadEquals,
	NS.kVK.ANSI_A 				= .A,
	NS.kVK.ANSI_S 				= .S,
	NS.kVK.ANSI_D 				= .D,
	NS.kVK.ANSI_F 				= .F,
	NS.kVK.ANSI_H 				= .H,
	NS.kVK.ANSI_G 				= .G,
	NS.kVK.ANSI_Z 				= .Z,
	NS.kVK.ANSI_X 				= .X,
	NS.kVK.ANSI_C 				= .C,
	NS.kVK.ANSI_V 				= .V,
	NS.kVK.ANSI_B 				= .B,
	NS.kVK.ANSI_Q 				= .Q,
	NS.kVK.ANSI_W 				= .W,
	NS.kVK.ANSI_E 				= .E,
	NS.kVK.ANSI_R 				= .R,
	NS.kVK.ANSI_Y 				= .Y,
	NS.kVK.ANSI_T 				= .T,
	NS.kVK.ANSI_O 				= .O,
	NS.kVK.ANSI_U 				= .U,
	NS.kVK.ANSI_I 				= .I,
	NS.kVK.ANSI_P 				= .P,
	NS.kVK.ANSI_L 				= .L,
	NS.kVK.ANSI_J 				= .J,
	NS.kVK.ANSI_K 				= .K,
	NS.kVK.ANSI_N 				= .N,
	NS.kVK.ANSI_M 				= .M,
	NS.kVK.F1 					= .F1,
	NS.kVK.F2 					= .F2,
	NS.kVK.F3 					= .F3,
	NS.kVK.F4 					= .F4,
	NS.kVK.F5 					= .F5,
	NS.kVK.F6 					= .F6,
	NS.kVK.F7 					= .F7,
	NS.kVK.F8 					= .F8,
	NS.kVK.F9 					= .F9,
	NS.kVK.F10 					= .F10,
	NS.kVK.F11 					= .F11,
	NS.kVK.F12 					= .F12,
	NS.kVK.F13 					= .F13,
	NS.kVK.F14 					= .F14,
	NS.kVK.F15 					= .F15,
	NS.kVK.F16 					= .F16,
	NS.kVK.F17 					= .F17,
	NS.kVK.F18 					= .F18,
	NS.kVK.F19 					= .F19,
	NS.kVK.F20 					= .F20,
	NS.kVK.LeftArrow  			= .LeftArrow,
	NS.kVK.RightArrow 			= .RightArrow,
	NS.kVK.DownArrow  			= .DownArrow,
	NS.kVK.UpArrow    			= .UpArrow,
	NS.kVK.Shift 				= .LeftShift,
	NS.kVK.Control 				= .LeftControl,
	NS.kVK.Option 				= .LeftAlt,
	NS.kVK.Command 				= .LeftSuper,
	NS.kVK.RightShift 			= .RightShift,
	NS.kVK.RightControl 		= .RightControl,
	NS.kVK.RightOption 			= .RightAlt,
	NS.kVK.RightCommand			= .RightSuper,
	NS.kVK.ANSI_Quote 			= .Apostrophe,
	NS.kVK.ANSI_Comma 			= .Comma,
	NS.kVK.ANSI_Minus 			= .Minus,
	NS.kVK.ANSI_Period 			= .Period,
	NS.kVK.ANSI_Slash 			= .Slash,
	NS.kVK.ANSI_Semicolon 		= .Semicolon,
	NS.kVK.ANSI_Equal 			= .Equal,
	NS.kVK.ANSI_LeftBracket 	= .LeftBracket,
	NS.kVK.ANSI_Backslash 		= .Backslash,
	NS.kVK.ANSI_RightBracket 	= .RightBracket,
	NS.kVK.ANSI_Grave 			= .GraveAccent,
	NS.kVK.Space 				= .Space,
	NS.kVK.Escape 				= .Escape,
	NS.kVK.Return 				= .Enter,
	NS.kVK.Tab 					= .Tab,
	NS.kVK.Delete				= .Backspace,
	NS.kVK.ForwardDelete 		= .ForwardDelete,
	NS.kVK.Home 				= .Home,
	NS.kVK.PageUp 				= .PageUp,
	NS.kVK.End 					= .End,
	NS.kVK.PageDown 			= .PageDown,
	NS.kVK.CapsLock 			= .CapsLock,
	NS.kVK.Function 			= .Function,
	NS.kVK.VolumeUp 			= .VolumeUp,
	NS.kVK.VolumeDown 			= .VolumeDown,
	NS.kVK.Mute 				= .Mute,
	NS.kVK.Help 				= .Help,
	NS.kVK.JIS_Yen				= .JIS_Yen,
	NS.kVK.JIS_Underscore 		= .JIS_Underscore,
	NS.kVK.JIS_KeypadComma 		= .JIS_KeypadComma,
	NS.kVK.JIS_Eisu 			= .JIS_Eisu,
	NS.kVK.JIS_Kana 			= .JIS_Kana,
	NS.kVK.ISO_Section 			= .ISO_Section,
}

set_window_position_darwin :: proc(id: Window_ID, x, y: int) {
	// Topleft (0, 0), Y increasing downwards
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	state.position = {x, y}

	screen := NS.Screen_mainScreen()
	screen_frame := screen->frame()
	
	point := NS.Point {
		x = NS.Float(x),
		y = screen_frame.size.height - NS.Float(y),
	}

	state.window->setFrameTopLeftPoint(point)
}

get_window_position_darwin :: proc(id: Window_ID) -> Vec2i {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	
	screen := NS.Screen_mainScreen()
	screen_frame := screen->frame()
	
	window_frame := state.window->frame()
	
	x := int(window_frame.origin.x)
	y := int(screen_frame.size.height - window_frame.origin.y - window_frame.size.height)
	
	return {x, y}
}

get_window_scale :: proc(id: Window_ID) -> f32 {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	return f32(state.window->backingScaleFactor())
}

// NOTE: X can be infinite but Y gets capped by screen height
set_window_size_darwin :: proc(id: Window_ID, w, h: int) {
	state := cast(^Darwin_Window_State)get_state_from_id(id)

	min_width := state.min_size.x if state.min_size.x != 0 else w
	max_width := state.max_size.x if state.max_size.x != 0 else max(w, min_width)
	width := clamp(w, min_width, max_width)

	min_height := state.min_size.y if state.min_size.y != 0 else h
	max_height := state.max_size.y if state.max_size.y != 0 else max(h, min_height)
	height := clamp(h, min_height, max_height)

	frame := state.window->frame()
	frame.size = {
		width = NS.Float(width),
		height = NS.Float(height),
	}

	state.window->setFrame(frame, true)
}

set_window_min_size_darwin :: proc(id: Window_ID, w, h: int) {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	state.min_size = {w, h}
	
	size := get_window_size_darwin(id)
	if size.x < w || size.y < h {
		set_window_size_darwin(id, max(w, size.x), max(h, size.y))
	}
}

set_window_max_size_darwin :: proc(id: Window_ID, w, h: int) { 
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	state.max_size = {w, h}

	size := get_window_size_darwin(id)
	if size.x > w || size.y > h {
		set_window_size_darwin(id, min(w, size.x), min(h, size.y))
	}
}

set_window_title :: proc(id: Window_ID, title: string) {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	state.title = title
	ns_title := NS.alloc(NS.String)->initWithOdinString(title)
	defer ns_title->release()
	state.window->setTitle(ns_title)
}

set_window_visible_darwin :: proc(id: Window_ID, visible: bool) {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	if visible {
		state.window->orderFront(nil)
	} else {
		state.window->orderOut(nil)
	}
}

minimize_window :: proc(id: Window_ID) {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	state.window->setIsMiniaturized(true)
}

maximize_window :: proc(id: Window_ID) {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	state.window->setIsMiniaturized(false)
}

set_window_focused_darwin :: proc(id: Window_ID) {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	state.window->makeKeyAndOrderFront(nil)
}

get_native_window_handle_darwin :: proc(id: Window_ID) -> Window_Handle {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	return cast(Window_Handle)state.window
}

window_close_darwin :: proc(id: Window_ID) {
	state := cast(^Darwin_Window_State)get_state_from_id(id)
	state.window->close()
	state.is_alive = false
}

Darwin_Window_State :: struct {
	using header : Window_State_Header,

	application: ^NS.Application,
	window: ^NS.Window,
}

window_state_size_darwin :: proc() -> int {
	return size_of(Darwin_Window_State)
}

window_open_darwin :: proc(width, height: int, title: string) -> Window_ID {
	state, id := get_free_state()
	darwin_state := cast(^Darwin_Window_State)state

	darwin_state^ = Darwin_Window_State {
		application = NS.Application.sharedApplication(),
		window = NS.Window_alloc(),
		size = {width, height},
		title = title,
        id = id,
        is_alive = true,
	}
	
	NS.Application.sharedApplication()->setActivationPolicy(.Regular)

	application_delegate_cls := NS.application_delegate_register_and_alloc(Application_Delegate_Template, "MyApplicationDelegate", context)
	NS.Application.sharedApplication()->setDelegate(application_delegate_cls)

	rect := NS.Rect {
		origin = {0, 0},
		size = {NS.Float(width), NS.Float(height)},
	}

	darwin_state.window->initWithContentRect(rect, {.Resizable, .Closable, .Titled, .Miniaturizable}, .Buffered, false)
	darwin_state.window->setReleasedWhenClosed(true)

	window_delegate_cls := NS.window_delegate_register_and_alloc(Window_Delegate_Template, "MyWindowDelegate", context)
	darwin_state.window->setDelegate(window_delegate_cls)
	
	_register_window(cast(Window_Handle)darwin_state.window, id)

	darwin_state.window->setBackgroundColor(NS.Color_purpleColor())
	darwin_state.window->makeKeyAndOrderFront(nil)
	darwin_state.window->center()
	
	set_window_title(id, title)
	//NS.Application.sharedApplication()->activateIgnoringOtherApps(true)
	NS.Application.sharedApplication()->finishLaunching()
	NS.Application.sharedApplication()->activate()

	// Cursor locking "hack"
	source := C.CGEventSourceCreate(C.kCGEventSourceStateCombinedSessionState)
	C.CGEventSourceSetLocalEventsSuppressionInterval(source, 0.001)
	C.Release(source)

	return id
}

// APPLICATION DELEGATE

Application_Delegate_Template :: NS.ApplicationDelegateTemplate {
	applicationDidBecomeActive                      = application_did_become_active,
	applicationDidResignActive                      = application_did_resign_active,
	applicationShouldTerminate                      = application_should_terminate,
	applicationShouldTerminateAfterLastWindowClosed = application_should_terminate_after_last_window_closed,
	applicationDidHide                              = application_did_hide,
	applicationDidUnhide                            = application_did_unhide,
}

application_did_become_active :: proc(notification: ^NS.Notification) { emit_platform_event(.DidBecomeActive) }

application_did_resign_active :: proc(notification: ^NS.Notification) { emit_platform_event(.DidResignActive) }

application_should_terminate :: proc(sender: ^NS.Application) -> NS.ApplicationTerminateReply { 
	reply := emit_platform_event(.ShouldTerminate)
	value := reply.(bool)
	return .TerminateNow if value else .TerminateCancel
}

application_should_terminate_after_last_window_closed :: proc(sender: ^NS.Application) -> NS.BOOL {
	reply := emit_platform_event(.TerminateAfterLastWindowClosed)
	value := reply.(bool)
	return NS.BOOL(value)
}

application_did_hide :: proc(notification: ^NS.Notification) { 
	emit_platform_event(.DidHide)
}
application_did_unhide :: proc(notification: ^NS.Notification) {
	emit_platform_event(.DidUnhide)
}

// WINDOW DELEGATE

Window_Delegate_Template :: NS.WindowDelegateTemplate {
	windowDidChangeOcclusionState = window_did_change_occlusion_state, 
	windowShouldClose = window_should_close,
	windowDidResize = window_did_resize,
	windowDidMove = window_did_move,
	windowDidBecomeKey = window_did_become_key,
	windowDidResignKey = window_did_resign_key,
	windowDidMiniaturize = window_did_miniaturize,
	windowDidDeminiaturize = window_did_deminiaturize,
	windowDidEnterFullScreen = window_did_enter_full_screen,
	windowDidExitFullScreen = window_did_exit_full_screen,
}

window_did_change_occlusion_state :: proc(notification: ^NS.Notification) {
	sender_window := cast(^NS.Window)notification->object()
	window_id := platform.registry.handle_to_id[cast(Window_Handle)sender_window]
	occlusion_state := sender_window->occlusionStateVisible()
	emit_window_event(Window_Did_Change_Occlusion_State{
		sender = window_id,
		state = bool(occlusion_state),
	})
}

window_should_close :: proc(window: ^NS.Window) -> NS.BOOL {
	window_id := platform.registry.handle_to_id[cast(Window_Handle)window]
	emit_window_event(Window_Should_Close{
		sender = window_id,
	})
	return false
}

window_did_resize :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	size := window->frame().size
	emit_window_event(Window_Did_Resize{
		sender = platform.registry.handle_to_id[cast(Window_Handle)window],
		size = {int(size.width), int(size.height)},
	})
}

window_did_move :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	position := window->frame().origin
	emit_window_event(Window_Did_Move{
		sender = platform.registry.handle_to_id[cast(Window_Handle)window],
		position = {int(position.x), int(position.y)},
	})
}

window_did_become_key :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	emit_window_event(Window_Change_Key_State{
		sender = platform.registry.handle_to_id[cast(Window_Handle)window],
		state = true,
	})
}

window_did_resign_key :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	emit_window_event(Window_Change_Key_State{
		sender = platform.registry.handle_to_id[cast(Window_Handle)window],
		state = false,
	})
}

window_did_miniaturize :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	emit_window_event(Window_Change_Miniaturize_State{
		sender = platform.registry.handle_to_id[cast(Window_Handle)window],
		state = true,
	})
}

window_did_deminiaturize :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	emit_window_event(Window_Change_Miniaturize_State{
		sender = platform.registry.handle_to_id[cast(Window_Handle)window],
		state = false,
	})
}

window_did_enter_full_screen :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	emit_window_event(Window_Change_Full_Screen_State{
		sender = platform.registry.handle_to_id[cast(Window_Handle)window],
		state = true,
	})
}

window_did_exit_full_screen :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	emit_window_event(Window_Change_Full_Screen_State{
		sender = platform.registry.handle_to_id[cast(Window_Handle)window],
		state = false,
	})
}
