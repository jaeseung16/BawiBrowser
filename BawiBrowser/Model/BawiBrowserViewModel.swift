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

@MainActor
class BawiBrowserViewModel: NSObject, ObservableObject {
    private let logger = Logger()
    
    private let multipartPrefix = "multipart/form-data; boundary="
    
    @AppStorage("BawiBrowser.useKeychain") private var useKeychain: Bool = false
    @AppStorage("BawiBrowser.spotlightIndexing") private var spotlightIndexing: Bool = false
    @AppStorage("BawiBrowser.oldIndexDeleted") private var oldIndexDeleted: Bool = false
    @AppStorage("BawiBrowser.articleAsHtml") var articleAsHtml: Bool = false
    
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
            Task {
                do {
                    try await persistenceHelper.save(note: noteDTO)
                } catch let error {
                    self.message = "Cannot save a note to \(self.noteDTO.to) with msg = \(self.noteDTO.msg)"
                    self.logger.log("While saving \(self.noteDTO, privacy: .public) occured an unresolved error \(error.localizedDescription, privacy: .public)")
                    self.showAlert.toggle()
                }
            }
        }
    }
    
    @Published var commentDTO = BawiCommentDTO(articleId: -1, articleTitle: "", boardId: -1, boardTitle: "", body: "") {
        didSet {
            Task {
                do {
                    try await persistenceHelper.save(comment: commentDTO)
                } catch let error {
                    self.message = "Cannot save a comment: \"\(self.commentDTO.body)\""
                    self.logger.log("While saving \(self.commentDTO, privacy: .public) occured an unresolved error \(error.localizedDescription, privacy: .public)")
                    self.showAlert.toggle()
                }
            }
        }
    }
    
    @Published var articleDTO = BawiArticleDTO(articleId: -1, articleTitle: "", boardId: -1, boardTitle: "", body: "") {
        didSet {
            Task {
                do {
                    try await persistenceHelper.save(article: articleDTO)
                } catch let error {
                    self.message = "Cannot save an article with title = \(self.articleDTO.articleTitle)"
                    self.logger.log("Cannot save articleDTO=\(self.articleDTO, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    self.showAlert.toggle()
                }
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
    
    private let persistenceHelper: PersistenceHelper
    
    private let keyChainHelper = KeyChainHelper()
    @Published var bawiCredentials = BawiCredentials(username: "", password: "")
    
    init(persistence: Persistence) {
        self.persistence = persistence
        self.persistenceHelper = PersistenceHelper(persistence: persistence)
        
        self.persistence.container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        self.searchHelper = SearchHelper(persistence: persistence)
        
        super.init()
        
        NotificationCenter.default
          .publisher(for: .NSPersistentStoreRemoteChange)
          .receive(on: DispatchQueue.main)
          .sink { [weak self] notification in
              self?.fetchUpdates(notification)
          }
          .store(in: &subscriptions)
        
        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.defaultsChanged()
            }
            .store(in: &subscriptions)
        
        fetchAll()
        
        if useKeychain {
            keyChainHelper.initialize()
            bawiCredentials = keyChainHelper.credentials
        }
        
        Task {
            if await self.searchHelper.isReady() {
                logger.log("init: oldIndexDeleted=\(self.oldIndexDeleted, privacy: .public)")
                if !self.oldIndexDeleted {
                    await self.searchHelper.deleteOldIndicies()
                    self.spotlightIndexing = false
                    self.oldIndexDeleted = true
                }
                
                await self.searchHelper.startIndexing()
                
                logger.log("init: spotlightIndexing=\(self.spotlightIndexing, privacy: .public)")
                if !spotlightIndexing {
                    await self.indexAll()
                    self.spotlightIndexing.toggle()
                }
                
                $searchString
                    .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
                    .sink { _ in
                        self.search()
                    }
                    .store(in: &subscriptions)
            }
        }
    }
    
    @objc private func defaultsChanged() -> Void {
        Task {
            logger.log("spotlightIndexing=\(self.spotlightIndexing, privacy: .public)")
            if !spotlightIndexing {
                await self.searchHelper.refresh()
                await self.indexAll()
                self.spotlightIndexing = true
            }
        }
    }
    
    private func indexAll() async {
        Task {
            logger.log("indexing all")
            for note in notes {
                await addToIndex(note.objectID)
            }
            for comment in comments {
                await addToIndex(comment.objectID)
            }
            for article in articles {
                await addToIndex(article.objectID)
            }
            logger.log("indexed all")
        }
    }
    
    private func fetchAll() {
        fetchNotes()
        fetchComments()
        fetchArticles()
    }
    
    private func fetchUpdates(_ notification: Notification) -> Void {
        Task {
            await persistence.fetchUpdates(notification) { result in
                switch result {
                case .success(let notification):
                    if let userInfo = notification.userInfo {
                        userInfo.forEach { key, value in
                            if let objectIDs = value as? Set<NSManagedObjectID> {
                                for objectId in objectIDs {
                                    Task {
                                        await self.addToIndex(objectId)
                                    }
                                }
                            }
                        }
                    }
                    break
                case .failure(let error):
                    self.logger.log("Error while persistence.fetchUpdates: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    private func addToIndex(_ objectID: NSManagedObjectID) async -> Void {
        guard let object = persistenceHelper.find(with: objectID) else {
            await searchHelper.remove(with: objectID.uriRepresentation().absoluteString)
            logger.log("Removed from index: \(objectID)")
            return
        }
        
        if let article = object as? Article {
            let articleAttributeSet = SearchAttributeSet(uid: article.objectID.uriRepresentation().absoluteString,
                                                         title: article.boardTitle,
                                                         subject: article.articleTitle,
                                                         textContent: article.body?.removingPercentEncoding,
                                                         comment: nil,
                                                         displayName: article.boardTitle,
                                                         contentDescription: article.articleTitle,
                                                         kind: BawiBrowserTab.articles.rawValue)
            
            await searchHelper.index(articleAttributeSet)
        }
        
        if let comment = object as? Comment {
            let commentAttributeSet = SearchAttributeSet(uid: comment.objectID.uriRepresentation().absoluteString,
                                                         title: nil,
                                                         subject: nil,
                                                         textContent: comment.body?.removingPercentEncoding,
                                                         comment: nil,
                                                         displayName: comment.boardTitle,
                                                         contentDescription: comment.body?.removingPercentEncoding,
                                                         kind: BawiBrowserTab.comments.rawValue)
            
            await searchHelper.index(commentAttributeSet)
        }
        
        if let note = object as? Note {
            let noteAttributeSet = SearchAttributeSet(uid: note.objectID.uriRepresentation().absoluteString,
                                                         title: nil,
                                                         subject: nil,
                                                         textContent: nil,
                                                         comment: note.msg?.removingPercentEncoding,
                                                         displayName: note.to,
                                                         contentDescription: note.msg?.removingPercentEncoding,
                                                         kind: BawiBrowserTab.notes.rawValue)
            
            await searchHelper.index(noteAttributeSet)
        }
        
    }
    
    private func saveContext(completionHandler: @escaping (Error) -> Void) -> Void {
        Task {
            persistence.container.viewContext.transactionAuthor = "App"
            
            do {
                try await persistence.save()
                self.toggle.toggle()
            } catch {
                self.logger.log("Error while saving data: \(error.localizedDescription, privacy: .public)")
                self.logger.log("Error while saving data: \(Thread.callStackSymbols, privacy: .public)")
                self.showAlert.toggle()
            }
            
            persistence.container.viewContext.transactionAuthor = nil
        }
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
        self.articles = persistenceHelper.perform(fetchRequest)
    }
    
    private func fetchComments() {
        let fetchRequest = NSFetchRequest<Comment>(entityName: "Comment")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Comment.created, ascending: false)]
        self.comments = persistenceHelper.perform(fetchRequest)
    }
    
    private func fetchNotes() {
        let fetchRequest = NSFetchRequest<Note>(entityName: "Note")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.created, ascending: false)]
        self.notes = persistenceHelper.perform(fetchRequest)
    }
    
    func delete(_ object: NSManagedObject) {
        persistenceHelper.delete(object)
    }
    
    func save() {
        persistenceHelper.save() { result in
            switch result {
            case .success(_):
                self.logger.log("Data saved successfully")
                DispatchQueue.main.async {
                    self.fetchAll()
                }
            case .failure(let error):
                self.logger.log("Error while saving data: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    // MARK: - Search
    private let searchHelper: SearchHelper
    

    var spotlightFoundComments: Set<CSSearchableItem> = []
    var spotlightFoundNotes: [CSSearchableItem] = []
    
    var articleSearchQuery: CSSearchQuery?
    var commentSearchQuery: CSSearchQuery?
    var noteSearchQuery: CSSearchQuery?
    
    private func search() {
        switch selectedTab {
        case .browser:
            return
        case .articles:
            searchArticle(searchString)
        case .comments:
            searchComment(searchString)
        case .notes:
            searchNote(searchString)
        }
    }
    
    func searchNote(_ text: String) -> Void {
        if text.isEmpty {
            noteSearchQuery?.cancel()
            fetchNotes()
        } else {
            searchNotes(text)
        }
    }
    
    func searchComment(_ text: String) -> Void {
        if text.isEmpty {
            commentSearchQuery?.cancel()
            fetchComments()
        } else {
            searchComments(text)
        }
    }
    
    func searchArticle(_ text: String) -> Void {
        if text.isEmpty {
            articleSearchQuery?.cancel()
            fetchArticles()
        } else {
            searchArticles(text)
        }
    }
    
    private func searchNotes(_ text: String) {
        Task {
            let items = await searchHelper.searchNotes(text)
            self.fetchNotes(items)
        }
    }
    
    private func searchComments(_ text: String) {
        Task {
            let items = await searchHelper.searchComments(text)
            self.fetchComments(items)
        }
    }
    
    private func searchArticles(_ text: String) {
        Task {
            let items = await searchHelper.searchArticles(text)
            self.fetchArticles(items)
        }
    }
    
    private func fetchNotes(_ items: [CSSearchableItem]) {
        logger.log("Fetching \(items.count) notes")
        notes = fetch(items).sorted(by: { note1, note2 in
            guard let created1 = note1.created else {
                return false
            }
            guard let created2 = note2.created else {
                return true
            }
            return created1 > created2
        })
        logger.log("Found \(self.notes.count) notes")
    }
    
    private func fetchNotes(_ uniqueIdentifiers: [String]) {
        logger.log("Fetching \(uniqueIdentifiers.count) notes")
        notes = fetch(uniqueIdentifiers).sorted(by: { note1, note2 in
            guard let created1 = note1.created else {
                return false
            }
            guard let created2 = note2.created else {
                return true
            }
            return created1 > created2
        })
        logger.log("Found \(self.notes.count) notes")
    }
    
    private func fetchComments(_ items: Set<CSSearchableItem>) {
        logger.log("Fetching \(items.count) comments")
        comments = fetch(Array(items)).sorted(by: { comment1, comment2 in
            guard let created1 = comment1.created else {
                return false
            }
            guard let created2 = comment2.created else {
                return true
            }
            return created1 > created2
        })
        logger.log("Found \(self.comments.count) comments")
    }
    
    private func fetchComments(_ uniqueIdentifiers: [String]) {
        logger.log("Fetching \(uniqueIdentifiers.count) comments")
        comments = fetch(uniqueIdentifiers).sorted(by: { comment1, comment2 in
            guard let created1 = comment1.created else {
                return false
            }
            guard let created2 = comment2.created else {
                return true
            }
            return created1 > created2
        })
        logger.log("Found \(self.comments.count) comments")
    }
    
    private func fetchArticles(_ items: [CSSearchableItem]) {
        logger.log("Fetching \(items.count) articles")
        let fetched: [Article] = fetch(items)
        logger.log("fetched.count=\(fetched.count)")
        articles = fetched.sorted(by: { article1, article2 in
            guard let created1 = article1.created else {
                return false
            }
            guard let created2 = article2.created else {
                return true
            }
            return created1 > created2
        })
        logger.log("Found \(self.articles.count) articles")
    }
    
    private func fetch<T: NSManagedObject>(_ items: [CSSearchableItem]) -> [T] {
        return items.compactMap { (item: CSSearchableItem) -> T? in
            guard let url = URL(string: item.uniqueIdentifier) else {
                self.logger.log("url is nil for item=\(item)")
                return nil
            }
            return find(for: url) as? T
        }
    }
    
    private func fetchArticles(_ uniqueIdentifiers: [String]) {
        logger.log("Fetching \(uniqueIdentifiers.count) articles")
        let fetched: [Article] = fetch(uniqueIdentifiers)
        logger.log("fetched.count=\(fetched.count)")
        articles = fetched.sorted(by: { article1, article2 in
            guard let created1 = article1.created else {
                return false
            }
            guard let created2 = article2.created else {
                return true
            }
            return created1 > created2
        })
        logger.log("Found \(self.articles.count) articles")
    }
    
    private func fetch<T: NSManagedObject>(_ uniqueIdentifiers: [String]) -> [T] {
        return uniqueIdentifiers.compactMap { (uniqueIdentifier: String) -> T? in
            guard let url = URL(string: uniqueIdentifier) else {
                self.logger.log("url is nil for uniqueIdentifier=\(uniqueIdentifier)")
                return nil
            }
            return find(for: url) as? T
        }
    }
    
    func find(for url: URL) -> NSManagedObject? {
        guard let objectID = persistence.container.viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
            self.logger.log("objectID is nil for url=\(url)")
            return nil
        }
        return persistence.container.viewContext.object(with: objectID)
    }
    
    func continueActivity(_ activity: NSUserActivity) {
        logger.log("continueActivity: \(activity)")
        guard let info = activity.userInfo, let objectIdentifier = info[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        guard let objectURI = URL(string: objectIdentifier), let entity = find(for: objectURI) else {
            logger.log("Can't find an object with objectIdentifier=\(objectIdentifier)")
            return
        }
        
        logger.log("entity = \(entity)")
        
        DispatchQueue.main.async {
            if let article = entity as? Article {
                self.selectedTab = .articles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.search(article.articleTitle ?? "")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.selectedArticle = ["articleId": article.articleId, "boardId": article.boardId]
                    }
                }
            } else if let comment = entity as? Comment {
                self.selectedTab = .comments
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.search(comment.body?.removingPercentEncoding ?? "")
                }
            } else if let note = entity as? Note {
                self.selectedTab = .notes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.search(note.msg?.removingPercentEncoding ?? "")
                }
            }
        }
        
    }
    
    // MARK: - credentials
    func searchCredentials(completionHandler: @escaping (Result<BawiCredentials, Error>) -> Void) {
        self.keyChainHelper.search(completionHandler: completionHandler)
    }
    
    func processCredentials(_ httpBody: Data) -> Void {
        guard useKeychain else {
            logger.log("Do nothing since useKeychain=\(self.useKeychain, privacy: .public)")
            self.setCredentials(BawiCredentials(username: "", password: ""))
            return
        }
        
        guard let dataString = String(data: httpBody, encoding: .utf8) else {
            logger.log("Cannot convert to String: httpBody=\(httpBody)")
            return
        }
        
        let keyValuePair: [String: String] = Dictionary(uniqueKeysWithValues: dataString.split(separator: "&")
                .map {
                    let keyValuePair = $0.split(separator: "=")
                    return (String(keyValuePair[0]), String(keyValuePair[1]))
                }
            )

        var credentials: BawiCredentials?
        if let username = keyValuePair["id"], let password = keyValuePair["passwd"] {
            credentials = BawiCredentials(username: username, password: password)
            logger.log("username=\(credentials!.username), password=\(credentials!.password)")
        }
        
        searchCredentials { result in
            switch result {
            case .failure(let error):
                self.logger.log("Can't find credentials in key chain: \(error.localizedDescription, privacy: .public)")
                if let credentials = credentials {
                    self.logger.log("Trying to add credentials to keychain")
                    self.keyChainHelper.credentials = credentials
                    self.setCredentials(credentials)
                    do {
                        try self.keyChainHelper.add()
                    } catch {
                        self.logger.log("Failed to add credentials to keychain: \(error.localizedDescription, privacy: .public)")
                    }
                }
            case .success(let existingCredentials):
                self.setCredentials(existingCredentials)
                if let credentials = credentials {
                    if existingCredentials.username != credentials.username || existingCredentials.password != credentials.password {
                        self.logger.log("Trying to update credentials in keychain")
                        self.keyChainHelper.credentials = credentials
                        self.setCredentials(credentials)
                        do {
                            try self.keyChainHelper.update()
                        } catch {
                            self.logger.log("Failed to update credentials in keychain: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
            }
        }
    }
    
    func deleteCredentials() -> Void {
        setCredentials(BawiCredentials(username: "", password: ""))
        navigation = .reload
        do {
            try self.keyChainHelper.delete()
        } catch {
            self.logger.log("Failed to delete credentials in keychain: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func setCredentials(_ credentials: BawiCredentials) -> Void {
        DispatchQueue.main.async {
            self.bawiCredentials = credentials
        }
    }
    
    func selectArticle(title: String, articleId: Int64, boradId: Int64) -> Void {
        searchArticleTitle = title
        selectedArticle = ["articleId": articleId, "boardId": boradId]
    }
}

extension BawiBrowserViewModel: BawiBrowserSearchDelegate {
    nonisolated func search(_ text: String) {
        Task { @MainActor in
            searchString = text
        }
    }
    
    nonisolated func cancelSearch() {
        Task { @MainActor in
            await searchHelper.cancelSearch()
            fetchAll()
        }
    }
}
