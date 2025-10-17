//
//  ArticleWebView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 1/12/25.
//

import SwiftUI
import WebKit
import MultipartKit
import Combine
import os

struct ArticleWebView: NSViewRepresentable {
    let htmlBody: String
    
    func makeNSView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlBody.replacingOccurrences(of: "\n", with: "<br>"), baseURL: nil)
    }
}
