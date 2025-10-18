//
//  SafariExtensionPersister.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 1/20/25.
//

import SafariServices
import Persistence
import os

actor SafariExtensionPersister {
    
    public static let shared = SafariExtensionPersister()
    
    private let logger = Logger()
    
    private let viewContext = Persistence(name: BawiBrowserConstants.appName.rawValue, identifier: BawiBrowserConstants.iCloudIdentifier.rawValue).container.viewContext
    
    var articleDTO: BawiArticleDTO?
    private var attachedData: [Data]?
    private var downloading: Bool = false
    
    func isAricleAvailable() -> Bool {
        return articleDTO != nil
    }
    
    func hasAttachments() -> Bool {
        return attachedData != nil
    }
    
    func populate(article dto: BawiArticleDTO) -> Void {
        self.articleDTO = dto
        logger.log("articleDTO = \(String(describing: self.articleDTO), privacy: .public)")
    }
    
    func addAttachments(_ data: Data) -> Void {
        if attachedData == nil {
            attachedData = [Data]()
        }
        attachedData?.append(data)
    }
    
    func saveArticle(_ articleId: Int) {
        if isAricleAvailable() {
            if hasAttachments() && articleDTO!.attachCount != attachedData!.count {
                logger.log("WARNING: \(String(describing: self.articleDTO!.attachCount), privacy: .public) files are expected. But \(self.attachedData!.count, privacy: .public) files have been downloaded")
            }
            
            articleDTO!.articleId = articleId
            articleDTO!.attachments = attachedData
            logger.log("articleDTO = \(String(describing: self.articleDTO), privacy: .public)")
            
            if let dto = articleDTO {
                save(article: dto)
            }
        }
        
        articleDTO = nil
        attachedData = nil
    }
    
    func saveArticle(_ properties: SFSafariPageProperties) {
        if let url = properties.url, url.absoluteString.contains("read.cgi") {
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            
            if let queryItems = urlComponents?.queryItems {
                for queryItem in queryItems {
                    if queryItem.name == "aid", let aid = queryItem.value {
                        logger.log("aid = \(aid, privacy: .public)")
                        self.articleDTO!.articleId = Int(aid)!
                    }
                }
            }
            
            if self.attachedData != nil && self.articleDTO!.attachCount != self.attachedData!.count {
                logger.log("WARNING: \(String(describing: self.articleDTO!.attachCount), privacy: .public) files are expected. But \(self.attachedData!.count, privacy: .public) files have been downloaded")
            }
            
            self.articleDTO!.attachments = self.attachedData
            
            logger.log("articleDTO = \(String(describing: self.articleDTO))")
            
            self.save(article: self.articleDTO!)
            
            self.articleDTO = nil
            self.attachedData = nil
        }
    }
    
    func save(article dto: BawiArticleDTO) -> Void {
        if dto.articleId > 0, let existingArticle = getExistingArticle(boardId: dto.boardId, articleId: dto.articleId) {
            existingArticle.articleId = Int64(dto.articleId)
            existingArticle.articleTitle = dto.articleTitle
            existingArticle.boardId = Int64(dto.boardId)
            existingArticle.boardTitle = dto.boardTitle
            existingArticle.body = dto.body
            existingArticle.lastupd = Date()
            
            addAttachmens(to: existingArticle, from: dto)
        } else {
            let article = Article(context: viewContext)
            article.articleId = Int64(dto.articleId)
            article.articleTitle = dto.articleTitle
            article.boardId = Int64(dto.boardId)
            article.boardTitle = dto.boardTitle
            article.body = dto.body
            article.created = Date()
            article.lastupd = Date()
            
            addAttachmens(to: article, from: dto)
        }
        
        do {
            try saveContext()
        } catch {
            logger.log("While saving \(dto, privacy: .public) occured an unresolved error \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func getExistingArticle(boardId: Int, articleId: Int) -> Article? {
        let predicate = NSPredicate(format: "boardId == %@ AND articleId == %@", argumentArray: [boardId, articleId])
        
        let fetchRequest = NSFetchRequest<Article>(entityName: "Article")
        fetchRequest.predicate = predicate
        
        var fetchedArticles = [Article]()
        do {
            fetchedArticles = try viewContext.fetch(fetchRequest)
        } catch {
            logger.log("Failed to fetch article with boardId = \(boardId, privacy: .public) and articleId = \(articleId, privacy: .public): \(error.localizedDescription)")
        }
        
        return fetchedArticles.isEmpty ? nil : fetchedArticles[0]
    }
    
    private func addAttachmens(to article: Article, from dto: BawiArticleDTO) -> Void {
        if let attachments = dto.attachments, !attachments.isEmpty {
            attachments.forEach { attachment in
                let attachmentEntity = Attachment(context: viewContext)
                attachmentEntity.article = article
                attachmentEntity.content = attachment
                attachmentEntity.created = Date()
            }
            logger.log("attachments.count = \(attachments.count, privacy: .public)")
        }
    }
    
    func save(comment dto: BawiCommentDTO) -> Void {
        logger.log("commentDTO = \(dto, privacy: .public)")
        
        let comment = Comment(context: self.viewContext)
        comment.articleId = Int64(dto.articleId)
        comment.articleTitle = dto.articleTitle
        comment.boardId = Int64(dto.boardId)
        comment.boardTitle = dto.boardTitle
        comment.body = dto.body
        comment.created = Date()
        
        do {
            try saveContext()
        } catch {
            logger.log("Error occured while saving \(dto, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func save(note dto: BawiNoteDTO) -> Void {
        logger.log("noteDTO = \(dto)")
        
        let note = Note(context: self.viewContext)
        note.action = dto.action
        note.to = dto.to
        note.msg = dto.msg
        note.created = Date()
        
        do {
            try saveContext()
        } catch {
            logger.log("Error occured while saving \(dto, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func saveContext() throws -> Void {
        viewContext.transactionAuthor = "Safari Extension"
        try viewContext.save()
        viewContext.transactionAuthor = nil
    }
}
