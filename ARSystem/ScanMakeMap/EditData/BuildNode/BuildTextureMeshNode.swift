//
//  BuildTextureMeshNode.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import SceneKit
import ARKit

class BuildTextureMeshNode: SCNNode {
    private var models: Navi_Modelname //List<anchor_data>
    private var texImage: UIImage
    
    let decoder = JSONDecoder()
    let tex_node = SCNNode()
    
    private var url: URL!
    
    init(models: Navi_Modelname, texImage: UIImage) {
        self.models = models
        self.texImage = texImage
        super.init()
        
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        
        buildTexMesh()
        tex_node.name = "meshNode"
        addChildNode(tex_node)
    }
    
    func buildTexMesh() {
        
//        for i in 0..<models.meshNum {
        for i in 0..<DataManagement.getDataCount(name: "\(models.dayString)/\(ModelManagement.modelID)/texcoords") {
            let texcoordsPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/texcoords/texcoords\(i).data")
            let vertexPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/vertex/vertex\(i).data")
            let normalsPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/normals/normals\(i).data")
            let facesPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/faces/faces\(i).data")
            
            let vertexData = try! Data(contentsOf: vertexPath) //result[i].vertices!
            let normalData = try! Data(contentsOf: normalsPath) //result[i].normals!
            
            
            var faces: [Int32]!
            if ((try? decoder.decode([Int32].self, from: try! Data(contentsOf: facesPath))) != nil) {
                faces = (try? decoder.decode([Int32].self, from: try! Data(contentsOf: facesPath)))
            } else {
                let facesData = try! Data(contentsOf: facesPath)
                faces = [Int32](repeating: Int32(0), count: facesData.count / MemoryLayout<Int32>.stride)
                faces = facesData.withUnsafeBytes {
                    Array(UnsafeBufferPointer<Int32>(start: $0, count: facesData.count/MemoryLayout<Int32>.size))
                }
            }
            
            var texcoords: [SIMD2<Float>]!
            if ((try? decoder.decode([SIMD2<Float>].self, from: try! Data(contentsOf: texcoordsPath))) != nil) {
                texcoords = (try? decoder.decode([SIMD2<Float>].self, from: try! Data(contentsOf: texcoordsPath)))
            } else {
                let texcoordsData = try! Data(contentsOf: texcoordsPath)
                texcoords = [SIMD2<Float>](repeating: SIMD2<Float>(0,0), count: faces.count)
                texcoords = texcoordsData.withUnsafeBytes {
                    Array(UnsafeBufferPointer<SIMD2<Float>>(start: $0, count: texcoordsData.count/MemoryLayout<SIMD2<Float>>.size))
                }
            }
            
//            print("vertexData\(i) : \(vertexData)")
//            print("normalData\(i) : \(normalData)")
//            print("faceData\(i) : \(faces)")
//            print("texData\(i) : \(texcoords)")
            
            let verticeSource = SCNGeometrySource(
                data: vertexData,
                semantic: SCNGeometrySource.Semantic.vertex,
                vectorCount: faces.count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SIMD3<Float>>.size
            )
            let normalSource = SCNGeometrySource(
                data: normalData,
                semantic: SCNGeometrySource.Semantic.normal,
                vectorCount: faces.count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: MemoryLayout<Float>.size * 3,
                dataStride: MemoryLayout<SIMD3<Float>>.size
            )
            let faceSource = SCNGeometryElement(indices: faces, primitiveType: .triangles)
            let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords)

            let nodeGeometry = SCNGeometry(sources: [verticeSource, normalSource, textureCoordinates], elements: [faceSource])
            nodeGeometry.firstMaterial?.diffuse.contents = texImage
            

            let node = SCNNode(geometry: nodeGeometry)
            tex_node.addChildNode(node)
        }
        print("load完了")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
