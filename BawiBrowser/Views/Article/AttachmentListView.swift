//
//  AttachmentListView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/18/21.
//

import SwiftUI

struct AttachmentListView: View {
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    @State var attachments: [Attachment]

    var body: some View {
        GeometryReader { geometry in
            List {
                ForEach(attachments) { attachment in
                    VStack {
                        Text(attachment.created!, format: .dateTime)
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
                .onDelete { indexSet in
                    for index in indexSet {
                        let attachment = attachments[index]
                        attachments.remove(at: index)
                        viewModel.delete(attachment)
                    }
                    viewModel.save()
                }

            }
        }
    }

}
