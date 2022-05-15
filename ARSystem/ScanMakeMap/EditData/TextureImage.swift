//
//  TextureImage.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import UIKit

class TextureImage {
    private var width: CGFloat
    private var height: CGFloat
    private var imageArray: [UIImage]
    private var yoko: Float
    private var num: CGFloat
    
    init(W: CGFloat, H: CGFloat, array: [UIImage], yoko: Float, num: CGFloat) {
        self.width = W
        self.height = H
        self.imageArray = array
        self.yoko = yoko
        self.num = num
    }
    
    func makeTexture() -> UIImage? {
        // 指定された画像の大きさのコンテキストを用意
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        
//        let context = UIGraphicsGetCurrentContext()
//        context!.setFillColor(UIColor.white.cgColor)
        
        var tate_count = -1
        for (i,image) in imageArray.enumerated() {
            if i % Int(yoko) == 0 {
                tate_count += 1
            }
            // コンテキストに画像を描画する
            image.draw(in: CGRect(x: CGFloat(i % Int(yoko)) * image.size.width/num, y: CGFloat(tate_count) * image.size.height/num, width: image.size.width/num, height: image.size.height/num))
        }
        // コンテキストからUIImageを作る
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
