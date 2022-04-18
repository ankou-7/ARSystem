//
//  SCNGeometry.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/18.
//

import SceneKit
import ARKit

//extension  SCNGeometry {
//    static func fromAnchor(meshAnchor: ARMeshAnchor) -> SCNGeometry {
//        let vertices = meshAnchor.geometry.vertices
//        let faces = meshAnchor.geometry.faces
//
//        let vertexSource = SCNGeometrySource(buffer: vertices.buffer, vertexFormat: vertices.format, semantic: .vertex, vertexCount: vertices.count, dataOffset: vertices.offset, dataStride: vertices.stride)
//        let faceData = Data(bytesNoCopy: faces.buffer.contents(), count: faces.buffer.length, deallocator: .none)
//        let geometryElement = SCNGeometryElement(data: faceData, primitiveType: .triangles, primitiveCount: faces.count, bytesPerIndex: faces.bytesPerIndex)
//        let geometry = SCNGeometry(sources: [vertexSource], elements: [geometryElement])
//        let defaultMaterial = SCNMaterial()
//        defaultMaterial.fillMode = .lines
//        defaultMaterial.diffuse.contents = UIColor(displayP3Red:1, green:1, blue:1, alpha:0.7) //meshの色を設定
//        geometry.materials = [defaultMaterial]
//
//        return geometry;
//      }
//}
