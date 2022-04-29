//
//  CheckDataController.swift
//  ARMeshNavigation
//
//  Created by yasue kouki on 2021/04/19.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift

class CheckDataController: UIViewController, ARSCNViewDelegate,  UIGestureRecognizerDelegate {
    
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    var current_model_num = Int() //現在表示しているモデルの番号を格納
    var database_model_num = 1 //読み込んだcellの中に格納されているモデル数

    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    
    var particleSizeSlider = UISlider()
    
    var ballnode: SCNNode! //ボールのノード
    var existball: SCNNode! //ボールノードが作成済みかどうか
    var save_flag = false
    var load_flag = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self //delegateのセット
        sceneView.scene = scene
        
        sceneView.allowsCameraControl = true //カメラ位置をタップでコントロール可能にする
        //sceneView.showsStatistics = true
        
        let width = view.frame.width
        let height = view.frame.height
        
        particleSizeSlider.minimumValue = 0.0
        particleSizeSlider.maximumValue = 20.0
        particleSizeSlider.isContinuous = true
        particleSizeSlider.value = 10
        particleSizeSlider.frame = CGRect(x: width * 0.1, y: height * 0.2, width: width * 0.5, height: height * 0.1)
        particleSizeSlider.addTarget(self, action: #selector(ValueChanged), for: .valueChanged)
        view.addSubview(particleSizeSlider)
        
//        let sphereCamera:SCNGeometry = SCNSphere(radius: 0.01)
//        sphereCamera.firstMaterial?.diffuse.contents = UIColor.green
//        let cameraNode = SCNNode(geometry: sphereCamera)
//        cameraNode.camera = SCNCamera()
//        cameraNode.position = SCNVector3(x: 0, y: 0, z: 1.5)
//        scene.rootNode.addChildNode(cameraNode)
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        let modelname = results[section_num].cells[cell_num].models[current_model_num].modelname
        self.database_model_num = results[section_num].cells[cell_num].models.count

        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            if results[section_num].cells[cell_num].models[current_model_num].exit_mesh == 1 {
                let mesh_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).scn")
                if let referenceNode = SCNReferenceNode(url: mesh_model_name) {
                    referenceNode.load()
                    referenceNode.name = "obj"
                    self.scene.rootNode.addChildNode(referenceNode)
                }
            }
            
            if results[section_num].cells[cell_num].models[current_model_num].exit_point == 1 {
                let txt_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).txt")
                guard let fileContents = try? String(contentsOf: txt_model_name) else {
                    fatalError("ファイル読み込みエラー")
                }
                let row = fileContents.components(separatedBy: "\n")
                
                let data_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).data")
                let data = try NSData(contentsOf: data_model_name)
                let node = self.buildNode2(vertexData: data!, count: Int(row[0])!)
                node.position = SCNVector3(x: 0, y: 0, z: 0)
                node.name = "load_txt_model"
                self.scene.rootNode.addChildNode(node)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    @objc func ValueChanged(_ sender: UISlider) {
        let value = sender.value
        print(value)
        //pointCloudRenderer.particleSize = value
    }
    
    
    
    public func buildNode2(vertexData: NSData, count: Int) -> SCNNode {
        
        let positionSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.vertex,
            vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        let colorSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.color,
            vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: MemoryLayout<Float>.size * 3,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        let element = SCNGeometryElement(
            data: nil,
            primitiveType: .point,
            primitiveCount: count,
            bytesPerIndex: MemoryLayout<Int>.size
        )

        // for bigger dots
        element.pointSize = 1
        element.minimumPointScreenSpaceRadius = 1
        element.maximumPointScreenSpaceRadius = 7

        let pointsGeometry = SCNGeometry(sources: [positionSource, colorSource], elements: [element])
        
        return SCNNode(geometry: pointsGeometry)
    }
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    
}
