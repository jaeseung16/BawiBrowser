//
//  BawiBrowserViewModel.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/29/21.
//

import Foundation
import WebKit
import Combine
import MultipartKit
import SwiftUI
import Persistence
import os

class BawiBrowserViewModel: NSObject, ObservableObject {
    private let logger = Logger()
    
    private let multipartPrefix = "multipart/form-data; boundary="
    var subscriptions: Set<AnyCancellable> = []
    
    @Published var httpCookies = [HTTPCookie]()
    @Published var innerHTML = String()
    @Published var httpBody = Data()
    
    var didStartProvisionalNavigationURLString = String()
    var didStartProvisionalNavigationTitle = String()
    var didCommitURLString = String()
    var didCommitTitle = String()
    var didFinishURLString = String()
    var didFinishTitle = String()
    
    @Published var toggle = false
    @Published var showAlert = false
    var message = ""
    
    @Published var navigation = BawiBrowserNavigation.none
    
    @Published var noteDTO = BawiNoteDTO(action: "", to: "", msg: "") {
        didSet {
            let note = Note(context: persistenceContainer.viewContext)
            note.action = noteDTO.action
            note.to = noteDTO.to
            note.msg = noteDTO.msg
            note.created = Date()
            
            saveContext { error in
                self.message = "Cannot save a note to \(self.noteDTO.to) with msg = \(self.noteDTO.msg)"
                self.logger.log("While saving \(self.noteDTO, privacy: .public) occured an unresolved error \(error.localizedDescription, privacy: .public)")
                self.showAlert.toggle()
            }
        }
    }
    
    @Published var commentDTO = BawiCommentDTO(articleId: -1, articleTitle: "", boardId: -1, boardTitle: "", body: "") {
        didSet {
            let comment = Comment(context: persistenceContainer.viewContext)
            comment.articleId = Int64(commentDTO.articleId)
            comment.articleTitle = commentDTO.articleTitle
            comment.boardId = Int64(commentDTO.boardId)
            comment.boardTitle = commentDTO.boardTitle
            comment.body = commentDTO.body.replacingOccurrences(of: "+", with: "%20")
            comment.created = Date()
            
            saveContext { error in
                self.message = "Cannot save a comment: \"\(self.commentDTO.body)\""
                self.logger.log("While saving \(comment, privacy: .public) occured an unresolved error \(error.localizedDescription, privacy: .public)")
                self.showAlert.toggle()
            }
        }
    }
    
    @Published var articleDTO = BawiArticleDTO(articleId: -1, articleTitle: "", boardId: -1, boardTitle: "", body: "") {
        didSet {
            
            if articleDTO.articleId > 0, let existingArticle = getArticle(boardId: articleDTO.boardId, articleId: articleDTO.articleId) {
                existingArticle.articleId = Int64(articleDTO.articleId)
                existingArticle.articleTitle = articleDTO.articleTitle
                existingArticle.boardId = Int64(articleDTO.boardId)
                existingArticle.boardTitle = articleDTO.boardTitle
                existingArticle.body = articleDTO.body
                existingArticle.lastupd = Date()
                
                if let attachments = articleDTO.attachments, !attachments.isEmpty {
                    for attachment in attachments {
                        let attachmentEntity = Attachment(context: persistenceContainer.viewContext)

                        attachmentEntity.article = existingArticle
                        attachmentEntity.content = attachment
                        attachmentEntity.created = Date()
                    }
                }
                
            } else {
                let article = Article(context: persistenceContainer.viewContext)
                article.articleId = Int64(articleDTO.articleId)
                article.articleTitle = articleDTO.articleTitle
                article.boardId = Int64(articleDTO.boardId)
                article.boardTitle = articleDTO.boardTitle
                article.body = articleDTO.body
                article.created = Date()
                article.lastupd = Date()
                
                if let attachments = articleDTO.attachments, !attachments.isEmpty {
                    for attachment in attachments {
                        let attachmentEntity = Attachment(context: persistenceContainer.viewContext)

                        attachmentEntity.article = article
                        attachmentEntity.content = attachment
                        attachmentEntity.created = Date()
                        
                    }
                    print("attachments.count = \(attachments.count)")
                }
                
                print("article = \(article)")
            }
            
            saveContext() { error in
                self.message = "Cannot save an article with title = \(self.articleDTO.articleTitle)"
                self.logger.log("Cannot save articleDTO=\(self.articleDTO, privacy: .public): \(error.localizedDescription, privacy: .public)")
                self.showAlert.toggle()
            }
        }
    }
    
    @Published var isDarkMode = false
    
    @Published var enableSearch = false
    @Published var searchString = ""
    @Published var searchResultTotalCount = 0
    @Published var searchResultCounter = 0
    
    @Published var searchArticleTitle = ""
    
    @Published var selectedTab: BawiBrowserTab = BawiBrowserTab.browser
    @Published var selectedArticle = [String: Int64]() {
        didSet {
            selectedTab = .articles
        }
    }
    
    var urlToCopy: String = ""
    
    private let persistence: Persistence
    private var persistenceContainer: NSPersistentCloudKitContainer {
        persistence.container
    }
    
    init(persistence: Persistence) {
        self.persistence = persistence
        
        super.init()
        
        NotificationCenter.default
          .publisher(for: .NSPersistentStoreRemoteChange)
          .sink { self.fetchUpdates($0) }
          .store(in: &subscriptions)
        
        self.persistence.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    private lazy var historyRequestQueue = DispatchQueue(label: "history")
    private func fetchUpdates(_ notification: Notification) -> Void {
        persistence.fetchUpdates(notification) { _ in
            DispatchQueue.main.async {
                self.toggle.toggle()
            }
        }
    }
    
    private func saveContext(completionHandler: @escaping (Error) -> Void) -> Void {
        persistenceContainer.viewContext.transactionAuthor = "App"
        persistence.save { result in
            switch result {
            case .success(_):
                DispatchQueue.main.async {
                    self.toggle.toggle()
                }
            case .failure(let error):
                self.logger.log("Error while saving data: \(error.localizedDescription, privacy: .public)")
                self.logger.log("Error while saving data: \(Thread.callStackSymbols, privacy: .public)")
                print("Error while saving data: \(Thread.callStackSymbols)")
                DispatchQueue.main.async {
                    self.showAlert.toggle()
                    completionHandler(error)
                }
            }
        }
        persistenceContainer.viewContext.transactionAuthor = nil
    }
    
    func getArticle(boardId: Int, articleId: Int) -> Article? {
        print("boardId = \(boardId), articleId = \(articleId)")
        let predicate = NSPredicate(format: "boardId == %@ AND articleId == %@", argumentArray: [boardId, articleId])
        
        let fetchRequest = NSFetchRequest<Article>(entityName: "Article")
        fetchRequest.predicate = predicate
        
        var fetchedArticles = [Article]()
        do {
            fetchedArticles = try persistenceContainer.viewContext.fetch(fetchRequest)
            
            print("fetchedArticle = \(fetchedArticles)")
        } catch {
            fatalError("Failed to fetch article: \(error)")
        }
        
        return fetchedArticles.isEmpty ? nil : fetchedArticles[0]
    }
    
    func processComment(url: URL, httpBody: Data, articleTitle: String?, boardTitle: String?) -> Void {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.query = String(data: httpBody, encoding: .utf8)
        
        var articleId = -1
        var boardId = -1
        var body = ""
        if let queryItems = urlComponents?.queryItems {
            for queryItem in queryItems {
                switch queryItem.name {
                case BawiCommentConstant.aid.rawValue:
                    if let value = queryItem.value, let id = Int(value) {
                        articleId = id
                    }
                case BawiCommentConstant.bid.rawValue:
                    if let value = queryItem.value, let id = Int(value) {
                        boardId = id
                    }
                case BawiCommentConstant.body.rawValue:
                    if let value = queryItem.value {
                        body = value
                    }
                default:
                    continue
                }
            }
        }
        
        self.commentDTO = BawiCommentDTO(articleId: articleId,
                                                     articleTitle: articleTitle ?? "",
                                                     boardId: boardId,
                                                     boardTitle: boardTitle ?? "",
                                                     body: body)
    }
    
    func processNote(url: URL, httpBody: Data) -> Void {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.query = String(data: httpBody, encoding: .utf8)
        
        var action: String?
        var to: String?
        var msg: String?
        if let queryItems = urlComponents?.queryItems {
            for queryItem in queryItems {
                switch queryItem.name {
                case BawiNoteConstant.action.rawValue:
                    if let value = queryItem.value {
                        action = value
                    }
                case BawiNoteConstant.to.rawValue:
                    if let value = queryItem.value {
                        to = value
                    }
                case BawiNoteConstant.msg.rawValue:
                    if let value = queryItem.value {
                        msg = value
                    }
                default:
                    continue
                }
            }
        }
        
        if let message = msg, !message.isEmpty {
            noteDTO = BawiNoteDTO(action: action ?? "", to: to ?? "", msg: message)
        }
    }
    
    private func extractBoundary(from navigationAction: WKNavigationAction) -> String? {
        if let contentTypeHeader = navigationAction.request.allHTTPHeaderFields!["Content-Type"],
           contentTypeHeader.starts(with: multipartPrefix) {
            var boundary = contentTypeHeader
            boundary.removeSubrange(Range(uncheckedBounds: (multipartPrefix.startIndex, multipartPrefix.endIndex)))
            return boundary
        }
        return nil
    }
    
    func processEdit(url: URL, httpBody: Data?, httpBodyStream: InputStream?, boundary: String, boardTitle: String?) -> Void {
        if let httpBody = httpBody {
             populate(from: httpBody, with: boundary) { bawiWriteForm in
                let (articleId, articleTitle, boardId, body) = extractPropertiesForEdit(from: bawiWriteForm)
                self.articleDTO = BawiArticleDTO(articleId: articleId,
                                                 articleTitle: articleTitle,
                                                 boardId: boardId,
                                                 boardTitle: boardTitle ?? "",
                                                 body: body)
            }
        } else if let httpBodyStream = httpBodyStream {
            populate(from: httpBodyStream, with: boundary) { bawiWriteForm, attachments in
                let (articleId, articleTitle, boardId, body) = extractPropertiesForEdit(from: bawiWriteForm)
                self.articleDTO = BawiArticleDTO(articleId: articleId,
                                                 articleTitle: articleTitle,
                                                 boardId: boardId,
                                                 boardTitle: boardTitle ?? "",
                                                 body: body,
                                                 attachments: attachments)
            }
        }
    }
    
    private func extractPropertiesForEdit(from bawiWriteForm: BawiWriteForm?) -> (Int, String, Int, String) {
        var articleId = -1
        var articleTitle = ""
        var boardId = -1
        var body = ""
        if let bawiWriteForm = bawiWriteForm {
            articleId = Int(bawiWriteForm.aid) ?? -1
            articleTitle = bawiWriteForm.title
            boardId = Int(bawiWriteForm.bid) ?? -1
            body = bawiWriteForm.body
        }
        return (articleId, articleTitle, boardId, body)
    }
    
    private func populate(from httpBody: Data, with boundary: String, completionHandler: (BawiWriteForm?) -> Void) -> Void {
        if let stringToParse = String(data: httpBody, encoding: .utf8) {
            var bawiWriteForm: BawiWriteForm?
            do {
                bawiWriteForm = try FormDataDecoder().decode(BawiWriteForm.self, from: stringToParse, boundary: String(boundary))
            } catch {
                print("error: \(error).")
            }
            
            completionHandler(bawiWriteForm)
        }
    }
    
    private func populate(from httpBodyStream: InputStream, with boundary: String, completionHandler: (BawiWriteForm?, [Data]) -> Void) -> Void {
        httpBodyStream.open()

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        while httpBodyStream.hasBytesAvailable {
            let read = httpBodyStream.read(buffer, maxLength: bufferSize)
            if (read == 0) {
                break
            }
            data.append(buffer, count: read)
        }
        buffer.deallocate()

        httpBodyStream.close()
        
        do {
            let bawiWriteForm = try FormDataDecoder().decode(BawiWriteForm.self, from: [UInt8](data), boundary: boundary)
            print("bawiWriteForm = \(bawiWriteForm)")
            
            var attachements = [Data]()
            if bawiWriteForm.attach1 != nil {
                attachements.append(bawiWriteForm.attach1!)
            }
            if bawiWriteForm.attach2 != nil {
                attachements.append(bawiWriteForm.attach2!)
            }
            if bawiWriteForm.attach3 != nil {
                attachements.append(bawiWriteForm.attach3!)
            }
            if bawiWriteForm.attach4 != nil {
                attachements.append(bawiWriteForm.attach4!)
            }
            if bawiWriteForm.attach5 != nil {
                attachements.append(bawiWriteForm.attach5!)
            }
            if bawiWriteForm.attach6 != nil {
                attachements.append(bawiWriteForm.attach6!)
            }
            if bawiWriteForm.attach7 != nil {
                attachements.append(bawiWriteForm.attach7!)
            }
            if bawiWriteForm.attach8 != nil {
                attachements.append(bawiWriteForm.attach8!)
            }
            if bawiWriteForm.attach9 != nil {
                attachements.append(bawiWriteForm.attach9!)
            }
            if bawiWriteForm.attach10 != nil {
                attachements.append(bawiWriteForm.attach10!)
            }
            
            completionHandler(bawiWriteForm, attachements)
        } catch {
            print("error: \(error).")
        }
    }
    
    func preprocessWrite(url: URL, httpBody: Data?, httpBodyStream: InputStream?, boundary: String, boardTitle: String?, coordinator: WebView.Coordinator) -> Void {
        if let httpBody = httpBody {
            populate(from: httpBody, with: boundary) { bawiWriteForm in
                let (parentArticleId, articleTitle, boardId, body) = extractPropertiesForWrite(from: bawiWriteForm)
                coordinator.articleDTO = BawiArticleDTO(articleId: -1, articleTitle: articleTitle, boardId: boardId, boardTitle: boardTitle ?? "", body: body, parentArticleId: parentArticleId)
           }
        } else if let httpBodyStream = httpBodyStream {
            populate(from: httpBodyStream, with: boundary) { bawiWriteForm, attachments in
                let (parentArticleId, articleTitle, boardId, body) = extractPropertiesForWrite(from: bawiWriteForm)
                coordinator.articleDTO = BawiArticleDTO(articleId: -1,
                                                 articleTitle: articleTitle,
                                                 boardId: boardId,
                                                 boardTitle: boardTitle ?? "",
                                                 body: body,
                                                 parentArticleId: parentArticleId,
                                                 attachments: attachments)
            }
        }
    }
    
    private func extractPropertiesForWrite(from bawiWriteForm: BawiWriteForm?) -> (Int, String, Int, String) {
        var parentArticleId = -1
        var articleTitle = ""
        var boardId = -1
        var body = ""
        if let bawiWriteForm = bawiWriteForm {
            parentArticleId = Int(bawiWriteForm.aid) ?? -1
            articleTitle = bawiWriteForm.title
            boardId = Int(bawiWriteForm.bid) ?? -1
            body = bawiWriteForm.body
        }
        return (parentArticleId, articleTitle, boardId, body)
    }
}
