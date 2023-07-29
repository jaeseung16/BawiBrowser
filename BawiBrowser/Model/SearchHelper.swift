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
}

class SearchHelper {
    static let shared = SearchHelper()
    
    private let logger = Logger()
    
    var spotlightFoundArticles: [CSSearchableItem] = []
    var spotlightFoundComments: Set<CSSearchableItem> = []
    var spotlightFoundNotes: [CSSearchableItem] = []
    
    private var searchQueryForArticle: CSSearchQuery?
    private var searchQueryForComment: CSSearchQuery?
    private var searchQueryForNote: CSSearchQuery?
    
    private init() {
        
    }
    
    func prepareArticleQuery(_ text: String) -> CSSearchQuery {
        let escapedText = escape(text: text)
        let queryString = "(\(QueryAttribute.textContent.rawValue) == \"*\(escapedText)*\"cd) || (\(QueryAttribute.subject.rawValue) == \"*\(escapedText)*\"cd)"
        logger.log("articleQuery=\(queryString)")
        return CSSearchQuery(queryString: queryString, attributes: [QueryAttribute.textContent.rawValue, QueryAttribute.subject.rawValue])
    }
    
    func prepareCommentQuery(_ text: String) -> CSSearchQuery {
        let escapedText = escape(text: text)
        let queryString = "(\(QueryAttribute.textContent.rawValue) == \"*\(escapedText)*\"cd)"
        logger.log("commentQuery=\(queryString)")
        return CSSearchQuery(queryString: queryString, attributes: [QueryAttribute.textContent.rawValue])
    }
    
    func prepareNoteQuery(_ text: String) -> CSSearchQuery {
        let escapedText = escape(text: text)
        let queryString = "(\(QueryAttribute.comment.rawValue) == \"*\(escapedText)*\"cd)"
        logger.log("noteQuery=\(queryString)")
        return CSSearchQuery(queryString: queryString, attributes: [QueryAttribute.comment.rawValue])
    }
    
    private func escape(text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
