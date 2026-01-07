package pohja

main :: proc() {
    init(1)
    id := open_window(WindowDescription{
        width = 600,
        height = 600,
        title = "Hellope",
        x = 0,
        y = 300,
        window_flags = {.MainWindow, .CenterOnOpen}
    })
    run()
}