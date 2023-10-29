//
//  BawiBrowserSpotlightDelegate.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/28/23.
//

import Foundation
import CoreSpotlight
import CoreData
import OSLog

class BawiBrowserSpotlightDelegate: NSCoreDataCoreSpotlightDelegate {
    let logger = Logger()
    
    override func domainIdentifier() -> String {
        return BawiBrowserConstants.domainIdentifier.rawValue
    }

    override func indexName() -> String? {
        return BawiBrowserConstants.indexName.rawValue
    }
    
    override func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        if let article = object as? Article {
            return populateAttributes(for: article)
        }
        
        if let comment = object as? Comment {
            return populateAttributes(for: comment)
        }
        
        if let note = object as? Note {
            return populateAttributes(for: note)
        }
        
        return nil
    }
    
    private func populateAttributes(for article: Article)-> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = article.boardTitle
        attributeSet.subject = article.articleTitle
        attributeSet.textContent = article.body?.removingPercentEncoding
        attributeSet.displayName = article.boardTitle
        attributeSet.contentDescription = article.articleTitle
        attributeSet.kind = BawiBrowserTab.articles.rawValue
        return attributeSet
    }
    
    private func populateAttributes(for comment: Comment)-> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.textContent = comment.body?.removingPercentEncoding
        attributeSet.displayName = comment.boardTitle
        attributeSet.contentDescription = comment.body?.removingPercentEncoding
        attributeSet.kind = BawiBrowserTab.comments.rawValue
        return attributeSet
    }
    
    private func populateAttributes(for note: Note)-> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.comment = note.msg?.removingPercentEncoding
        attributeSet.displayName = note.to
        attributeSet.contentDescription = note.msg?.removingPercentEncoding
        attributeSet.kind = BawiBrowserTab.notes.rawValue
        return attributeSet
    }
    
}

class ArticleSpotlightDelegate: NSCoreDataCoreSpotlightDelegate {
    override func domainIdentifier() -> String {
        return BawiBrowserConstants.domainIdentifier.rawValue
    }

    override func indexName() -> String? {
        return BawiBrowserConstants.articleIndexName.rawValue
    }
    
    override func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        if let article = object as? Article {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = article.boardTitle
            attributeSet.subject = article.articleTitle
            attributeSet.textContent = article.body?.removingPercentEncoding
            attributeSet.displayName = article.boardTitle
            attributeSet.contentDescription = article.articleTitle
            return attributeSet
        }

        return nil
    }
}

class CommentSpotlightDelegate: NSCoreDataCoreSpotlightDelegate {
    override func domainIdentifier() -> String {
        return BawiBrowserConstants.domainIdentifier.rawValue
    }

    override func indexName() -> String? {
        return BawiBrowserConstants.commentIndexName.rawValue
    }
    
    override func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        if let comment = object as? Comment {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.textContent = comment.body?.removingPercentEncoding
            attributeSet.displayName = comment.boardTitle
            attributeSet.contentDescription = comment.body?.removingPercentEncoding
            return attributeSet
        }
        
        return nil
    }
}

class NoteSpotlightDelegate: NSCoreDataCoreSpotlightDelegate {
    override func domainIdentifier() -> String {
        return BawiBrowserConstants.domainIdentifier.rawValue
    }

    override func indexName() -> String? {
        return BawiBrowserConstants.noteIndexName.rawValue
    }
    
    override func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        if let note = object as? Note {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.comment = note.msg?.removingPercentEncoding
            attributeSet.displayName = note.to
            attributeSet.contentDescription = note.msg?.removingPercentEncoding
            return attributeSet
        }

        return nil
    }
}
