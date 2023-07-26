//
//  BawiBrowserTab.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/15/22.
//

import Foundation

enum BawiBrowserTab: String, CaseIterable, Identifiable {
    case browser, articles, comments, notes
    
    var id: Self {
        return self
    }
}
