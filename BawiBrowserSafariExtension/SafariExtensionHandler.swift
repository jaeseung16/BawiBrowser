//
//  SafariExtensionHandler.swift
//  BawiBrowserSafariExtension
//
//  Created by Jae Seung Lee on 7/25/21.
//

import SafariServices

class SafariExtensionHandler: SFSafariExtensionHandler {
    
    private let attachments = ["attach1", "attach2", "attach3", "attach4", "attach5", "attach6", "attach7", "attach8", "attach9", "attach10"]
    
    private let viewContext = PersistenceController.shared.container.viewContext
    
    private static var articleDTO: BawiArticleDTO?
    private static var attachedData: [Data]?
    private static var downloading: Bool = false
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        // This method will be called when a content script provided by your extension calls safari.extension.dispatchMessage("message").
        page.getPropertiesWithCompletionHandler { properties in
            NSLog("The extension received a message (\(messageName)) from a script injected into (\(String(describing: properties?.url))) with userInfo (\(userInfo ?? [:]))")
            
            // Assume that attachments do not come before article
            if self.attachments.contains(messageName) {
                if SafariExtensionHandler.articleDTO != nil {
                    if let userInfo = userInfo, userInfo["data"] != nil, let data = userInfo["data"] as? [UInt8] {
                        let attachment = Data(data)
                        
                        if SafariExtensionHandler.attachedData == nil {
                            SafariExtensionHandler.attachedData = [Data]()
                        }
                        SafariExtensionHandler.attachedData!.append(attachment)
                    }
                }
            }
            
            if SafariExtensionHandler.articleDTO != nil, let properties = properties {
                if let url = properties.url, url.absoluteString.contains("read.cgi") {
                    let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    
                    if let queryItems = urlComponents?.queryItems {
                        for queryItem in queryItems {
                            if queryItem.name == "aid", let aid = queryItem.value {
                                NSLog("aid = \(aid)")
                                SafariExtensionHandler.articleDTO!.articleId = Int(aid)!
                            }
                        }
                    }
                    
                    if SafariExtensionHandler.attachedData != nil && SafariExtensionHandler.articleDTO!.attachCount != SafariExtensionHandler.attachedData!.count {
                        NSLog("WARNING: \(String(describing: SafariExtensionHandler.articleDTO!.attachCount)) files are expected. But \(SafariExtensionHandler.attachedData!.count) files have been downloaded")
                    }
                    
                    SafariExtensionHandler.articleDTO!.attachments = SafariExtensionHandler.attachedData
                    
                    NSLog("articleDTO = \(String(describing: SafariExtensionHandler.articleDTO))")
                    
                    self.populateArticle(from: SafariExtensionHandler.articleDTO!)
                    
                    SafariExtensionHandler.articleDTO = nil
                    SafariExtensionHandler.attachedData = nil
                }
            }
            
            if messageName == "writeForm", let userInfo = userInfo {
                var articleId = -1
                if let properties = properties, let url = properties.url, url.absoluteString.contains("edit.cgi") {
                    NSLog("edit.cgi: url.query = \(String(describing: url.query))")
                    if let query = url.query {
                        let queries = query.split(separator: ";")
                        for q in queries {
                            let keyValue = q.split(separator: "=")
                            NSLog("keyValue = \(keyValue[0]) \(keyValue[1])")
                            if keyValue[0] == "aid" {
                                articleId = Int(keyValue[1]) ?? -1
                            }
                        }
                    } 
                }
                
                _ = userInfo["action"] as? String
                let bid = userInfo["bid"] as? String
                let body = userInfo["body"] as? String
                let articleTitle = userInfo["title"] as? String
                let boardTitle = userInfo["boardTitle"] as? String
                let attachCount = userInfo["attach-count"] as? String
                
                SafariExtensionHandler.articleDTO = BawiArticleDTO(articleId: articleId,
                                            articleTitle: articleTitle ?? "",
                                            boardId: bid != nil ? Int(bid!)! : -1,
                                            boardTitle: boardTitle ?? "",
                                            body: body ?? "",
                                            attachCount: attachCount != nil ? Int(attachCount!)! : 0)
                
                NSLog("articleDTO = \(String(describing: SafariExtensionHandler.articleDTO))")
            }
            
            if messageName == "commentForm", let userInfo = userInfo {
                _ = userInfo["action"] as? String
                let aid = userInfo["aid"] as? String ?? ""
                let bid = userInfo["bid"] as? String ?? ""
                let body = userInfo["body"] as? String
                let articleTitle = userInfo["articleTitle"] as? String
                let boardTitle = userInfo["boardTitle"] as? String
                
                let commentDTO = BawiCommentDTO(articleId: Int(aid) ?? -1,
                                                articleTitle: articleTitle ?? "",
                                                boardId: Int(bid) ?? -1,
                                                boardTitle: boardTitle ?? "",
                                                body: body ?? "")
                
                NSLog("commentDTO = \(commentDTO)")
                
                let comment = Comment(context: self.viewContext)
                comment.articleId = Int64(commentDTO.articleId)
                comment.articleTitle = commentDTO.articleTitle
                comment.boardId = Int64(commentDTO.boardId)
                comment.boardTitle = commentDTO.boardTitle
                comment.body = commentDTO.body
                comment.created = Date()
                
                do {
                    try self.saveContext()
                } catch {
                    let nsError = error as NSError
                    NSLog("While saving \(commentDTO) occured an unresolved error \(nsError), \(nsError.userInfo)")
                }
            }
            
            if messageName == "noteForm", let userInfo = userInfo {
                let action = userInfo["action"] as? String
                let to = userInfo["to"] as? String
                let msg = userInfo["msg"] as? String
                
                if msg != nil && !(msg!.isEmpty) {
                    let noteDTO = BawiNoteDTO(action: action ?? "",
                                              to: to ?? "",
                                              msg: msg!)
                    
                    NSLog("noteDTO = \(noteDTO)")
                    
                    let note = Note(context: self.viewContext)
                    note.action = noteDTO.action
                    note.to = noteDTO.to
                    note.msg = noteDTO.msg
                    note.created = Date()
                    
                    do {
                        try self.saveContext()
                    } catch {
                        let nsError = error as NSError
                        NSLog("While saving \(noteDTO) occured an unresolved error \(nsError), \(nsError.userInfo)")
                    }
                }
            }
        }
    }
    
    private func saveContext() throws -> Void {
        viewContext.transactionAuthor = "Safari Extension"
        try viewContext.save()
        viewContext.transactionAuthor = nil
    }

    private func populateArticle(from articleDTO: BawiArticleDTO) -> Void {
        if articleDTO.articleId > 0, let existingArticle = getArticle(boardId: articleDTO.boardId, articleId: articleDTO.articleId) {
            existingArticle.articleId = Int64(articleDTO.articleId)
            existingArticle.articleTitle = articleDTO.articleTitle
            existingArticle.boardId = Int64(articleDTO.boardId)
            existingArticle.boardTitle = articleDTO.boardTitle
            existingArticle.body = articleDTO.body
            existingArticle.lastupd = Date()
            
            if let attachments = articleDTO.attachments, !attachments.isEmpty {
                for attachment in attachments {
                    let attachmentEntity = Attachment(context: viewContext)

                    attachmentEntity.article = existingArticle
                    attachmentEntity.content = attachment
                    attachmentEntity.created = Date()
                }
            }
            
        } else {
            let article = Article(context: viewContext)
            article.articleId = Int64(articleDTO.articleId)
            article.articleTitle = articleDTO.articleTitle
            article.boardId = Int64(articleDTO.boardId)
            article.boardTitle = articleDTO.boardTitle
            article.body = articleDTO.body
            article.created = Date()
            article.lastupd = Date()
            
            if let attachments = articleDTO.attachments, !attachments.isEmpty {
                for attachment in attachments {
                    let attachmentEntity = Attachment(context: viewContext)

                    attachmentEntity.article = article
                    attachmentEntity.content = attachment
                    attachmentEntity.created = Date()
                    
                }
                NSLog("attachments.count = \(attachments.count)")
            }
            
            NSLog("article = \(article)")
        }
        
        do {
            try saveContext()
        } catch {
            let nsError = error as NSError
            NSLog("While saving \(articleDTO) occured an unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func getArticle(boardId: Int, articleId: Int) -> Article? {
        let predicate = NSPredicate(format: "boardId == %@ AND articleId == %@", argumentArray: [boardId, articleId])
        
        let fetchRequest = NSFetchRequest<Article>(entityName: "Article")
        fetchRequest.predicate = predicate
        
        var fetchedArticles = [Article]()
        do {
            fetchedArticles = try viewContext.fetch(fetchRequest)
        } catch {
            let nsError = error as NSError
            NSLog("Failed to fetch article with boardId = \(boardId) and articleId = \(articleId): \(nsError)")
        }
        
        return fetchedArticles.isEmpty ? nil : fetchedArticles[0]
    }
    
    override func toolbarItemClicked(in window: SFSafariWindow) {
        // This method will be called when your toolbar item is clicked.
        NSLog("The extension's toolbar item was clicked")
    }
    
    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        // This is called when Safari's state changed in some way that would require the extension's toolbar item to be validated again.
        validationHandler(true, "")
    }
    
    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }

}
