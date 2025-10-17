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
    @Namespace var namespace
    
    private let navigation = "navigation"
    private let tools = "tools"
    
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
                    Spacer()
                    if viewModel.searchResultTotalCount > 0 {
                        searchResultCounterStepper
                    }
                }
                
                HStack {
                    toolContainer
                    Spacer()
                    navigationContainer
                }
            }
        }
        .padding()
        .alert("Link Copied", isPresented: $linkCopied) {
            Button("OK") {
                
            }
        } message: {
            Text("\(viewModel.didFinishURLString)")
        }
    }
    
    private var toolContainer: some View {
        GlassEffectContainer {
            HStack {
                Toggle(isOn: $darkMode) {
                    Text(viewModel.isDarkMode ? "dark" : "light")
                }
                .toggleStyle(.switch)
                .padding(5.0)
                .glassEffect()
                .onChange(of: darkMode) {
                    viewModel.isDarkMode = darkMode
                    viewModel.navigation = .reload
                }
                .glassEffectUnion(id: tools, namespace: namespace)
                
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.didFinishURLString, forType: .string)
                    linkCopied.toggle()
                } label: {
                    Label("Copy Link", systemImage: "link")
                }
                .keyboardShortcut("l", modifiers: [.command])
                .padding(5.0)
                .glassEffect()
                .glassEffectUnion(id: tools, namespace: namespace)
            }
        }
    }
    
    private var navigationContainer: some View {
        GlassEffectContainer {
            HStack {
                Button {
                    viewModel.navigation = .back
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .padding(5.0)
                .glassEffect()
                .glassEffectUnion(id: navigation, namespace: namespace)
                
                Button {
                    viewModel.navigation = .home
                } label: {
                    Image(systemName: "house")
                }
                .keyboardShortcut("h", modifiers: [.command])
                .padding(5.0)
                .glassEffect()
                .glassEffectUnion(id: navigation, namespace: namespace)
                
                Button {
                    viewModel.navigation = .logout
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
                .keyboardShortcut("h", modifiers: [.command])
                .padding(5.0)
                .glassEffect()
                .glassEffectUnion(id: navigation, namespace: namespace)
                
                Button {
                    viewModel.navigation = .forward
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .padding(5.0)
                .glassEffect()
                .glassEffectUnion(id: navigation, namespace: namespace)
            }
        }
    }
    
    private var searchResultCounterStepper: some View {
        Stepper {
            Text("\(viewModel.searchResultCounter) of \(viewModel.searchResultTotalCount)")
        } onIncrement: {
            incrementSearchResultCounter()
        } onDecrement: {
            decrementSearchResultCounter()
        }
        .padding(5.0)
        .glassEffect()
    }
    
    private func incrementSearchResultCounter() {
        viewModel.searchResultCounter += 1
        if viewModel.searchResultCounter >= viewModel.searchResultTotalCount {
            viewModel.searchResultCounter = viewModel.searchResultTotalCount
        }
    }
    
    private func decrementSearchResultCounter() {
        viewModel.searchResultCounter -= 1
        if viewModel.searchResultCounter <= 1 {
            viewModel.searchResultCounter = 1
        }
    }
}

