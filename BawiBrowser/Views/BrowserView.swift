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
    
    @State private var searchCounter = 0
    @State private var linkCopied = false
    
    var body: some View {
        ZStack {
            WebView(url: url)
                .environmentObject(viewModel)
                .shadow(color: Color.gray, radius: 1.0)
                .colorScheme(viewModel.isDarkMode ? .dark : .light)
            
            VStack {
                Spacer()
                
                HStack {
                    Button {
                        viewModel.navigation = .back
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .glassEffect()
                    
                    Spacer()
                    
                    Button {
                        viewModel.navigation = .home
                    } label: {
                        Image(systemName: "house")
                    }
                    .keyboardShortcut("h", modifiers: [.command])
                    .glassEffect()
                    
                    Button {
                        viewModel.navigation = .logout
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .keyboardShortcut("h", modifiers: [.command])
                    .glassEffect()
                    
                    Spacer()
                    
                    Toggle(viewModel.isDarkMode ? "dark" : "light", isOn: $darkMode)
                        .toggleStyle(SwitchToggleStyle())
                        .onChange(of: darkMode) {
                            viewModel.isDarkMode = darkMode
                            viewModel.navigation = .reload
                        }
                        .glassEffect()
                    
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.didFinishURLString, forType: .string)
                        linkCopied.toggle()
                    } label: {
                        Label("Copy Link", systemImage: "link")
                    }
                    .keyboardShortcut("l", modifiers: [.command])
                    .glassEffect()
                    
                    HStack {
                        SearchView(searchString: $viewModel.searchString)
                        
                        if viewModel.searchResultTotalCount > 0 {
                            Stepper {
                                Text("\(viewModel.searchResultCounter) of \(viewModel.searchResultTotalCount)")
                            } onIncrement: {
                                viewModel.searchResultCounter += 1
                                if viewModel.searchResultCounter >= viewModel.searchResultTotalCount {
                                    viewModel.searchResultCounter = viewModel.searchResultTotalCount
                                }
                            } onDecrement: {
                                viewModel.searchResultCounter -= 1
                                if viewModel.searchResultCounter <= 1 {
                                    viewModel.searchResultCounter = 1
                                }
                            }
                            .glassEffect()
                        }
                    }
                    .frame(width: 250)
                    
                    Button {
                        viewModel.navigation = .forward
                    } label: {
                        Image(systemName: "chevron.forward")
                    }
                    .glassEffect()
                }
                .alert("Link Copied", isPresented: $linkCopied) {
                    Button("OK") {
                        
                    }
                } message: {
                    Text("\(viewModel.didFinishURLString)")
                }
            }
            
            
        }
        .padding()
    }
}

