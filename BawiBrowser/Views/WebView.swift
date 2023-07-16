//
//  WebView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/28/21.
//

import SwiftUI
import WebKit
import MultipartKit
import Combine

struct WebView: NSViewRepresentable {
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    @AppStorage("BawiBrowser.appearance") var darkMode: Bool = false
    
    let url: URL
    
    func makeNSView(context: NSViewRepresentableContext<WebView>) -> WKWebView {
        DispatchQueue.main.async {
            viewModel.isDarkMode = darkMode
        }
        
        let configuration = WKWebViewConfiguration()
        if let path = Bundle.main.path(forResource: "UIWebViewSearch", ofType: "js"), let jsString = try? String(contentsOfFile: path, encoding: .utf8) {
            let userContentController = WKUserContentController()
            let userScript = WKUserScript(source: jsString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            userContentController.addUserScript(userScript)
            configuration.userContentController = userContentController
        }
        
        if let path = Bundle.main.path(forResource: "LoginAutofill", ofType: "js"), let jsString = try? String(contentsOfFile: path, encoding: .utf8) {
            let userContentController = WKUserContentController()
            let userScript = WKUserScript(source: jsString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            userContentController.addUserScript(userScript)
            configuration.userContentController = userContentController
        }
        
        let request = URLRequest(url: url)
        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.load(request)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        
        viewModel.$searchString
            .sink {
                if !$0.isEmpty {
                    let startSearch = "uiWebview_HighlightAllOccurencesOfString('\($0)')"
                    
                    webView.find($0) { result in
                        if result.matchFound {
                            webView.evaluateJavaScript(startSearch) { result, error in
                                if error != nil {
                                    print("uiWebview_HighlightAllOccurencesOfString: \(String(describing: error))")
                                    return
                                }
                                
                                webView.evaluateJavaScript("uiWebview_SearchResultTotalCount") { result, error in
                                    if error != nil {
                                        print("uiWebview_SearchResultTotalCount: \(String(describing: error))")
                                        return
                                    }
                                    
                                    if let result = result as? Int {
                                        viewModel.searchResultTotalCount = result
                                        viewModel.searchResultCounter = 1
                                        webView.evaluateJavaScript("uiWebview_ScrollTo(\(result))")
                                    }
                                }
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        viewModel.searchResultTotalCount = 0
                        viewModel.searchResultCounter = 0
                        webView.evaluateJavaScript("uiWebview_RemoveAllHighlights()")
                    }
                }
            }
            .store(in: &viewModel.subscriptions)
        
        viewModel.$searchResultCounter
            .sink {
                let idx = viewModel.searchResultTotalCount - $0 + 1
                print("idx=\(idx)")
                webView.evaluateJavaScript("uiWebview_ScrollTo(\(idx))")
            }
            .store(in: &viewModel.subscriptions)
        
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        DispatchQueue.main.async {
            switch (viewModel.navigation) {
            case .home:
                viewModel.navigation = .none
                let request = URLRequest(url: URL(string: "https://www.bawi.org/main/news.cgi")!)
                nsView.load(request)
            case .logout:
                viewModel.navigation = .none
                let request = URLRequest(url: URL(string: "https://www.bawi.org/main/logout.cgi")!)
                nsView.load(request)
            case .back:
                viewModel.navigation = .none
                nsView.goBack()
            case .forward:
                viewModel.navigation = .none
                nsView.goForward()
            case .reload:
                viewModel.navigation = .none
                nsView.reload()
            case .none:
                return
            }
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
            
            guard let url = navigationAction.request.url, needProcessing(navigationAction) else {
                decisionHandler(.allow, preferences)
                return
            }
            
            if navigationAction.navigationType == .linkActivated {
                if let host = url.host, !host.contains("bawi.org"), NSWorkspace.shared.open(url) {
                    decisionHandler(.cancel, preferences)
                } else {
                    decisionHandler(.allow, preferences)
                }
                return
            }
            
            if navigationAction.request.httpMethod == "POST", let action = getBawiAction(url: url) {
                switch action {
                case .note:
                    if let httpBody = navigationAction.request.httpBody {
                        parent.viewModel.processNote(url: url, httpBody: httpBody)
                    }
                case .comment:
                    if let httpBody = navigationAction.request.httpBody {
                        parent.viewModel.processComment(url: url, httpBody: httpBody, articleTitle: self.articleTitle, boardTitle: self.boardTitle)
                    }
                case .write:
                    if let boundary = extractBoundary(from: navigationAction) {
                        parent.viewModel.preprocessWrite(url: url,
                                     httpBody: navigationAction.request.httpBody,
                                     httpBodyStream: navigationAction.request.httpBodyStream,
                                     boundary: boundary,
                                     boardTitle: self.boardTitle,
                                     coordinator: self)
                    }
                case .edit:
                    if let boundary = extractBoundary(from: navigationAction) {
                        parent.viewModel.processEdit(url: url,
                                     httpBody: navigationAction.request.httpBody,
                                     httpBodyStream: navigationAction.request.httpBodyStream,
                                     boundary: boundary,
                                     boardTitle: self.boardTitle)
                    }
                }
            }
                
            decisionHandler(.allow, preferences)
        }
        
        private func needProcessing(_ navigationAction: WKNavigationAction) -> Bool {
            return navigationAction.request.httpMethod == "POST" || navigationAction.navigationType == .linkActivated
        }
        
        private func getBawiAction(url: URL) -> BawiAction? {
            return BawiAction.allCases.first(where: { url.absoluteString.contains($0.cgi) })
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
            parent.viewModel.didStartProvisionalNavigationURLString = webView.url?.absoluteString ?? ""
            parent.viewModel.didStartProvisionalNavigationTitle = webView.title ?? ""
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            parent.viewModel.didCommitURLString = webView.url?.absoluteString ?? ""
            parent.viewModel.didCommitTitle = webView.title ?? ""
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.viewModel.didFinishURLString = webView.url?.absoluteString ?? ""
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
            
            webView.evaluateJavaScript("document.getElementById('login_id').outerHTML", completionHandler: { (value: Any!, error: Error!) -> Void in
                if error != nil {
                    print("didFinish: \(String(describing: error))")
                    return
                }

                if value != nil {
                    print("didFinish: value = \(value!)")
                    webView.evaluateJavaScript("LoginAutofill_EnableAutofill(\"galley\")") { result, error in
                        if error != nil {
                            print("LoginAutofill_EnableAutofill: \(String(describing: error))")
                            return
                        }
                        
                        print("LoginAutofill_EnableAutofill: result = \(String(describing: result))")
                    }
                }
                
            })
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            webView.load(navigationAction.request)
            return nil
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = message
            alert.informativeText = "Please confirm"
            alert.alertStyle = .warning
            
            let deleteButton = alert.addButton(withTitle: "OK")
            deleteButton.tag = NSApplication.ModalResponse.OK.rawValue
            
            _ = alert.runModal()
            
            completionHandler()
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
