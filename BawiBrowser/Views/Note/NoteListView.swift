//
//  NoteListView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/20/21.
//

import SwiftUI

struct NoteListView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
    @State private var presentFilterNoteView = false
    
    @State private var recipient: String?
    
    private var recipients: Array<String> {
        var toSet = Set<String>()
        
        viewModel.notes.compactMap { note in
            note.to
        }
        .forEach { to in
            toSet.insert(to)
        }
        
        return Array(toSet)
    }
  
    private var filteredNotes: Array<Note> {
        viewModel.notes.filter { note in
            if recipient == nil {
                return true
            } else {
                return note.to != nil && note.to! == recipient!
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                header(geometry: geometry)
            
                ScrollView {
                    LazyVGrid(columns: Array(repeating: .init(), count: 1)) {
                        ForEach(filteredNotes) { note in
                            NoteDetailView(note: note, geometry: geometry)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 8.0).stroke(lineWidth: 0.5))
                        }
                    }
                }
            }
            .padding()
            .sheet(isPresented: $presentFilterNoteView) {
                NoteFilterView(to: $recipient, toList: recipients)
            }
        }
    }
    
    private func header(geometry: GeometryProxy) -> some View {
        HStack {
            Button(action: {
                presentFilterNoteView = true
            }) {
                Label("Filter", systemImage: "line.horizontal.3.decrease.circle")
            }
            
            Spacer()
        }
    }

}
