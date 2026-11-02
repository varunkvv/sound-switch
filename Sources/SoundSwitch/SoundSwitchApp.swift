import SwiftUI

@main
struct SoundSwitchApp: App {
    @State private var model = AudioModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environment(model)
        } label: {
            Image(systemName: model.currentOutput?.symbol(input: false) ?? "speaker.wave.2.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
