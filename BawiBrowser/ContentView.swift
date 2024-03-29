//
//  ContentView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/28/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject private var viewModel: BawiBrowserViewModel
    @Environment(\.managedObjectContext) private var viewContext

    @AppStorage("BawiBrowser.appearance")
    var appearance: BawiBrowserAppearance = .light
    
    @State private var selectedTab: String?
    @State private var searchString = ""
    
    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            BrowserView(url: URL(string: "https://www.bawi.org/main/login.cgi")!)
                .tabItem {
                    Text("Bawi")
                }
                .tag(BawiBrowserTab.browser)
            
            ArticleListView()
                .tabItem {
                    Text("Articles")
                }
                .tag(BawiBrowserTab.articles)
            
            CommentListView()
                .tabItem {
                    Text("Comments")
                }
                .tag(BawiBrowserTab.comments)
            
            NoteListView()
                .tabItem {
                    Text("Notes")
                }
                .tag(BawiBrowserTab.notes)
        }
        .frame(minWidth: 800, idealWidth: 1000, maxWidth: 1280, minHeight: 600, idealHeight: 1200, maxHeight: 1440, alignment: .center)
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("Unable to Save Data"),
                  message: Text(viewModel.message),
                  dismissButton: .default(Text("Dismiss")))
        }
        .searchable(text: $searchString)
        .onChange(of: searchString) { newValue in
            viewModel.search(newValue)
        }
        .onChange(of: viewModel.selectedTab) { _ in
            searchString = ""
            viewModel.cancelSearch()
        }
        
    }
    
    private func getHttpBody() -> String {
        if let httpBodyString = String(data: viewModel.httpBody, encoding: .utf8) {
            return httpBodyString
        } else {
            return String()
        }
    }
    
    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .long
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }

    /*
    private func addItem() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    */
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()
