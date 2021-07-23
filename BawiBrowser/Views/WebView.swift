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
                    processNote(url: url, httpBody: httpBody)
                }
                
                if url.absoluteString.contains("comment.cgi"), let httpBody = navigationAction.request.httpBody {
                    processComment(url: url, httpBody: httpBody)
                }
                
                if url.absoluteString.contains("write.cgi"), let boundary = extractBoundary(from: navigationAction) {
                    processWrite(url: url,
                                 httpBody: navigationAction.request.httpBody,
                                 httpBodyStream: navigationAction.request.httpBodyStream,
                                 boundary: boundary)
                }
                
                if url.absoluteString.contains("edit.cgi"), let boundary = extractBoundary(from: navigationAction) {
                    processEdit(url: url,
                                 httpBody: navigationAction.request.httpBody,
                                 httpBodyStream: navigationAction.request.httpBodyStream,
                                 boundary: boundary)
                }
            }
            
            decisionHandler(.allow, preferences)
        }
        
        private func processNote(url: URL, httpBody: Data) -> Void {
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            urlComponents?.query = String(data: httpBody, encoding: .utf8)
            
            var action: String?
            var to: String?
            var msg: String?
            if let queryItems = urlComponents?.queryItems {
                for queryItem in queryItems {
                    switch queryItem.name {
                    case BawiNoteConstant.action.rawValue:
                        if let value = queryItem.value {
                            action = value
                        }
                    case BawiNoteConstant.to.rawValue:
                        if let value = queryItem.value {
                            to = value
                        }
                    case BawiNoteConstant.msg.rawValue:
                        if let value = queryItem.value {
                            msg = value
                        }
                    default:
                        continue
                    }
                }
            }
            
            parent.viewModel.noteDTO = BawiNoteDTO(action: action ?? "", to: to ?? "", msg: msg ?? "")
        }
        
        private func processComment(url: URL, httpBody: Data) -> Void {
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
            
            parent.viewModel.commentDTO = BawiCommentDTO(articleId: articleId,
                                                         articleTitle: self.articleTitle ?? "",
                                                         boardId: boardId,
                                                         boardTitle: self.boardTitle ?? "",
                                                         body: body)
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
        
        private func processWrite(url: URL, httpBody: Data?, httpBodyStream: InputStream?, boundary: String) -> Void {
            if let httpBody = httpBody {
                populate(from: httpBody, with: boundary) { bawiWriteForm in
                   var parentArticleId = -1
                   var articleTitle = ""
                   var boardId = -1
                   var boardTitle = ""
                   var body = ""
                   if let bawiWriteForm = bawiWriteForm {
                       parentArticleId = Int(bawiWriteForm.aid) ?? -1
                       articleTitle = bawiWriteForm.title
                       boardId = Int(bawiWriteForm.bid) ?? -1
                       boardTitle = self.boardTitle ?? ""
                       body = bawiWriteForm.body
                   }
                   
                   self.articleDTO = BawiArticleDTO(articleId: -1, articleTitle: articleTitle, boardId: boardId, boardTitle: boardTitle, body: body, parentArticleId: parentArticleId)
               }
            } else if let httpBodyStream = httpBodyStream {
                populate(from: httpBodyStream, with: boundary) { bawiWriteForm, attachments in
                    var parentArticleId = -1
                    var articleTitle = ""
                    var boardId = -1
                    var boardTitle = ""
                    var body = ""
                    if let bawiWriteForm = bawiWriteForm {
                        parentArticleId = Int(bawiWriteForm.aid) ?? -1
                        articleTitle = bawiWriteForm.title
                        boardId = Int(bawiWriteForm.bid) ?? -1
                        boardTitle = self.boardTitle ?? ""
                        body = bawiWriteForm.body
                    }
                    
                    self.articleDTO = BawiArticleDTO(articleId: -1,
                                                     articleTitle: articleTitle,
                                                     boardId: boardId,
                                                     boardTitle: boardTitle,
                                                     body: body,
                                                     parentArticleId: parentArticleId,
                                                     attachments: attachments)
                }
            }
        }
        
        private func processEdit(url: URL, httpBody: Data?, httpBodyStream: InputStream?, boundary: String) -> Void {
            if let httpBody = httpBody {
                 populate(from: httpBody, with: boundary) { bawiWriteForm in
                    var articleId = -1
                    var articleTitle = ""
                    var boardId = -1
                    var boardTitle = ""
                    var body = ""
                    if let bawiWriteForm = bawiWriteForm {
                        articleId = Int(bawiWriteForm.aid) ?? -1
                        articleTitle = bawiWriteForm.title
                        boardId = Int(bawiWriteForm.bid) ?? -1
                        boardTitle = self.boardTitle ?? ""
                        body = bawiWriteForm.body
                    }
                    
                    parent.viewModel.articleDTO = BawiArticleDTO(articleId: articleId, articleTitle: articleTitle, boardId: boardId, boardTitle: boardTitle, body: body)
                }
            } else if let httpBodyStream = httpBodyStream {
                populate(from: httpBodyStream, with: boundary) { bawiWriteForm, attachments in
                    var articleId = -1
                    var articleTitle = ""
                    var boardId = -1
                    var boardTitle = ""
                    var body = ""
                    if let bawiWriteForm = bawiWriteForm {
                        articleId = Int(bawiWriteForm.aid) ?? -1
                        articleTitle = bawiWriteForm.title
                        boardId = Int(bawiWriteForm.bid) ?? -1
                        boardTitle = self.boardTitle ?? ""
                        body = bawiWriteForm.body
                    }
                    
                    parent.viewModel.articleDTO = BawiArticleDTO(articleId: articleId,
                                                     articleTitle: articleTitle,
                                                     boardId: boardId,
                                                     boardTitle: boardTitle,
                                                     body: body,
                                                     attachments: attachments)
                }
            }
        }
        
        private func populate(from httpBody: Data, with boundary: String, completionHandler: (BawiWriteForm?) -> Void) -> Void {
            if let stringToParse = String(data: httpBody, encoding: .utf8) {
                var bawiWriteForm: BawiWriteForm?
                do {
                    bawiWriteForm = try FormDataDecoder().decode(BawiWriteForm.self, from: stringToParse, boundary: String(boundary))
                } catch {
                    print("error: \(error).")
                }
                
                completionHandler(bawiWriteForm)
            }
        }
        
        private func populate(from httpBodyStream: InputStream, with boundary: String, completionHandler: (BawiWriteForm?, [Data]) -> Void) -> Void {
            httpBodyStream.open()

            var data = Data()
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            while httpBodyStream.hasBytesAvailable {
                let read = httpBodyStream.read(buffer, maxLength: bufferSize)
                if (read == 0) {
                    break
                }
                data.append(buffer, count: read)
            }
            buffer.deallocate()

            httpBodyStream.close()
            
            do {
                let bawiWriteForm = try FormDataDecoder().decode(BawiWriteForm.self, from: [UInt8](data), boundary: boundary)
                print("bawiWriteForm = \(bawiWriteForm)")
                
                var attachements = [Data]()
                if bawiWriteForm.attach1 != nil {
                    attachements.append(bawiWriteForm.attach1!)
                }
                if bawiWriteForm.attach2 != nil {
                    attachements.append(bawiWriteForm.attach2!)
                }
                if bawiWriteForm.attach3 != nil {
                    attachements.append(bawiWriteForm.attach3!)
                }
                if bawiWriteForm.attach4 != nil {
                    attachements.append(bawiWriteForm.attach4!)
                }
                if bawiWriteForm.attach5 != nil {
                    attachements.append(bawiWriteForm.attach5!)
                }
                if bawiWriteForm.attach6 != nil {
                    attachements.append(bawiWriteForm.attach6!)
                }
                if bawiWriteForm.attach7 != nil {
                    attachements.append(bawiWriteForm.attach7!)
                }
                if bawiWriteForm.attach8 != nil {
                    attachements.append(bawiWriteForm.attach8!)
                }
                if bawiWriteForm.attach9 != nil {
                    attachements.append(bawiWriteForm.attach9!)
                }
                if bawiWriteForm.attach10 != nil {
                    attachements.append(bawiWriteForm.attach10!)
                }
                
                completionHandler(bawiWriteForm, attachements)
            } catch {
                print("error: \(error).")
            }
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
                    var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    
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
