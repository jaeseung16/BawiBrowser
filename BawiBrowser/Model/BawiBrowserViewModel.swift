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

class BawiBrowserViewModel: NSObject, ObservableObject {
    static let shared = BawiBrowserViewModel()
    
    private let multipartPrefix = "multipart/form-data; boundary="
    private let persistenteContainer = PersistenceController.shared.container
    private var subscriptions: Set<AnyCancellable> = []
    
    @Published var changedPeristentContext = NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
    
    @Published var httpCookies = [HTTPCookie]()
    @Published var innerHTML = String()
    @Published var httpBody = Data()
    
    @Published var didStartProvisionalNavigationURLString = String()
    @Published var didStartProvisionalNavigationTitle = String()
    @Published var didCommitURLString = String()
    @Published var didCommitTitle = String()
    @Published var didFinishURLString = String()
    @Published var didFinishTitle = String()
    
    @Published var showAlert = false
    var message = ""
    
    @Published var navigation = BawiBrowserNavigation.none
    
    @Published var noteDTO = BawiNoteDTO(action: "", to: "", msg: "") {
        didSet {
            let note = Note(context: persistenteContainer.viewContext)
            note.action = noteDTO.action
            note.to = noteDTO.to
            note.msg = noteDTO.msg
            note.created = Date()
            
            do {
                try saveContext()
            } catch {
                let nsError = error as NSError
                print("While saving \(note) occured an unresolved error \(nsError), \(nsError.userInfo)")
                message = "Cannot save a note to \(noteDTO.to) with msg = \(noteDTO.msg)"
                showAlert.toggle()
            }
        }
    }
    
    @Published var commentDTO = BawiCommentDTO(articleId: -1, articleTitle: "", boardId: -1, boardTitle: "", body: "") {
        didSet {
            let comment = Comment(context: persistenteContainer.viewContext)
            comment.articleId = Int64(commentDTO.articleId)
            comment.articleTitle = commentDTO.articleTitle
            comment.boardId = Int64(commentDTO.boardId)
            comment.boardTitle = commentDTO.boardTitle
            comment.body = commentDTO.body.replacingOccurrences(of: "+", with: "%20")
            comment.created = Date()
            
            do {
                try saveContext()
            } catch {
                let nsError = error as NSError
                print("While saving \(comment) occured an unresolved error \(nsError), \(nsError.userInfo)")
                message = "Cannot save a comment: \"\(commentDTO.body)\""
                showAlert.toggle()
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
                        let attachmentEntity = Attachment(context: persistenteContainer.viewContext)

                        attachmentEntity.article = existingArticle
                        attachmentEntity.content = attachment
                        attachmentEntity.created = Date()
                    }
                }
                
            } else {
                let article = Article(context: persistenteContainer.viewContext)
                article.articleId = Int64(articleDTO.articleId)
                article.articleTitle = articleDTO.articleTitle
                article.boardId = Int64(articleDTO.boardId)
                article.boardTitle = articleDTO.boardTitle
                article.body = articleDTO.body
                article.created = Date()
                article.lastupd = Date()
                
                if let attachments = articleDTO.attachments, !attachments.isEmpty {
                    for attachment in attachments {
                        let attachmentEntity = Attachment(context: persistenteContainer.viewContext)

                        attachmentEntity.article = article
                        attachmentEntity.content = attachment
                        attachmentEntity.created = Date()
                        
                    }
                    print("attachments.count = \(attachments.count)")
                }
                
                print("article = \(article)")
            }
            
            do {
                try saveContext()
            } catch {
                let nsError = error as NSError
                print("While saving \(articleDTO) occured an unresolved error \(nsError), \(nsError.userInfo)")
                message = "Cannot save an article with title = \(articleDTO.articleTitle)"
                showAlert.toggle()
            }
        }
    }
    
    override init() {
        super.init()
        
        NotificationCenter.default
          .publisher(for: .NSPersistentStoreRemoteChange)
          .sink { self.fetchUpdates($0) }
          .store(in: &subscriptions)
    }
    
    private lazy var historyRequestQueue = DispatchQueue(label: "history")
    private func fetchUpdates(_ notification: Notification) -> Void {
        historyRequestQueue.async {
            print("subscriptions.count = \(self.subscriptions.count)")
            let backgroundContext = self.persistenteContainer.newBackgroundContext()
            backgroundContext.performAndWait {
                do {
                    let fetchHistoryRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastToken)
                    
                    if let historyResult = try backgroundContext.execute(fetchHistoryRequest) as? NSPersistentHistoryResult,
                       let history = historyResult.result as? [NSPersistentHistoryTransaction] {
                        for transaction in history.reversed() {
                            //print("transaction: author = \(transaction.author), contextName = \(transaction.contextName), storeId = \(transaction.storeID), timeStamp = \(transaction.timestamp), \(transaction.objectIDNotification())")
                            self.persistenteContainer.viewContext.perform {
                                if let userInfo = transaction.objectIDNotification().userInfo {
                                    //print("transaction.objectIDNotification().userInfo = \(userInfo)")
                                    if let insertedObjectIds = userInfo["inserted_objectsIDs"] {
                                        if let idSet = insertedObjectIds as? NSSet {
                                            for id in idSet {
                                                print("inserted_objectsIDs: \(id) - \(self.persistenteContainer.viewContext.object(with: id as! NSManagedObjectID))")
                                            }
                                        }
                                    } else if let updatedObjectIds = userInfo["updated_objectIDs"] {
                                        if let idSet = updatedObjectIds as? NSSet {
                                            for id in idSet {
                                                print("updated_objectID: \(id) - \(self.persistenteContainer.viewContext.object(with: id as! NSManagedObjectID))")
                                            }
                                        }
                                    }
                                    
                                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo,
                                                                        into: [self.persistenteContainer.viewContext])
                                }
                            }
                        }
                        
                        self.lastToken = history.last?.token
                        
                    }
                } catch {
                    print("Could not convert history result to transactions after lastToken = \(String(describing: self.lastToken)): \(error)")
                }
            }
        }
    }
    
    private var lastToken: NSPersistentHistoryToken? = nil {
        didSet {
            guard let token = lastToken,
                  let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
                return
            }
            
            do {
                try data.write(to: tokenFile)
            } catch {
                let message = "Could not write token data"
                print("###\(#function): \(message): \(error)")
            }
        }
    }
    
    lazy var tokenFile: URL = {
        let url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("BawiBrowser",isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            } catch {
                let message = "Could not create persistent container URL"
                print("###\(#function): \(message): \(error)")
            }
        }
        return url.appendingPathComponent("token.data", isDirectory: false)
    }()
    
    private func saveContext() throws -> Void {
        persistenteContainer.viewContext.transactionAuthor = "App"
        try persistenteContainer.viewContext.save()
        persistenteContainer.viewContext.transactionAuthor = nil
    }
    
    func getArticle(boardId: Int, articleId: Int) -> Article? {
        print("boardId = \(boardId), articleId = \(articleId)")
        let predicate = NSPredicate(format: "boardId == %@ AND articleId == %@", argumentArray: [boardId, articleId])
        
        let fetchRequest = NSFetchRequest<Article>(entityName: "Article")
        fetchRequest.predicate = predicate
        
        var fetchedArticles = [Article]()
        do {
            fetchedArticles = try persistenteContainer.viewContext.fetch(fetchRequest)
            
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
