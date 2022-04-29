//
//  DiffPointCloudController.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/10/18.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift

class Diff_PointCloud2Controller: UIViewController, ARSCNViewDelegate, UIPopoverPresentationControllerDelegate {
    
    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    var model_array: [Bool] = []
    var model_name1_num = Int()
    var model_name2_num = Int()
    
    let results = try! Realm().objects(Navi_SectionTitle.self)
    
    var model_name_1: String!
    var model_name_2: String!
    
    //使用点群格納
    var points1: [PointCloudVertex]!
    var points2: [PointCloudVertex]!
    var diff_voxcel_points: [PointCloudVertex] = []
    var diff_points: [PointCloudVertex]!
    var re_points: [PointCloudVertex]!
    var point_cloud_flag1 = false
    var point_cloud_flag2 = false
    var diff_point_cloud_flag = false
    var re_point_cloud_flag = false
    
    var diff_mode_num = 2
    
    var voxel_size: Float = 2.0
    var zure: Float = 0.005 //ボクセル間の違いをわかりやすくするためのずらす範囲
    var in_voxel_count: Int = 80
    var remove_voxel_num: Int = 3
    
    @IBOutlet weak var repointButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self //delegateのセット
        sceneView.scene = scene
        sceneView.allowsCameraControl = true //カメラ位置をタップでコントロール可能にする
        
        model_name_1 = results[section_num].cells[cell_num].models[model_name1_num].modelname
        model_name_2 = results[section_num].cells[cell_num].models[model_name2_num].modelname
        
        print(model_name_1!)
        print(model_name_2!)
        
        points1 = read_points(name: model_name_1)
        print(points1.count)

        points2 = read_points(name: model_name_2)
        print(points2.count)
        
        //カメラ設定
        let sphereCamera:SCNGeometry = SCNSphere(radius: 0.01)
        sphereCamera.firstMaterial?.diffuse.contents = UIColor.green
        let cameraNode = SCNNode(geometry: sphereCamera)
        cameraNode.camera = SCNCamera()
        cameraNode.opacity = 0
        //cameraNode.position = SCNVector3(x: 0, y: 0, z: 3.5)
        cameraNode.camera?.zNear = 0.0
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)
    }
    
    func read_points(name: String) -> [PointCloudVertex] {
        var points: [PointCloudVertex] = []
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
//            let mesh_model_name = documentDirectoryFileURL.appendingPathComponent("\(name).scn")
//            if let referenceNode = SCNReferenceNode(url: mesh_model_name) {
//                referenceNode.load()
//                referenceNode.name = "mesh"
//                referenceNode.opacity = 0.5
//                self.scene.rootNode.addChildNode(referenceNode)
//            }
            
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
    
    @IBAction func to_realtimepointcloudController(_ sender: UIButton) {
        let index = model_array.indices.filter{model_array[$0] == true}
        let storyboard = UIStoryboard(name: "Diff_PointCloud2", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "RealtimePointCloudController") as! RealtimePointCloudController
        vc.section_num = section_num
        vc.cell_num = cell_num
        vc.model_name1_num = index[0]
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func tap_point1(_ sender: UIButton) {
        point_cloud_flag1.toggle()
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "point1", recursively: false) {
            node.removeFromParentNode()
        }
        
        if point_cloud_flag1 == true {
            let node = self.buildNode2(points: points1)
            node.name = "point1"
            self.scene.rootNode.addChildNode(node)
        }
    }
    
    @IBAction func tap_point2(_ sender: UIButton) {
        point_cloud_flag2.toggle()
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "point2", recursively: false) {
            node.removeFromParentNode()
        }
        
        if point_cloud_flag2 == true {
            let node = self.buildNode2(points: points2)
            node.name = "point2"
            self.scene.rootNode.addChildNode(node)
        }
    }
    
    @IBAction func tap_diffpoint(_ sender: UIButton) {
        diff_point_cloud_flag.toggle()
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "diff_point", recursively: false) {
            node.removeFromParentNode()
        }
        
        if diff_point_cloud_flag == true {
            let node = self.buildNode2(points: diff_points)
            node.name = "diff_point"
            self.scene.rootNode.addChildNode(node)
        }
    }
    
    @IBAction func tap_repoint(_ sender: UIButton) {
        re_point_cloud_flag.toggle()
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "re_point", recursively: false) {
            node.removeFromParentNode()
        }
        
        if re_point_cloud_flag == true {
            let (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: diff_points)
            re_points = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points1)
            let node = self.buildNode2(points: re_points)
            node.name = "re_point"
            self.scene.rootNode.addChildNode(node)
        }
    }
    
    @IBAction func diff_start(_ sender: UIButton) {
        all_riset()
        diff_voxcel_points = []
        //差分化処理
        let start = Date()
        let (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: points1)
        
        let new_points2 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points2)
        
        diff_voxcel_grid(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points1: points1, points2: new_points2)
        
        let elapsed = Date().timeIntervalSince(start)
        print("差分化処理の実行時間：\(elapsed)")
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
        
        print("x : \(x_max), \(x_min)")
        print("y : \(y_max), \(y_min)")
        print("z : \(z_max), \(z_min)")
        
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
        
        if diff_mode_num == 1 {
            for x in 1...Int(x_count) {
                for y in 1...Int(y_count) {
                    for z in 1...Int(z_count) {
                        if (xyz_voxcel_points1[x-1][y-1][z-1].count > in_voxel_count) {
                            diff_voxcel_points.append(PointCloudVertex(x: (x_min+(size*Float(x-1)) + x_min+(size*Float(x)))/2,
                                                                       y: (y_min+(size*Float(y-1)) + y_min+(size*Float(y)))/2,
                                                                       z: (z_min+(size*Float(z-1)) + z_min+(size*Float(z)))/2,
                                                                       r: 0, g: 0, b: 255))
                        }
                        if (xyz_voxcel_points2[x-1][y-1][z-1].count > in_voxel_count) {
                            diff_voxcel_points.append(PointCloudVertex(x: (x_min+(size*Float(x-1)) + zure + x_min+(size*Float(x)))/2,
                                                                       y: (y_min+(size*Float(y-1)) + zure + y_min+(size*Float(y)))/2,
                                                                       z: (z_min+(size*Float(z-1)) + zure + z_min+(size*Float(z)))/2,
                                                                       r: 255, g: 0, b: 0))
                        }
                    }
                }
            }
        }
        else if diff_mode_num == 2 {
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
        }
    
        print(diff_voxcel_points.count)
        //print(diff_voxcel_points)
        print("voxcel_gridによる差分化完了")
        
        diff_points = remove_points(points: diff_voxcel_points)//diff_voxcel_points
        
//        let new_voxcel_points = remove_voxcel_points(points: diff_voxcel_points) //余分なvoxcelを削除
//        print(new_voxcel_points.count)
//        let (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: new_voxcel_points)
//        let new_points1 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points1)
//        let node = self.buildNode2(points: new_points1)
        
        let node = self.buildNode2(points: diff_points)
        node.name = "diff_point"
        diff_point_cloud_flag = true
        self.scene.rootNode.addChildNode(node)
    }
    
    //各点とvoxel_size距離離れた点の数を調べ，余分な点を削除
    func remove_points(points: [PointCloudVertex]) -> [PointCloudVertex]{
        var voxel_points: [PointCloudVertex] = []
        let num = remove_voxel_num
        
        var p_count = 0
        
        for p_out in points {
            p_count = 0
            for p_in in points {
                if abs(abs(p_out.x) - abs(p_in.x)) <= voxel_size / 100 && abs(abs(p_out.y) - abs(p_in.y)) <= voxel_size / 100 && abs(abs(p_out.z) - abs(p_in.z)) <= voxel_size / 100 {
                    p_count += 1
                }
                
                if p_count >= num {
                    voxel_points.append(p_out)
                    break
                }
            }
        }
        
        print(voxel_points.count)
        
        return voxel_points
    }
    
    //ボクセル化して差分をとった点群から適切なバウンディングボックスを推定する
    func remove_voxcel_points(points: [PointCloudVertex]) -> [PointCloudVertex]{
        var voxcel_points: [PointCloudVertex] = []
        var voxcel_points_x: [PointCloudVertex] = []
        var voxcel_points_z: [PointCloudVertex] = []
        
        var pre_voxcel_points = points
        //y
        while pre_voxcel_points.count > 0 {
            let py = pre_voxcel_points.indices.filter{pre_voxcel_points[$0].y == pre_voxcel_points[0].y}
            if py.count > 8 {
                for (i, index) in py.enumerated() {
                    voxcel_points.append(pre_voxcel_points[index - i])
                    pre_voxcel_points.remove(at: index - i)
                }
            } else {
                pre_voxcel_points.remove(at: 0)
            }
            //print(pre_voxcel_points.count)
        }
        
        //x
        while voxcel_points.count > 0 {
            let p = voxcel_points.indices.filter{voxcel_points[$0].x == voxcel_points[0].x}
            if p.count > 8 {
                for (i, index) in p.enumerated() {
                    voxcel_points_x.append(voxcel_points[index - i])
                    voxcel_points.remove(at: index - i)
                }
            } else {
                voxcel_points.remove(at: 0)
            }
            //print(voxcel_points.count)
        }
        
        //z
        while voxcel_points_x.count > 0 {
            let p = voxcel_points_x.indices.filter{voxcel_points_x[$0].z == voxcel_points_x[0].z}
            if p.count > 8 {
                for (i, index) in p.enumerated() {
                    voxcel_points_z.append(voxcel_points_x[index - i])
                    voxcel_points_x.remove(at: index - i)
                }
            } else {
                voxcel_points_x.remove(at: 0)
            }
            //print(voxcel_points_x.count)
        }
        
        return voxcel_points_z
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
    
    //MARK: -パラメータ設定用のメニュー呼び出し部分
    @IBAction func menu_button(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Diff_PointCloud2", bundle: nil)
        let contentVC = storyboard.instantiateViewController(withIdentifier: "SetParametorPopOver") as! SetParametorPopOver
        
        contentVC.modalPresentationStyle = .popover
        contentVC.preferredContentSize = CGSize(width: 300, height: 500)
        contentVC.voxel_size = voxel_size
        contentVC.diff_mode_num = diff_mode_num
        contentVC.in_voxel_count = in_voxel_count
        contentVC.remove_voxel_num = remove_voxel_num
        
        guard let popoverPresentationController = contentVC.popoverPresentationController else { return }
        
        popoverPresentationController.sourceView = view
        popoverPresentationController.sourceRect = sender.frame
        popoverPresentationController.permittedArrowDirections = .any
        popoverPresentationController.delegate = self
        
        contentVC.closure = { (voxel_size: Float) -> Void in
            self.voxel_size = voxel_size
        }
        contentVC.closure2 = { (diff_mode_num: Int) -> Void in
            self.diff_mode_num = diff_mode_num
        }
        contentVC.closure3 = { (in_voxel_count: Int) -> Void in
            self.in_voxel_count = in_voxel_count
        }
        contentVC.closure4 = { (remove_voxel_num: Int) -> Void in
            self.remove_voxel_num = remove_voxel_num
        }
        present(contentVC, animated: true, completion: nil)
    }
    
    func all_riset() {
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "point1", recursively: false) {
            node.removeFromParentNode()
            point_cloud_flag1 = false
        }
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "point2", recursively: false) {
            node.removeFromParentNode()
            point_cloud_flag2 = false
        }
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "diff_point", recursively: false) {
            node.removeFromParentNode()
            diff_point_cloud_flag = false
        }
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "re_point", recursively: false) {
            node.removeFromParentNode()
            re_point_cloud_flag = false
        }
    }
    
    @IBAction func all_riset_button(_ sender: UIButton) {
        all_riset()
    }
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
}
