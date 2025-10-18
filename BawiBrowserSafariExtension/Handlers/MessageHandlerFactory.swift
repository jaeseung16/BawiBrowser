//
//  MessageHandlerFactory.swift
//  BawiBrowserSafariExtension
//
//  Created by Jae Seung Lee on 10/18/25.
//

import Foundation

class MessageHandlerFactory {
    
    static func attachmentHandler(data: Data) -> MessageHandling {
        return AttachmentHandler(data: data)
    }
    
    static func writeFormHandler(article: BawiArticleDTO) -> MessageHandling {
        return WriteFormHandler(article: article)
    }
    
    static func commentFormHandler(comment: BawiCommentDTO) -> MessageHandling {
        return CommentFormHandler(comment: comment)
    }
    
    static func noteFormHandler(note: BawiNoteDTO) -> MessageHandling {
        return NoteFormHandler(note: note)
    }
    

    
}
