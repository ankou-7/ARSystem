//
//  Extensions.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/07/14.
//

import UIKit
import ARKit

extension CVPixelBuffer {

    var width: Int { CVPixelBufferGetWidth(self) }
    var height: Int { CVPixelBufferGetHeight(self) }

    func cropPortraitCenterData<T>(sideCutoff: Int) -> ([T], Int) {
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else { return ([], 0) }
        let pointer = UnsafeMutableBufferPointer<T>(start: baseAddress.assumingMemoryBound(to: T.self),
                                                    count: width * height)
        var dataArray: [T] = []
        // 画面上の横幅のサイズを計算。画面の横サイズいっぱいから左右は切り落とした値。
        // ※紛らわしいがポートレート時にARKitから取得されるデータは横向きなので height で計算。
        let size = height - sideCutoff * 2 //184
        //height = 192
        //width = 256
        // 画面の縦方向の中央部分のデータを取得。取得順番は上下逆転。
        for x in (Int((width / 2) - (size / 2)) ..< Int((width / 2) + (size / 2))).reversed() {
            // 画面の横方向の中央部分のデータを取得。取得順番は左右逆転。
            for y in (sideCutoff ..< (height - sideCutoff)).reversed() {
                let index = y * width + x
                dataArray.append(pointer[index])
            }
        }
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        return (dataArray, size)
    }
}

extension ARFrame {

    func cropCenterSquareImage(fullWidthScale: CGFloat, aspectRatio: CGFloat, orientation: UIInterfaceOrientation) -> CIImage {
        let pixelBuffer = self.capturedImage

        // 入力画像をスクリーンサイズに変換
        let imageSize = CGSize(width: pixelBuffer.width, height: pixelBuffer.height)
        let image = CIImage(cvImageBuffer: pixelBuffer)
        // 1) 入力画像を 0.0〜1.0 の座標に変換
        let normalizeTransform = CGAffineTransform(scaleX: 1.0/imageSize.width, y: 1.0/imageSize.height)
        // 2) ポートレートの場合、X軸Y軸を反転
        var flipTransform = CGAffineTransform.identity
        if orientation.isPortrait {
            // X軸Y軸共に反転
            flipTransform = CGAffineTransform(scaleX: -1, y: -1)
            // X軸Y軸共にマイナス側に移動してしまうのでプラス側に移動
            flipTransform = flipTransform.concatenating(CGAffineTransform(translationX: 1, y: 1))
        }
        // 3) 入力画像上でのスクリーンの向き・位置に移動
        let viewPortSize = CGSize(width: fullWidthScale, height: fullWidthScale * aspectRatio)
        let displayTransform = self.displayTransform(for: orientation, viewportSize: viewPortSize)
        // 4) 0.0〜1.0 の座標系からスクリーンの座標系に変換
        let toViewPortTransform = CGAffineTransform(scaleX: viewPortSize.width, y: viewPortSize.height)
        // 5) 1〜4までの変換を行い、変換後の画像を指定サイズでクリップ
        let transformedImage = image
            .transformed(by: normalizeTransform
                            .concatenating(flipTransform)
                            .concatenating(displayTransform)
                            .concatenating(toViewPortTransform))
            .cropped(to: CGRect(x: 0,
                                y: CGFloat(Int(viewPortSize.height / 2.0 - fullWidthScale / 2.0)),
                                width: fullWidthScale,
                                height: fullWidthScale))

        return transformedImage
    }

    func cropPortraitCenterSquareDepth(aspectRatio: CGFloat) -> ([Float32], Int) {
        guard let pixelBuffer = self.smoothedSceneDepth?.depthMap else { return ([], 0) }
        return cropPortraitCenterSquareMap(pixelBuffer, aspectRatio)
    }

    func cropPortraitCenterSquareDepthConfidence(aspectRatio: CGFloat) -> ([UInt8], Int) {
        guard let pixelBuffer = self.smoothedSceneDepth?.confidenceMap else { return ([], 0) }
        return cropPortraitCenterSquareMap(pixelBuffer, aspectRatio)
    }

    private func cropPortraitCenterSquareMap<T>(_ pixelBuffer: CVPixelBuffer, _ aspectRatio: CGFloat) -> ([T], Int) {

        let viewPortSize = CGSize(width: 1.0, height: aspectRatio)
        var displayTransform = self.displayTransform(for: .portrait, viewportSize: viewPortSize)
        // ポートレートの場合、X軸Y軸共に反転
        var flipTransform =  CGAffineTransform(scaleX: -1, y: -1)
        // X軸Y軸共にマイナス側に移動してしまうのでプラス側に移動
        flipTransform = flipTransform.concatenating(CGAffineTransform(translationX: 1, y: 1))

        displayTransform = displayTransform.concatenating(flipTransform)
        let sideCutoff = Int((1.0 - (1.0 / displayTransform.c)) / 2.0 * CGFloat(pixelBuffer.height))
        
        print("sideCutoff:\(sideCutoff)") //4
        print("height:\(pixelBuffer.height)") //192
        print("width:\(pixelBuffer.width)") //256

        return pixelBuffer.cropPortraitCenterData(sideCutoff: sideCutoff)
    }
}
