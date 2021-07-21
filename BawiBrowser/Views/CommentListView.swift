//
//  CommentListView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/16/21.
//

import SwiftUI

struct CommentListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Comment.created, ascending: false)],
        animation: .default)
    private var comments: FetchedResults<Comment>
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                HStack {
                    Text("Date")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.16)
                    Text("Board / Article")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.3)
                    Text("Comment")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.5)
                }
            
                List {
                    ForEach(comments) { comment in
                        HStack {
                            Text(dateFormatter.string(from: comment.created!))
                                .frame(width: geometry.size.width * 0.16)
                                
                            VStack {
                                Text(comment.boardTitle ?? "")
                                    .font(.headline)
                                
                                Text(comment.articleTitle ?? "")
                                    .font(.subheadline)
                            }
                            .frame(width: geometry.size.width * 0.3)
                            
                            Text(comment.body?.removingPercentEncoding ?? "")
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .frame(width: geometry.size.width * 0.5, alignment: .leading)
                        }
                    }
                    .onDelete(perform: { indexSet in
                        for index in indexSet {
                            let comment = comments[index]
                            viewContext.delete(comment)
                        }
                        
                        do {
                            try viewContext.save()
                        } catch {
                            print(error)
                        }
                    })
                }
                .listStyle(InsetListStyle())
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

struct CommentListView_Previews: PreviewProvider {
    static var previews: some View {
        CommentListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(BawiBrowserViewModel())
    }
}
