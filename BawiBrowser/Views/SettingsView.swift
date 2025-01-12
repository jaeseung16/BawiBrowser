//
//  SettingsView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/23/23.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    @AppStorage("BawiBrowser.useKeychain") private var useKeychain: Bool = false
    @AppStorage("BawiBrowser.spotlightIndexing") private var spotlightIndexing: Bool = false
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Form {
                    Picker("Use Keychain:", selection: $useKeychain) {
                        Text("Yes").tag(true)
                        Text("No").tag(false)
                    }
                    .pickerStyle(.inline)
                    Button("Refresh Spotlight Indices") {
                        print("SettingsView: spotlightIndexing=\(spotlightIndexing)")
                        spotlightIndexing = false
                    }
                }
                Spacer()
            }
            Spacer()
        }
        .frame(width: 300)
        .navigationTitle("Bawi Browser Settings")
        .padding(80)
        .onChange(of: useKeychain) {
            if !useKeychain {
                viewModel.deleteCredentials()
            }
        }
    }
}
