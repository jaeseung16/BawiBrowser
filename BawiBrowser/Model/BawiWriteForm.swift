//
//  BawiWriteForm.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/9/21.
//

import Foundation

struct BawiWriteForm: Codable {
    var bid: String
    var p: String
    var aid: String
    var img: String
    var title: String
    var body: String
    var attach_no: String
    var resize: String
    var poll: String
    var duration: String
    var attach1: Data?
}
