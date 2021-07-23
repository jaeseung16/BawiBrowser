//
//  BrowserView.swift
//  BawiBrowser
//
//  Created by Jae Seung Lee on 7/16/21.
//

import SwiftUI

struct BrowserView: View {
    @EnvironmentObject var viewModel: BawiBrowserViewModel
    
    var url: URL
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    viewModel.navigation = .back
                }, label: {
                    Image(systemName: "chevron.backward")
                })
                
                Spacer()
                
                Button(action: {
                    viewModel.navigation = .home
                }, label: {
                    Image(systemName: "house")
                })
                
                Spacer()
                
                Button(action: {
                    viewModel.navigation = .forward
                }, label: {
                    Image(systemName: "chevron.forward")
                })
            }
            
            WebView(url: url)
                .environmentObject(viewModel)
                .shadow(color: Color.gray, radius: 1.0)
                
        }
        .padding()
    }
}

struct BrowserView_Previews: PreviewProvider {
    static var previews: some View {
        BrowserView(url: URL(string: "https://www.bawi.org/main/login.cgi")!)
            .environmentObject(BawiBrowserViewModel())
    }
}
