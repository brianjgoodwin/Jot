//
//  AboutView.swift
//  Jot
//
//  Created by Brian on 12/3/23.
//

import SwiftUI

struct AboutView: View {
	var body: some View {
		VStack {
			
			Spacer()
			
			Text("Jot")
				.font(.largeTitle)
			
			Text("Version 1.0")
			
			Image("icon_256")
			
//			Image(uiImage: UIImage(named: "Icon")!)
			
			Spacer()
			
			Text(verbatim: "Copyright © Brian Goodwin 2023 - \(Calendar.current.component(.year, from: .now))")
			
			Spacer()
			
			Text("Credits:")
				.font(.headline)
			
			Text("Brian Goodwin")
//			Text("Jane Smith")
			Spacer()
			
		}
		.padding()
	}
}

#Preview {
    AboutView()
}
