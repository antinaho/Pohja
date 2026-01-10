#+build darwin
#+private file

package pohja

import NS "core:sys/darwin/Foundation"

@(private="package")
DARWIN_PLATFORM_API :: PlatformAPI {
	window_state_size = window_state_size_darwin,
	window_open = window_open_darwin,
	window_close = window_close_darwin,
	get_native_window_handle = get_native_window_handle_darwin,
	set_window_position = set_window_position_darwin,
	set_window_size = set_window_size_darwin,
	set_window_title = set_window_title_darwin,
	set_window_visible = set_window_visible_darwin,
	set_window_minimized = set_window_minimized_darwin,
	set_window_mode = set_window_mode_darwin,
	focus_window = focus_window_darwin,
	process_events = process_events_darwin,
	get_window_width = get_window_width_darwin,
	get_window_height = get_window_height_darwin,
}

get_window_width_darwin :: proc(id: WindowID) -> int {
	state := cast(^DarwinWindowState)get_state_from_id(id)
	frame := state.window->frame()
	return int(frame.width)
}

get_window_height_darwin :: proc(id: WindowID) -> int {
	state := cast(^DarwinWindowState)get_state_from_id(id)
	frame := state.window->frame()
	return int(frame.height)
}

process_events_darwin :: proc() {
	event: ^NS.Event
	
	application := NS.Application.sharedApplication()

	for {
		event = application->nextEventMatchingMask(NS.EventMaskAny, NS.Date_distantPast(), NS.DefaultRunLoopMode, true)
		if event == nil { break }
		
		#partial switch event->type() {
			case .KeyDown:
				emit_input_event(KeyPressedEvent{key=code_to_keyboard_key[event->keyCode()]})
			case .KeyUp:
				emit_input_event(KeyReleasedEvent{key=code_to_keyboard_key[event->keyCode()]})
			
			case .LeftMouseDown, .RightMouseDown, .OtherMouseDown:
				btn_n := event->buttonNumber()
				emit_input_event(MousePressedEvent{button=code_to_mouse_button[int(btn_n)]})
			case .LeftMouseUp, .RightMouseUp, .OtherMouseUp:
				btn_n := event->buttonNumber()
				emit_input_event(MouseReleasedEvent{button=code_to_mouse_button[int(btn_n)]})

			case .MouseMoved, .LeftMouseDragged, .RightMouseDragged, .OtherMouseDragged:
				position := event->locationInWindow()				
				emit_input_event(MousePositionEvent{x=f64(position.x), y=f64(position.y)})
			case .ScrollWheel:
				scroll_x, scroll_y := event->scrollingDelta()
				emit_input_event(MouseScrollEvent{x=f64(scroll_x), y=f64(scroll_y)})
			case .MouseEntered:
			case .MouseExited:
			// TODO implement touch "pointer" cases
		}
		application->sendEvent(event)
	}
}

code_to_mouse_button := [64]InputMouseButton {
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
	31 = .MouseOther_29
}

code_to_keyboard_key := [255]InputKeyboardKey {
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

set_window_position_darwin :: proc(id: WindowID, x, y: int) {
	state := cast(^DarwinWindowState)get_state_from_id(id)
	state.x = x
	state.y = y

	point := NS.Point {
		x = NS.Float(x),
		y = NS.Float(y)
	}

	state.window->setFrameOrigin(point)
} 

set_window_size_darwin :: proc(id: WindowID, w, h: int) {
	state := cast(^DarwinWindowState)get_state_from_id(id)

	frame := state.window->frame()
	frame.size = {
		width = NS.Float(w),
		height = NS.Float(h),
	}

	state.window->setFrame(frame, false)
}

set_window_title_darwin :: proc(id: WindowID, title: string) {
	state := cast(^DarwinWindowState)get_state_from_id(id)
	ns_title := NS.alloc(NS.String)->initWithOdinString(title)
	defer ns_title->release()
	state.window->setTitle(ns_title)
}

set_window_visible_darwin :: proc(id: WindowID, visible: bool) {
	state := cast(^DarwinWindowState)get_state_from_id(id)
	if visible {
		state.window->orderFront(nil)
	} else {
		state.window->orderOut(nil)
	}
}

set_window_minimized_darwin :: proc(id: WindowID, minimized: bool) {
	state := cast(^DarwinWindowState)get_state_from_id(id)
	if minimized {
		state.window->setIsMiniaturized(true)
	} else {
		state.window->setIsMiniaturized(false)
	}
}

set_window_mode_darwin :: proc(id: WindowID, new_mode: WindowDisplayMode) {
	state := cast(^DarwinWindowState)get_state_from_id(id)
	prev_mode := state.window_mode

	if new_mode == prev_mode {
		return
	}

	// Exit current mode
	switch prev_mode {
		case .Windowed:
		case .Fullscreen, .BorderlessFullscreen:
			//state.window->toggleFullScreen(false)
	}

	// Enter new mode
	switch new_mode {
		case .Windowed:
		case .Fullscreen:
			//state.window->toggleFullScreen(true)
		case .BorderlessFullscreen:
			// TODO: implement borderless fullscreen (set window frame to screen size, remove decorations)
	}
}

focus_window_darwin :: proc(id: WindowID) {
	state := cast(^DarwinWindowState)get_state_from_id(id)
	state.window->makeKeyAndOrderFront(nil)
}

get_native_window_handle_darwin :: proc(id: WindowID) -> WindowHandle {
	state := cast(^DarwinWindowState)get_state_from_id(id)
	return cast(WindowHandle)state.window
}

window_close_darwin :: proc(id: WindowID) {
    state := cast(^DarwinWindowState)get_state_from_id(id)
    
    state.window->close()

    state.is_alive = false
}

DarwinWindowState :: struct {
	using header : WindowStateHeader,

	application: ^NS.Application,
	window: ^NS.Window,
}

window_state_size_darwin :: proc() -> int {
	return size_of(DarwinWindowState)
}

window_open_darwin :: proc(desc: WindowDescription) -> WindowID {
    state, id := get_free_state()
    darwin_state := cast(^DarwinWindowState)state

	darwin_state^ = DarwinWindowState {
		application = NS.Application.sharedApplication(),
		window = NS.Window_alloc(),
		x = desc.x,
		y = desc.y,
		width = desc.width,
		height = desc.height,
		title = desc.title,
        flags = desc.flags,
        id = id,
        is_alive = true,
	}
	
	NS.Application.sharedApplication()->setActivationPolicy(.Regular)

	application_delegate_cls := NS.application_delegate_register_and_alloc(ApplicationDelegateTemplate, "MyApplicationDelegate", context)
	NS.Application.sharedApplication()->setDelegate(application_delegate_cls)

	rect := NS.Rect {
		origin = {NS.Float(desc.x), NS.Float(desc.y)},
		size = {NS.Float(desc.width), NS.Float(desc.height)}
	}

	darwin_state.window->initWithContentRect(rect, {.Resizable, .Closable, .Titled, .Miniaturizable}, .Buffered, false)
	darwin_state.window->setReleasedWhenClosed(true)

	register_window(cast(WindowHandle)darwin_state.window, id)

	set_window_title(id, desc.title)
	
	darwin_state.window->setBackgroundColor(NS.Color_purpleColor())

    darwin_state.window->makeKeyAndOrderFront(nil)

    if .CenterOnOpen in desc.flags {
        darwin_state.window->center()
    }
	
	window_delegate_cls := NS.window_delegate_register_and_alloc(WindowDelegateTemplate, "MyWindowDelegate", context)
	darwin_state.window->setDelegate(window_delegate_cls)
	
	//NS.Application.sharedApplication()->activateIgnoringOtherApps(true)
	NS.Application.sharedApplication()->finishLaunching()
	NS.Application.sharedApplication()->activate()

	return id
}

// APPLICATION DELEGATE

ApplicationDelegateTemplate :: NS.ApplicationDelegateTemplate {
	applicationDidBecomeActive = application_did_become_active,
	applicationDidResignActive = application_did_resign_active,
	applicationShouldTerminate = application_should_terminate,
	applicationShouldTerminateAfterLastWindowClosed = application_should_terminate_after_last_window_closed,
	applicationDidHide = application_did_hide,
	applicationDidUnhide = application_did_unhide,
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

WindowDelegateTemplate :: NS.WindowDelegateTemplate {
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
	window_id := platform.registry.handle_to_id[cast(WindowHandle)sender_window]
	occlusion_state := sender_window->occlusionStateVisible()
	emit_window_event(DidChangeOcclusionState{
		sender = window_id,
		state = bool(occlusion_state),
	})
}

window_should_close :: proc(window: ^NS.Window) -> NS.BOOL {
	window_id := platform.registry.handle_to_id[cast(WindowHandle)window]
	emit_window_event(WindowShouldClose{
		sender = window_id,
	})
	return false
}

window_did_resize :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	size := window->frame().size
	emit_window_event(WindowDidResize{
		sender = platform.registry.handle_to_id[cast(WindowHandle)window],
		size = {int(size.width), int(size.height)}
	})
}

window_did_move :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	position := window->frame().origin
	emit_window_event(WindowDidMove{
		sender = platform.registry.handle_to_id[cast(WindowHandle)window],
		position = {int(position.x), int(position.x)}
	})
}

window_did_become_key :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	emit_window_event(WindowChangeKeyState{
		sender = platform.registry.handle_to_id[cast(WindowHandle)window],
		state = true
	})
}

window_did_resign_key :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	emit_window_event(WindowChangeKeyState{
		sender = platform.registry.handle_to_id[cast(WindowHandle)window],
		state = false
	})
}

window_did_miniaturize :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	emit_window_event(WindowChangeMiniaturizeState{
		sender = platform.registry.handle_to_id[cast(WindowHandle)window],
		state = true
	})
}

window_did_deminiaturize :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	emit_window_event(WindowChangeMiniaturizeState{
		sender = platform.registry.handle_to_id[cast(WindowHandle)window],
		state = false
	})
}

window_did_enter_full_screen :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	emit_window_event(WindowChangeFullScreenState{
		sender = platform.registry.handle_to_id[cast(WindowHandle)window],
		state = true
	})
}

window_did_exit_full_screen :: proc(notification: ^NS.Notification) {
	window := cast(^NS.Window)notification->object()
	emit_window_event(WindowChangeFullScreenState{
		sender = platform.registry.handle_to_id[cast(WindowHandle)window],
		state = false
	})
}
