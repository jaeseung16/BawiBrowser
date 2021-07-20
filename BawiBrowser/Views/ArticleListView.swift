//
//  ArticleView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/16/21.
//

import SwiftUI

struct ArticleListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Article.created, ascending: false)],
        animation: .default)
    private var articles: FetchedResults<Article>

    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
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
                    ForEach(articles) { article in
                        HStack {
                            VStack {
                                Text(dateFormatter.string(from: article.created!))
                                
                                if article.lastupd != nil {
                                    Text(dateFormatter.string(from: article.lastupd!))
                                }
                            }
                            .frame(width: geometry.size.width * 0.16)
                            
                            VStack {
                                Text("\(article.boardTitle ?? "")")
                                    .font(.headline)
                                
                                Text("\(article.articleTitle ?? "")")
                                    .font(.subheadline)
                            }
                            .frame(width: geometry.size.width * 0.3)
                            
                            Text(article.body?.removingPercentEncoding ?? "")
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .frame(width: geometry.size.width * 0.5, alignment: .leading)
                        }
                    }
                }
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

struct ArticleListView_Previews: PreviewProvider {
    static var previews: some View {
        ArticleListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(BawiBrowserViewModel())
    }
}
