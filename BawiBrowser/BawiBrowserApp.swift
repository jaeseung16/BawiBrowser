//
//  BawiBrowserApp.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/28/21.
//

import SwiftUI

@main
struct BawiBrowserApp: App {
    let persistenceController = PersistenceController.shared
    let bawiBrowserViewModel = BawiBrowserViewModel.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(bawiBrowserViewModel)
        }
        .commands {
            CommandGroup(after: .pasteboard) {
                Button(action: {
                        NSApp.orderFrontCharacterPalette(nil)
                }, label: {
                    Text("Emoji & Symbols")
                })
                .keyboardShortcut(" ", modifiers: [.command, .control])
            }
        }
    }
}
