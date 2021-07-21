//
//  ArticleDetailVoew.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/20/21.
//

import SwiftUI

struct ArticleDetailView: View {
    @State var article: Article
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: 10.0) {
                    HStack {
                        Text("\(article.articleTitle ?? "")")
                            .font(.title2)
                            .frame(width: geometry.size.width * 0.5)
                    }
                    .frame(alignment: .center)
                    
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
                    .frame(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                    
                    if article.lastupd != nil {
                        HStack {
                            Text("Last Update")
                                .font(.headline)
                                .frame(width: geometry.size.width * 0.16)
         
                            Text(dateFormatter.string(from: article.lastupd!))
                                .font(.body)
                                .frame(width: geometry.size.width * 0.3)

                        }
                        .frame(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                    }
                    
                    Divider()
                    
                    Text(article.body?.removingPercentEncoding ?? "")
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .frame(alignment: .leading)
                    
                    ForEach(0..<attachments.count) { index in
                        attachementView(attachment: attachments[index])
                    }
                    .frame(alignment: .center)

                }
                .frame(height: geometry.size.height, alignment: .top)
            }
            
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
    
    private func attachementView(attachment: Attachment) -> some View {
        GeometryReader { geometry in
            HStack {
                Text(dateFormatter.string(from: attachment.created!))
                    .font(.caption)
                    .frame(width: geometry.size.width * 0.16)
                
                if let image = NSImage(data: attachment.content!) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * 0.75)
                }
            }
        }
    }
}

struct ArticleDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ArticleDetailView(article: Article())
    }
}
