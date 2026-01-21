package pohja

import "core:fmt"
import "core:mem"
import "core:log"

// For testing, should never be ran itself
main :: proc() {
    when ODIN_DEBUG {
        default_allocator := context.allocator
        tracking_allocator: mem.Tracking_Allocator
        mem.tracking_allocator_init(&tracking_allocator, default_allocator)
        context.allocator = mem.tracking_allocator(&tracking_allocator)
        defer reset_tracking_allocator(&tracking_allocator)
    }

    context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

    platform_init(1)
    id := open_window(
        width = 900,
        height = 900,
        title = "Hellope",)

    set_window_min_size(id, 400, 400)
    cursor_lock_to_window(id)
    //set_window_opacity(id, 0.66)

    set_window_mode(id, Borderless)
    
    for platform_update() {
        if input_key_went_down(.Escape) {
            application_request_shutdown()
        }

        if input_key_is_held(.A) {

        }

        if input_key_went_down(.E) {

        }
        
        if input_key_went_down(.Q) {

        }

        if input_key_went_down(.W) {

        }

        
        set_window_title(id, fmt.tprintf("%.1f ms", get_fps()))
    }

    cleanup()
}


reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> (err: bool) {
	fmt.println("Tracking allocator: ")

	for _, val in a.allocation_map {
		fmt.printfln("%v: Leaked %v bytes", val.location, val.size)
		err = true
	}

	mem.tracking_allocator_clear(a)

	return
}
