//
//  SafariExtensionHandler.swift
//  BawiBrowserSafariExtension
//
//  Created by Jae Seung Lee on 7/25/21.
//

import SafariServices
import Persistence
import os

class SafariExtensionHandler: SFSafariExtensionHandler {
    
    private let logger = Logger()
    
    private let attachments = ["attach1", "attach2", "attach3", "attach4", "attach5", "attach6", "attach7", "attach8", "attach9", "attach10"]
    
    private let viewContext = Persistence(name: BawiBrowserConstants.appName.rawValue, identifier: BawiBrowserConstants.iCloudIdentifier.rawValue).container.viewContext
    
    private static var articleDTO: BawiArticleDTO?
    private static var attachedData: [Data]?
    private static var downloading: Bool = false
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        // This method will be called when a content script provided by your extension calls safari.extension.dispatchMessage("message").
        Task {
            let properties = await page.properties()
            
            logger.log("The extension received a message (\(messageName)) from a script injected into (\(String(describing: properties?.url))) with userInfo (\(userInfo ?? [:]))")
            
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
                saveArticle(properties)
            }
            
            if messageName == "writeForm", let properties = properties, let userInfo = userInfo {
                populateArticle(properties, userInfo)
            }
            
            if messageName == "commentForm", let userInfo = userInfo {
                saveComment(userInfo)
            }
            
            if messageName == "noteForm", let userInfo = userInfo {
                saveNote(userInfo)
            }
        }
    }
    
    private func saveContext() throws -> Void {
        viewContext.transactionAuthor = "Safari Extension"
        try viewContext.save()
        viewContext.transactionAuthor = nil
    }

    private func saveArticle(from articleDTO: BawiArticleDTO) -> Void {
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
                logger.log("attachments.count = \(attachments.count)")
            }
            
            logger.log("article = \(article)")
        }
        
        do {
            try saveContext()
        } catch {
            logger.log("While saving \(articleDTO) occured an unresolved error \(error.localizedDescription)")
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
            logger.log("Failed to fetch article with boardId = \(boardId) and articleId = \(articleId): \(error.localizedDescription)")
        }
        
        return fetchedArticles.isEmpty ? nil : fetchedArticles[0]
    }
    
    private func populateAttachedData(_ info: [String: Any]) {
        if SafariExtensionHandler.articleDTO != nil {
            if info["data"] != nil, let data = info["data"] as? [UInt8] {
                let attachment = Data(data)
                
                if SafariExtensionHandler.attachedData == nil {
                    SafariExtensionHandler.attachedData = [Data]()
                }
                SafariExtensionHandler.attachedData!.append(attachment)
            }
        }
    }
    
    private func saveArticle(_ properties: SFSafariPageProperties) {
        if let url = properties.url, url.absoluteString.contains("read.cgi") {
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            
            if let queryItems = urlComponents?.queryItems {
                for queryItem in queryItems {
                    if queryItem.name == "aid", let aid = queryItem.value {
                        logger.log("aid = \(aid)")
                        SafariExtensionHandler.articleDTO!.articleId = Int(aid)!
                    }
                }
            }
            
            if SafariExtensionHandler.attachedData != nil && SafariExtensionHandler.articleDTO!.attachCount != SafariExtensionHandler.attachedData!.count {
                logger.log("WARNING: \(String(describing: SafariExtensionHandler.articleDTO!.attachCount)) files are expected. But \(SafariExtensionHandler.attachedData!.count) files have been downloaded")
            }
            
            SafariExtensionHandler.articleDTO!.attachments = SafariExtensionHandler.attachedData
            
            logger.log("articleDTO = \(String(describing: SafariExtensionHandler.articleDTO))")
            
            self.saveArticle(from: SafariExtensionHandler.articleDTO!)
            
            SafariExtensionHandler.articleDTO = nil
            SafariExtensionHandler.attachedData = nil
        }
    }
    
    private func readArticle(_ properties: SFSafariPageProperties) {
        if let url = properties.url, url.absoluteString.contains("read.cgi") {
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            
            if let queryItems = urlComponents?.queryItems {
                for queryItem in queryItems {
                    if queryItem.name == "aid", let aid = queryItem.value {
                        logger.log("aid = \(aid)")
                        SafariExtensionHandler.articleDTO!.articleId = Int(aid)!
                    }
                }
            }
            
            if SafariExtensionHandler.attachedData != nil && SafariExtensionHandler.articleDTO!.attachCount != SafariExtensionHandler.attachedData!.count {
                logger.log("WARNING: \(String(describing: SafariExtensionHandler.articleDTO!.attachCount)) files are expected. But \(SafariExtensionHandler.attachedData!.count) files have been downloaded")
            }
            
            SafariExtensionHandler.articleDTO!.attachments = SafariExtensionHandler.attachedData
            
            logger.log("articleDTO = \(String(describing: SafariExtensionHandler.articleDTO))")
            
            self.saveArticle(from: SafariExtensionHandler.articleDTO!)
            
            SafariExtensionHandler.articleDTO = nil
            SafariExtensionHandler.attachedData = nil
        }
    }
    
    private func populateArticle(_ properties: SFSafariPageProperties, _ info: [String: Any]) {
        var articleId = -1
        if let url = properties.url, url.absoluteString.contains("edit.cgi") {
            logger.log("edit.cgi: url.query = \(String(describing: url.query))")
            if let query = url.query {
                let queries = query.split(separator: ";")
                for q in queries {
                    let keyValue = q.split(separator: "=")
                    logger.log("keyValue = \(keyValue[0]) \(keyValue[1])")
                    if keyValue[0] == "aid" {
                        articleId = Int(keyValue[1]) ?? -1
                    }
                }
            }
        }
        
        let bid = info["bid"] as? String
        let body = info["body"] as? String
        let articleTitle = info["title"] as? String
        let boardTitle = info["boardTitle"] as? String
        let attachCount = info["attach-count"] as? String
        
        SafariExtensionHandler.articleDTO = BawiArticleDTO(articleId: articleId,
                                                           articleTitle: articleTitle ?? "",
                                                           boardId: bid != nil ? Int(bid!)! : -1,
                                                           boardTitle: boardTitle ?? "",
                                                           body: body ?? "",
                                                           attachCount: attachCount != nil ? Int(attachCount!)! : 0)
        
        logger.log("articleDTO = \(String(describing: SafariExtensionHandler.articleDTO))")
    }
    
    private func saveComment(_ info: [String : Any]) {
        let aid = info["aid"] as? String ?? ""
        let bid = info["bid"] as? String ?? ""
        let body = info["body"] as? String
        let articleTitle = info["articleTitle"] as? String
        let boardTitle = info["boardTitle"] as? String
        
        let commentDTO = BawiCommentDTO(articleId: Int(aid) ?? -1,
                                        articleTitle: articleTitle ?? "",
                                        boardId: Int(bid) ?? -1,
                                        boardTitle: boardTitle ?? "",
                                        body: body ?? "")
        
        logger.log("commentDTO = \(commentDTO)")
        
        let comment = Comment(context: self.viewContext)
        comment.articleId = Int64(commentDTO.articleId)
        comment.articleTitle = commentDTO.articleTitle
        comment.boardId = Int64(commentDTO.boardId)
        comment.boardTitle = commentDTO.boardTitle
        comment.body = commentDTO.body
        comment.created = Date()
        
        do {
            try saveContext()
        } catch {
            logger.log("While saving \(commentDTO) occured an unresolved error \(error.localizedDescription)")
        }
    }
    
    private func saveNote(_ info: [String : Any]) {
        if let msg = info["msg"] as? String, !(msg.isEmpty) {
            let noteDTO = BawiNoteDTO(action: info["action"] as? String ?? "",
                                      to: info["to"] as? String ?? "",
                                      msg: msg)
            logger.log("noteDTO = \(noteDTO)")
            
            let note = Note(context: self.viewContext)
            note.action = noteDTO.action
            note.to = noteDTO.to
            note.msg = noteDTO.msg
            note.created = Date()
            
            do {
                try saveContext()
            } catch {
                logger.log("Error occured while saving \(noteDTO): \(error.localizedDescription)")
            }
        }
    }
    
    override func toolbarItemClicked(in window: SFSafariWindow) {
        // This method will be called when your toolbar item is clicked.
        logger.log("The extension's toolbar item was clicked")
    }
    
    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        // This is called when Safari's state changed in some way that would require the extension's toolbar item to be validated again.
        validationHandler(true, "")
    }
    
    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }

}
