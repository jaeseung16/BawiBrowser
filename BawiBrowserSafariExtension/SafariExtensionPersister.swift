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
    
    func addAttachment(_ data: Data) -> Void {
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
    
    func save(article dto: BawiArticleDTO) -> Void {
        // viewContext is main-queue confined; the actor executor is not the main
        // queue, so all context work has to go through performAndWait.
        // Only the Sendable NSManagedObjectID crosses into the @Sendable
        // closure; the managed object itself is resolved inside the closure.
        let existingArticleID = dto.articleId > 0 ? getExistingArticleID(boardId: dto.boardId, articleId: dto.articleId) : nil
        viewContext.performAndWait {
            if let existingArticleID, let existingArticle = try? viewContext.existingObject(with: existingArticleID) as? Article {
                existingArticle.articleId = Int64(dto.articleId)
                existingArticle.articleTitle = dto.articleTitle
                existingArticle.boardId = Int64(dto.boardId)
                existingArticle.boardTitle = dto.boardTitle
                existingArticle.body = dto.body
                existingArticle.lastupd = Date()

                addAttachmens(to: existingArticle, from: dto, in: viewContext)
            } else {
                let article = Article(context: viewContext)
                article.articleId = Int64(dto.articleId)
                article.articleTitle = dto.articleTitle
                article.boardId = Int64(dto.boardId)
                article.boardTitle = dto.boardTitle
                article.body = dto.body
                article.created = Date()
                article.lastupd = Date()

                addAttachmens(to: article, from: dto, in: viewContext)
            }

            do {
                try saveContext(viewContext)
            } catch {
                logger.log("While saving \(dto, privacy: .public) occured an unresolved error \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    private func getExistingArticleID(boardId: Int, articleId: Int) -> NSManagedObjectID? {
        do {
            return try viewContext.performAndWait {
                // Built inside the closure because NSFetchRequest is not
                // Sendable and must not be captured by the @Sendable closure.
                // Only the Sendable objectID is returned out of the closure.
                let fetchRequest = NSFetchRequest<Article>(entityName: "Article")
                fetchRequest.predicate = NSPredicate(format: "boardId == %@ AND articleId == %@", argumentArray: [boardId, articleId])
                return try viewContext.fetch(fetchRequest).first?.objectID
            }
        } catch {
            logger.log("Failed to fetch article with boardId = \(boardId, privacy: .public) and articleId = \(articleId, privacy: .public): \(error.localizedDescription)")
            return nil
        }
    }
    
    // nonisolated because it's invoked from within viewContext.performAndWait
    // closures, which run on the context's queue rather than the actor's
    // executor. The context is passed in explicitly so no actor-isolated state
    // is touched.
    private nonisolated func addAttachmens(to article: Article, from dto: BawiArticleDTO, in context: NSManagedObjectContext) -> Void {
        if let attachments = dto.attachments, !attachments.isEmpty {
            attachments.forEach { attachment in
                let attachmentEntity = Attachment(context: context)
                attachmentEntity.article = article
                attachmentEntity.content = attachment
                attachmentEntity.created = Date()
            }
            logger.log("attachments.count = \(attachments.count, privacy: .public)")
        }
    }
    
    func save(comment dto: BawiCommentDTO) -> Void {
        logger.log("commentDTO = \(dto, privacy: .public)")

        viewContext.performAndWait {
            let comment = Comment(context: self.viewContext)
            comment.articleId = Int64(dto.articleId)
            comment.articleTitle = dto.articleTitle
            comment.boardId = Int64(dto.boardId)
            comment.boardTitle = dto.boardTitle
            comment.body = dto.body
            comment.created = Date()

            do {
                try saveContext(viewContext)
            } catch {
                logger.log("Error occured while saving \(dto, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func save(note dto: BawiNoteDTO) -> Void {
        logger.log("noteDTO = \(dto)")

        viewContext.performAndWait {
            let note = Note(context: self.viewContext)
            note.action = dto.action
            note.to = dto.to
            note.msg = dto.msg
            note.created = Date()

            do {
                try saveContext(viewContext)
            } catch {
                logger.log("Error occured while saving \(dto, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // nonisolated because it's invoked from within viewContext.performAndWait
    // closures, which run on the context's queue rather than the actor's
    // executor. The context is passed in explicitly so no actor-isolated state
    // is touched.
    private nonisolated func saveContext(_ context: NSManagedObjectContext) throws -> Void {
        // performAndWait is reentrancy-safe, so this may be called from within
        // another performAndWait block.
        try context.performAndWait {
            context.transactionAuthor = "Safari Extension"
            defer {
                context.transactionAuthor = nil
            }
            try context.save()
        }
    }
}
