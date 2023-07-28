//
//  BawiBrowserSpotlightDelegate.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/28/23.
//

import Foundation
import CoreSpotlight
import CoreData

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
