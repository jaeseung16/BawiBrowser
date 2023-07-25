//
//  BawiBrowserApp.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/28/21.
//

import SwiftUI

@main
struct BawiBrowserApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, appDelegate.persistence.container.viewContext)
                .environmentObject(appDelegate.viewModel)
        }
        .commands {
            CommandGroup(after: .pasteboard) {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appDelegate.viewModel.didFinishURLString, forType: .string)
                }, label: {
                    Text("Copy Link")
                })
                .keyboardShortcut("l", modifiers: [.command])
                
                Button(action: {
                    appDelegate.viewModel.enableSearch = true
                }, label: {
                    Text("Find")
                })
                .keyboardShortcut("f", modifiers: [.command])
                
                Button(action: {
                        NSApp.orderFrontCharacterPalette(nil)
                }, label: {
                    Text("Emoji & Symbols")
                })
                .keyboardShortcut(" ", modifiers: [.command, .control])
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appDelegate.viewModel)
        }
    }
}
