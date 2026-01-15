package pohja

import "core:fmt"

// For testing, should never be ran itself
main :: proc() {
    platform_init(1)
    id := open_window(
        width = 800,
        height = 800,
        title = "Hellope",)

    set_window_min_size(id, 200, 200)
    set_window_max_size(id, 400, 400)

    for !platform_should_close() {
        platform_update()

        if input_key_went_down(.E) {
            s := get_monitor_count()
            fmt.println(s)
        }
        
        if input_key_went_down(.Q) {
            set_window_size(id, 100, 100)
        }

        
        if input_key_went_down(.W) {
            set_window_size(id, 800, 800)
        }
        
    }    
    cleanup()
}
