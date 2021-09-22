//
//  CommentListView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/16/21.
//

import SwiftUI

struct CommentListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Comment.created, ascending: false)],
        animation: .default)
    private var comments: FetchedResults<Comment>
    
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
    @State private var presentFilterItemsView = false
    @State private var presentSortItemsView = false
    
    @State private var selectedBoard: String?
    
    @State private var searchString = ""
    
    private var boards: [String] {
        var boardSet = Set<String>()
        
        comments.compactMap { comment in
            comment.boardTitle
        }
        .forEach { boardTitle in
            boardSet.insert(boardTitle)
        }
        
        return Array(boardSet)
    }
    
    private var filteredComments: Array<Comment> {
        comments.filter { comment in
            if selectedBoard == nil {
                return true
            } else {
                guard let boardTitle = comment.boardTitle else {
                    return false
                }
                return boardTitle == selectedBoard!
            }
        }
        .filter { comment in
            if searchString.isEmpty {
                return true
            } else {
                return comment.body?.contains(searchString) ?? false
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                header(geometry: geometry)
            
                SearchView(searchString: $searchString)
                
                List {
                    ForEach(filteredComments) { comment in
                        label(comment: comment, in: geometry)
                    }
                    .onDelete(perform: { indexSet in
                        for index in indexSet {
                            let comment = filteredComments[index]
                            viewContext.delete(comment)
                        }
                        
                        do {
                            try viewContext.save()
                        } catch {
                            print(error)
                        }
                    })
                    .onReceive(viewModel.$changedPeristentContext) { _ in
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .listStyle(InsetListStyle())
                
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
                    
                    Text(dateFormatter.string(from: comment.created!))
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

struct CommentListView_Previews: PreviewProvider {
    static var previews: some View {
        CommentListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(BawiBrowserViewModel())
    }
}
