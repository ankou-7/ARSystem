//
//  GPUCalculateTexture.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import SceneKit
import RealmSwift
import ARKit
import Foundation

class GPUCalculateTexture {
    
    private var sceneView: SCNView
    private var anchors: [ARMeshAnchor]
    private var models: Navi_Modelname
    private var calculateParameta: calculateParameta
    
    private var calcuMatrix = [float4x4]()
    private var depth = [depthPosition]()
    private var calculateRenderer: CalculateRenderer!
    
    private var url: URL!
    
    var removeCount: [Int]
    
    var st = ""
    var posi = ""
    
    // 使用者が単位を把握できるようにするため
    typealias MegaByte = UInt64
    
    init(sceneView: SCNView, anchors: [ARMeshAnchor], models: Navi_Modelname, calculateParameta: calculateParameta, removeCount: [Int]) {
        self.sceneView = sceneView
        self.anchors = anchors
        self.models = models
        self.calculateParameta = calculateParameta
        
        self.removeCount = removeCount
        
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        make_calcuParameta()
    }
    
    func makeGPUTexture(completionHandler: @escaping () -> ()) {
        var flag = 0
        let start = Date()
        var poly = ""
        var time = ""
        print("calcu開始")
        
        self.calculateRenderer = CalculateRenderer(models: models, anchor: anchors, calcuUniforms: calcuMatrix, depth: depth, calculateParameta: calculateParameta)
        self.calculateRenderer.drawRectResized(size: self.sceneView.bounds.size)
        
        for i in 0..<anchors.count {
            print("-----------------------------------------")
            print("\(flag)回目")
            flag += self.calculateRenderer.calcu5(num: i)
            poly += "\(calculateRenderer.sumPolygon)\n"
            time += "\(Date().timeIntervalSince(start))\n"
            print("メモリ使用量：\(String(describing: getMemoryUsed()))")
        }
        print("-----------------------------------------")
        print("calcu終了")
        print("処理時間：\(Date().timeIntervalSince(start))")
        print("総ポリゴン数：\(calculateRenderer.sumPolygon)")
        print("割り当てられたポリゴン数：\(calculateRenderer.sumPolygon - calculateRenderer.texCount / 3)")
        print("テクスチャ割り当て割合：\(Double(calculateRenderer.sumPolygon - calculateRenderer.texCount / 3) / Double(calculateRenderer.sumPolygon))")
        print("割り当てられなかったポリゴン数：\(calculateRenderer.texCount / 3)")
        st += """
                    総ポリゴン数：\(calculateRenderer.sumPolygon)
                    割り当てられたポリゴン数：\(calculateRenderer.sumPolygon - calculateRenderer.texCount / 3)
                    テクスチャ割り当て割合：\(Double(calculateRenderer.sumPolygon - calculateRenderer.texCount / 3) / Double(calculateRenderer.sumPolygon))
                    割り当てられなかったポリゴン数：\(calculateRenderer.texCount / 3)\n
                """
        st += poly + time
        saveDocument(text: st)
        
        completionHandler()
    }
    
    func noLog_makeGPUTexture(completionHandler: @escaping () -> ()) {
        var flag = 0
        
        self.calculateRenderer = CalculateRenderer(models: models, anchor: anchors, calcuUniforms: calcuMatrix, depth: depth, calculateParameta: calculateParameta)
        self.calculateRenderer.drawRectResized(size: self.sceneView.bounds.size)
        
        for i in 0..<anchors.count {
            flag += self.calculateRenderer.calcu5(num: i)
        }
        
        completionHandler()
    }
    
    func saveDocument(text: String) {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let archivePath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/バージョン3.txt")
            do {
                try text.write(to: archivePath, atomically: false, encoding: .utf8)
            } catch {
                print("Error: \(error)")
            }
            
            
            let posiPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/posi.txt")
            do {
                try posi.write(to: posiPath, atomically: false, encoding: .utf8)
            } catch {
                print("Error: \(error)")
            }
            
//            var posiString = ""
//            for json in results[section_num].cells[cell_num].models[ModelManagement.modelID].json {
//                let json_data = try? JSONDecoder().decode(MakeMap_parameta.self, from: json.json_data!)
//                posiString += "\(json_data!.cameraPosition.x) \(json_data!.cameraPosition.y) \(json_data!.cameraPosition.z)\n"
//            }
//            let posiPath = url.appendingPathComponent("\(results[section_num].cells[cell_num].cellName)-\(ModelManagement.modelID)/position.txt")
//            do {
//                try posiString.write(to: posiPath, atomically: false, encoding: .utf8)
//            } catch {
//                print("Error: \(error)")
//            }
            
        }
    }
    
    
    func make_calcuParameta() {
        let decoder = JSONDecoder()
        
        for i in 0..<models.parametaNum { //pic.count {
            if removeCount.firstIndex(of: i) == nil {
                let jsonPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/json/json\(i).data")
                //let json_data = try? decoder.decode(MakeMap_parameta.self, from: models.json[i].json_data!)
                let json_data = try? decoder.decode(MakeMap_parameta.self, from: try! Data(contentsOf: jsonPath))
                
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
                
                posi += "\(i) : \(json_data!.cameraPosition)\n"
                
                let depthPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/depth/depth\(i).data")
                //let depth_array = (try? decoder.decode([depthPosition].self, from: models.depth[i].depth_data!))!
                let depth_array = try? decoder.decode([depthPosition].self, from: try! Data(contentsOf: depthPath))
                depth.append(contentsOf: depth_array!)
            }
        }
    }
    
    // 引数にenumで任意の単位を指定できるのが好ましい e.g. unit = .auto (デフォルト引数)
    func getMemoryUsed() -> MegaByte? {
        // タスク情報を取得
        var info = mach_task_basic_info()
        // `info`の値からその型に必要なメモリを取得
        var count = UInt32(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            task_info(mach_task_self_,
                      task_flavor_t(MACH_TASK_BASIC_INFO),
                      // `task_info`の引数にするためにInt32のメモリ配置と解釈させる必要がある
                      $0.withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                UnsafeMutablePointer<Int32>(pointer)
            }, &count)
        }
        // MB表記に変換して返却
        return result == KERN_SUCCESS ? info.resident_size / 1024 / 1024 : nil
    }
}