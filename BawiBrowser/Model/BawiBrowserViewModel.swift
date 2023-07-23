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
import CoreSpotlight

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
        persistence.cloudContainer!
    }
    private var viewContext: NSManagedObjectContext {
        persistenceContainer.viewContext
    }
    private let persistenceHelper: PersistenceHelper
    
    init(persistence: Persistence) {
        self.persistence = persistence
        self.persistenceHelper = PersistenceHelper(persistence: persistence)
        
        super.init()
        
        NotificationCenter.default
          .publisher(for: .NSPersistentStoreRemoteChange)
          .sink { self.fetchUpdates($0) }
          .store(in: &subscriptions)
        
        self.persistence.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        fetchAll()
        
        DispatchQueue.main.async {
            let articleIndex = CSSearchableIndex(name: self.articleIndexName)
            articleIndex.deleteAllSearchableItems() { error in
                if let error = error {
                    self.logger.log("Error while deleting article index: \(error.localizedDescription)")
                }
                self.indexArticles()
            }
            
            let commentIndex = CSSearchableIndex(name: self.commentIndexName)
            commentIndex.deleteAllSearchableItems() { error in
                if let error = error {
                    self.logger.log("Error while deleting comment index: \(error.localizedDescription)")
                }
                self.indexComments()
            }
            
            let noteIndex = CSSearchableIndex(name: self.noteIndexName)
            noteIndex.deleteAllSearchableItems() { error in
                if let error = error {
                    self.logger.log("Error while deleting note index: \(error.localizedDescription)")
                }
                self.indexNotes()
            }
        }
        
    }
    
    private func fetchAll() {
        fetchNotes()
        fetchComments()
        fetchArticles()
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
    
    // MARK: - Persistence
    @Published var articles = [Article]()
    @Published var comments = [Comment]()
    @Published var notes = [Note]()
    
    private func fetchArticles() {
        let fetchRequest = NSFetchRequest<Article>(entityName: "Article")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Article.lastupd, ascending: false)]
        articles = persistenceHelper.perform(fetchRequest)
    }
    
    private func fetchComments() {
        let fetchRequest = NSFetchRequest<Comment>(entityName: "Comment")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Comment.created, ascending: false)]
        comments = persistenceHelper.perform(fetchRequest)
    }
    
    private func fetchNotes() {
        let fetchRequest = NSFetchRequest<Note>(entityName: "Note")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.created, ascending: false)]
        notes = persistenceHelper.perform(fetchRequest)
    }
    
    func delete(_ object: NSManagedObject) {
        persistenceHelper.delete(object)
    }
    
    func save() {
        persistenceHelper.save() { result in
            switch result {
            case .success(_):
                self.logger.log("Data saved successfully")
            case .failure(let error):
                self.logger.log("Error while saving data: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    private var domainIdentifier = "com.resonance.jlee.BawiBrowser"
    private var noteIndexName = "bawibrowser-note-index"
    private var commentIndexName = "bawibrowser-comment-index"
    private var articleIndexName = "bawibrowser-article-index"
    
    var spotlightFoundArticles: [CSSearchableItem] = []
    var spotlightFoundComments: Set<CSSearchableItem> = []
    var spotlightFoundNotes: [CSSearchableItem] = []
    
    var searchQueryForArticle: CSSearchQuery?
    var searchQueryForComment: CSSearchQuery?
    var searchQueryForNote: CSSearchQuery?
    
    private func index<T: NSManagedObject>(_ entities: [T]) {
        let searchableItems: [CSSearchableItem] = entities.compactMap { (entity: T) -> CSSearchableItem? in
            guard let attributeSet = attributeSet(for: entity) else {
                self.logger.log("Cannot generate attribute set for \(entity, privacy: .public)")
                return nil
            }
            return CSSearchableItem(uniqueIdentifier: entity.objectID.uriRepresentation().absoluteString, domainIdentifier: domainIdentifier, attributeSet: attributeSet)
        }
        
        var indexName = ""
        
        switch T.self {
        case is Article.Type:
            indexName = articleIndexName
        case is Comment.Type:
            indexName = commentIndexName
        case is Note.Type:
            indexName = noteIndexName
        default:
            indexName = ""
        }
        
        logger.log("Adding \(searchableItems.count) items to index=\(indexName, privacy: .public)")
        
        CSSearchableIndex(name: indexName).indexSearchableItems(searchableItems) { error in
            guard let error = error else {
                return
            }
            self.logger.log("Error while indexing \(T.self): \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func indexNotes() -> Void {
        logger.log("Indexing \(self.notes.count, privacy: .public) notes")
        index<Note>(notes)
    }
    
    private func indexComments() -> Void {
        logger.log("Indexing \(self.comments.count, privacy: .public) comments")
        index<Comment>(comments)
    }
    
    private func indexArticles() -> Void {
        logger.log("Indexing \(self.articles.count, privacy: .public) articles")
        index<Article>(articles)
    }
    
    private func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        if let note = object as? Note {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.comment = note.msg?.removingPercentEncoding
            return attributeSet
        }
        
        if let comment = object as? Comment {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.textContent = comment.body?.removingPercentEncoding
            return attributeSet
        }
        
        if let article = object as? Article {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = article.boardTitle
            attributeSet.subject = article.articleTitle
            attributeSet.textContent = article.body?.removingPercentEncoding
            return attributeSet
        }

        return nil
    }
    
    func searchNote(_ text: String) -> Void {
        if text.isEmpty {
            searchQueryForNote?.cancel()
            fetchNotes()
        } else {
            searchNotes(text)
        }
    }
    
    func searchComment(_ text: String) -> Void {
        if text.isEmpty {
            searchQueryForComment?.cancel()
            fetchComments()
        } else {
            searchComments(text)
        }
    }
    
    func searchArticle(_ text: String) -> Void {
        if text.isEmpty {
            searchQueryForArticle?.cancel()
            fetchArticles()
        } else {
            searchArticles(text)
        }
    }
    
    private func searchNotes(_ text: String) {
        let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let queryString = "(comment == \"*\(escapedText)*\"cd)"
        
        logger.log("queryString=\(queryString)")
        
        searchQueryForNote = CSSearchQuery(queryString: queryString, attributes: ["comment"])
        
        searchQueryForNote?.foundItemsHandler = { items in
            DispatchQueue.main.async {
                self.spotlightFoundNotes += items
            }
        }
        
        searchQueryForNote?.completionHandler = { error in
            if let error = error {
                self.logger.log("Searching \(text) came back with error: \(error.localizedDescription, privacy: .public)")
            } else {
                DispatchQueue.main.async {
                    self.fetchNotes(self.spotlightFoundNotes)
                    self.spotlightFoundNotes.removeAll()
                }
            }
        }
        
        searchQueryForNote?.start()
    }
    
    private func searchComments(_ text: String) {
        let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let queryString = "(textContent == \"*\(escapedText)*\"cd)"
        
        logger.log("queryString=\(queryString)")
        
        searchQueryForComment = CSSearchQuery(queryString: queryString, attributes: ["textContent"])
        
        searchQueryForComment?.foundItemsHandler = { items in
            DispatchQueue.main.async {
                items.forEach { item in
                    self.spotlightFoundComments.insert(item)
                }
            }
        }
        
        searchQueryForComment?.completionHandler = { error in
            if let error = error {
                self.logger.log("Searching \(text) came back with error: \(error.localizedDescription, privacy: .public)")
            } else {
                DispatchQueue.main.async {
                    self.fetchComments(self.spotlightFoundComments)
                    self.spotlightFoundComments.removeAll()
                }
            }
        }
        
        searchQueryForComment?.start()
    }
    
    private func searchArticles(_ text: String) {
        let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let queryString = "(textContent == \"*\(escapedText)*\"cd)"
        
        logger.log("article queryString=\(queryString)")
        
        searchQueryForArticle = CSSearchQuery(queryString: queryString, attributes: ["textContent"])
        
        searchQueryForArticle?.foundItemsHandler = { items in
            DispatchQueue.main.async {
                self.spotlightFoundArticles += items
            }
        }
        
        searchQueryForArticle?.completionHandler = { error in
            if let error = error {
                self.logger.log("Searching \(text) came back with error: \(error.localizedDescription, privacy: .public)")
            } else {
                DispatchQueue.main.async {
                    self.fetchArticles(self.spotlightFoundArticles)
                    self.spotlightFoundArticles.removeAll()
                }
            }
        }
        
        searchQueryForArticle?.start()
    }
    
    private func fetch<T: NSManagedObject>(_ items: [CSSearchableItem]) -> [T] {
        return items.compactMap { (item: CSSearchableItem) -> T? in
            guard let url = URL(string: item.uniqueIdentifier) else {
                return nil
            }
            return find(for: url) as? T
        }
    }
    
    private func fetchNotes(_ items: [CSSearchableItem]) {
        logger.log("Fetching \(items.count) notes")
        let foundNotes: [Note] = fetch(items)
        logger.log("Found \(foundNotes.count) notes")
        notes = foundNotes.sorted(by: { note1, note2 in
            if note1.created == nil {
                return false
            } else if note2.created == nil {
                return true
            } else {
                return note1.created! > note2.created!
            }
        })
    }
    
    private func fetchComments(_ items: Set<CSSearchableItem>) {
        logger.log("Fetching \(items.count) comments")
        let foundComments: [Comment] = fetch(Array(items))
        logger.log("Found \(foundComments.count) comments")
        comments = foundComments.sorted(by: { comment1, comment2 in
            if comment1.created == nil {
                return false
            } else if comment2.created == nil {
                return true
            } else {
                return comment1.created! > comment2.created!
            }
        })
    }
    
    private func fetchArticles(_ items: [CSSearchableItem]) {
        logger.log("Fetching \(items.count) articles")
        let foundArticles: [Article] = fetch(items)
        logger.log("Found \(foundArticles.count) articles")
        articles = foundArticles.sorted(by: { article1, article2 in
            if article1.created == nil {
                return false
            } else if article2.created == nil {
                return true
            } else {
                return article1.created! > article2.created!
            }
        })
    }
    
    func find(for url: URL) -> NSManagedObject? {
        guard let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
            return nil
        }
        return viewContext.object(with: objectID)
    }
}

extension BawiBrowserViewModel: BawiBrowserSearchDelegate {
    func search(_ text: String) {
        switch selectedTab {
        case .browser:
            return
        case .articles:
            searchArticle(text)
        case .comments:
            searchComment(text)
        case .notes:
            searchNote(text)
        }
    }
    
    func cancelSearch() {
        DispatchQueue.main.async {
            self.searchQueryForArticle?.cancel()
            self.searchQueryForComment?.cancel()
            self.searchQueryForNote?.cancel()
            
            self.fetchAll()
        }
    }
}
