//
//  WebView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 6/28/21.
//

import SwiftUI
import WebKit

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
        
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            //print("decidePolicyFor: navigationAction.navigationType = \(navigationAction.navigationType.rawValue)")
            
            if (navigationAction.navigationType == .linkActivated) {
                print("linkActivated: \(navigationAction.request.url)")
            }
            
            if (navigationAction.request.httpMethod == "POST") {
                print("...")
                print("decidePolicyFor: navigationAction.request = \(navigationAction.request.description)")
                print("decidePolicyFor: httpMethod = \(navigationAction.request.httpMethod)")
                print("decidePolicyFor: httpBody = \(navigationAction.request.httpBody)")
                
                
                // Comments?
                if let url = navigationAction.request.url, let httpBody = navigationAction.request.httpBody {
                    if url.absoluteString.contains("comment.cgi") {
                        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        urlComponents?.query = String(data: httpBody, encoding: .utf8)
                        
                        var articleId = -1
                        var boardId = -1
                        var body = ""
                        
                        if let queryItems = urlComponents?.queryItems {
                            for queryItem in queryItems {
                                switch queryItem.name {
                                case BawiCommentConstant.aid.rawValue:
                                    if let value = queryItem.value, let id = Int(value) {
                                        articleId = id
                                    }
                                case BawiCommentConstant.bid.rawValue:
                                    if let value = queryItem.value, let id = Int(value) {
                                        boardId = id
                                    }
                                case BawiCommentConstant.body.rawValue:
                                    if let value = queryItem.value {
                                        body = value
                                    }
                                default:
                                    continue
                                }
                            }
                        }
                        
                        parent.viewModel.commentDTO = BawiCommentDTO(articleId: articleId, boardId: boardId, body: body)
                    }
                }
                
            /*
                if let httpBody = navigationAction.request.httpBody {
                    if let url = navigationAction.request.url, let httpBodyString = String(data: httpBody, encoding: .utf8) {
                        
                        print("decidePolicyFor: url = \(url)")
                        print("decidePolicyFor: url = \(url.absoluteString)")
                        print("decidePolicyFor: httpBodyString = \(httpBodyString)")
                        
                        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        urlComponents?.query = httpBodyString
                        
                        print("urlComponents: \(urlComponents)")
                    
                        if let queryItems = urlComponents?.queryItems {
                            print("queryItems: \(urlComponents?.queryItems)")
                            
                            if let queryItem = queryItems.first(where: {queryItem in queryItem.name == "body" }), let value = queryItem.value {
                                print(value.removingPercentEncoding)
                                parent.viewModel.commentPosted = value.removingPercentEncoding ?? ""
                            }
                            
                        }
                        
                    }
                }
 */
                
                print("decidePolicyFor: url = \(navigationAction.request.url)")
                print("decidePolicyFor: allHTTPHeaderFields = \(navigationAction.request.allHTTPHeaderFields)")
                print("...")
                
                //print("decidePolicyFor: navigationAction.sourceFrame = \(navigationAction.sourceFrame)")
                //print("decidePolicyFor: navigationAction.targetFrame = \(navigationAction.targetFrame)")
            }
            
            decisionHandler(.allow, preferences)
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
            
            /*
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies({ httpCookies in
                self.parent.viewModel.httpCookies.append(contentsOf: httpCookies)
                
                //print("parent.viewModel.httpCookies = \(self.parent.viewModel.httpCookies)")
            })
            
            webView.evaluateJavaScript("document.body.innerHTML", completionHandler: { (value: Any!, error: Error!) -> Void in

                if error != nil {
                    //Error logic
                    return
                }

                let result = value as? String
                //print("document.body.innerHTML = \(result)")
                //Main logic
                self.parent.viewModel.innerHTML = result ?? ""
            })
            */
            
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            
            print("createWebViewWith: \(navigationAction.request.url)")
            print("createWebViewWith: \(windowFeatures)")
            
            return nil
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("runJavaScriptAlertPanelWithMessage: \(message)")
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            print("runJavaScriptAlertPanelWithMessage: \(message)")
            
            print("\(frame.request)")
            
            let alert = NSAlert()
            alert.messageText = message
            alert.informativeText = "Please confirm"
            alert.alertStyle = .warning
            
            let deleteButton = alert.addButton(withTitle: "Delete")
            let cancelButton = alert.addButton(withTitle: "Cancel")
            
            deleteButton.tag = NSApplication.ModalResponse.OK.rawValue
            cancelButton.tag = NSApplication.ModalResponse.cancel.rawValue
            
            let response = alert.runModal()
            
            completionHandler(response == .OK)
        }
        
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            print("runJavaScriptTextInputPanelWithPrompt: \(prompt)")
        }
    }
}
