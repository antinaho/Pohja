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
    //set_window_opacity(id, 0.66)

    p := rawptr(uintptr(id))



    for platform_update() {
        if input_key_is_held(.A) {
            id := Window_ID(uintptr(p))
            
            fmt.println(is_window_visible(id))
        }

        if input_key_went_down(.E) {
            s := get_monitor_count()
            fmt.println(s)
        }
        
        if input_key_went_down(.Q) {
            clear_window_flag(id, .Resizable)
        }

        if input_key_went_down(.W) {
            a := is_window_visible(id)
            b := is_window_hidden(id)
            fmt.println(is_window_hidden(id))
        }

        dt_ms := f64(get_deltatime_ns()) / 1_000_000
        set_window_title(id, fmt.tprintf("%.1f ms", dt_ms))
    }    
    cleanup()
}
