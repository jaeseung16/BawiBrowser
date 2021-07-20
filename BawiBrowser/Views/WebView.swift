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
        print("updateNSView")
        print("viewModel.goMain = \(viewModel.goMain)")
        
        if viewModel.goMain {
            viewModel.goMain.toggle()
            let request = URLRequest(url: URL(string: "https://www.bawi.org/main/news.cgi")!)
            nsView.load(request)
        }
        
        if viewModel.navigateBack {
            viewModel.navigateBack.toggle()
            nsView.goBack()
        }
        
        if viewModel.navigateForward {
            viewModel.navigateForward.toggle()
            nsView.goForward()
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
                print("url = \(navigationAction.request.url?.absoluteString)")
                print("decidePolicyFor: navigationAction.request = \(navigationAction.request.description)")
                print("decidePolicyFor: httpMethod = \(navigationAction.request.httpMethod)")
                print("decidePolicyFor: httpBody = \(navigationAction.request.httpBody)")
                print("decidePolicyFor: httpBodyStream = \(navigationAction.request.httpBodyStream)")
                print("decidePolicyFor: allHTTPHeaderFields = \(navigationAction.request.allHTTPHeaderFields)")
                
                // Comments?
                if let url = navigationAction.request.url, let httpBody = navigationAction.request.httpBody {
                    print("url = \(url)")
                    print("httpBody = \(httpBody)")
                    
                    if url.absoluteString.contains("note.cgi") {
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
                        
                        let noteDTO = BawiNoteDTO(action: action ?? "", to: to ?? "", msg: msg ?? "")
                        parent.viewModel.noteDTO = noteDTO
                        print("noteDTO = \(noteDTO)")
                     
                    }
                    
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
                        
                        print("\(self.boardTitle), \(self.articleTitle)")
                        
                        parent.viewModel.commentDTO = BawiCommentDTO(articleId: articleId, articleTitle: self.articleTitle ?? "", boardId: boardId, boardTitle: self.boardTitle ?? "", body: body)
                    }
                    
                    print("\(url.absoluteString)")
                    if url.absoluteString.contains("write.cgi") {
                        if let boundary = navigationAction.request.allHTTPHeaderFields!["Content-Type"] {
                            print("\(boundary)")
                            let prefix = "multipart/form-data; boundary="
                            if boundary.starts(with: prefix) {
                                var boundaryCopy = boundary
                                boundaryCopy.removeSubrange(Range(uncheckedBounds: (prefix.startIndex, prefix.endIndex)))
                                print("boundary = \(boundaryCopy)")
                                self.articleDTO = populate(from: httpBody, with: boundaryCopy)
                            }
                        }
                    }
                    
                    if url.absoluteString.contains("edit.cgi") {
                        if let boundary = navigationAction.request.allHTTPHeaderFields!["Content-Type"] {
                            print("\(boundary)")
                            let prefix = "multipart/form-data; boundary="
                            if boundary.starts(with: prefix) {
                                var boundaryCopy = boundary
                                boundaryCopy.removeSubrange(Range(uncheckedBounds: (prefix.startIndex, prefix.endIndex)))
                                print("boundary = \(boundaryCopy)")
                                // parent.viewModel.articleDTO = populate(from: httpBody, with: boundaryCopy)
                                
                                var bawiArticleDTO = BawiArticleDTO(articleId: -1, articleTitle: "", boardId: -1, boardTitle: "", body: "")
                                
                                if let stringToParse = String(data: httpBody, encoding: .utf8) {
                                    print("stringToParse = \(stringToParse)")
                                    var bawiWriteForm: BawiWriteForm?
                                    do {
                                        bawiWriteForm = try FormDataDecoder().decode(BawiWriteForm.self, from: stringToParse, boundary: boundaryCopy)
                                    } catch {
                                        print("error: \(error).")
                                    }
                                    
                                    print("bawiWriteForm = \(bawiWriteForm)")
                                    
                                    if let bawiWriteForm = bawiWriteForm {
                                        bawiArticleDTO.articleId = Int(bawiWriteForm.aid) ?? -1
                                        bawiArticleDTO.articleTitle = bawiWriteForm.title
                                        bawiArticleDTO.boardId = Int(bawiWriteForm.bid) ?? -1
                                        bawiArticleDTO.boardTitle = self.boardTitle ?? ""
                                        bawiArticleDTO.body = bawiWriteForm.body
                                        
                                        parent.viewModel.articleDTO = bawiArticleDTO
                                    }
                                    
                                    print("boardTitle = \(self.boardTitle)")
                                }
                            }
                        }
                    }
                }
                
                if let url = navigationAction.request.url, let httpBodyStream = navigationAction.request.httpBodyStream {
                    
                    if url.absoluteString.contains("write.cgi") {
                        if let boundary = navigationAction.request.allHTTPHeaderFields!["Content-Type"] {
                            let prefix = "multipart/form-data; boundary="
                            if boundary.starts(with: prefix) {
                                var boundaryCopy = boundary
                                boundaryCopy.removeSubrange(Range(uncheckedBounds: (prefix.startIndex, prefix.endIndex)))
                                print("boundary = \(boundaryCopy)")
                                
                                self.articleDTO = populate(from: httpBodyStream, with: boundaryCopy)
                            }
                        }
                    }
                    
                    if url.absoluteString.contains("edit.cgi") {
                        if let boundary = navigationAction.request.allHTTPHeaderFields!["Content-Type"] {
                            let prefix = "multipart/form-data; boundary="
                            if boundary.starts(with: prefix) {
                                var boundaryCopy = boundary
                                boundaryCopy.removeSubrange(Range(uncheckedBounds: (prefix.startIndex, prefix.endIndex)))
                                print("boundary = \(boundaryCopy)")
                                
                                //self.articleDTO = populate(from: httpBodyStream, with: boundaryCopy)
                                
                                var bawiArticleDTO = BawiArticleDTO(articleId: -1, articleTitle: "", boardId: -1, boardTitle: "", body: "")
                                
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
                                
                                var bawiWriteForm: BawiWriteForm?
                                do {
                                    bawiWriteForm = try FormDataDecoder().decode(BawiWriteForm.self, from: [UInt8](data), boundary: boundaryCopy)
                                    print("bawiWriteForm = \(bawiWriteForm)")
                                } catch {
                                    print("error: \(error).")
                                }
                                
                                if let bawiWriteForm = bawiWriteForm {
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
                                    
                                    bawiArticleDTO.articleId = Int(bawiWriteForm.aid) ?? -1
                                    bawiArticleDTO.articleTitle = bawiWriteForm.title
                                    bawiArticleDTO.boardId = Int(bawiWriteForm.bid) ?? -1
                                    bawiArticleDTO.boardTitle = self.boardTitle ?? ""
                                    bawiArticleDTO.body = bawiWriteForm.body
                                    bawiArticleDTO.attachments = attachements
                                    
                                    parent.viewModel.articleDTO = bawiArticleDTO
                                }
                            }
                        }
                    }
                    
                    //var nsString: NSString?
                    //let usedLossyConversion = UnsafeMutablePointer<ObjCBool>.allocate(capacity: 1)
                    //let encoding = NSString.stringEncoding(for: data, encodingOptions: nil, convertedString: &nsString, usedLossyConversion: usedLossyConversion)
                    //print("encoding = \(encoding), \(String.Encoding(rawValue: 1058))")
                    //print("nsString = \(nsString)")
                    //print("usedLossyConversion = \(usedLossyConversion.pointee)")
                    
                    //print("data = \(String(data: data, encoding: .ascii) ?? "cannot convert")")
                }
                
                print("decidePolicyFor: url = \(navigationAction.request.url)")
                print("decidePolicyFor: allHTTPHeaderFields = \(navigationAction.request.allHTTPHeaderFields)")
                print("...")
                
                //print("decidePolicyFor: navigationAction.sourceFrame = \(navigationAction.sourceFrame)")
                //print("decidePolicyFor: navigationAction.targetFrame = \(navigationAction.targetFrame)")
            }
            
            decisionHandler(.allow, preferences)
        }
        
        private func populate(from httpBody: Data, with boundary: String) -> BawiArticleDTO {
            var bawiArticleDTO = BawiArticleDTO(articleId: -1, articleTitle: "", boardId: -1, boardTitle: "", body: "")
            
            if let stringToParse = String(data: httpBody, encoding: .utf8) {
                print("stringToParse = \(stringToParse)")
                var bawiWriteForm: BawiWriteForm?
                do {
                    bawiWriteForm = try FormDataDecoder().decode(BawiWriteForm.self, from: stringToParse, boundary: String(boundary))
                } catch {
                    print("error: \(error).")
                }
                
                print("bawiWriteForm = \(bawiWriteForm)")
                
                if let bawiWriteForm = bawiWriteForm {
                    bawiArticleDTO.parentArticleId = Int(bawiWriteForm.aid) ?? -1
                    bawiArticleDTO.articleTitle = bawiWriteForm.title
                    bawiArticleDTO.boardId = Int(bawiWriteForm.bid) ?? -1
                    bawiArticleDTO.boardTitle = self.boardTitle ?? ""
                    bawiArticleDTO.body = bawiWriteForm.body
                }
                
                print("boardTitle = \(self.boardTitle)")
            }
            
            return bawiArticleDTO
        }
        
        private func populate(from httpBodyStream: InputStream, with boundary: String) -> BawiArticleDTO {
            var bawiArticleDTO = BawiArticleDTO(articleId: -1, articleTitle: "", boardId: -1, boardTitle: "", body: "")
            
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
                
                bawiArticleDTO = BawiArticleDTO(articleId: -1,
                                                             articleTitle: bawiWriteForm.title,
                                                             boardId: Int(bawiWriteForm.bid) ?? -1,
                                                             boardTitle: self.boardTitle ?? "",
                                                             body: bawiWriteForm.body,
                                                             parentArticleId: Int(bawiWriteForm.aid) ?? -1,
                                                             attachments: attachements)
                    
            } catch {
                print("error: \(error).")
            }
            
            return bawiArticleDTO
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
            */
            print("url = \(webView.url)")
            
            if articleDTO != nil {
                if let url = webView.url {
                    var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    print("urlComponents = \(urlComponents)")
                    
                    if let queryItems = urlComponents?.queryItems {
                        print("queryItems = \(queryItems)")
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
            
            webView.evaluateJavaScript("document.getElementsByClassName('body attach')[0].innerHTML", completionHandler: { (value: Any!, error: Error!) -> Void in
                if error != nil {
                    print("didFinish: \(String(describing: error))")
                    return
                }

                if let result = value as? String {
                    print("didFinish: body attach = \(result)")
                }
            })
            
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            
            print("createWebViewWith: \(navigationAction.request.url)")
            print("createWebViewWith: \(windowFeatures)")
            print("self: \(self)")
            
            /*
            let newWebView = WKWebView(frame: CGRect.zero, configuration: configuration)
            newWebView.load(navigationAction.request)
            newWebView.uiDelegate = self
            newWebView.navigationDelegate = self
            
            self.webViewList.append(newWebView)
            
            return newWebView
            */
            webView.load(navigationAction.request)
            
            //if let url = navigationAction.request.url {
            //    print("createWebViewWith: \(url)")
                            
                //let request = URLRequest(url: url)
                //let newWebView = WKWebView(frame: CGRect.zero, configuration: configuration)
                //newWebView.load(request)
                //webView.uiDelegate = context.coordinator
                //webView.navigationDelegate = context.coordinator
                //return newWebView
            //}
            
            return nil
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("runJavaScriptAlertPanelWithMessage: \(message)")
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            print("runJavaScriptConfirmPanelWithMessage: \(message)")
            
            let alert = NSAlert()
            alert.messageText = message
            alert.informativeText = "Please confirm"
            alert.alertStyle = .warning
            
            let deleteButton = alert.addButton(withTitle: "OK")
            let cancelButton = alert.addButton(withTitle: "Cancel")
            
            deleteButton.tag = NSApplication.ModalResponse.OK.rawValue
            cancelButton.tag = NSApplication.ModalResponse.cancel.rawValue
            
            let response = alert.runModal()
            
            completionHandler(response == .OK)
        }
        
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            print("runJavaScriptTextInputPanelWithPrompt: \(prompt)")
        }
        
        func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
            print("runOpenPanelWith: \(parameters)")
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
