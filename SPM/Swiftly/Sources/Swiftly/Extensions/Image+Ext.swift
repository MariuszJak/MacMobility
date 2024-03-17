//
//  File.swift
//  
//
//  Created by Mariusz Jakowienko on 14/03/2024.
//

import SwiftUI
import Combine

public struct SwiftlyImage: UIViewRepresentable {
    var url: URL
    var placeholder: UIImage?
    
    public init(url: URL, placeholder: UIImage?) {
        self.url = url
        self.placeholder = placeholder
    }
    
    public func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        var cancellable = Set<AnyCancellable>()
        UIImageView().loadImage(with: url, placeholderImage: placeholder) { image in
            imageView.image = image
            return UIImageView(image: image)
        }
        .store(in: &cancellable)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return imageView
    }
    
    public func updateUIView(_ uiView: UIImageView, context: Context) {}
}
