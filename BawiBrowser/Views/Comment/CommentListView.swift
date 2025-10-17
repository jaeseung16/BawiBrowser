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
                            CommentDetailView(comment: comment, geometry: geometry)
                                .id(comment)
                                .environmentObject(viewModel)
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
    
    private func header(geometry: GeometryProxy) -> some View {
        HStack {
            FilterButton {
                presentFilterItemsView = true
            }
            
            Spacer()
        }
    }

}
