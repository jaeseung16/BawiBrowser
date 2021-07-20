//
//  NoteListView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/20/21.
//

import SwiftUI

struct NoteListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.created, ascending: false)],
        animation: .default)
    private var notes: FetchedResults<Note>
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                HStack {
                    Text("Date")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.16)
                    Text("To")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.2)
                    Text("Message")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.6)
                }
            
                List {
                    ForEach(notes) { note in
                        HStack {
                            Text(dateFormatter.string(from: note.created!))
                                .frame(width: geometry.size.width * 0.16)
                         
                            Text(note.to ?? "")
                                .font(.headline)
                                .frame(width: geometry.size.width * 0.2)
                            
                            Text(note.msg ?? "")
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .frame(width: geometry.size.width * 0.6, alignment: .leading)
                        }
                    }
                }
                .listStyle(InsetListStyle())
            }
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
