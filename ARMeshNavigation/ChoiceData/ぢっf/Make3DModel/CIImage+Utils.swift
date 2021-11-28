//
//  CIImage+Utils.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/07/13.
//

import CoreImage
import UIKit

extension CIImage {
    func createCGImage() -> CGImage {
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(self, from: extent) else { fatalError() }
        return cgImage
    }
}

extension CGImage {

    func pixelData() -> [UInt8]? {
//        guard let colorSpace = colorSpace else { return nil }

        let totalBytes = height * bytesPerRow
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
//        print("bytesPerRow:\(bytesPerRow)")
//        print("bitsPerComponent:\(bitsPerComponent)")
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent, //8
            bytesPerRow: bytesPerRow, //1024
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue)
            else { fatalError() }
        context.draw(self, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
        
        return pixelData
    }
    
    func makeImage(pixelData: [UInt8]) -> UIImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel = pixelData
        
        guard let context = CGContext(
            data: &pixel,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent, //8
            bytesPerRow: bytesPerRow, //1024
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue)
        else { fatalError() }
        
        let cgImage = context.makeImage()
        return UIImage(cgImage: cgImage!)
    }
}
