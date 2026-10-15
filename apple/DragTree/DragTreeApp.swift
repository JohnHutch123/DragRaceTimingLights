// Drag Tree: a drag racing start tree for practising reaction times.
// One SwiftUI app for iPhone, iPad and Mac.

import SwiftUI

@main
struct DragTreeApp: App {
    #if os(iOS)
    @StateObject private var model = TreeModel(multiTouch: true)
    #else
    @StateObject private var model = TreeModel(multiTouch: false)
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
