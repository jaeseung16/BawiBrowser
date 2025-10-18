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
    
    private static let logger = Logger()
    
    private static let attachments = ["attach1", "attach2", "attach3", "attach4", "attach5", "attach6", "attach7", "attach8", "attach9", "attach10"]
    
    private static let viewContext = Persistence(name: BawiBrowserConstants.appName.rawValue, identifier: BawiBrowserConstants.iCloudIdentifier.rawValue).container.viewContext
    
    private static let persister: SafariExtensionPersister = SafariExtensionPersister.shared
    
    @MainActor
    private let safariExtensionViewController = SafariExtensionViewController.shared
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        // This method will be called when a content script provided by your extension calls safari.extension.dispatchMessage("message").
        
        SafariExtensionHandler.logger.log("The extension received a message with name=\(messageName, privacy: .public)")
         
        page.getPropertiesWithCompletionHandler { properties in
            guard let properties = properties else {
                return
            }
            
            SafariExtensionHandler.logger.log("The message came from a script injected into \(String(describing: properties.url), privacy: .public)")
            
            
            // Assume that attachments do not come before article
            if SafariExtensionHandler.attachments.contains(messageName) {
                if let userInfo = userInfo, let data = userInfo["data"] as? [UInt8] {
                    Task {
                        await SafariExtensionHandler.add(attachment: Data(data))
                    }
                }
            }
            
            if let url = properties.url, url.absoluteString.contains("read.cgi") {
                Task {
                    if await SafariExtensionHandler.persister.isAricleAvailable() {
                        await SafariExtensionHandler.saveArticle(url)
                    }
                }
            }
                
            if messageName == "writeForm", let userInfo = userInfo {
                let article = SafariExtensionHandler.getArticle(properties, userInfo)
                SafariExtensionHandler.logger.log("articleDTO = \(article, privacy: .public)")
                Task {
                    await SafariExtensionHandler.populate(article: article)
                }
            }
                
            if messageName == "commentForm", let userInfo = userInfo {
                let comment = SafariExtensionHandler.getComment(userInfo)
                Task {
                    await SafariExtensionHandler.save(comment: comment)
                }
            }
            
            if messageName == "noteForm", let userInfo = userInfo, let note = SafariExtensionHandler.getNote(for: userInfo) {
                Task {
                    await SafariExtensionHandler.save(note: note)
                }
            }
        }
    }
    
    private static func add(attachment: Data) async {
        if await SafariExtensionHandler.persister.isAricleAvailable() {
            await SafariExtensionHandler.persister.addAttachments(attachment)
        }
    }
    
    private static func getArticle(boardId: Int, articleId: Int) -> Article? {
        let predicate = NSPredicate(format: "boardId == %@ AND articleId == %@", argumentArray: [boardId, articleId])
        
        let fetchRequest = NSFetchRequest<Article>(entityName: "Article")
        fetchRequest.predicate = predicate
        
        var fetchedArticles = [Article]()
        do {
            fetchedArticles = try SafariExtensionHandler.viewContext.fetch(fetchRequest)
        } catch {
            SafariExtensionHandler.logger.log("Failed to fetch article with boardId = \(boardId, privacy: .public) and articleId = \(articleId, privacy: .public): \(error.localizedDescription)")
        }
        
        return fetchedArticles.isEmpty ? nil : fetchedArticles[0]
    }
    
    private static func saveArticle(_ url: URL) async -> Void {
        let articleId = findArticleId(from: url)
        await SafariExtensionHandler.persister.saveArticle(articleId)
    }
    
    private static func findArticleId(from url: URL) -> Int {
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
        
        SafariExtensionHandler.logger.log("articleId = \(articleId, privacy: .public)")
        return articleId
    }
    
    private static func populate(article: BawiArticleDTO) async -> Void {
        await SafariExtensionHandler.persister.populate(article: article)
    }
    
    private static func getArticle(_ properties: SFSafariPageProperties, _ info: [String : Any]) -> BawiArticleDTO {
        var articleId = -1
        if let url = properties.url, url.absoluteString.contains("edit.cgi") {
            articleId = findArticleId(from: url)
        }
        
        let bid = info["bid"] as? String
        let body = info["body"] as? String
        let articleTitle = info["title"] as? String
        let boardTitle = info["boardTitle"] as? String
        let attachCount = info["attach-count"] as? String
        
        return BawiArticleDTO(articleId: articleId,
                              articleTitle: articleTitle ?? "",
                              boardId: bid != nil ? Int(bid!)! : -1,
                              boardTitle: boardTitle ?? "",
                              body: body ?? "",
                              attachCount: attachCount != nil ? Int(attachCount!)! : 0)
    }
    
    private static func save(comment: BawiCommentDTO) async -> Void {
        await SafariExtensionHandler.persister.save(comment: comment)
    }
    
    private static func getComment(_ info: [String : Any]) -> BawiCommentDTO {
        let aid = info["aid"] as? String ?? ""
        let bid = info["bid"] as? String ?? ""
        let body = info["body"] as? String
        let articleTitle = info["articleTitle"] as? String
        let boardTitle = info["boardTitle"] as? String
        
        return BawiCommentDTO(articleId: Int(aid) ?? -1,
                                        articleTitle: articleTitle ?? "",
                                        boardId: Int(bid) ?? -1,
                                        boardTitle: boardTitle ?? "",
                                        body: body ?? "")
    }
    
    private static func save(note: BawiNoteDTO) async -> Void {
        await SafariExtensionHandler.persister.save(note: note)
    }
    
    private static func getNote(for info: [String : Any]) -> BawiNoteDTO? {
        if let msg = info["msg"] as? String, !(msg.isEmpty) {
            return BawiNoteDTO(action: info["action"] as? String ?? "",
                                      to: info["to"] as? String ?? "",
                                      msg: msg)
        } else {
            return nil
        }
    }
    
    override func toolbarItemClicked(in window: SFSafariWindow) {
        // This method will be called when your toolbar item is clicked.
        SafariExtensionHandler.logger.log("The extension's toolbar item was clicked")
    }
    
    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        // This is called when Safari's state changed in some way that would require the extension's toolbar item to be validated again.
        validationHandler(true, "")
    }
    
    override func popoverViewController() -> SFSafariExtensionViewController {
        return safariExtensionViewController
    }

}
