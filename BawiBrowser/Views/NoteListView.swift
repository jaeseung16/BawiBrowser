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
    
    @State private var searchString = ""
    
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
                            label(note: note, in: geometry)
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
            .searchable(text: $searchString)
            .onChange(of: searchString) { newValue in
                viewModel.searchNote(newValue)
            }
        }
    }
    
    private func label(note: Note, in geometry: GeometryProxy) -> some View {
        HStack {
            VStack {
                Text(note.to ?? "")
                    
                HStack {
                    Spacer()
                    
                    Text(dateFormatter.string(from: note.created ?? Date()))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.trailing)
            .frame(width: geometry.size.width * 0.2)
         
            Divider()
            
            Text(makeReadable(note.msg))
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding(.leading)
                .frame(alignment: .leading)
            
            Spacer()
            
            Button {
                viewModel.delete(note)
                viewModel.save()
            } label: {
                Image(systemName: "trash")
            }
        }
    }
    
    private func makeReadable(_ msg: String?) -> String {
        return msg?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? ""
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
    
    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .long
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
}
