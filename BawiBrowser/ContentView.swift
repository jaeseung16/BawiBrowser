//
//  ContentView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/28/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Comment.created, ascending: false)],
        animation: .default)
    private var comments: FetchedResults<Comment>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Article.created, ascending: false)],
        animation: .default)
    private var articles: FetchedResults<Article>

    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
    var body: some View {
        HStack {
            
            /*
            VStack {
                Text("didStartProvisionalNavigationURL: " + viewModel.didStartProvisionalNavigationURLString)
                .padding()
             
                Text("didStartProvisionalNavigationTitle: " + viewModel.didStartProvisionalNavigationTitle)
                .padding()
                
                Spacer()
                
                Text("Comment: " + viewModel.commentDTO.description)
                .padding()
                
                Spacer()
                
                Text("didCommitURL: " + viewModel.didCommitURLString)
                .padding()
             
                Text("didCommitTitle" + viewModel.didCommitTitle)
                .padding()
                
                Spacer()
                
                Text("didFinishURL: " + viewModel.didFinishURLString)
                .padding()
             
                Text("didFinishTitle: " + viewModel.didFinishTitle)
                .padding()
                
            }
            */
            
            TabView {
                WebView(url: URL(string: "https://www.bawi.org/main/login.cgi")!)
                    .tabItem {
                        Text("Bawi")
                        
                    }
                    .environmentObject(viewModel)
                    .shadow(color: Color.gray, radius: 1.0)
                    //.border(Color.gray, width: 1.0)
                    .padding()
                
                
                ArticleListView()
                    .tabItem {
                        Text("Articles")
                    }
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(viewModel)
                
                CommentListView()
                    .tabItem {
                        Text("Comments")
                    }
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(viewModel)
                
            }
            .frame(width: 1000, height: 1200, alignment: .center)
            
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
