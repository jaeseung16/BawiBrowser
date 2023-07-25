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
        Form {
            Section(header: Text("Login")) {
                Toggle("Use keychain", isOn: $useKeychain)
            }
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
