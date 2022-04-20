//
//  GPUCalculateTexture.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import SceneKit
import RealmSwift
import ARKit

class GPUCalculateTexture {
    
    private var sceneView: SCNView
    private var anchors: [ARMeshAnchor]
    private var picCount: Int
    private var models: Navi_Modelname
    private var calculateParameta: calculateParameta
    
    private var calcuMatrix = [float4x4]()
    private var depth = [depthPosition]()
    private var calculateRenderer: CalculateRenderer!
    
    let decoder = JSONDecoder()
    
    init(sceneView: SCNView, anchors: [ARMeshAnchor], picCount: Int, models: Navi_Modelname, calculateParameta: calculateParameta) {
        self.sceneView = sceneView
        self.anchors = anchors
        self.picCount = picCount
        self.models = models
        self.calculateParameta = calculateParameta
        
        make_calcuParameta()
    }
    
    func makeGPUTexture(completionHandler: @escaping () -> ()) {
        var flag = 0
        
        //DispatchQueue.global().sync {
            let start = Date()
            print("calcu開始")
            
            self.calculateRenderer = CalculateRenderer(models: models, anchor: anchors, calcuUniforms: calcuMatrix, depth: depth, calculateParameta: calculateParameta)
            self.calculateRenderer.drawRectResized(size: self.sceneView.bounds.size)
            
            //DispatchQueue.main.async { [self] in
                //ActivityView.startAnimating()
                for i in 0..<anchors.count {
                    print("---------------------------------------------------------------------------------")
                    print("\(flag)回目")
                    flag += self.calculateRenderer.calcu5(num: i)
                    
                    if flag == anchors.count {
                        print("---------------------------------------------------------------------------------")
                        print("calcu終了")
                        let elapsed = Date().timeIntervalSince(start)
                        print("処理時間：\(elapsed)")
                        completionHandler()
                    }
                }
            //}
        //}
    }
    
    
    func make_calcuParameta() {
        for i in 0..<picCount {
            let json_data = try? decoder.decode(MakeMap_parameta.self, from: models.json[i].json_data!)
            
            let viewMatrix = simd_float4x4(json_data!.viewMatrix.x,
                                           json_data!.viewMatrix.y,
                                           json_data!.viewMatrix.z,
                                           json_data!.viewMatrix.w)
            let projectionMatrix = simd_float4x4(json_data!.projectionMatrix.x,
                                                 json_data!.projectionMatrix.y,
                                                 json_data!.projectionMatrix.z,
                                                 json_data!.projectionMatrix.w)
            let matrix = projectionMatrix * viewMatrix
            calcuMatrix.append(matrix)
            
            let depth_array = (try? decoder.decode([depthPosition].self, from: models.depth[i].depth_data!))!
            depth.append(contentsOf: depth_array)
        }
    }
}
