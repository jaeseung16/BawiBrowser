//
//  AttachmentListView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/18/21.
//

import SwiftUI

struct AttachmentListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State var attachments: [Attachment]

    var body: some View {
        GeometryReader { geometry in
            List {
                ForEach(attachments) { attachment in
                    VStack {
                        Text(dateFormatter.string(from: attachment.created!))
                            .font(.caption)
                            .frame(width: geometry.size.width * 0.9, alignment: .leading)
                        
                        if let image = NSImage(data: attachment.content!) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width * 0.9)
                                .padding()
                        }
                    }
                }
                .onDelete(perform: { indexSet in
                    print("\(indexSet)")
                    for index in indexSet {
                        let attachment = attachments[index]
                        attachments.remove(at: index)
                        viewContext.delete(attachment)
                    }
                    
                    do {
                        try viewContext.save()
                    } catch {
                        print(error)
                    }
                })

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
        AttachmentListView(attachments: [Attachment]())
    }
}
