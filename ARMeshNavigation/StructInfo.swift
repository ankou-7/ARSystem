//
//  StructInfo.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/11/06.
//

struct Vector33Entity: Codable {
    let x: SIMD3<Float>
    let y: SIMD3<Float>
    let z: SIMD3<Float>
}

struct Vector44Entity: Codable {
    let x: SIMD4<Float>
    let y: SIMD4<Float>
    let z: SIMD4<Float>
    let w: SIMD4<Float>
}

struct Vector3Entity: Codable {
    let x: Float
    let y: Float
    let z: Float
}

struct json_pointcloudUniforms: Codable {
    var Intrinsics: Vector33Entity
    var ViewMatrix: Vector44Entity
    
    var cameraPosition: Vector3Entity
    var cameraEulerAngles: Vector3Entity
}

struct depthMap_data: Codable {
    var depth: Float32!
}

struct ObjectInfo_data: Codable {
    var Position: Vector3Entity
    var Scale: Vector3Entity
    var EulerAngles: Vector3Entity
}

struct MakeMap_parameta: Codable {
    var cameraPosition: Vector3Entity
    var cameraEulerAngles: Vector3Entity
    var cameraVector: Vector3Entity
}

struct json_parameta: Codable {
    var Intrinsics: Vector33Entity
    var ViewMatrix: Vector44Entity
    
    var cameraPosition: Vector3Entity
    var cameraEulerAngles: Vector3Entity
    var cameraTransform: Vector44Entity
}
