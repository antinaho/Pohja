package pohja

// Example
main :: proc() {

    init(1)

    id := open_window(WindowDescription{
        width = 600,
        height = 600,
        x = 200,
        y = 200,
        title = "Hellope",
        flags = {.MainWindow, .Resizable, .Decorated},
    })

    for !platform_should_close() {
        platform_update()
    }

    cleanup()
}

