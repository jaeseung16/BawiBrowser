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
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    @Published var articleDTO = BawiArticleDTO(articleId: -1, articleTitle: "", boardId: -1, boardTitle: "", body: "")
    
    override init() {
        super.init()
    }
    
    
    
}
