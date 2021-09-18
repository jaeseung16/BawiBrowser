//
//  BawiBrowserSettings.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 9/17/21.
//

//import SwiftUI

enum BawiBrowserAppearance: String, CaseIterable, Identifiable {
    case light, dark
    
    var id: BawiBrowserAppearance {
        return self
    }
}

/*
struct BawiBrowserSettings: View {
    @AppStorage("BawiBrowser.appearance")
    private var appearance: BawiBrowserAppearance = .light
    
    var body: some View {
        Form {
            Picker("Appearance:", selection: $appearance) {
                ForEach(BawiBrowserAppearance.allCases) { appearance in
                    Text(appearance.rawValue)
                }
            }
            .pickerStyle(InlinePickerStyle())
        }
        .frame(width: 300)
        .navigationTitle("BawiBrowser Settings")
        .padding(80)
    }
}
*/
