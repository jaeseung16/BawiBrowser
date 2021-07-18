//
//  BawiBrowserViewModel.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/29/21.
//

import Foundation
import WebKit
import Combine

class BawiBrowserViewModel: NSObject, ObservableObject {
    static let shared = BawiBrowserViewModel()
    
    @Published var httpCookies = [HTTPCookie]()
    @Published var innerHTML = String()
    @Published var httpBody = Data()
    
    @Published var didStartProvisionalNavigationURLString = String()
    @Published var didStartProvisionalNavigationTitle = String()
    @Published var didCommitURLString = String()
    @Published var didCommitTitle = String()
    @Published var didFinishURLString = String()
    @Published var didFinishTitle = String()
    
    @Published var commentDTO = BawiCommentDTO(articleId: -1, articleTitle: "", boardId: -1, boardTitle: "", body: "") {
        didSet {
            let comment = Comment(context: PersistenceController.shared.container.viewContext)
            comment.articleId = Int64(commentDTO.articleId)
            comment.articleTitle = commentDTO.articleTitle
            comment.boardId = Int64(commentDTO.boardId)
            comment.boardTitle = commentDTO.boardTitle
            comment.body = commentDTO.body.replacingOccurrences(of: "+", with: "%20")
            comment.created = Date()
            
            do {
                try PersistenceController.shared.container.viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                print("While saving \(comment) occured an unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    @Published var articleDTO = BawiArticleDTO(articleId: -1, articleTitle: "", boardId: -1, boardTitle: "", body: "") {
        didSet {
            
            if let existingArticle = getArticle(boardId: articleDTO.boardId, articleId: articleDTO.articleId) {
                existingArticle.articleId = Int64(articleDTO.articleId)
                existingArticle.articleTitle = articleDTO.articleTitle
                existingArticle.boardId = Int64(articleDTO.boardId)
                existingArticle.boardTitle = articleDTO.boardTitle
                existingArticle.body = articleDTO.body
            } else {
                let article = Article(context: PersistenceController.shared.container.viewContext)
                article.articleId = Int64(articleDTO.articleId)
                article.articleTitle = articleDTO.articleTitle
                article.boardId = Int64(articleDTO.boardId)
                article.boardTitle = articleDTO.boardTitle
                article.body = articleDTO.body
                article.created = Date()
            }
            
            do {
                try saveContext()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                print("While saving \(articleDTO) occured an unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    override init() {
        super.init()
    }
    
    private func saveContext() throws -> Void {
        try PersistenceController.shared.container.viewContext.save()
    }
    
    func getArticle(boardId: Int, articleId: Int) -> Article? {
        print("boardId = \(boardId), articleId = \(articleId)")
        let predicate = NSPredicate(format: "boardId == %@ AND articleId == %@", argumentArray: [boardId, articleId])
        
        let fetchRequest = NSFetchRequest<Article>(entityName: "Article")
        fetchRequest.predicate = predicate
        
        var fetchedArticles = [Article]()
        do {
            fetchedArticles = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            
            print("fetchedArticle = \(fetchedArticles)")
        } catch {
            fatalError("Failed to fetch article: \(error)")
        }
        
        return fetchedArticles.isEmpty ? nil : fetchedArticles[0]
    }
}
