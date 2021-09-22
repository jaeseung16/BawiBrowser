//
//  BrowserView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/16/21.
//

import SwiftUI

struct BrowserView: View {
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var url: URL
    @AppStorage("BawiBrowser.appearance") var darkMode: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    viewModel.navigation = .back
                }, label: {
                    Image(systemName: "chevron.backward")
                })
                
                Spacer()
                
                Button(action: {
                    viewModel.navigation = .home
                }, label: {
                    Image(systemName: "house")
                })
                
                Spacer()
                
                Toggle(viewModel.isDarkMode ? "dark" : "light", isOn: $darkMode)
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: darkMode) { _ in
                        viewModel.isDarkMode = darkMode
                        viewModel.navigation = .reload
                    }
                
                Spacer()
                
                Button(action: {
                    viewModel.navigation = .forward
                }, label: {
                    Image(systemName: "chevron.forward")
                })
            }
            
            WebView(url: url)
                .environmentObject(viewModel)
                .shadow(color: Color.gray, radius: 1.0)
                .colorScheme(viewModel.isDarkMode ? .dark : .light)
        }
        .padding()
    }
}

struct BrowserView_Previews: PreviewProvider {
    static var previews: some View {
        BrowserView(url: URL(string: "https://www.bawi.org/main/login.cgi")!)
            .environmentObject(BawiBrowserViewModel())
    }
}
