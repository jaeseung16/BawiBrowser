//
//  ArticleFilterView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 9/15/21.
//

import SwiftUI

struct BoardFilterView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    @Binding var board: String?
    @State var selectedBoard: String = "N/A"
    
    var boards: [String]
    
    @State private var isSelected = false
    
    private var boardTitle: String {
        return board == nil ? "N/A" : board!
    }
    
    var body: some View {
        VStack {
            Text("Select a board")
            
            Text("Selected: \(boardTitle)")
            
            Divider()
            
            Picker("Boards", selection: $selectedBoard) {
                ForEach(boards, id: \.self) { board in
                    Text(board)
                }
            }
            .onChange(of: selectedBoard) { _ in
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
                board = isSelected ? selectedBoard : nil
                presentationMode.wrappedValue.dismiss()
            }, label: {
                Text("Done")
            })
            
            Spacer()
        }
    }
    
    private func reset() -> Void {
        isSelected = false
        board = nil
    }
    
    private func selected() -> Void {
        isSelected = true
        board = selectedBoard
    }
    
}
