//
//  CIImage+Utils.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/07/13.
//

import CoreImage

extension CIImage {
    func createCGImage() -> CGImage {
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(self, from: extent) else { fatalError() }
        return cgImage
    }
}

