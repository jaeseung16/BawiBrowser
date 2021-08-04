//
//  BawiArticleDTO.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/8/21.
//

import Foundation

struct BawiArticleDTO: CustomStringConvertible {
    var articleId: Int
    var articleTitle: String
    var boardId: Int
    var boardTitle: String
    var body: String
    var parentArticleId: Int?
    var attachments: [Data]?
    var attachCount: Int?
    
    var description: String {
        return "BawiArticleDTO[boardId: \(boardId), boardTitle: \(boardTitle), articleId: \(articleId), articleTitle: \(articleTitle), body: \(String(describing: body.removingPercentEncoding)), attachCount: \(String(describing: attachCount))]"
    }
}
