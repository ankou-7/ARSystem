//
//  ShaderTypes.h
//  ARMeshNavigation
//
//  Created by 安江洸希 on 2021/03/04.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

enum TextureIndices {
    kTextureY = 0,
    kTextureCbCr = 1,
    kTextureDepth = 2,
    kTextureConfidence = 3
};

enum BufferIndices {
    kPointCloudUniforms = 0,
    kParticleUniforms = 1,
    kGridPoints = 2,
    kDepthUniforms = 3,
};

struct RGBUniforms {
    matrix_float3x3 viewToCamera;
    float viewRatio;
    float radius;
};

struct PointCloudUniforms {
    matrix_float4x4 viewProjectionMatrix;
    matrix_float4x4 localToWorld;
    matrix_float3x3 cameraIntrinsicsInversed;
    simd_float2 cameraResolution;
    
    float particleSize;
    int maxPoints;
    int pointCloudCurrentIndex;
    int confidenceThreshold;
    
    int numGridPoints;
    
    //追加
    simd_float2 pan_move;
    matrix_float4x4 rotate;
    float scale;
};

struct ParticleUniforms {
    simd_float3 position;
    simd_float3 color;
    float confidence;
};

struct DepthUniforms {
    simd_float3 position;
    float confidence;
};

struct CalcuUniforms {
    matrix_float4x4 matrix;
    int yoko;
    int tate;
};

struct anchorUniforms {
    matrix_float4x4 transform;
    int calcuCount;
    int yoko;
    int tate;
    int maxCount;
    int arrayCount;
    int depthCount;
};

struct MeshUniforms {
    simd_float3 vertex1;
    //simd_float3 vertex2;
    //simd_float3 vertex3;
    vector_float4 color;
    int index;
    int originIndex;
    simd_int3 faceIndex;
};

struct realAnchorUniforms {
    matrix_float4x4 transform;
    matrix_float4x4 viewProjectionMatrix;
    int maxCount;
    int currentIndex;
};
#endif /* ShaderTypes_h */
