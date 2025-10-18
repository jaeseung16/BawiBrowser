//
//  WriteFormHandler.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 10/18/25.
//

actor WriteFormHandler: MessageHandling {

    private let article: BawiArticleDTO
    
    init(article: BawiArticleDTO) {
        self.article = article
    }
    
    func process() async -> Void {
        await SafariExtensionPersister.shared.populate(article: article)
    }
    
}
