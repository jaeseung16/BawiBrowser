//
//  ArticleDetailVoew.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/20/21.
//

import SwiftUI

struct ArticleDetailView: View {
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    @State var article: Article
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: 10.0) {
                Text("\(article.articleTitle ?? "")")
                    .font(.title2)
                    .frame(width: geometry.size.width * 0.5, alignment: .center)
                
                HStack {
                    Text("Board")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.16)
                    
                    Text("\(article.boardTitle ?? "")")
                        .font(.body)
                        .frame(width: geometry.size.width * 0.3)
                }
                .frame(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                
                HStack {
                    Text("Created")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.16)
                    
                    Text(article.created ?? Date(), format: .dateTime)
                        .font(.body)
                        .frame(width: geometry.size.width * 0.3)
                }
                .frame(alignment: .center)
                
                if article.lastupd != nil {
                    HStack {
                        Text("Last Update")
                            .font(.headline)
                            .frame(width: geometry.size.width * 0.16)
                        
                        Text(article.lastupd!, format: .dateTime)
                            .font(.body)
                            .frame(width: geometry.size.width * 0.3)
                    }
                    .frame(alignment: .center)
                }
                
                Divider()
                
                if viewModel.articleAsHtml {
                    ArticleWebView(htmlBody: article.body ?? "")
                        .frame(maxHeight: 0.75 * geometry.size.height, alignment: .center)
                } else {
                    ScrollView {
                        Text(LocalizedStringKey(article.body?.removingPercentEncoding ?? ""))
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                            .frame(alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                if !attachments.isEmpty {
                    AttachmentListView(attachments: attachments)
                        .environmentObject(viewModel)
                }
            }
            .frame(height: geometry.size.height, alignment: .top)
            .padding()
        }
    }
    
    private var attachments: [Attachment] {
        if let attachments = article.attachments, attachments.count > 0 {
            return attachments.map {$0 as! Attachment}
        } else {
            return [Attachment]()
        }
    }
    
}
