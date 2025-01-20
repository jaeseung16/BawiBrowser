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
    
    private let persister: SafariExtensionPersister = SafariExtensionPersister()
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        // This method will be called when a content script provided by your extension calls safari.extension.dispatchMessage("message").
        Task {
            let properties = await page.properties()
            
            logger.log("The extension received a message (\(messageName)) from a script injected into (\(String(describing: properties?.url))) with userInfo (\(userInfo ?? [:]))")
            
            // Assume that attachments do not come before article
            if self.attachments.contains(messageName) {
                if await persister.isAricleAvailable() {
                    if let userInfo = userInfo, userInfo["data"] != nil, let data = userInfo["data"] as? [UInt8] {
                        let attachment = Data(data)
                        await persister.addAttachments(attachment)
                    }
                }
            }
            
            if await persister.isAricleAvailable(), let properties = properties {
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
    
    private func saveArticle(_ properties: SFSafariPageProperties) {
        Task {
            if let url = properties.url, url.absoluteString.contains("read.cgi") {
                let articleId = findArticleId(from: url)
                await persister.saveArticle(articleId)
            }
        }
    }
    
    private func findArticleId(from url: URL) -> Int {
        var articleId = -1
        
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let queryItems = urlComponents?.queryItems {
            for queryItem in queryItems {
                if queryItem.name == "aid", let aid = queryItem.value {
                    articleId = Int(aid)!
                    break
                }
            }
        }
        
        logger.log("articleId = \(articleId)")
        return articleId
    }
    
    private func populateArticle(_ properties: SFSafariPageProperties, _ info: [String: Any]) {
        Task {
            var articleId = -1
            if let url = properties.url, url.absoluteString.contains("edit.cgi") {
                articleId = findArticleId(from: url)
            }
            
            let bid = info["bid"] as? String
            let body = info["body"] as? String
            let articleTitle = info["title"] as? String
            let boardTitle = info["boardTitle"] as? String
            let attachCount = info["attach-count"] as? String
            
            let articleDTO = BawiArticleDTO(articleId: articleId,
                                            articleTitle: articleTitle ?? "",
                                            boardId: bid != nil ? Int(bid!)! : -1,
                                            boardTitle: boardTitle ?? "",
                                            body: body ?? "",
                                            attachCount: attachCount != nil ? Int(attachCount!)! : 0)
            
            logger.log("articleDTO = \(articleDTO)")
            await persister.populate(article: articleDTO)
        }
    }
    
    private func saveComment(_ info: [String : Any]) -> Void {
        Task {
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
            
            await persister.save(comment: commentDTO)
        }
    }
    
    private func saveNote(_ info: [String : Any]) -> Void {
        Task {
            if let msg = info["msg"] as? String, !(msg.isEmpty) {
                let noteDTO = BawiNoteDTO(action: info["action"] as? String ?? "",
                                          to: info["to"] as? String ?? "",
                                          msg: msg)
                
                await persister.save(note: noteDTO)
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
