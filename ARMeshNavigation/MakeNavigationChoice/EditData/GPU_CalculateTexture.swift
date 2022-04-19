//
//  GPU_CalculateTexture.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import SceneKit

extension EditDataController {
    
    func GPU_makeTexture() {
        let count = results[section_num].cells[cell_num].models[current_model_num].pic.count
        let yoko: Float = 17.0
        let tate: Float = ceil(Float(count)/yoko)
        let (calcuUnifoms, depth) = make_calcuParameta()
        //self.calculate.matrix = calcuMatrix
        
        var flag = 0
        
        DispatchQueue.global().sync {
            
            let start = Date()
            print("calcu開始")
            //DispatchQueue.main.async { [self] in
            
            self.calculate = CalculateRenderer(section_num: section_num, cell_num: cell_num, model_num: current_model_num, anchor: anchors, metalDevice: self.sceneView.device!, calcuUniforms: calcuUnifoms, depth: depth, tate: Int(tate), yoko: Int(yoko), screenWidth: Int(sceneView.bounds.width), screenHeight: Int(sceneView.bounds.height), texString: texString)
            self.calculate.drawRectResized(size: self.sceneView.bounds.size)
            print("calcuCount(スクリーン座標変換用の行列数):\(calcuUnifoms.count)")
            
            
            DispatchQueue.main.async { [self] in
                //ActivityView.startAnimating()
                for i in 0..<anchors.count {
                    print("---------------------------------------------------------------------------------")
                    print("\(flag)回目")
                    flag += self.calculate.calcu5(num: i)
                    //print("配列中身：\(results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i])")
                    
                    if flag == anchors.count {
                        print("---------------------------------------------------------------------------------")
                        print("calcu終了")
                        let elapsed = Date().timeIntervalSince(start)
                        print("処理時間：\(elapsed)")
                        //print("配列全て中身：\(results[section_num].cells[cell_num].models[current_model_num].mesh_anchor)")
//                        print("load")
                        delete_mesh()
                        texmeshNode = BuildTextureMeshNode(result: results[section_num].cells[cell_num].models[current_model_num].mesh_anchor, texImage: new_uiimage)
                        //texmeshNode.name = "meshNode"
                        sceneView.scene?.rootNode.addChildNode(texmeshNode)
                        //let node = build2(image: new_uiimage)
                        //sceneView.scene?.rootNode.addChildNode(node)
                        //load_anchor2()
                        //ActivityView.stopAnimating()
                    }
                }
            }
        }
    }
    
    func make_calcuParameta() -> ([float4x4], [depthPosition]) {
        var calcuMatrix: [float4x4] = []
        var depth: [depthPosition] = []
        
        let count = results[section_num].cells[cell_num].models[current_model_num].pic.count
        let yoko: Float = 17.0
        let tate: Float = ceil(Float(count)/yoko)
        for i in 0..<count {
            let json_data = try? decoder.decode(MakeMap_parameta.self, from:results[section_num].cells[cell_num].models[current_model_num].json[i].json_data!)
            
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
            
            let depth_array = (try? decoder.decode([depthPosition].self, from: results[section_num].cells[cell_num].models[current_model_num].depth[i].depth_data!))!
            depth.append(contentsOf: depth_array)
        }
        return (calcuMatrix, depth)
    }
    
}
