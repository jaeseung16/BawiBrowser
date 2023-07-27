//
//  CommentListView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/16/21.
//

import SwiftUI

struct CommentListView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
    @State private var presentFilterItemsView = false
    @State private var presentSortItemsView = false
    
    @State private var selectedBoard: String?
    
    private var boards: [String] {
        var boardSet = Set<String>()
        
        viewModel.comments.compactMap { comment in
            comment.boardTitle
        }
        .forEach { boardTitle in
            boardSet.insert(boardTitle)
        }
        
        return Array(boardSet)
    }
    
    private var filteredComments: Array<Comment> {
        viewModel.comments.filter { comment in
            if selectedBoard == nil {
                return true
            } else {
                guard let boardTitle = comment.boardTitle else {
                    return false
                }
                return boardTitle == selectedBoard!
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                header(geometry: geometry)
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: .init(), count: 1)) {
                        ForEach(filteredComments) { comment in
                            label(comment: comment, in: geometry)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 8.0).stroke(lineWidth: 0.5))
                        }
                    }
                }
            }
            .padding()
            .sheet(isPresented: $presentFilterItemsView) {
                BoardFilterView(board: $selectedBoard, boards: boards)
            }
        }
    }
    
    private func label(comment: Comment, in geometry: GeometryProxy) -> some View {
        HStack {
            VStack {
                Text(comment.boardTitle ?? "")
                    .font(.subheadline)
                    
                HStack {
                    Text(comment.articleTitle ?? "")
                        .font(.body)
                    
                    Spacer()
                }
                
                HStack {
                    Spacer()
                    
                    Text(dateFormatter.string(from: comment.created ?? Date()))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.trailing)
            .frame(width: geometry.size.width * 0.25)
            
            Divider()
            
            Text(comment.body?.removingPercentEncoding ?? "")
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding(.leading)
                .frame(alignment: .leading)
            
            Spacer()
            
            Button {
                viewModel.delete(comment)
                viewModel.save()
            } label: {
                Image(systemName: "trash")
            }
        }
    }
    
    private func header(geometry: GeometryProxy) -> some View {
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
    }
    
    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .long
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
}
