//
//  SearchAttributeSet.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 1/5/25.
//

import CoreSpotlight

struct SearchAttributeSet: Sendable {
    private let contentType = UTType.text
    
    let uid: String
    let title: String?
    let subject: String?
    let textContent: String?
    let comment: String?
    let displayName: String?
    let contentDescription: String?
    let kind: String?
    
    func getCSSearchableItemAttributeSet() -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(contentType: contentType)
        attributeSet.title = title
        attributeSet.subject = subject
        attributeSet.textContent = textContent
        attributeSet.comment = comment
        attributeSet.displayName = displayName
        attributeSet.contentDescription = contentDescription
        attributeSet.kind = kind
        return attributeSet
    }
}
