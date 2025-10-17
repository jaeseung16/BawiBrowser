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
            NavigationSplitView {
                List(selection: $selectedArticle) {
                    ForEach(filteredArticles) { article in
                        NavigationLink(value: article) {
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
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            presentFilterItemsView = true
                        } label: {
                            Label("Filter", systemImage: "line.horizontal.3.decrease.circle")
                        }
                    }
                }
            } detail: {
                if let selectedArticle = selectedArticle {
                    ArticleDetailView(article: selectedArticle)
                        .id(selectedArticle)
                        .environmentObject(viewModel)
                }
            }
            .sheet(isPresented: $presentFilterItemsView) {
                BoardFilterView(board: $selectedBoard, boards: boards)
            }
            .onChange(of: viewModel.selectedArticle) { oldValue, newValue in
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
            FilterButton {
                presentFilterItemsView = true
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private func label(article: Article) -> some View {
        VStack(alignment: .leading) {
            Text("\(article.articleTitle ?? "")")
                .font(.body)
            
            HStack {
                Spacer()
                
                Text(dateFormatter.string(from: article.created ?? Date()))
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

