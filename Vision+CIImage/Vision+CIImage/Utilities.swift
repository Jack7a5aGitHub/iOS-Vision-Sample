//
//  Utilities.swift
//  Vision+CIImage
//
//  Created by Jack Wong on 2018/08/16.
//  Copyright © 2018 Jack Wong. All rights reserved.
//

import UIKit

// Convert UIImageOrientation to CGImageOrientation for use in Vision analysis
extension CGImagePropertyOrientation {
    init(_ uiImageOrientation: UIImageOrientation) {
        switch uiImageOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        }
    }
}
