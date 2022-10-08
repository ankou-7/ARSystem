//
//  RealtimePointCloudController.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/10/19.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift

class RealtimePointCloudController: UIViewController, ARSCNViewDelegate, ARSessionDelegate,  UIPopoverPresentationControllerDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    let scene = SCNScene()
    
    private var pointCloudRenderer: Renderer!
    var pointCloud_flag = false
    let configuration = ARWorldTrackingConfiguration()
    var timer: Timer!
    
    let results = try! Realm().objects(Navi_SectionTitle.self)
    
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    var model_name1_num = Int()
    var model_name_1: String!
    
    var points1: [PointCloudVertex]!
    var points: [PointCloudVertex]!
    var pre_count: Int = 0
    
    var diff_voxcel_points: [PointCloudVertex] = []
    var diff_points: [PointCloudVertex]!
    
    var voxel_size: Float = 5.0
    var zure: Float = 0.005 //ボクセル間の違いをわかりやすくするためのずらす範囲
    var in_voxel_count: Int = 0
    var remove_voxel_num: Int = 3
    
    var x_min: Float = 0.0
    var x_max: Float = 0.0
    var y_min: Float = 0.0
    var y_max: Float = 0.0
    var z_min: Float = 0.0
    var z_max: Float = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self //delegateのセット
        sceneView.session.delegate = self
        sceneView.scene = scene
        sceneView.debugOptions = [.showWorldOrigin, .showFeaturePoints]
        
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        //AR使用のための設定
        configuration.environmentTexturing = .none
        configuration.frameSemantics = .smoothedSceneDepth
        configuration.planeDetection = [.horizontal, .vertical] //平面検出の有効化
        sceneView.session.run(configuration)
        
        self.pointCloudRenderer = Renderer(
            session: self.sceneView.session,
            metalDevice: self.sceneView.device!,
            sceneView: self.sceneView)
        self.pointCloudRenderer.drawRectResized(size: self.sceneView.bounds.size)
        
        //pointCloudRenderer.maxPoints = 1000
        
        model_name_1 = results[section_num].cells[cell_num].models[model_name1_num].modelname
        points1 = read_points(name: model_name_1)
        (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: points1)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func tap_ReOrigine(_ sender: UIButton) {
        //let worlddata = results[self.section_num].cells[self.cell_num].models[self.model_name1_num].worlddata
        //WoeldMap復元
//        if let worldMap = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: worlddata!) {
//            configuration.planeDetection = [.horizontal, .vertical] //平面検出の有効化
//            configuration.frameSemantics = .smoothedSceneDepth
//            configuration.initialWorldMap = worldMap //保存したWorldMapで再開する
//            self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
//
//        }
    }
    
    @IBAction func tap_start_p(_ sender: UIButton) {
        pointCloud_flag.toggle()
//        if pointCloud_flag == true {
//            diff()
//        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        if pointCloud_flag == true {
            pointCloudRenderer.draw()
        }
    }
    
    func diff() {
        (pre_count, points) = pointCloudRenderer.realtime_vertice(pre_count: pre_count)
        
//        (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: points)
        let new_points2 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points)
        diff_voxcel_grid(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points1: points1, points2: new_points2)
        diff()
    }
    
    @objc func update() {
        if pointCloud_flag == true {
            (pre_count, points) = pointCloudRenderer.realtime_vertice(pre_count: pre_count)

            let new_points2 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points)
            diff_voxcel_grid(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points1: new_points2, points2: points1)
        }
    }
    
    //MARK: -差分化処理部分
    
    //点群のx,y,zにおける最大・最小を調べる
    func xyz_min_max(points: [PointCloudVertex]) -> (Float,Float,Float,Float,Float,Float) {
        var x_max: Float = -100.0, x_min: Float = 100.0
        var y_max: Float = -100.0, y_min: Float = 100.0
        var z_max: Float = -100.0, z_min: Float = 100.0
        
        for p in points {
            if p.x > x_max {
                x_max = p.x
            }
            if p.y > y_max {
                y_max = p.y
            }
            if p.z > z_max {
                z_max = p.z
            }
            if p.x < x_min {
                x_min = p.x
            }
            if p.y < y_min {
                y_min = p.y
            }
            if p.z < z_min {
                z_min = p.z
            }
        }
        
        return (x_min, x_max, y_min, y_max, z_min, z_max)
    }
    
    //バウンディングボックス外の点を削除
    func remove_points(x_min: Float, x_max: Float, y_min: Float, y_max: Float, z_min: Float, z_max: Float, points: [PointCloudVertex]) -> [PointCloudVertex]{
        var new_points: [PointCloudVertex] = []
        for p in points {
            if (x_min <= p.x && x_max >= p.x && y_min <= p.y && y_max >= p.y && z_min <= p.z && z_max >= p.z) {
                new_points.append(p)
            }
        }
        return new_points
    }
    
    //点群をボクセル化し差分処理
    func diff_voxcel_grid(x_min: Float, x_max: Float, y_min: Float, y_max: Float, z_min: Float, z_max: Float, points1: [PointCloudVertex], points2: [PointCloudVertex]) {
        let size: Float = voxel_size / 100
        print(size)
        let x_count = ceil(abs(x_max - x_min) / size)
        let y_count = ceil(abs(y_max - y_min) / size)
        let z_count = ceil(abs(z_max - z_min) / size)
        print("x_count, y_count, z_count = \(x_count), \(y_count), \(z_count)")
        print("voxcel_count : \(x_count * y_count * z_count)")
        
        var xyz_voxcel_points1: [[[[PointCloudVertex]]]] = []
        var xyz_voxcel_points2: [[[[PointCloudVertex]]]] = []
        
        for i in 0..<Int(x_count) {
            xyz_voxcel_points1.append([])
            xyz_voxcel_points2.append([])
            for j in 0..<Int(y_count) {
                xyz_voxcel_points1[i].append([])
                xyz_voxcel_points2[i].append([])
                for _ in 0..<Int(z_count) {
                    xyz_voxcel_points1[i][j].append([])
                    xyz_voxcel_points2[i][j].append([])
                }
            }
        }
        

        for p in points1 {
            var num = 0
            var num_y = 0
            var num_z = 0
            
            if p.x == x_min {
                num = 0
            } else if p.x == x_max {
                num = Int(x_count - 1)
            } else {
                num = Int(floor((p.x - x_min) / size))
            }
            
            if p.y == y_min {
                num_y = 0
            } else if p.y == y_max {
                num_y = Int(y_count - 1)
            } else {
                num_y = Int(floor((p.y - y_min) / size))
            }
            
            if p.z == z_min {
                num_z = 0
            } else if p.z == z_max {
                num_z = Int(z_count - 1)
            } else {
                num_z = Int(floor((p.z - z_min) / size))
            }
            
            xyz_voxcel_points1[num][num_y][num_z].append(p)
        }
        
        for p in points2 {
            var num = 0
            var num_y = 0
            var num_z = 0
            
            if p.x == x_min {
                num = 0
            } else if p.x == x_max {
                num = Int(x_count - 1)
            } else {
                num = Int(floor((p.x - x_min) / size))
            }
            
            if p.y == y_min {
                num_y = 0
            } else if p.y == y_max {
                num_y = Int(y_count - 1)
            } else {
                num_y = Int(floor((p.y - y_min) / size))
            }
            
            if p.z == z_min {
                num_z = 0
            } else if p.z == z_max {
                num_z = Int(z_count - 1)
            } else {
                num_z = Int(floor((p.z - z_min) / size))
            }
            
            xyz_voxcel_points2[num][num_y][num_z].append(p)
        }
        
        for x in 1...Int(x_count) {
            for y in 1...Int(y_count) {
                for z in 1...Int(z_count) {
                    if (xyz_voxcel_points1[x-1][y-1][z-1].count > in_voxel_count && xyz_voxcel_points2[x-1][y-1][z-1].count == 0) {
                        diff_voxcel_points.append(PointCloudVertex(x: (x_min+(size*Float(x-1)) + x_min+(size*Float(x)))/2,
                                                                   y: (y_min+(size*Float(y-1)) + y_min+(size*Float(y)))/2,
                                                                   z: (z_min+(size*Float(z-1)) + z_min+(size*Float(z)))/2,
                                                                   r: 0, g: 0, b: 255))
                    }
                }
            }
        }
        
//        for x in 1...Int(x_count) {
//            for y in 1...Int(y_count) {
//                for z in 1...Int(z_count) {
//                    if (xyz_voxcel_points1[x-1][y-1][z-1].count > in_voxel_count) {
//                        diff_voxcel_points.append(PointCloudVertex(x: (x_min+(size*Float(x-1)) + x_min+(size*Float(x)))/2,
//                                                                   y: (y_min+(size*Float(y-1)) + y_min+(size*Float(y)))/2,
//                                                                   z: (z_min+(size*Float(z-1)) + z_min+(size*Float(z)))/2,
//                                                                   r: 0, g: 0, b: 255))
//                    }
//                    if (xyz_voxcel_points2[x-1][y-1][z-1].count > in_voxel_count) {
//                        diff_voxcel_points.append(PointCloudVertex(x: (x_min+(size*Float(x-1)) + zure + x_min+(size*Float(x)))/2,
//                                                                   y: (y_min+(size*Float(y-1)) + zure + y_min+(size*Float(y)))/2,
//                                                                   z: (z_min+(size*Float(z-1)) + zure + z_min+(size*Float(z)))/2,
//                                                                   r: 255, g: 0, b: 0))
//                    }
//                }
//            }
//        }
    
        print(diff_voxcel_points.count)
        //print(diff_voxcel_points)
        print("voxcel_gridによる差分化完了")
        
        diff_points = diff_voxcel_points //remove_points(points: diff_voxcel_points)
        
//        let new_voxcel_points = remove_voxcel_points(points: diff_voxcel_points) //余分なvoxcelを削除
//        print(new_voxcel_points.count)
//        let (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: new_voxcel_points)
//        let new_points1 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points1)
//        let node = self.buildNode2(points: new_points1)
        
        let node = self.buildNode2(points: diff_points)
        node.name = "diff_point"
        self.scene.rootNode.addChildNode(node)
    }
    
    func read_points(name: String) -> [PointCloudVertex] {
        var points: [PointCloudVertex] = []
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            
            let data_model_name = documentDirectoryFileURL.appendingPathComponent("\(name).data")
            guard let data = try? Data(contentsOf: data_model_name) else {
                fatalError("ファイル読み込みエラー")
            }
            let decoder = JSONDecoder()
            guard let points_data = try? decoder.decode([PointCloudVertex].self, from: data) else {
                fatalError("JSON読み込みエラー")
            }
            
            for p in points_data {
                if (p.x == 0.0 && p.y == 0.0 && p.z == 0.0) {
                    continue
                }
                points.append(p)
            }
            
        }
        
        return points
    }
    
    public func buildNode2(points: [PointCloudVertex]) -> SCNNode {
        let vertexData = NSData(
            bytes: points,
            length: MemoryLayout<PointCloudVertex>.size * points.count
        )
        
        let positionSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.vertex,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        let colorSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.color,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: MemoryLayout<Float>.size * 3,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        
    //        let normalSource = SCNGeometrySource(
    //            data: normalsData as Data,
    //            semantic: SCNGeometrySource.Semantic.normal,
    //            vectorCount: count,
    //            usesFloatComponents: true,
    //            componentsPerVector: 3,
    //            bytesPerComponent: MemoryLayout<Float>.size,
    //            dataOffset: 0,
    //            dataStride: MemoryLayout<vector_float3>.size
    //        )
    //        //SCNGeometrySource(normals: normals)
        
        let element = SCNGeometryElement(
            data: nil,
            primitiveType: .point,
            primitiveCount: points.count,
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
