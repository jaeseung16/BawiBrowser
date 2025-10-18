//
//  CommentFormHandler.swift
//  BawiBrowserSafariExtension
//
//  Created by Jae Seung Lee on 10/18/25.
//

actor CommentFormHandler: MessageHandling {
    
    private let comment: BawiCommentDTO
    
    init(comment: BawiCommentDTO) {
        self.comment = comment
    }
    
    func process() async -> Void {
        await SafariExtensionPersister.shared.save(comment: comment)
    }
    
}
