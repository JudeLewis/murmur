import MurmurCore
import SwiftUI

@main
struct MurmurPhoneApp: App {
    @State private var murmur = PhoneMurmur()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(murmur: murmur)
                .onOpenURL { url in
                    if KeyboardLink.isStart(url) { murmur.openedByKeyboard() }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { murmur.openedFromKeyboard = false }
                }
        }
    }
}
