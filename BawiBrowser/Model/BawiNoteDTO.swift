//
//  BawiNoteDTO.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/20/21.
//

import Foundation

struct BawiNoteDTO: CustomStringConvertible {
    var action: String
    var to: String
    var msg: String
    
    var description: String {
        return "BawiNoteDTO[to: \(to), msg: \(msg), action: \(action)]"
    }
}
