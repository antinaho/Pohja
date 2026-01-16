package pohja

import "core:fmt"

// For testing, should never be ran itself
main :: proc() {
    platform_init(1)
    id := open_window(
        width = 800,
        height = 800,
        title = "Hellope",)

    set_window_min_size(id, 400, 200)
    set_window_max_size(id, 800, 800)
    cursor_lock_to_window(id)
    set_window_position(id, 0, 0)

    for platform_update() {

        if input_key_is_held(.A) {
            fmt.println(input_mouse_delta_vector(.Both))
        }

        if input_key_went_down(.E) {
            s := get_monitor_count()
            fmt.println(s)
        }
        
        if input_key_went_down(.Q) {
            show_cursor()

        }

        if input_key_went_down(.W) {
            hide_cursor()
        }

        set_window_title(id, fmt.tprintf("%v", int(get_fps())))
    }    
    cleanup()
}
