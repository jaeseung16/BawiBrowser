//
//  AttachmentListView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/18/21.
//

import SwiftUI

struct AttachmentListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Attachment.created, ascending: false)],
        animation: .default)
    private var attachments: FetchedResults<Attachment>

    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                HStack {
                    Text("Date")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.16)
                    Text("Board / Article")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.3)
                    Text("Attachment")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.5)
                }
                
                List {
                    ForEach(attachments) { attachment in
                        HStack {
                            VStack {
                                Text(dateFormatter.string(from: attachment.created!))
                            }
                            .frame(width: geometry.size.width * 0.16)
                            
                            VStack {
                                Text("\(attachment.article!.boardId ?? 0)")
                                    .font(.headline)
                                
                                Text("\(attachment.article!.articleId ?? 0)")
                                    .font(.subheadline)
                            }
                            .frame(width: geometry.size.width * 0.3)
                            
                            if let image = NSImage(data: attachment.content!) {
                                Image(nsImage: image)
                                .frame(width: geometry.size.width * 0.5)
                            }
                            
                                
                        }
                    }
                }
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

struct AttachmentListView_Previews: PreviewProvider {
    static var previews: some View {
        AttachmentListView()
    }
}
