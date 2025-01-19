//
//  CommentDetailView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 1/12/25.
//

import SwiftUI

struct CommentDetailView: View {
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
    let comment: Comment
    let geometry: GeometryProxy
    
    var body: some View {
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
            
            Text(LocalizedStringKey(comment.body?.removingPercentEncoding ?? ""))
                .font(.body)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
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
    
    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .long
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
}
