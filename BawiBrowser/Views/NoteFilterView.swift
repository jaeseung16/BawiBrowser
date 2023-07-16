//
//  ArticleSortView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 9/15/21.
//

import SwiftUI

struct NoteFilterView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    @Binding var to: String?
    @State var selectedTo: String = "N/A"

    var toList: [String]
    
    @State private var isSelected = false
    
    private var toName: String {
        return to == nil ? "N/A" : to!
    }
    
    var body: some View {
        VStack {
            Text("Select an id")
            
            Text("Selected: \(toName)")
            
            Divider()
            
            Picker("Id", selection: $selectedTo) {
                ForEach(toList, id: \.self) { to in
                    Text(to)
                }
            }
            .onChange(of: selectedTo) { _ in
                self.selected()
            }
            
            buttons()
        }
        .padding()
    }
    
    private func buttons() -> some View {
        HStack {
            Spacer()
            
            Button(action: {
                reset()
            }, label: {
                Text("Reset")
            })
            
            Spacer()
            
            Button(action: {
                to = isSelected ? selectedTo : nil
                presentationMode.wrappedValue.dismiss()
            }, label: {
                Text("Done")
            })
            
            Spacer()
        }
    }
    
    private func reset() -> Void {
        isSelected = false
        to = nil
    }
    
    private func selected() -> Void {
        isSelected = true
        to = selectedTo
    }
    
}

