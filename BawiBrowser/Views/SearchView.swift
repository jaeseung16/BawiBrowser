//
//  SearchView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 9/22/21.
//

import Foundation
import SwiftUI

struct SearchView: NSViewRepresentable {
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    @Binding var searchString: String
    
    func makeNSView(context: NSViewRepresentableContext<SearchView>) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.delegate = context.coordinator
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if viewModel.enableSearch {
            nsView.window?.makeFirstResponder(nsView)
            viewModel.enableSearch = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchView
        
        init(_ parent: SearchView) {
            self.parent = parent
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else {
                print("Unexpected control in update notification: \(notification)")
                return
            }
            DispatchQueue.main.async {
                self.parent.searchString = searchField.stringValue
            }
        }
    }
}
