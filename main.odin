package pohja

import "core:fmt"

// For testing, should never be ran itself
main :: proc() {
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

        dt_ms := f64(get_deltatime_ns()) / 1_000_000
        set_window_title(id, fmt.tprintf("%.1f ms", dt_ms))
    }

    cleanup()
}
