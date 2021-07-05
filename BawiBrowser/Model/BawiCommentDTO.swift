//
//  BawiCommentDTO.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/4/21.
//

import Foundation

struct BawiCommentDTO: CustomStringConvertible {
    var articleId: Int
    var boardId: Int
    var body: String
    
    var description: String {
        return "articleId: \(articleId), boardId: \(boardId), body: \(String(describing: body.removingPercentEncoding))"
    }
}
