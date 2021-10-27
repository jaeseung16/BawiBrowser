//
//  NoteListView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/20/21.
//

import SwiftUI

struct NoteListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.created, ascending: false)],
        animation: .default)
    private var notes: FetchedResults<Note>
    
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
    @State private var presentFilterNoteView = false
    
    @State private var recipient: String?
    
    private var recipients: Array<String> {
        var toSet = Set<String>()
        
        notes.compactMap { note in
            note.to
        }
        .forEach { to in
            toSet.insert(to)
        }
        
        return Array(toSet)
    }
    
    private var filteredNotes: Array<Note> {
        notes.filter { note in
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
            
                List {
                    ForEach(filteredNotes) { note in
                        label(note: note, in: geometry)
                    }
                    .onDelete(perform: { indexSet in
                        for index in indexSet {
                            let note = filteredNotes[index]
                            viewContext.delete(note)
                        }
                        
                        do {
                            try viewContext.save()
                        } catch {
                            print(error)
                        }
                    })
                }
                .listStyle(InsetListStyle())
            }
            .padding()
            .sheet(isPresented: $presentFilterNoteView) {
                NoteFilterView(to: $recipient, toList: recipients)
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
            
            Text(note.msg ?? "")
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding(.leading)
                .frame(alignment: .leading)
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
    
    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .long
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
}

struct NoteListView_Previews: PreviewProvider {
    static var previews: some View {
        NoteListView()
    }
}
