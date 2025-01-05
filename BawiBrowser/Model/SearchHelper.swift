//
//  SearchHelper.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/28/23.
//

import Foundation
import CoreSpotlight
import CoreData
import os

enum SearchError: Error {
    case emptySearchText
}

enum QueryAttribute: String {
    case textContent
    case comment
    case subject
    case kind
}

actor SearchHelper {
    private let logger = Logger()
    
    private var spotlightFoundComments: Set<CSSearchableItem> = []
    private var spotlightFoundNotes: [CSSearchableItem] = []
    
    private var searchQueryForArticle: CSSearchQuery?
    private var searchQueryForComment: CSSearchQuery?
    private var searchQueryForNote: CSSearchQuery?
    
    private let spotlightIndexer: BawiBrowserSpotlightDelegate?
    
    init(spotlightIndexer: BawiBrowserSpotlightDelegate?) {
        self.spotlightIndexer = spotlightIndexer
    }
    
    func toggleIndexing() {
        guard let spotlightIndexer = spotlightIndexer else { return }
        if spotlightIndexer.isIndexingEnabled {
            spotlightIndexer.stopSpotlightIndexing()
        } else {
            spotlightIndexer.startSpotlightIndexing()
        }
    }
    
    func startIndexing() {
        guard let spotlightIndexer = spotlightIndexer else { return }
        if !spotlightIndexer.isIndexingEnabled {
            spotlightIndexer.startSpotlightIndexing()
        }
    }
    
    func stopIndexing() {
        guard let spotlightIndexer = spotlightIndexer else { return }
        if spotlightIndexer.isIndexingEnabled {
            spotlightIndexer.stopSpotlightIndexing()
        }
    }
    
    func refresh() {
        stopIndexing()
        delete(indexName: BawiBrowserConstants.indexName.rawValue)
        startIndexing()
    }
    
    private func delete(indexName: String) {
        let index = CSSearchableIndex(name: indexName)
        index.deleteAllSearchableItems { error in
            self.logger.log("Error while deleting index=\(BawiBrowserConstants.indexName.rawValue, privacy: .public)")
        }
    }
    
    func deleteOldIndicies() {
        [BawiBrowserConstants.articleIndexName,
         BawiBrowserConstants.commentIndexName,
         BawiBrowserConstants.noteIndexName].forEach {
            delete(indexName: $0.rawValue)
        }
    }
    
    private func index<T: NSManagedObject>(_ entities: [T]) {
        guard let spotlightIndexer = spotlightIndexer, let indexName = spotlightIndexer.indexName() else { return }
        
        let searchableItems: [CSSearchableItem] = entities.compactMap { (entity: T) -> CSSearchableItem? in
            guard let attributeSet = spotlightIndexer.attributeSet(for: entity) else {
                self.logger.log("Cannot generate attribute set for \(entity, privacy: .public)")
                return nil
            }
            return CSSearchableItem(uniqueIdentifier: entity.objectID.uriRepresentation().absoluteString, domainIdentifier: BawiBrowserConstants.domainIdentifier.rawValue, attributeSet: attributeSet)
        }
        
        logger.log("Adding \(searchableItems.count) items to index=\(indexName, privacy: .public)")
        
        CSSearchableIndex(name: indexName).indexSearchableItems(searchableItems) { error in
            guard let error = error else {
                return
            }
            self.logger.log("Error while indexing \(T.self): \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func index(notes: [Note]) -> Void {
        logger.log("Indexing \(notes.count, privacy: .public) notes")
        index<Note>(notes)
    }
    
    func index(comments: [Comment]) -> Void {
        logger.log("Indexing \(comments.count, privacy: .public) comments")
        index<Comment>(comments)
    }
    
    func index(articles: [Article]) -> Void {
        logger.log("Indexing \(articles.count, privacy: .public) articles")
        index<Article>(articles)
    }
    
    public func index(_ attributeSet: SearchAttributeSet) {
        guard let spotlightIndexer = spotlightIndexer, let indexName = spotlightIndexer.indexName() else { return }
        
        let searchableItem: CSSearchableItem = CSSearchableItem(uniqueIdentifier: attributeSet.uid,
                                                                domainIdentifier: spotlightIndexer.domainIdentifier(),
                                                                attributeSet: attributeSet.getCSSearchableItemAttributeSet())
        
        CSSearchableIndex(name: indexName).indexSearchableItems([searchableItem]) { error in
            guard let error = error else {
                return
            }
            self.logger.log("Error while indexing: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func remove<T: NSManagedObject>(_ entity: T) -> Void {
        remove(with: entity.objectID.uriRepresentation().absoluteString)
    }
    
    func remove(with identifier: String) {
        guard let spotlightIndexer = spotlightIndexer, let indexName = spotlightIndexer.indexName() else { return }
        
        CSSearchableIndex(name: indexName).deleteSearchableItems(withIdentifiers: [identifier]) { error in
            self.logger.log("Can't delete an item with identifier=\(identifier, privacy: .public)")
        }
    }

    private func search(with query: CSSearchQuery) async throws -> [String] {
        var results: [String] = []
        for try await result in query.results {
            results.append(result.item.uniqueIdentifier)
        }
        return results
    }
        
    func searchArticles(_ text: String) async -> [String] {
        var results: [String] = []
        do {
            results = try await search(with: prepareArticleQuery(text))
        } catch {
            self.logger.log("Caught an error while searching articles with search string \(text): \(error.localizedDescription, privacy: .public)")
        }
        return results
    }
    
    func prepareArticleQuery(_ text: String) -> CSSearchQuery {
        let escapedText = escape(text: text)
        let queryString = "(\(QueryAttribute.textContent.rawValue) == \"*\(escapedText)*\"cd || \(QueryAttribute.subject.rawValue) == \"*\(escapedText)*\"cd) && \(QueryAttribute.kind.rawValue) == \"\(BawiBrowserTab.articles.rawValue)\""
        logger.log("articleQuery=\(queryString)")
        
        let queryContext = CSSearchQueryContext()
        queryContext.fetchAttributes = [QueryAttribute.textContent.rawValue, QueryAttribute.subject.rawValue, QueryAttribute.kind.rawValue]
        
        return CSSearchQuery(queryString: queryString, queryContext: queryContext)
    }
    
    func searchComments(_ text: String) async -> [String] {
        var results: [String] = []
        do {
            results = try await search(with: prepareCommentQuery(text))
        } catch {
            self.logger.log("Caught an error while searching comments with search string \(text): \(error.localizedDescription, privacy: .public)")
        }
        return results
    }
    
    func prepareCommentQuery(_ text: String) -> CSSearchQuery {
        let escapedText = escape(text: text)
        let queryString = "\(QueryAttribute.textContent.rawValue) == \"*\(escapedText)*\"cd && \(QueryAttribute.kind.rawValue) == \"\(BawiBrowserTab.comments.rawValue)\""
        logger.log("commentQuery=\(queryString)")
        
        let queryContext = CSSearchQueryContext()
        queryContext.fetchAttributes = [QueryAttribute.textContent.rawValue, QueryAttribute.kind.rawValue]
        
        return CSSearchQuery(queryString: queryString, queryContext: queryContext)
    }
    
    func searchNotes(_ text: String) async -> [String] {
        var results: [String] = []
        do {
            results = try await search(with: prepareNoteQuery(text))
        } catch {
            self.logger.log("Caught an error while searching notes with search string \(text): \(error.localizedDescription, privacy: .public)")
        }
        return results
    }
    
    func prepareNoteQuery(_ text: String) -> CSSearchQuery {
        let escapedText = escape(text: text)
        let queryString = "\(QueryAttribute.comment.rawValue) == \"*\(escapedText)*\"cd && \(QueryAttribute.kind.rawValue) == \"\(BawiBrowserTab.notes.rawValue)\""
        logger.log("noteQuery=\(queryString)")
        
        let queryContext = CSSearchQueryContext()
        queryContext.fetchAttributes = [QueryAttribute.comment.rawValue, QueryAttribute.kind.rawValue]
        
        return CSSearchQuery(queryString: queryString, queryContext: queryContext)
    }
    
    private func escape(text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
    
    func cancelSearch() {
        self.searchQueryForArticle?.cancel()
        self.searchQueryForComment?.cancel()
        self.searchQueryForNote?.cancel()
    }
}
