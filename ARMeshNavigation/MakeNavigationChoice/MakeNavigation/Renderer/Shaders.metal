//
//  Shaders.metal
//  ARMeshNavigation
//
//  Created by 安江洸希 on 2021/03/04.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

//#include <SceneKit/scn_metal>

constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
constant auto yCbCrToRGB = float4x4(float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                    float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                    float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                    float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f));
constant float2 viewVertices[] = { float2(-1, 1), float2(-1, -1), float2(1, 1), float2(1, -1) };
constant float2 viewTexCoords[] = { float2(0, 0), float2(0, 1), float2(1, 0), float2(1, 1) };

/// Retrieves the world position of a specified camera point with depth
static simd_float4 worldPoint(simd_float2 cameraPoint, float depth, matrix_float3x3 cameraIntrinsicsInversed, matrix_float4x4 localToWorld) {
    const auto localPoint = cameraIntrinsicsInversed * simd_float3(cameraPoint, 1) * depth;
    const auto worldPoint = localToWorld * simd_float4(localPoint, 1);
    
    return worldPoint / worldPoint.w;
}

//画面上の２次元点情報を３次元点情報に置き換える
///  Vertex shader that takes in a 2D grid-point and infers its 3D position in world-space, along with RGB and confidence
vertex void unprojectVertex(uint vertexID [[vertex_id]],
                            constant PointCloudUniforms &uniforms [[buffer(kPointCloudUniforms)]],
                            device ParticleUniforms *particleUniforms [[buffer(kParticleUniforms)]],
                            constant float2 *gridPoints [[buffer(kGridPoints)]],
                            texture2d<float, access::sample> capturedImageTextureY [[texture(kTextureY)]],
                            texture2d<float, access::sample> capturedImageTextureCbCr [[texture(kTextureCbCr)]],
                            texture2d<float, access::sample> depthTexture [[texture(kTextureDepth)]],
                            texture2d<unsigned int, access::sample> confidenceTexture [[texture(kTextureConfidence)]]) {
    
    const auto gridPoint = gridPoints[vertexID];
    //超えないようにしている
    const auto currentPointIndex = (uniforms.pointCloudCurrentIndex + vertexID) % uniforms.maxPoints;
    const auto texCoord = gridPoint / uniforms.cameraResolution;
    // Sample the depth map to get the depth value
    const auto depth = depthTexture.sample(colorSampler, texCoord).r;
    //const auto depth = 1.0 - depthTexture.sample(colorSampler, texCoord).r;
    // With a 2D point plus depth, we can now get its 3D position
    const auto position = worldPoint(gridPoint, depth, uniforms.cameraIntrinsicsInversed, uniforms.localToWorld);
    
    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
    const auto ycbcr = float4(capturedImageTextureY.sample(colorSampler, texCoord).r, capturedImageTextureCbCr.sample(colorSampler, texCoord.xy).rg, 1);
    const auto sampledColor = (yCbCrToRGB * ycbcr).rgb;
    // Sample the confidence map to get the confidence value
    const auto confidence = confidenceTexture.sample(colorSampler, texCoord).r;
    
    // Write the data to the buffer
    particleUniforms[currentPointIndex].position = position.xyz;
    particleUniforms[currentPointIndex].color = sampledColor;
    particleUniforms[currentPointIndex].confidence = confidence;
}

//depth計算
vertex void depth(uint id [[vertex_id]],
                  constant PointCloudUniforms &uniforms [[buffer(0)]],
                  constant float2 *gridPoints [[buffer(1)]],
                  device DepthUniforms *depthUniforms [[buffer(2)]],
                  texture2d<float, access::sample> depthTexture [[texture(0)]]) {
    
    const auto gridPoint = gridPoints[id];
    const auto currentPointIndex = (uniforms.pointCloudCurrentIndex + id) % uniforms.maxPoints;
    const auto texCoord = gridPoint / uniforms.cameraResolution;
    const auto depth = depthTexture.sample(colorSampler, texCoord).r;
    const auto position = worldPoint(gridPoint, depth, uniforms.cameraIntrinsicsInversed, uniforms.localToWorld);
    float4 projectedPosition = uniforms.viewProjectionMatrix * position;
    projectedPosition /= projectedPosition.w;
    
    depthUniforms[currentPointIndex].position = projectedPosition.xyz;
}


//// Camera's RGB vertex shader outputs
//struct RGBVertexOut {
//    float4 position [[position]];
//    float2 texCoord;
//};

//カメラから取得した画像情報用
//vertex RGBVertexOut rgbVertex(uint vertexID [[vertex_id]],
//                              constant RGBUniforms &uniforms [[buffer(0)]]) {
//    const float3 texCoord = float3(viewTexCoords[vertexID], 1) * uniforms.viewToCamera;
//
//    RGBVertexOut out;
//    out.position = float4(viewVertices[vertexID], 0, 1);
//    out.texCoord = texCoord.xy;
//
//    return out;
//}
//
//fragment float4 rgbFragment(RGBVertexOut in [[stage_in]],
//                            constant RGBUniforms &uniforms [[buffer(0)]],
//                            texture2d<float, access::sample> capturedImageTextureY [[texture(kTextureY)]],
//                            texture2d<float, access::sample> capturedImageTextureCbCr [[texture(kTextureCbCr)]]) {
//
//    const float2 offset = (in.texCoord - 0.5) * float2(1, 1 / uniforms.viewRatio) * 2;
//    const float visibility = saturate(uniforms.radius * uniforms.radius - length_squared(offset));
//    const float4 ycbcr = float4(capturedImageTextureY.sample(colorSampler, in.texCoord.xy).r, capturedImageTextureCbCr.sample(colorSampler, in.texCoord.xy).rg, 1);
//
//    // convert and save the color back to the buffer
//    const float3 sampledColor = (yCbCrToRGB * ycbcr).rgb;
//    return float4(sampledColor, 1) * visibility;
//}


// Particle vertex shader outputs and fragment shader inputs
struct ParticleVertexOut {
    float4 position [[position]]; //特徴点の３次元座標
    float pointSize [[point_size]]; //特徴点の大きさ
    float4 color; //特徴点の色情報
};
struct ParticleFragmentOut {
    float depth [[depth(any)]]; //深度情報
    float4 color; //色情報
};

//取得した特徴点用
vertex ParticleVertexOut particleVertex(uint vertexID [[vertex_id]],
                                        constant PointCloudUniforms &uniforms [[buffer(kPointCloudUniforms)]],
                                        constant ParticleUniforms *particleUniforms [[buffer(kParticleUniforms)]]) {
    
    // get point data
    const auto particleData = particleUniforms[vertexID];
    const auto position = particleData.position;
    const auto confidence = particleData.confidence;
    const auto sampledColor = particleData.color;
    const auto visibility = confidence >= uniforms.confidenceThreshold;
    
    // animate and project the point
    float4 projectedPosition = uniforms.viewProjectionMatrix * float4(position, 1.0);

    //const float pointSize = max(uniforms.particleSize / max(1.0, projectedPosition.z), 2.0);
    //const float pointSize = 20.0; // ADDED
    const float pointSize = uniforms.particleSize;
  
    projectedPosition /= projectedPosition.w;
    
    // prepare for output
    ParticleVertexOut out;
    out.position = projectedPosition;
    out.pointSize = pointSize;
    out.color = float4(sampledColor, visibility);
    
    return out;
}

fragment ParticleFragmentOut particleFragment(ParticleVertexOut in [[stage_in]],
                                 const float2 coords [[point_coord]]) {
    // we draw within a circle
    //特徴点の形を四角形から円形にしている
    const float distSquared = length_squared(coords - float2(0.5));
    if (in.color.a == 0 || distSquared > 0.25) {
        discard_fragment(); //当該のピクセルを放棄
    }

    ParticleFragmentOut out;

    // scale depth values to a range compatible
    // with depth buffer rendered by SceneKit
    out.depth = 1.0 - in.position.z;
    out.color = in.color;

    return out;
}

///////////
vertex ParticleVertexOut particleVertex2(uint vertexID [[vertex_id]],
                                         constant PointCloudUniforms &uniforms [[buffer(kPointCloudUniforms)]],
                                        constant ParticleUniforms *particleUniforms [[buffer(kParticleUniforms)]]) {
    
    // get point data
    const auto particleData = particleUniforms[vertexID];
    const auto position = particleData.position;
    //const auto confidence = particleData.confidence;
    const auto sampledColor = particleData.color;
    
    // animate and project the point
    float4 projectedPosition = uniforms.viewProjectionMatrix * float4(position, 1.0);

    //const float pointSize = max(uniforms.particleSize / max(1.0, projectedPosition.z), 2.0);
    //const float pointSize = 20.0; // ADDED
    //const float pointSize = uniforms.particleSize;
  
    projectedPosition /= projectedPosition.w;
    
    // prepare for output
    ParticleVertexOut out;
    out.position = projectedPosition; //float4(position,1.0);
    out.pointSize = 10.0;
    out.color = float4(sampledColor, 1.0);
    
    return out;
}

fragment ParticleFragmentOut particleFragment2(ParticleVertexOut in [[stage_in]],
                                 const float2 coords [[point_coord]]) {
    // we draw within a circle
    //特徴点の形を四角形から円形にしている
    const float distSquared = length_squared(coords - float2(0.5));
    if (in.color.a == 0 || distSquared > 0.25) {
        discard_fragment(); //当該のピクセルを放棄
    }

    ParticleFragmentOut out;

    // scale depth values to a range compatible
    // with depth buffer rendered by SceneKit
    out.depth = 1.0 - in.position.z;
    out.color = in.color;

    return out;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//load用
struct Vertex {
    float4 position [[position]];
    float pointSize[[point_size]];
    float4 color;
};

vertex Vertex vertex_func(constant PointCloudUniforms &uniforms [[buffer(kPointCloudUniforms)]],
                          constant float4 *positions [[buffer(1)]],
                          constant float4 *colors [[buffer(2)]],
                          uint vid [[vertex_id]]) {

    float4 projectedPosition = uniforms.viewProjectionMatrix * uniforms.rotate * positions[vid];
    //float4 projectedPosition = positions[vid];
    
    //const auto currentPointIndex = (uniforms.pointCloudCurrentIndex + vid) % uniforms.maxPoints;

    projectedPosition /= projectedPosition.w;
    //projectedPosition.y = projectedPosition.y - 0.3;
    //projectedPosition.z = projectedPosition.z + move_y;
    
    //上下左右の移動制御
    const auto pan_move = uniforms.pan_move;
    projectedPosition.x = projectedPosition.x + pan_move.x;
    projectedPosition.y = projectedPosition.y - pan_move.y;
    
    //projectedPosition.x = projectedPosition.x * uniforms.scale;
    //projectedPosition.y = projectedPosition.y * uniforms.scale;
    //projectedPosition.z = projectedPosition.z * uniforms.scale;
    
//    positions[currentPointIndex].x = projectedPosition.x;
//    positions[currentPointIndex].y = projectedPosition.y;

    //return vertices[vid];
    Vertex out;
    out.position = projectedPosition;
    out.pointSize = uniforms.particleSize; //10.0;
    out.color = colors[vid];
    return out;
}

//vertex Vertex vertex_func(constant float4 *positions [[buffer(1)]],
//                          constant float4 *colors [[buffer(2)]],
//                          uint vid [[vertex_id]]) {
//
//    //return vertices[vid];
//    Vertex out;
//    out.position = positions[vid];
//    out.pointSize = 10.0;
//    out.color = colors[vid];
//    return out;
//}

//fragment float4 fragment_func(Vertex vert [[stage_in]]) {
//    //float4 color = float4(vert.color.x, vert.color.y, vert.color.z, 1);
//
////    float3 inColor = float3(vert.color.x, vert.color.y, vert.color.z);
////    half gray = dot(kRec709Luma, inColor);
////    float4 outColor = float4(gray, gray, gray, 1);
////    return outColor;
//    return vert.color;
//    //return float4(1,0,0,1);
//}

fragment ParticleFragmentOut fragment_func(Vertex vert [[stage_in]], const float2 coords [[point_coord]]) {
    // we draw within a circle
    //特徴点の形を四角形から円形にしている
    const float distSquared = length_squared(coords - float2(0.5));
    if (vert.color.a == 0 || distSquared > 0.25) {
        discard_fragment(); //当該のピクセルを放棄
    }

    ParticleFragmentOut out;

    // scale depth values to a range compatible
    // with depth buffer rendered by SceneKit
    //out.depth = 1.0 - vert.position.z;
    out.depth = 1.5 + vert.position.z;
    out.color = vert.color;

    return out;
}


/////////////////////////////////////////////////////////////
//
struct Vertex2 {
    float4 position [[position]];
    float pointSize [[point_size]];
    float4 color;
};

struct RenderParams {
    float4x4 projectionMatrix;
    float3 eyePosition;
};

vertex Vertex2 vertex_func2(//const device RenderParams &params [[buffer(0)]],
                            constant float4 *positions [[buffer(1)]],
                            constant float4 *colors [[buffer(2)]],
                            uint vid [[vertex_id]]) {
    
    Vertex2 out;
    //return vertices[vid];
    //const auto VertexData = vertices[vid];
    const auto position = positions[vid];
    //out.position = params.projectionMatrix * position;
    
    const auto color = colors[vid];

    out.position = position;
    out.pointSize = 10.0;
    out.color = color;
    return out;
}

fragment float4 fragment_func2(Vertex2 in [[stage_in]],
                               const float2 coords [[point_coord]]) {
    
    const float distSquared = length_squared(coords - float2(0.5));
    if (in.color.a == 0 || distSquared > 0.25) {
        discard_fragment(); //当該のピクセルを放棄
    }
    
    return in.color;
}


