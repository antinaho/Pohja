package pohja

import "core:fmt"

main :: proc() {
    init()
    id := open_window(WindowDescription{
        width = 600,
        height = 600,
        title = "Hellope",
        flags = {.MainWindow, .CenterOnOpen, .Resizable, .Decorated, .Visible},
    })
    run()
}
