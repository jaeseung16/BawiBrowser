//
//  PersistenceHelper.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/16/23.
//

import Foundation
import CoreData
import os
@preconcurrency import Persistence

final class PersistenceHelper: Sendable {
    private static let logger = Logger()
    
    private let persistence: Persistence
    var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }
    
    init(persistence: Persistence) {
        self.persistence = persistence
    }
    
    func save(completionHandler: @escaping (Result<Void, Error>) -> Void) -> Void {
        Task {
            do {
                try await save()
                completionHandler(.success(()))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    func save() async throws -> Void {
        try await persistence.save()
    }
    
    func delete(_ object: NSManagedObject) -> Void {
        viewContext.delete(object)
    }
    
    func fetch<Element>(_ fetchRequest: NSFetchRequest<Element>) -> [Element] {
        var fetchedEntities = [Element]()
        do {
            fetchedEntities = try viewContext.fetch(fetchRequest)
        } catch {
            PersistenceHelper.logger.error("Failed to fetch with fetchRequest=\(fetchRequest, privacy: .public): error=\(error.localizedDescription, privacy: .public)")
        }
        return fetchedEntities
    }
    
    func perform<Element>(_ fetchRequest: NSFetchRequest<Element>) -> [Element] {
        var fetchedEntities = [Element]()
        do {
            fetchedEntities = try viewContext.fetch(fetchRequest)
        } catch {
            PersistenceHelper.logger.error("Failed to fetch with fetchRequest=\(fetchRequest, privacy: .public): error=\(error.localizedDescription, privacy: .public)")
        }
        return fetchedEntities
    }
    
    @available(*, renamed: "save(article:)")
    func save(article dto: BawiArticleDTO, completionHandler: @escaping (Result<Void,Error>) -> Void) -> Void {
        Task {
            do {
                try await save(article: dto)
                completionHandler(.success(()))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    func save(article dto: BawiArticleDTO) async throws {
        if dto.articleId > 0, let existingArticle = getArticle(boardId: dto.boardId, articleId: dto.articleId) {
            existingArticle.articleId = Int64(dto.articleId)
            existingArticle.articleTitle = dto.articleTitle
            existingArticle.boardId = Int64(dto.boardId)
            existingArticle.boardTitle = dto.boardTitle
            existingArticle.body = dto.body
            existingArticle.lastupd = Date()
            
            if let attachments = dto.attachments, !attachments.isEmpty {
                for attachment in attachments {
                    let attachmentEntity = Attachment(context: viewContext)
                    attachmentEntity.article = existingArticle
                    attachmentEntity.content = attachment
                    attachmentEntity.created = Date()
                }
                PersistenceHelper.logger.log("attachments.count = \(attachments.count)")
            }
        } else {
            let article = Article(context: viewContext)
            article.articleId = Int64(dto.articleId)
            article.articleTitle = dto.articleTitle
            article.boardId = Int64(dto.boardId)
            article.boardTitle = dto.boardTitle
            article.body = dto.body
            article.created = Date()
            article.lastupd = Date()
            
            if let attachments = dto.attachments, !attachments.isEmpty {
                for attachment in attachments {
                    let attachmentEntity = Attachment(context: viewContext)
                    attachmentEntity.article = article
                    attachmentEntity.content = attachment
                    attachmentEntity.created = Date()
                }
                PersistenceHelper.logger.log("attachments.count = \(attachments.count)")
            }
            
            PersistenceHelper.logger.log("article = \(article)")
        }
        
        try await save()
    }
    
    private func getArticle(boardId: Int, articleId: Int) -> Article? {
        PersistenceHelper.logger.log("boardId = \(boardId), articleId = \(articleId)")
        let fetchRequest = NSFetchRequest<Article>(entityName: "Article")
        fetchRequest.predicate = NSPredicate(format: "boardId == %@ AND articleId == %@", argumentArray: [boardId, articleId])
        
        let fetchedArticles = perform(fetchRequest)
        return fetchedArticles.isEmpty ? nil : fetchedArticles[0]
    }
    
    @available(*, renamed: "save(comment:)")
    func save(comment dto: BawiCommentDTO, completionHandler: @escaping (Result<Void,Error>) -> Void) {
        Task {
            do {
                try await save(comment: dto)
                completionHandler(.success(()))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    
    func save(comment dto: BawiCommentDTO) async throws {
        let comment = Comment(context: viewContext)
        comment.articleId = Int64(dto.articleId)
        comment.articleTitle = dto.articleTitle
        comment.boardId = Int64(dto.boardId)
        comment.boardTitle = dto.boardTitle
        comment.body = dto.body.replacingOccurrences(of: "+", with: "%20")
        comment.created = Date()
        
        try await save()
    }
    
    @available(*, renamed: "save(note:)")
    func save(note dto: BawiNoteDTO, completionHandler: @escaping (Result<Void,Error>) -> Void) {
        Task {
            do {
                try await save(note: dto)
                completionHandler(.success(()))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    func save(note dto: BawiNoteDTO) async throws -> Void {
        let note = Note(context: viewContext)
        note.action = dto.action
        note.to = dto.to
        note.msg = dto.msg
        note.created = Date()
        
        try await save()
    }
    
    func find(with objectID: NSManagedObjectID) -> NSManagedObject? {
        return viewContext.object(with: objectID)
    }
}
