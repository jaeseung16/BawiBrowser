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
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        // This method will be called when a content script provided by your extension calls safari.extension.dispatchMessage("message").
        page.getPropertiesWithCompletionHandler { properties in
            NSLog("The extension received a message (\(messageName)) from a script injected into (\(String(describing: properties?.url))) with userInfo (\(userInfo ?? [:]))")
            
            if self.attachments.contains(messageName) {
                NSLog("\(messageName): userInfo = \(userInfo)")
                if let userInfo = userInfo, userInfo["data"] != nil {
                    let data = userInfo["data"] as? [UInt8]
                    NSLog("\(messageName): type of data = \(type(of: data))")
                    NSLog("\(messageName): data.count = \(data?.count)")
                    NSLog("\(messageName): data = \(String(describing: data))")
                }
            }
            
            if messageName == "commentForm", let userInfo = userInfo {
                let aid = userInfo["aid"] as? Int
                let action = userInfo["action"] as? String
                let bid = userInfo["bid"] as? Int
                let body = userInfo["body"] as? String
                let articleTitle = userInfo["articleTitle"] as? String
                let boardTitle = userInfo["boardTitle"] as? String
                
                let commentDTO = BawiCommentDTO(articleId: aid ?? -1,
                                                articleTitle: articleTitle ?? "",
                                                boardId: bid ?? -1,
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
                    try self.viewContext.save()
                } catch {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    let nsError = error as NSError
                    NSLog("While saving \(commentDTO) occured an unresolved error \(nsError), \(nsError.userInfo)")
                }
            }
        }
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
