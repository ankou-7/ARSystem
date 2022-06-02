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
    
    //let results = try! Realm().objects(Data_parameta.self)
    //private var models = try! Realm().objects(Navityu.self)
    var picCount: Int!
    private var imageArray = [UIImage]()
    private var texImage: UIImage!
    private var calcuMatrix: [float4x4] = []
    private var depth: [depthPosition] = []
    
    var anchors: [ARMeshAnchor] = []
    var calculateParameta: calculateParameta!
    private var checkRenderer: CheckRenderer!
    private let tex_node = SCNNode()
    
    var url: URL!
    var recording_count: Int!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SVProgressHUD.show()
        SVProgressHUD.show(withStatus: "Loading･･･")
        
        sceneView.delegate = self
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        sceneView.scene?.rootNode.addChildNode(LightNode())
        
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        for i in 0..<picCount {
            let per_picPath = url.appendingPathComponent("保存前/\(recording_count!)/pic\(i).data")
            let uiimage = UIImage(data: try! Data(contentsOf: per_picPath))
            imageArray.append(uiimage!)
        }
        
        let num = 2.0

        let picPath = url.appendingPathComponent("保存前/\(recording_count!)/pic0.data")
        let imageWidth = UIImage(data: try! Data(contentsOf: picPath))!.size.width
        let imageHeight = UIImage(data: try! Data(contentsOf: picPath))!.size.height
        texImage = TextureImage(W: (imageWidth / num) * CGFloat(calculateParameta.yoko),
                                H: (imageHeight / num) * CGFloat(calculateParameta.tate),
                                array: imageArray,
                                yoko: Float(calculateParameta.yoko), num: num).makeTexture()
        
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
    
    
    @IBAction func tapped_snapshot(_ sender: UIButton) {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let archivePath = url.appendingPathComponent("モデル.jpg")
            let imageData = sceneView.snapshot().jpegData(compressionQuality: 1.0)
            do {
                try imageData!.write(to: archivePath)
            } catch {
                print("Failed to save the image:", error)
            }
        }
    }
    
    func make_calcuParameta() {
        let decoder = JSONDecoder()
        
        for i in 0..<picCount {
            let jsonPath = url.appendingPathComponent("保存前/\(recording_count!)/json\(i).data")
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
            
            let depthPath = url.appendingPathComponent("保存前/\(recording_count!)/depth\(i).data")
            let depth_array = try? decoder.decode([depthPosition].self, from: try! Data(contentsOf: depthPath))
            depth.append(contentsOf: depth_array!)
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
