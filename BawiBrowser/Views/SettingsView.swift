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
                }
                Spacer()
            }
            Spacer()
        }
        .frame(width: 300)
        .navigationTitle("Bawi Browser Settings")
        .padding(80)
        .onChange(of: useKeychain) { newValue in
            if !useKeychain {
                viewModel.deleteCredentials()
            }
        }
    }
}
