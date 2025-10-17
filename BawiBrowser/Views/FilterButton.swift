//
//  FilterButton.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 10/17/25.
//

import SwiftUI

struct FilterButton: View {
    
    private var action: () -> Void
    
    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            Label("Filter", systemImage: "line.horizontal.3.decrease.circle")
        }
    }
}
