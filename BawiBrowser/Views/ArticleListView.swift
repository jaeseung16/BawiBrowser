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
                    Text("Article")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.25, alignment: .center)
                    
                    Text("Details")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.75, alignment: .center)
                }
                
                NavigationView {
                    List {
                        ForEach(articles) { article in
                            NavigationLink(destination: ArticleDetailView(article: article)) {
                                VStack {
                                    Text("\(article.articleTitle ?? "")")
                                        .font(.body)
                                        .frame(alignment: .center)
                                    
                                    Text(dateFormatter.string(from: article.created!))
                                        .font(.caption)
                                        .frame(alignment: .center)
                                }
                            }
                        }
                        .onDelete(perform: { indexSet in
                            for index in indexSet {
                                let article = articles[index]
                                viewContext.delete(article)
                            }
                            
                            do {
                                try viewContext.save()
                            } catch {
                                print(error)
                            }
                        })
                    }
                    .frame(width: geometry.size.width * 0.25)
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
