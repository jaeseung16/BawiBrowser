//
//  ArticleView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/16/21.
//

import SwiftUI

struct ArticleListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Article.lastupd, ascending: false)],
        animation: .default)
    private var articles: FetchedResults<Article>

    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
    @State private var presentFilterItemsView = false
    @State private var presentSortItemsView = false
    
    @State private var selectedBoard: String?
    
    @State private var searchString = ""
    
    private var boards: [String] {
        var boardSet = Set<String>()
        
        articles.compactMap { article in
            article.boardTitle
        }
        .forEach { boardTitle in
            boardSet.insert(boardTitle)
        }
        
        return Array(boardSet)
    }
    
    private var filteredArticles: Array<Article> {
        articles.filter { article in
            if selectedBoard == nil {
                return true
            } else {
                guard let boardTitle = article.boardTitle else {
                    return false
                }
                return boardTitle == selectedBoard!
            }
        }
        .filter { article in
            if searchString.isEmpty {
                return true
            } else {
                return article.body?.contains(searchString) ?? false
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                VStack {
                    header()
                    
                    SearchView(searchString: $searchString)
                    
                    Divider()
                    
                    List {
                        ForEach(filteredArticles) { article in
                            NavigationLink(destination: ArticleDetailView(article: article)
                            ) {
                                label(article: article)
                            }
                        }
                        .onDelete(perform: { indexSet in
                            for index in indexSet {
                                let article = filteredArticles[index]
                                viewContext.delete(article)
                            }
                            
                            do {
                                try viewContext.save()
                            } catch {
                                print(error)
                            }
                        })
                    }
                    .frame(width: geometry.size.width * 0.25)
                }
            }
            .sheet(isPresented: $presentFilterItemsView) {
                BoardFilterView(board: $selectedBoard, boards: boards)
            }
        }
    }
    
    private func header() -> some View {
        HStack {
            Button(action: {
                presentFilterItemsView = true
            }) {
                Label("Filter", systemImage: "line.horizontal.3.decrease.circle")
            }
            
            Spacer()
            
            /*
            Button(action: {
                presentSortItemsView = true
            }) {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            */
        }
        .padding(.horizontal)
    }
    
    private func label(article: Article) -> some View {
        VStack(alignment: .leading) {
            Text("\(article.articleTitle ?? "")")
                .font(.body)
            
            HStack {
                Spacer()
                
                Text(dateFormatter.string(from: article.created!))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .long
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
}

