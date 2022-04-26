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
import SVProgressHUD

class CheckDataViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: SCNView!
    let scene = SCNScene()
    
    let results = try! Realm().objects(Data_parameta.self)
    private var models: Data_parameta!
    private var picCount: Int!
    private var imageArray = [UIImage]()
    private var texImage: UIImage!
    private var calcuMatrix: [float4x4] = []
    private var depth: [depthPosition] = []
    
    var anchors: [ARMeshAnchor] = []
    var calculateParameta: calculateParameta!
    private var checkRenderer: CheckRenderer!
    private let tex_node = SCNNode()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SVProgressHUD.show()
        SVProgressHUD.show(withStatus: "Loading･･･")
        
        sceneView.delegate = self
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        sceneView.scene?.rootNode.addChildNode(LightNode())
        
        models = results[0]
        picCount = models.pic.count
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        for i in 0..<picCount {
            let uiimage = UIImage(data: models.pic[i].pic_data!)
            imageArray.append(uiimage!)
        }
        let num = 3.0
        texImage = TextureImage(W: (2880 / num) * CGFloat(calculateParameta.yoko), H: (3840 / num) * CGFloat(calculateParameta.tate), array: imageArray, yoko: Float(calculateParameta.yoko), num: num).makeTexture()
        
        make_calcuParameta()
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10), execute: { [self] in
            makeTexture()
            
        })
    }
    
    func makeTexture() {
        var flag = 0
        print("calcu開始")
        
        self.checkRenderer = CheckRenderer(anchor: anchors, calcuUniforms: calcuMatrix, depth: depth, calculateParameta: calculateParameta, texImage: texImage)
        self.checkRenderer.drawRectResized(size: self.sceneView.bounds.size)
            
        for i in 0..<anchors.count {
            print("\(flag)回目")
            tex_node.addChildNode(self.checkRenderer.calcu5(num: i))
            flag += 1
            
            if flag == anchors.count {
                print("calcu完了")
                sceneView.scene?.rootNode.addChildNode(tex_node)
                SVProgressHUD.dismiss()
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

extension CheckDataViewController {
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
        guard let presentationController = presentationController else {
            return
        }
        presentationController.delegate?.presentationControllerDidDismiss?(presentationController)
    }
}
