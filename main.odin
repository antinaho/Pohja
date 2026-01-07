package pohja

import "core:fmt"

main :: proc() {
    init()
    id := open_window(WindowDescription{
        width = 600,
        height = 600,
        title = "Hellope",
        window_flags = {.MainWindow, .CenterOnOpen}
    })
    run()
}
