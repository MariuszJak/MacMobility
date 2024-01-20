//
//  String+Ext.swift
//  MagicTrackpad
//
//  Created by Mariusz Jakowienko on 22/07/2023.
//

import UIKit

extension String {
    var convertBase64StringToImage: UIImage? {
        guard let imageData = Data(base64Encoded: self) else {
            return nil
        }
        return UIImage(data: imageData)
    }
}
