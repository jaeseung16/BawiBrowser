//
//  BawiBrowserSearchHelper.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/19/23.
//

import Foundation

protocol BawiBrowserSearchDelegate {
    
    func search(_ text: String)
    
    func cancelSearch()
    
}
