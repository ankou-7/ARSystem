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
        let start = Date()
        print("calcu開始")
        
        self.calculateRenderer = CalculateRenderer(models: models, anchor: anchors, calcuUniforms: calcuMatrix, depth: depth, calculateParameta: calculateParameta)
        self.calculateRenderer.drawRectResized(size: self.sceneView.bounds.size)
        
        for i in 0..<anchors.count {
            print("-----------------------------------------")
            print("\(flag)回目")
            flag += self.calculateRenderer.calcu5(num: i)
        }
        print("-----------------------------------------")
        print("calcu終了")
        let elapsed = Date().timeIntervalSince(start)
        print("処理時間：\(elapsed)")
        print("総ポリゴン数：\(calculateRenderer.sumPolygon)")
        print("割り当てられたポリゴン数：\(calculateRenderer.sumPolygon - calculateRenderer.texCount / 3)")
        print("テクスチャ割り当て割合：\(Double(calculateRenderer.sumPolygon - calculateRenderer.texCount / 3) / Double(calculateRenderer.sumPolygon))")
        print("割り当てられなかったポリゴン数：\(calculateRenderer.texCount / 3)")
        let st = """
                    総ポリゴン数：\(calculateRenderer.sumPolygon)
                    割り当てられたポリゴン数：\(calculateRenderer.sumPolygon - calculateRenderer.texCount / 3)
                    テクスチャ割り当て割合：\(Double(calculateRenderer.sumPolygon - calculateRenderer.texCount / 3) / Double(calculateRenderer.sumPolygon))
                    割り当てられなかったポリゴン数：\(calculateRenderer.texCount / 3)
                  """
        saveDocument(text: st)
        
        completionHandler()
    }
    
    func saveDocument(text: String) {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            //フォルダ作成
            let section_num = ViewManagement.sectionID!
            let cell_num = ViewManagement.cellID!
            let results = try! Realm().objects(Navi_SectionTitle.self)
            let directory = url.appendingPathComponent("\(results[section_num].cells[cell_num].cellName)-\(ModelManagement.modelID)", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("失敗した")
            }
            
            let archivePath = url.appendingPathComponent("\(results[section_num].cells[cell_num].cellName)-\(ModelManagement.modelID)/rate.txt")
            do {
                try text.write(to: archivePath, atomically: false, encoding: .utf8)
            } catch {
                print("Error: \(error)")
            }
            
            var posiString = ""
            for json in results[section_num].cells[cell_num].models[ModelManagement.modelID].json {
                let json_data = try? JSONDecoder().decode(MakeMap_parameta.self, from: json.json_data!)
                posiString += "\(json_data!.cameraPosition.x) \(json_data!.cameraPosition.y) \(json_data!.cameraPosition.z)\n"
            }
            let posiPath = url.appendingPathComponent("\(results[section_num].cells[cell_num].cellName)-\(ModelManagement.modelID)/position.txt")
            do {
                try posiString.write(to: posiPath, atomically: false, encoding: .utf8)
            } catch {
                print("Error: \(error)")
            }
            
        }
    }
    
    
    func make_calcuParameta() {
        let decoder = JSONDecoder()
        
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
