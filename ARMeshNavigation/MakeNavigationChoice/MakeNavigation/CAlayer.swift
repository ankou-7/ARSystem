//
//  CAlayer.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/11/30.
//

import UIKit
 
class LayerView : UIView {
    override func draw(_ rect: CGRect) {
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        UIGraphicsPushContext(ctx)
        
        // グラデーションレイヤーの生成
        let gradLayer = CAGradientLayer()
        gradLayer.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        gradLayer.colors = [
            UIColor.blue.cgColor,
            UIColor.red.cgColor,
        ]
        
        // 三角レイヤーの生成
        let line = UIBezierPath();
        line.move(to: CGPoint(x: 30, y: 80));
        line.addLine(to: CGPoint(x: 200, y: 450));
        line.addLine(to: CGPoint(x: 300, y: 280));
        line.close()
        
        // 三角レイヤーのシェイプを生成
        let ovalShapeLayer = CAShapeLayer()
        ovalShapeLayer.path = line.cgPath
        
        // マスクを設定
        gradLayer.mask = ovalShapeLayer
        
        // 描写
        layer.addSublayer(gradLayer)
        UIGraphicsPopContext()
    }
}
