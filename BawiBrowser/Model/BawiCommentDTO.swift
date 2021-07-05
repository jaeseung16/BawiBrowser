//
//  BawiCommentDTO.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/4/21.
//

import Foundation

struct BawiCommentDTO: CustomStringConvertible {
    var articleId: Int
    var articleTitle: String
    var boardId: Int
    var boardTitle: String
    var body: String
    
    var description: String {
        return "boardTitle: \(boardTitle), articleTitle: \(articleTitle), body: \(String(describing: body.removingPercentEncoding))"
    }
}
