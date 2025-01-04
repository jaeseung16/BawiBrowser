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

class SearchHelper {
    private let logger = Logger()
    
    var spotlightFoundArticles: [CSSearchableItem] = []
    var spotlightFoundComments: Set<CSSearchableItem> = []
    var spotlightFoundNotes: [CSSearchableItem] = []
    
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
    
    func prepareArticleQuery(_ text: String) -> CSSearchQuery {
        let escapedText = escape(text: text)
        let queryString = "(\(QueryAttribute.textContent.rawValue) == \"*\(escapedText)*\"cd || \(QueryAttribute.subject.rawValue) == \"*\(escapedText)*\"cd) && \(QueryAttribute.kind.rawValue) == \"\(BawiBrowserTab.articles.rawValue)\""
        logger.log("articleQuery=\(queryString)")
        return CSSearchQuery(queryString: queryString, attributes: [QueryAttribute.textContent.rawValue, QueryAttribute.subject.rawValue, QueryAttribute.kind.rawValue])
    }
    
    func prepareCommentQuery(_ text: String) -> CSSearchQuery {
        let escapedText = escape(text: text)
        let queryString = "\(QueryAttribute.textContent.rawValue) == \"*\(escapedText)*\"cd && \(QueryAttribute.kind.rawValue) == \"\(BawiBrowserTab.comments.rawValue)\""
        logger.log("commentQuery=\(queryString)")
        return CSSearchQuery(queryString: queryString, attributes: [QueryAttribute.textContent.rawValue])
    }
    
    func prepareNoteQuery(_ text: String) -> CSSearchQuery {
        let escapedText = escape(text: text)
        let queryString = "\(QueryAttribute.comment.rawValue) == \"*\(escapedText)*\"cd && \(QueryAttribute.kind.rawValue) == \"\(BawiBrowserTab.notes.rawValue)\""
        logger.log("noteQuery=\(queryString)")
        return CSSearchQuery(queryString: queryString, attributes: [QueryAttribute.comment.rawValue])
    }
    
    private func escape(text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
