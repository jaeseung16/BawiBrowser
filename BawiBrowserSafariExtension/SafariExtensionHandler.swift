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
    
    @MainActor
    private let safariExtensionViewController = SafariExtensionViewController.shared
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        // This method will be called when a content script provided by your extension calls safari.extension.dispatchMessage("message").
        
        SafariExtensionHandler.logger.log("The extension received a message with name=\(messageName, privacy: .public)")
        
        // Assume that attachments do not come before article
        if SafariExtensionHandler.attachments.contains(messageName) {
            if let data = userInfo?["data"] as? [UInt8] {
                Task {
                    if await SafariExtensionPersister.shared.isAricleAvailable() {
                        await MessageHandlerFactory.attachmentHandler(data: Data(data)).process()
                    }
                }
            }
        }
        
        page.getPropertiesWithCompletionHandler { properties in
            guard let properties = properties, let url = properties.url, url.absoluteString.contains("read.cgi") else {
                return
            }
            
            SafariExtensionHandler.logger.log("The message came from a script injected into \(url, privacy: .public)")
            Task {
                if await SafariExtensionPersister.shared.isAricleAvailable() {
                    await SafariExtensionHandler.saveArticle(url)
                }
            }
        }
        
        guard let userInfo = userInfo else {
            return
        }
        
        if messageName == "writeForm" {
            let bid = userInfo["bid"] as? String
            let body = userInfo["body"] as? String
            let articleTitle = userInfo["title"] as? String
            let boardTitle = userInfo["boardTitle"] as? String
            let attachCount = userInfo["attach-count"] as? String
            
            page.getPropertiesWithCompletionHandler { properties in
                guard let properties = properties, let url = properties.url, url.absoluteString.contains("edit.cgi") else {
                    return
                }
                
                SafariExtensionHandler.logger.log("The message came from a script injected into \(url, privacy: .public)")
                let article = BawiArticleDTO(articleId: SafariExtensionHandler.findArticleId(from: url),
                                             articleTitle: articleTitle ?? "",
                                             boardId: bid != nil ? Int(bid!)! : -1,
                                             boardTitle: boardTitle ?? "",
                                             body: body ?? "",
                                             attachCount: attachCount != nil ? Int(attachCount!)! : 0)
                SafariExtensionHandler.logger.log("articleDTO = \(article, privacy: .public)")
                Task {
                    await MessageHandlerFactory.writeFormHandler(article: article).process()
                }
            }
        }
        
        if messageName == "commentForm" {
            let comment = SafariExtensionHandler.comment(from: userInfo)
            Task {
                await MessageHandlerFactory.commentFormHandler(comment: comment).process()
            }
        }
        
        if messageName == "noteForm", let note = SafariExtensionHandler.note(from: userInfo) {
            Task {
                await MessageHandlerFactory.noteFormHandler(note: note).process()
            }
        }
        
    }
    
    private static func extractProperties(from page: SFSafariPage) async -> SFSafariPageProperties? {
        return await page.properties()
    }
    
    private static func saveArticle(_ url: URL) async -> Void {
        let articleId = findArticleId(from: url)
        await SafariExtensionPersister.shared.saveArticle(articleId)
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
        await SafariExtensionPersister.shared.populate(article: article)
    }
    
    private static func comment(from info: [String : Any]) -> BawiCommentDTO {
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
  
    private static func note(from info: [String : Any]) -> BawiNoteDTO? {
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
