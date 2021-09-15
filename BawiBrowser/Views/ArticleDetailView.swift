//
//  ArticleDetailVoew.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/20/21.
//

import SwiftUI

struct ArticleDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
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
                    
                    Text(dateFormatter.string(from: article.created!))
                        .font(.body)
                        .frame(width: geometry.size.width * 0.3)
                }
                .frame(alignment: .center)
                
                if article.lastupd != nil {
                    HStack {
                        Text("Last Update")
                            .font(.headline)
                            .frame(width: geometry.size.width * 0.16)
                        
                        Text(dateFormatter.string(from: article.lastupd!))
                            .font(.body)
                            .frame(width: geometry.size.width * 0.3)
                        
                    }
                    .frame(alignment: .center)
                }
                
                Divider()
                
                ScrollView {
                    Text(article.body?.removingPercentEncoding ?? "")
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .frame(alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if !attachments.isEmpty {
                    AttachmentListView(attachments: attachments)
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
    
    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .long
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
    
}

struct ArticleDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ArticleDetailView(article: Article())
    }
}
