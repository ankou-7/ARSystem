//
//  CheckDataViewController.swift
//  ARMesh
//
//  Created by 安江洸希 on 2022/03/01.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift

class CheckDataViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: SCNView!
    let scene = SCNScene()
    let results = try! Realm().objects(Data_parameta.self)
    
    var anchors: [ARMeshAnchor] = []
    var tex_image: UIImage!
    var calcuMatrix: [float4x4] = []
    var depth: [depthPosition] = []
    
    private var calculate: CheckRenderer!
    var texString: String = "calcu50" //calcu5:テクスチャ無しでも表示，calcu50:テクスチャ有りのみ表示
    
    var makeNavi = MakeNavigationController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        //sceneView.autoenablesDefaultLighting = true
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .ambient //.omni
        scene.rootNode.addChildNode(lightNode)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let results = try! Realm().objects(Data_parameta.self)
        for i in 0..<results[0].mesh_anchor.count {
            let mesh_data = results[0].mesh_anchor[i].mesh
            if let meshAnchor = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARMeshAnchor.self, from: mesh_data!) {
                anchors.append(meshAnchor)
            }
        }
        
        var uiimage_array = [UIImage]()
        for i in 0..<results[0].pic.count {
            let uiimage = UIImage(data: results[0].pic[i].pic_data!)
            uiimage_array.append(uiimage!)
        }
        
        let yoko: Float = 17.0
        let tate: Float = ceil(Float(results[0].pic.count)/yoko)
        let num: CGFloat = 3.0 //画像のサイズの縮尺率
        tex_image = ComposeUIImage(UIImageArray: uiimage_array, width: (2880 / num) * CGFloat(yoko), height: (3840 / num) * CGFloat(tate), yoko: yoko, num: num)
        
        print(results)
        
        makeTexture()
    }
    
    
//    @IBAction func finish_button(_ sender: UIButton) {
//        let storyboard = UIStoryboard(name: "AddDataCellChoice", bundle: nil)
//        let vc = storyboard.instantiateViewController(withIdentifier: "AddDataCellChoiceController") as! AddDataCellChoiceController
//        self.present(vc, animated: true, completion: nil)
//    }
//
//    @IBAction func restart_button(_ sender: UIButton) {
//        makeNavi.restart_flag = true
//        self.dismiss(animated: true, completion: nil)
//    }
    
    func makeTexture() {
        let count = results[0].pic.count
        let yoko: Float = 17.0
        let tate: Float = ceil(Float(count)/yoko)
        var flag = 0
        
        let tex_node = SCNNode()
        tex_node.name = "tex_node"
        
        DispatchQueue.global().sync {
            
            self.calculate = CheckRenderer(anchor: anchors, metalDevice: self.sceneView.device!, calcuUniforms: calcuMatrix, depth: depth, tate: Int(tate), yoko: Int(yoko), screenWidth: Int(sceneView.bounds.width), screenHeight: Int(sceneView.bounds.height), texString: texString, tex_image: tex_image)
            self.calculate.drawRectResized(size: self.sceneView.bounds.size)
            
            
            DispatchQueue.main.async { [self] in
                for i in 0..<anchors.count {
                    print("\(flag)回目")
                    tex_node.addChildNode(self.calculate.calcu5(num: i))
                    flag += 1
                    
                    if flag == anchors.count {
                        sceneView.scene?.rootNode.addChildNode(tex_node)
                        //load_anchor2()
                    }
                }
            }
        }
    }
    
    func build2(image: UIImage) -> SCNNode {
        let tex_node = SCNNode()
        tex_node.name = "tex_node"
        for i in 0..<anchors.count {
            let vertexData = results[0].mesh_anchor[i].vertices!
            let normalData = results[0].mesh_anchor[i].normals!
            let count = results[0].mesh_anchor[i].vertice_count
            
            let faces = (try? JSONDecoder().decode([Int32].self, from: results[0].mesh_anchor[i].faces))!
            let texcoords = (try? JSONDecoder().decode([SIMD2<Float>].self, from: results[0].mesh_anchor[i].texcoords))!
            
            let verticeSource = SCNGeometrySource(
                data: vertexData,
                semantic: SCNGeometrySource.Semantic.vertex,
                vectorCount: count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SIMD3<Float>>.size
            )
            let normalSource = SCNGeometrySource(
                data: normalData,
                semantic: SCNGeometrySource.Semantic.normal,
                vectorCount: count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: MemoryLayout<Float>.size * 3,
                dataStride: MemoryLayout<SIMD3<Float>>.size
            )
            let faceSource = SCNGeometryElement(indices: faces, primitiveType: .triangles)
            let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords)
            
            let nodeGeometry = SCNGeometry(sources: [verticeSource, normalSource, textureCoordinates], elements: [faceSource])
            nodeGeometry.firstMaterial?.diffuse.contents = image
            
            let node = SCNNode(geometry: nodeGeometry)
            //knownAnchors[anchors[i].identifier] = node
            node.name = "child_tex_node"
            tex_node.addChildNode(node)
        }
        return tex_node
    }
    
    func ComposeUIImage(UIImageArray : [UIImage], width: CGFloat, height : CGFloat, yoko: Float, num: CGFloat)->UIImage!{
        // 指定された画像の大きさのコンテキストを用意
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        
        var tate_count = -1
        for (i,image) in UIImageArray.enumerated() {
            if i % Int(yoko) == 0 {
                tate_count += 1
            }
            // コンテキストに画像を描画する
            image.draw(in: CGRect(x: CGFloat(i % Int(yoko)) * image.size.width/num, y: CGFloat(tate_count) * image.size.height/num, width: image.size.width/num, height: image.size.height/num))
        }
        // コンテキストからUIImageを作る
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
