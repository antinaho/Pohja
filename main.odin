package pohja

main :: proc() {
    init(1)
    id := open_window(Window_Description{
        width = 600,
        height = 600,
        title = "Hellope",
        flags = {.MainWindow, .Resizable, .Decorated},
    })

    for !platform_should_close() {
        platform_update()
    }
    cleanup()
}
