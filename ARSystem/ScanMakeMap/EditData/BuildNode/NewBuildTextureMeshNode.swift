//
//  NewBuildTextureMeshNode.swift
//  ARSystem
//
//  Created by 安江洸希 on 2022/11/08.
//

import SceneKit
import ARKit

class NewBuildTextureMeshNode: SCNNode {
    private var models: Navi_Modelname //List<anchor_data>
    private var texImage: UIImage
    
    private var texcoordsData: Data
    private var verticesData: Data
    private var normalsData: Data
    private var facesData: Data
    private var faces: [Int32]
    private var texcoords: [SIMD2<Float>]
    
    let decoder = JSONDecoder()
    
    private var url: URL!
    
    init(models: Navi_Modelname, texImage: UIImage, texcoordsData: Data, verticesData: Data, normalsData: Data, facesData: Data, faces: [Int32], texcoords: [SIMD2<Float>]) {
        self.models = models
        self.texImage = texImage
        
        self.texcoordsData = texcoordsData
        self.verticesData = verticesData
        self.normalsData = normalsData
        self.facesData = facesData
        self.faces = faces
        self.texcoords = texcoords
        
        super.init()
        
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        
        let node = buildTexMesh()
        addChildNode(node)
    }
    
    func buildTexMesh() -> SCNNode {
        
        print(facesData.count / MemoryLayout<Int32>.stride)
        //var faces = [Int32](repeating: Int32(0), count: facesData.count / MemoryLayout<Int32>.stride)
//        var faces = facesData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<Int32>(start: $0, count: facesData.count/MemoryLayout<Int32>.size))
//        }
//
//        //var texcoords = [SIMD2<Float>](repeating: SIMD2<Float>(0,0), count: faces.count)
//        var texcoords = texcoordsData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<SIMD2<Float>>(start: $0, count: texcoordsData.count/MemoryLayout<SIMD2<Float>>.size))
//        }
        
        print(self.faces[0...10])
        print(self.texcoords[0...10])
        
        let verticeSource = SCNGeometrySource(
            data: verticesData,
            semantic: SCNGeometrySource.Semantic.vertex,
            vectorCount: faces.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.size
        )
        let normalSource = SCNGeometrySource(
            data: normalsData,
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
        node.name = "meshNode"
        print("load完了")
        
        return node
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

