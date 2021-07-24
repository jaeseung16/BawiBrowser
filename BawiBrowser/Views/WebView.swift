//
//  WebView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/28/21.
//

import SwiftUI
import WebKit
import MultipartKit

struct WebView: NSViewRepresentable {
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
    let url: URL
    
    func makeNSView(context: NSViewRepresentableContext<WebView>) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let request = URLRequest(url: url)
        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.load(request)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        switch (viewModel.navigation) {
        case .home:
            viewModel.navigation = .none
            let request = URLRequest(url: URL(string: "https://www.bawi.org/main/news.cgi")!)
            nsView.load(request)
        case .back:
            viewModel.navigation = .none
            nsView.goBack()
        case .forward:
            viewModel.navigation = .none
            nsView.goForward()
        case .none:
            return
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var parent: WebView
        
        var boardTitle: String?
        var articleTitle: String?
        var articleDTO: BawiArticleDTO?
        
        private var url: URL?
        
        private let multipartPrefix = "multipart/form-data; boundary="
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            if let url = navigationAction.request.url, navigationAction.request.httpMethod == "POST" {
                if url.absoluteString.contains("note.cgi"), let httpBody = navigationAction.request.httpBody {
                    parent.viewModel.processNote(url: url, httpBody: httpBody)
                }
                
                if url.absoluteString.contains("comment.cgi"), let httpBody = navigationAction.request.httpBody {
                    parent.viewModel.processComment(url: url, httpBody: httpBody, articleTitle: self.articleTitle, boardTitle: self.boardTitle)
                }
                
                if url.absoluteString.contains("write.cgi"), let boundary = extractBoundary(from: navigationAction) {
                    parent.viewModel.preprocessWrite(url: url,
                                 httpBody: navigationAction.request.httpBody,
                                 httpBodyStream: navigationAction.request.httpBodyStream,
                                 boundary: boundary,
                                 boardTitle: self.boardTitle,
                                 coordinator: self)
                }
                
                if url.absoluteString.contains("edit.cgi"), let boundary = extractBoundary(from: navigationAction) {
                    parent.viewModel.processEdit(url: url,
                                 httpBody: navigationAction.request.httpBody,
                                 httpBodyStream: navigationAction.request.httpBodyStream,
                                 boundary: boundary,
                                 boardTitle: self.boardTitle)
                }
            }
            
            decisionHandler(.allow, preferences)
        }
        
        private func extractBoundary(from navigationAction: WKNavigationAction) -> String? {
            if let contentTypeHeader = navigationAction.request.allHTTPHeaderFields!["Content-Type"],
               contentTypeHeader.starts(with: multipartPrefix) {
                var boundary = contentTypeHeader
                boundary.removeSubrange(Range(uncheckedBounds: (multipartPrefix.startIndex, multipartPrefix.endIndex)))
                return boundary
            }
            return nil
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.viewModel.didStartProvisionalNavigationURLString = webView.url?.description ?? ""
            parent.viewModel.didStartProvisionalNavigationTitle = webView.title ?? ""
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            parent.viewModel.didCommitURLString = webView.url?.description ?? ""
            parent.viewModel.didCommitTitle = webView.title ?? ""
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.viewModel.didFinishURLString = webView.url?.description ?? ""
            parent.viewModel.didFinishTitle = webView.title ?? ""
            
            if articleDTO != nil {
                if let url = webView.url {
                    let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    
                    if let queryItems = urlComponents?.queryItems {
                        for queryItem in queryItems {
                            switch queryItem.name {
                            case BawiCommentConstant.aid.rawValue:
                                if let value = queryItem.value, let id = Int(value) {
                                    articleDTO!.articleId = id
                                }
                            default:
                                continue
                            }
                        }
                    }
                }
                
                parent.viewModel.articleDTO = articleDTO!
                articleDTO = nil
            }
            
            webView.evaluateJavaScript("document.getElementsByTagName('h1')[0].innerText", completionHandler: { (value: Any!, error: Error!) -> Void in
                if error != nil {
                    print("didFinish: \(String(describing: error))")
                    return
                }

                if let result = value as? String {
                    print("didFinish: boardTitle = \(result)")
                    self.boardTitle = result
                }
            })
            
            webView.evaluateJavaScript("document.getElementsByClassName('article')[0].innerText", completionHandler: { (value: Any!, error: Error!) -> Void in
                if error != nil {
                    print("didFinish: \(String(describing: error))")
                    return
                }

                if let result = value as? String {
                    print("didFinish: articleTitle = \(result)")
                    self.articleTitle = result
                }
            })
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            webView.load(navigationAction.request)
            return nil
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("runJavaScriptAlertPanelWithMessage: \(message)")
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = NSAlert()
            alert.messageText = message
            alert.informativeText = "Please confirm"
            alert.alertStyle = .warning
            
            let deleteButton = alert.addButton(withTitle: "OK")
            deleteButton.tag = NSApplication.ModalResponse.OK.rawValue
            
            let cancelButton = alert.addButton(withTitle: "Cancel")
            cancelButton.tag = NSApplication.ModalResponse.cancel.rawValue
            
            let response = alert.runModal()
            
            completionHandler(response == .OK)
        }
        
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            print("runJavaScriptTextInputPanelWithPrompt: \(prompt)")
        }
        
        func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.begin { result in
                if result == NSApplication.ModalResponse.OK {
                    if let url = openPanel.url {
                        self.url = url
                        completionHandler([url])
                    }
                } else if result == NSApplication.ModalResponse.cancel {
                    completionHandler(nil)
                }
            }
        }
    }
}
