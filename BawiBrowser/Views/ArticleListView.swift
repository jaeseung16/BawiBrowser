//
//  ArticleView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/16/21.
//

import SwiftUI

struct ArticleListView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
    @State private var presentFilterItemsView = false
    @State private var presentSortItemsView = false
    
    @State private var selectedBoard: String?

    private var boards: [String] {
        var boardSet = Set<String>()
        
        viewModel.articles.compactMap { article in
            article.boardTitle
        }
        .forEach { boardTitle in
            boardSet.insert(boardTitle)
        }
        
        return Array(boardSet)
    }
    
    private var filteredArticles: Array<Article> {
        viewModel.articles.filter { article in
            if selectedBoard == nil {
                return true
            } else {
                guard let boardTitle = article.boardTitle else {
                    return false
                }
                return boardTitle == selectedBoard!
            }
        }
    }
    
    @State private var selectedArticle: Article?
    
    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                VStack {
                    header()
                    
                    Divider()
                    
                    List {
                        ForEach(filteredArticles) { article in
                            NavigationLink(tag: article, selection: $selectedArticle) {
                                ArticleDetailView(article: article)
                                    .environmentObject(viewModel)
                            } label: {
                                label(article: article)
                            }

                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let article = filteredArticles[index]
                                viewModel.delete(article)
                            }
                            viewModel.save()
                        }
                    }
                    .frame(width: geometry.size.width * 0.25)
                }
            }
            .sheet(isPresented: $presentFilterItemsView) {
                BoardFilterView(board: $selectedBoard, boards: boards)
            }
            .onChange(of: viewModel.selectedArticle) { newValue in
                guard let articleId = newValue["articleId"], let boardId = newValue["boardId"] else {
                    return
                }
                
                let article = viewModel.articles.first { $0.articleId == articleId && $0.boardId == boardId }
                if article != nil {
                    selectedBoard = nil
                    selectedArticle = article
                }
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

