//
//  NoteDetailView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 1/12/25.
//

import SwiftUI

struct NoteDetailView: View {
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
    let note: Note
    let geometry: GeometryProxy
    
    var body: some View {
        HStack {
            VStack {
                Text(note.to ?? "")
                
                HStack {
                    Spacer()
                    
                    Text(note.created ?? Date(), format: .dateTime)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.trailing)
            .frame(width: geometry.size.width * 0.2)
            
            Divider()
            
            Text(convertToLocalizedStringKey(note.msg))
                .font(.body)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
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
    
    private func convertToLocalizedStringKey(_ msg: String?) -> LocalizedStringKey {
        return LocalizedStringKey(msg?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? "")
    }
    
}
