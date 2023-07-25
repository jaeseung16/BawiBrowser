//
//  BawiAction.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 8/1/22.
//

import Foundation

enum BawiAction: String, CaseIterable {
    case note
    case comment
    case write
    case edit
    case index
    case login
    
    var cgi: String {
        return rawValue + ".cgi"
    }
    
}
