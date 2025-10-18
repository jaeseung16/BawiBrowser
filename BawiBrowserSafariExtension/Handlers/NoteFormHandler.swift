//
//  NoteHandler.swift
//  BawiBrowserSafariExtension
//
//  Created by Jae Seung Lee on 10/18/25.
//

actor NoteFormHandler: MessageHandling {

    private let note: BawiNoteDTO
    
    init(note: BawiNoteDTO) {
        self.note = note
    }
    
    func process() async -> Void {
        await SafariExtensionPersister.shared.save(note: note)
    }
    
}
