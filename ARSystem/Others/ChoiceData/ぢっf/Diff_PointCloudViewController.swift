//
//  Diff_PointCloudViewController.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/08/14.
//

import UIKit
import SceneKit
import ARKit
import Accelerate
import Matft
import RealmSwift

class Diff_PointCloudViewController: UIViewController, ARSCNViewDelegate, UIPopoverPresentationControllerDelegate {
    
    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    
    @IBOutlet weak var imageview1: UIImageView!
    @IBOutlet weak var imageview2: UIImageView!
    @IBOutlet weak var imageview3: UIImageView!
    
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    var model_name1_num = Int()
    var model_name2_num = Int()
    
    var picture1_num = Int()
    var picture2_num = Int()
    
    var mode_number: Int = 1
    
    let results = try! Realm().objects(Navi_SectionTitle.self)
    
    var r_value:Float = 255
    var g_value:Float = 255
    var b_value:Float = 255
    
    var model_name_1: String!
    var model_name_2: String!
    
    //使用点群格納
    var points1: [PointCloudVertex]!
    var points2: [PointCloudVertex]!
    var regist_points: [PointCloudVertex]!
    
    var point_cloud_flag1 = false
    var point_cloud_flag2 = false
    var point_cloud_flag3 = false
    @IBOutlet weak var point3_button: UIButton!
    
    //特徴点マッチングにより取得した対応点を格納
    var pointsArray: Array<CGPoint>!
    var pointsArray2: Array<CGPoint>!
    
    var matrix_1: MfArray!
    var matrix_2: MfArray!
    
    let decoder = JSONDecoder()
    var json_data1: json_pointcloudUniforms!
    var json_data2: json_pointcloudUniforms!
    
    var depth_data1: [Float32] = []
    var depth_data2: [Float32] = []
    
    var cameraNode = SCNNode()
    
    var start: Date!
    
    let openCV = Matching_OpenCV()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self //delegateのセット
        sceneView.scene = scene
        sceneView.allowsCameraControl = true //カメラ位置をタップでコントロール可能にする
        
        print(sceneView.bounds)
        
        let sphereCamera:SCNGeometry = SCNSphere(radius: 0.01)
        sphereCamera.firstMaterial?.diffuse.contents = UIColor.green
        cameraNode = SCNNode(geometry: sphereCamera)
        cameraNode.camera = SCNCamera()
        cameraNode.opacity = 0
        //cameraNode.position = SCNVector3(x: 0, y: 0, z: 3.5)
        cameraNode.camera?.zNear = 0.0
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)
        
        model_name_1 = results[section_num].cells[cell_num].models[model_name1_num].modelname
        model_name_2 = results[section_num].cells[cell_num].models[model_name2_num].modelname
        
        print(model_name_1!)
        print(model_name_2!)
        
        points1 = read_points(name: model_name_1)
        print(points1.count)

        points2 = read_points(name: model_name_2)
        print(points2.count)

        make_matlab_points(points: points1, name: "points1")
        make_matlab_points(points: points2, name: "points2")

        //RGB画像 → 横：2880，縦：3840
        //depth画像 → 横：384，縦：512
        //depthMap → width:256, height:192
        
        //let imageWidth = 2682
        //let imageHeight = 3765
        
        //選択した特徴点マッチングのための画像表示
        imageview1.image = UIImage(data: results[section_num].cells[cell_num].models[model_name1_num].pic[picture1_num].pic_data!)
        imageview2.image = UIImage(data: results[section_num].cells[cell_num].models[model_name2_num].pic[picture2_num].pic_data!)
        
        json_data1 = try? decoder.decode(json_pointcloudUniforms.self, from:results[section_num].cells[cell_num].models[model_name1_num].json[picture1_num].json_data!)
        json_data2 = try? decoder.decode(json_pointcloudUniforms.self, from: results[section_num].cells[cell_num].models[model_name2_num].json[picture2_num].json_data!)
        
        point3_button.isHidden = true
        
        
//        depth_data1 = read_depth_data(name: "depth_\(results[section_num].cells[cell_num].models[model_name1_num].json[picture1_num].json_name)")
//        depth_data2 = read_depth_data(name: "depth_\(results[section_num].cells[cell_num].models[model_name2_num].json[picture2_num].json_name)")
//
//        print(depth_data1.count)
//        print(depth_data2.count)
//        print(depth_data1[0...10])
    }
    
    func read_depth_data(name: String) -> [Float32] {
        var depthArray: [Float32] = []
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            
            let data_model_name = documentDirectoryFileURL.appendingPathComponent("\(name).data")
            guard let data = try? Data(contentsOf: data_model_name) else {
                fatalError("ファイル読み込みエラー")
            }
            let decoder = JSONDecoder()
            guard let datas = try? decoder.decode([depthMap_data].self, from: data) else {
                fatalError("JSON読み込みエラー")
            }
            for i in 0...datas.count-1 {
                depthArray.append(datas[i].depth!)
            }
        }
        return depthArray
    }
    
    @IBAction func tap_use_depth(_ sender: UIButton) {
        let start1 = Date()
        let start_all = Date()
        
        imageview1.isHidden = true
        imageview2.isHidden = true

        let image1 = UIImage(data: results[section_num].cells[cell_num].models[model_name1_num].pic[picture1_num].pic_data!)
        let image2 = UIImage(data: results[section_num].cells[cell_num].models[model_name2_num].pic[picture2_num].pic_data!)

        //特徴点マッチングによる対応点探索
        openCV.detectPoints(image1, image2)
        imageview3.image = openCV.image()

        pointsArray = openCV.pointsArray() as? Array<CGPoint>
        pointsArray2 = openCV.pointsArray2() as? Array<CGPoint>
        print(pointsArray!)
        print(pointsArray2!)

        print("特徴マッチング完了")
        
        matrix_1 = depth_make_3d_points(json: json_data1!, depthArray: depth_data1, pointsArray: pointsArray, f_b: 0)
        matrix_2 = depth_make_3d_points(json: json_data2!, depthArray: depth_data2, pointsArray: pointsArray2, f_b: 1)
        
        let (R_matrix, t_matrix) = ICPMatching(matrix_1: matrix_2, matrix_2: matrix_1)
        let matrix_3 = Matft.matmul(R_matrix, matrix_1.transpose()).transpose() + t_matrix.transpose()
        make_3d_nodes3(matrix: matrix_3, f_b: 2)
        
        let elapsed1 = Date().timeIntervalSince(start1)
        print("画像での位置合わせの実行時間：\(elapsed1)")

        regist_points = regist(points: points1, R_matrix: R_matrix, t_matrix: t_matrix)
        make_matlab_points(points: regist_points, name: "depth_points3")
        DispatchQueue.main.async {
            self.point3_button.isHidden = false
        }
        
//        //差分化処理
//        let start2 = Date()
//        let (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: regist_points)
//
//        let new_points2 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points2)
//
//        diff_voxcel_grid(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points1: regist_points, points2: new_points2)
//
//        let elapsed2 = Date().timeIntervalSince(start2)
//        print("差分化処理の実行時間：\(elapsed2)")
        
        let elapsed_all = Date().timeIntervalSince(start_all)
        print("全体の実行時間：\(elapsed_all)")
    }
    
    @IBAction func start_button(_ sender: Any) {
        if mode_number != 4 {
            start = Date()
            
            imageview1.isHidden = true
            imageview2.isHidden = true

            let image1 = UIImage(data: results[section_num].cells[cell_num].models[model_name1_num].pic[picture1_num].pic_data!)
            let image2 = UIImage(data: results[section_num].cells[cell_num].models[model_name2_num].pic[picture2_num].pic_data!)

            //特徴点マッチングによる対応点探索
            openCV.detectPoints(image1, image2)
            imageview3.image = openCV.image()

            pointsArray = openCV.pointsArray() as? Array<CGPoint>
            pointsArray2 = openCV.pointsArray2() as? Array<CGPoint>
            print(pointsArray!)
            print(pointsArray2!)

            print("特徴マッチング完了")

            make_3dPoints(meshname: "\(model_name_1!).scn", json_data: json_data1!, pointsArray: pointsArray!, f_b: 0)
        }
        else {
            play_mode(f_b: 100, mode_number: mode_number)
        }
    }
    
    @IBAction func Menu_button(_ sender: UIButton) {
        print("modechange")
        let storyboard = UIStoryboard(name: "Diff_PointCloud", bundle: nil)
        let contentVC = storyboard.instantiateViewController(withIdentifier: "ChangeModePopOver") as! ChangeModePopOver
        
        contentVC.modalPresentationStyle = .popover
        contentVC.preferredContentSize = CGSize(width: 300, height: 400)
        //contentVC.menu_array = menu_array
        
        guard let popoverPresentationController = contentVC.popoverPresentationController else { return }
        
        popoverPresentationController.sourceView = view
        popoverPresentationController.sourceRect = sender.frame
        popoverPresentationController.permittedArrowDirections = .any
        popoverPresentationController.delegate = self
        
        contentVC.closure = { (mode_num: Int) -> Void in
            self.mode_number = mode_num
            print(mode_num)
        }
        present(contentVC, animated: true, completion: nil)
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
    
    func read_mesh(name: String) {
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            let mesh_model_name = documentDirectoryFileURL.appendingPathComponent("\(name).scn")
            if let referenceNode = SCNReferenceNode(url: mesh_model_name) {
                referenceNode.load()
                referenceNode.name = "mesh"
                referenceNode.opacity = 0.5
                self.scene.rootNode.addChildNode(referenceNode)
            }
        }
    }
    
    func make_matlab_points(points: [PointCloudVertex], name: String) {
        //deta = [1,2,3;4,5,6]
        var p_string = ""
        for (i,p) in points.enumerated() {
            if (p.x == 0.0 && p.y == 0.0 && p.z == 0.0) {
                continue
            }
            if i != points.count-1 {
                p_string += "\(p.x) \(p.y) \(p.z)\n"
            } else {
                p_string += "\(p.x) \(p.y) \(p.z)"
            }
        }
        
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
            let targetTextFilePath = documentDirectoryFileURL.appendingPathComponent("\(name).txt")
            do {
                try p_string.write(to: targetTextFilePath, atomically: true, encoding: String.Encoding.ascii)
                print("\(name).txt：保存完了")
            } catch {
                print("Failed to write PLY file", error)
            }
        }
    }
    
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
        let size: Float = 0.05
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
        
        print("階層化完了")
        //print(xyz_voxcel_points1[0...50])
        
        var diff_voxcel_points: [PointCloudVertex] = []
        for x in 1...Int(x_count) {
            //print(x)
            for y in 1...Int(y_count) {
                for z in 1...Int(z_count) {
                    if (xyz_voxcel_points1[x-1][y-1][z-1].count > 5) {//&& xyz_voxcel_points2[x-1][y-1][z-1].count == 0) {
                        diff_voxcel_points.append(PointCloudVertex(x: (x_min+(size*Float(x-1)) + x_min+(size*Float(x)))/2,
                                                                   y: (y_min+(size*Float(y-1)) + y_min+(size*Float(y)))/2,
                                                                   z: (z_min+(size*Float(z-1)) + z_min+(size*Float(z)))/2,
                                                                   r: 0, g: 0, b: 255))
                    }
                    if (xyz_voxcel_points2[x-1][y-1][z-1].count > 10) { //&& xyz_voxcel_points1[x-1][y-1][z-1].count == 0) {
                        diff_voxcel_points.append(PointCloudVertex(x: (x_min+(size*Float(x-1)) + 0.01 + x_min+(size*Float(x)))/2,
                                                                   y: (y_min+(size*Float(y-1)) + 0.01 + y_min+(size*Float(y)))/2,
                                                                   z: (z_min+(size*Float(z-1)) + 0.01 + z_min+(size*Float(z)))/2,
                                                                   r: 255, g: 0, b: 0))
                    }
                }
            }
        }
    
        print(diff_voxcel_points.count)
        print("voxcel_gridによる差分化完了")
        
        let node = self.buildNode2(points: diff_voxcel_points)
        
//        let new_voxcel_points = remove_voxcel_points(points: diff_voxcel_points) //余分なvoxcelを削除
//        print(new_voxcel_points.count)
//        let (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: new_voxcel_points)
//        let new_points1 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points1)
//        let node = self.buildNode2(points: new_points1)
        
        node.name = "point"
        self.scene.rootNode.addChildNode(node)
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
    
    func All_ICP(_ sender: UIButton) {
        print("All ICP実行")
        var matrix:MfArray!
        var matrix2:MfArray!
       
            
        matrix = Matft.arange(start: 0, to: points1.count*3, by: 1, shape: [points1.count, 3], mftype: .Float, mforder: .Row)
        matrix2 = Matft.arange(start: 0, to: points2.count*3, by: 1, shape: [points2.count, 3], mftype: .Float, mforder: .Row)
        
        for (i,p) in points1.enumerated() {
            matrix[i,0] = p.x
            matrix[i,1] = p.y
            matrix[i,2] = p.z
        }
        
        for (i,p) in points2.enumerated() {
            matrix2[i,0] = p.x
            matrix2[i,1] = p.y
            matrix2[i,2] = p.z
        }
        print("matrix化完了")
        
        let start2 = Date()
        let (R_matrix, t_matrix) = ICPMatching(matrix_1: matrix2, matrix_2: matrix)
        let elapsed2 = Date().timeIntervalSince(start2)
        print("実行時間：\(elapsed2)")
    }
    
    func make_3dPoints(meshname: String, json_data: json_pointcloudUniforms, pointsArray: Array<CGPoint>, f_b: Int) {
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "mesh", recursively: false) {
            node.removeFromParentNode()
        }
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            let mesh_model_name = documentDirectoryFileURL.appendingPathComponent(meshname)
            if let referenceNode = SCNReferenceNode(url: mesh_model_name) {
                referenceNode.load()
                referenceNode.name = "mesh"
                referenceNode.opacity = 0.5
                self.scene.rootNode.addChildNode(referenceNode)
            }
        }
        
        let cameraPosition = SCNVector3(json_data.cameraPosition.x,
                                        json_data.cameraPosition.y,
                                        json_data.cameraPosition.z)
        let cameraEulerAngles = SCNVector3(json_data.cameraEulerAngles.x,
                                           json_data.cameraEulerAngles.y,
                                           json_data.cameraEulerAngles.z)
        
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "camera", recursively: false) {
            
            let move = SCNAction.move(to: cameraPosition, duration: 0)
            let rotation = SCNAction.rotateTo(x: CGFloat(cameraEulerAngles.x), y: CGFloat(cameraEulerAngles.y), z: CGFloat(cameraEulerAngles.z), duration: 0)
            node.runAction(SCNAction.group([move, rotation]),
                           completionHandler: { [self] in
                            play_mode(f_b: f_b, mode_number: mode_number)
                           })
        }
    }
    
    func play_mode(f_b: Int, mode_number: Int) {
        if mode_number == 1 {
            if f_b == 0 {
                matrix_1 = make_Matlix(pointsArray: pointsArray) //対応点をmatrix化
                make_3d_nodes3(matrix: matrix_1, f_b: 0) //対応点のnodeを表示
                print("matrix_1: \(matrix_1!)")
                make_3dPoints(meshname: "\(model_name_2!).scn", json_data: json_data2!, pointsArray: pointsArray2, f_b: 1)
            } else if f_b == 1 {
                matrix_2 = make_Matlix(pointsArray: pointsArray2)
                make_3d_nodes3(matrix: matrix_2, f_b: 1)
                print("matrix_2: \(matrix_2!)")
                
                let (use_matrix_1, use_matrix_2) = ignor_point(matrix_1: matrix_1, matrix_2: matrix_2)
                print("use_matrix1 : \(use_matrix_1)")
                print("use_matrix2 : \(use_matrix_2)")
                
                let (R_matrix, t_matrix) = ICPMatching(matrix_1: use_matrix_2, matrix_2: use_matrix_1)
                
                let matrix_3 = Matft.matmul(R_matrix, matrix_1.transpose()).transpose() + t_matrix.transpose()
                make_3d_nodes3(matrix: matrix_3, f_b: 2)
                
                let elapsed = Date().timeIntervalSince(start)
                print("画像での位置合わせの実行時間：\(elapsed)")
            }
        }
        else if mode_number == 2 {
            if f_b == 0 {
                matrix_1 = make_Matlix(pointsArray: pointsArray) //対応点をmatrix化
                print("matrix_1: \(matrix_1!)")
                make_3dPoints(meshname: "\(model_name_2!).scn", json_data: json_data2!, pointsArray: pointsArray2, f_b: 1)
            } else if f_b == 1 {
                matrix_2 = make_Matlix(pointsArray: pointsArray2)
                print("matrix_2: \(matrix_2!)")
                
                let (use_matrix_1, use_matrix_2) = ignor_point(matrix_1: matrix_1, matrix_2: matrix_2)
                print("use_matrix1 : \(use_matrix_1)")
                print("use_matrix2 : \(use_matrix_2)")
                
                let (R_matrix, t_matrix) = ICPMatching(matrix_1: use_matrix_2, matrix_2: use_matrix_1)
                regist_points = regist(points: points1, R_matrix: R_matrix, t_matrix: t_matrix) //位置合わせした後の点群
                DispatchQueue.main.async {
                    self.point3_button.isHidden = false
                }
                
                make_matlab_points(points: regist_points, name: "points3")
                
                let elapsed = Date().timeIntervalSince(start)
                print("点群の位置合わせまでの実行時間：\(elapsed)")
            }
        }
        else if mode_number == 3 {
            if f_b == 0 {
                matrix_1 = make_Matlix(pointsArray: pointsArray) //対応点をmatrix化
                print("matrix_1: \(matrix_1!)")
                make_3dPoints(meshname: "\(model_name_2!).scn", json_data: json_data2!, pointsArray: pointsArray2, f_b: 1)
            } else if f_b == 1 {
                matrix_2 = make_Matlix(pointsArray: pointsArray2)
                print("matrix_2: \(matrix_2!)")
                
                let (use_matrix_1, use_matrix_2) = ignor_point(matrix_1: matrix_1, matrix_2: matrix_2)
                print("use_matrix1 : \(use_matrix_1)")
                print("use_matrix2 : \(use_matrix_2)")
                
                let (R_matrix, t_matrix) = ICPMatching(matrix_1: use_matrix_2, matrix_2: use_matrix_1)
                regist_points = regist(points: points1, R_matrix: R_matrix, t_matrix: t_matrix)
                DispatchQueue.main.async {
                    self.point3_button.isHidden = false
                }
                
                //差分化処理
                let start2 = Date()
                let (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: regist_points)
                
                let new_points2 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points2)
                
                diff_voxcel_grid(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points1: regist_points, points2: new_points2)
                
                let elapsed2 = Date().timeIntervalSince(start2)
                print("差分化処理の実行時間：\(elapsed2)")
                let elapsed = Date().timeIntervalSince(start)
                print("全体の実行時間：\(elapsed)")
            }
        }
        else if mode_number == 4 {
            //差分化処理
            let start2 = Date()
            let (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: points1)
            
            let new_points2 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points2)
            
            diff_voxcel_grid(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points1: points1, points2: new_points2)
            
            let elapsed2 = Date().timeIntervalSince(start2)
            print("差分化処理の実行時間：\(elapsed2)")
        }
    }
    
    func depth_make_3d_points(json: json_pointcloudUniforms, depthArray: [Float32], pointsArray: Array<CGPoint>, f_b: Int) -> MfArray {
        
        var vertice_data: [PointCloudVertex] = []
        let matrix = Matft.arange(start: 0, to: pointsArray.count*3, by: 1, shape: [pointsArray.count, 3], mftype: .Float, mforder: .Row)
        
        let resizeScale_x = CGFloat(184) / CGFloat(2880)
        let resizeScale_y = CGFloat(184) / CGFloat(3840)
        var new_points: [CGPoint] = []
        for p in pointsArray {
            let points = CGPoint(x: (p.x * resizeScale_x), y: 184 - (p.y * resizeScale_y))
            new_points.append(points)
        }
        //print(new_points)
        
        let IntrinsicsInversed = simd_float3x3(
            json.Intrinsics.x,
            json.Intrinsics.y,
            json.Intrinsics.z)
        
        let localToworld = simd_float4x4(json.ViewMatrix.x,
                                     json.ViewMatrix.y,
                                     json.ViewMatrix.z,
                                     json.ViewMatrix.w)
        
        let depthSize = 184
        let depthScreenScaleFactor = Float(self.sceneView.bounds.width * UIScreen.screens.first!.scale / CGFloat(depthSize))
        
        if f_b == 0 {
            r_value = 255; g_value = 0; b_value = 0
        } else if f_b == 1 {
            r_value = 0; g_value = 0; b_value = 255
        }
        
        for (i,p) in new_points.enumerated() {
            //depthArray.count = 33856（184 * 184）
            let depth = depthArray[Int(round(p.y) * CGFloat(depthSize) + round(p.x))]
            let x_px = Float(p.x) * depthScreenScaleFactor
            let y_px = Float(p.y) * depthScreenScaleFactor
            let localPoint = IntrinsicsInversed * simd_float3(x_px, y_px, 1) * depth
            let worldPoint = localToworld * simd_float4(localPoint, 1)
            
            matrix[i,0] = worldPoint.x
            matrix[i,1] = worldPoint.y
            matrix[i,2] = worldPoint.z
            
//            vertice_data.append(PointCloudVertex(x: worldPoint.x,
//                                                    y: worldPoint.y,
//                                                    z: worldPoint.z,
//                                                    r: r_value,
//                                                    g: g_value,
//                                                    b: b_value))
        }
        
        make_3d_nodes3(matrix: matrix, f_b: f_b)
        return matrix
        
        
//        for y in 0 ..< depthSize {
//            for x in 0 ..< depthSize {
//                // 頂点座標を作成（最終的に表示しないものも作る）
//                let depth = depthArray[y * depthSize + x]
//                if depth < 0 {
//                    continue
//                }
//                let x_px = Float(x) * depthScreenScaleFactor
//                let y_px = Float(y) * depthScreenScaleFactor
//                // 2Dの深度情報を3Dに変換
//                let localPoint = IntrinsicsInversed * simd_float3(x_px, y_px, 1) * depth
//                //ワールド座標に合わせてローカルから変換
//                let worldPoint = localToworld * simd_float4(localPoint, 1)
//                //worldPoint = worldPoint / worldPoint.w
//
//                vertice_data.append(PointCloudVertex(x: worldPoint.x,
//                                                        y: worldPoint.y,
//                                                        z: worldPoint.z,
//                                                        r: r_value,
//                                                        g: g_value,
//                                                        b: b_value))
//            }
//        }
//
//        let node = buildNode2(points: vertice_data)
//        self.scene.rootNode.addChildNode(node)
    }
    
    func make_Matlix(pointsArray: Array<CGPoint>) -> (MfArray) {
        let matrix = Matft.arange(start: 100, to: pointsArray.count*3 + 100, by: 1, shape: [pointsArray.count, 3], mftype: .Float, mforder: .Row)
        var count = -1
        for p in pointsArray {
            let points = CGPoint(x: p.x * 834 / 2682, y: p.y * 1194 / 3840)
            let hitResults = sceneView.hitTest(points, options: [:])
            
            if !hitResults.isEmpty {
                var point: SCNVector3!
                for j in 0..<hitResults.count {
                    if  (hitResults[j].node.name != nil) {
                        //print(hitResults[j].node.name!)
                        if hitResults[j].node.name! == "mesh" {
                            count += 1
                            point = hitResults[j].worldCoordinates
                            
                            matrix[count,0] = point.x
                            matrix[count,1] = point.y
                            matrix[count,2] = point.z
                            break
                        }
                    }
                }
            }
        }
        
        return matrix
    }
    
    func make_3d_nodes3(matrix: MfArray, f_b: Int){
        for (_,p) in matrix.enumerated() {
            let sphere_geo:SCNGeometry = SCNSphere(radius: 0.002)
            if f_b == 0 {
                sphere_geo.firstMaterial?.diffuse.contents = UIColor.red
            } else if f_b == 1 {
                sphere_geo.firstMaterial?.diffuse.contents = UIColor.blue
            } else {
                sphere_geo.firstMaterial?.diffuse.contents = UIColor.green
            }
            let sphere = SCNNode(geometry: sphere_geo)
            sphere.name = "sphere"
            sphere.position = SCNVector3((p[0].scalar as? Float)!, (p[1].scalar as? Float)!, (p[2].scalar as? Float)!)
            self.scene.rootNode.addChildNode(sphere)
        }
    }
    
    func regist(points: [PointCloudVertex], R_matrix: MfArray, t_matrix: MfArray) -> [PointCloudVertex]{
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "mesh", recursively: false) {
            node.removeFromParentNode()
        }
        
        var re_points: [PointCloudVertex] = []
        
        let R1: [Float] = [R_matrix[0][0].scalar as! Float, R_matrix[0][1].scalar as! Float, R_matrix[0][2].scalar as! Float]
        let R2: [Float] = [R_matrix[1][0].scalar as! Float, R_matrix[1][1].scalar as! Float, R_matrix[1][2].scalar as! Float]
        let R3: [Float] = [R_matrix[2][0].scalar as! Float, R_matrix[2][1].scalar as! Float, R_matrix[2][2].scalar as! Float]
        
        let tx = t_matrix[0].scalar as! Float
        let ty = t_matrix[1].scalar as! Float
        let tz = t_matrix[2].scalar as! Float
        
        for p in points {
            let x = R1[0]*p.x + R1[1]*p.y + R1[2]*p.z + tx
            let y = R2[0]*p.x + R2[1]*p.y + R2[2]*p.z + ty
            let z = R3[0]*p.x + R3[1]*p.y + R3[2]*p.z + tz
            re_points.append(PointCloudVertex(x: x, y: y, z: z, r: p.r, g: p.g, b: p.b))
        }
        print("Regist完了")
            
        return re_points
    }
    
    func ignor_point(matrix_1: MfArray, matrix_2: MfArray) -> (MfArray, MfArray){
        var count1 = 0
        var count2 = 0
        for (i,_) in matrix_1.enumerated() {
            if (matrix_1[i,0].scalar as? Float)! >= 10 {
                count1 += 1
            }
            if (matrix_2[i,0].scalar as? Float)! >= 10 {
                count2 += 1
            }
        }
        
        var ignorpoints = count1
        if count2 > count1 {
            ignorpoints = count2
        }
        
        let new_matrix_1 = Matft.arange(start: 0, to: (matrix_1.count-ignorpoints)*3, by: 1, shape: [matrix_1.count-ignorpoints, 3], mftype: .Float, mforder: .Row)
        let new_matrix_2 = Matft.arange(start: 0, to: (matrix_1.count-ignorpoints)*3, by: 1, shape: [matrix_1.count-ignorpoints, 3], mftype: .Float, mforder: .Row)
        
        var count = 0
        for (i,_) in new_matrix_1.enumerated() {
            if ((matrix_1[i,0].scalar as? Float)! >= 10) || ((matrix_2[i,0].scalar as? Float)! >= 10) {
                continue
            }
            
            new_matrix_1[count] = matrix_1[i]
            new_matrix_2[count] = matrix_2[i]
            count += 1
        }
        
        return (new_matrix_1, new_matrix_2)
    }
    
    func ICPMatching(matrix_1: MfArray, matrix_2: MfArray) -> (MfArray, MfArray){
        var preError: Float = 0 //一つ前のイタレーションのerror値
        var dError: Float = 1000 //エラー値の差分
        let EPS: Float = 0.0001 //収束判定値
        let maxIter = 100 //最大イテレーション数
        var count = 0 //ループカウンタ
        var R = MfArray([[1, 0, 0],
                         [0, 1, 0],
                         [0, 0, 1]], mftype: .Float)
        var t = MfArray([0, 0, 0], mftype: .Float)
        var new_matrix_2 = matrix_2
        //print(new_matrix_2)
        
        while (dError > EPS) {
            count=count+1;
            print("count : \(count)")

            var (index, error) = FindNearestPoint(matrix_1: matrix_1, matrix_2: new_matrix_2, num: count) //最近傍点探索
            let (R1,t1) = SVDMotionEstimation(matrix_1: matrix_1, matrix_2: new_matrix_2, index: index) //特異値分解による移動量推定
            //計算したRとtで点群とRとtの値を更新
            new_matrix_2 = Matft.matmul(R1, new_matrix_2.transpose()).transpose() + t1.transpose()
            //print(new_matrix_2)
            R = Matft.matmul(R1, R)
            //print(R)
            t = Matft.stats.sum(R1 * t, axis: 1) + t1
            //print(t)
            
            error = sqrt(error / Float(matrix_1.count))
            //10点：0.0173
            //20点：0.019
            //30点：0.016215699
            //50点：0.01655224
            //100点：0.048821755

            print("error : \(error)")
            dError = abs(preError - error) //エラーの改善量
            preError = error //一つ前のエラーの総和値を保存

            if count > maxIter {//収束しなかった
                print("Max Iteration")
                break
            }
        }
        
        print("ICP完了")
        print(count)
        print(R)
        print(t)
        
        return (R, t)
    }
    
    func FindNearestPoint(matrix_1: MfArray, matrix_2: MfArray, num: Int) -> ([Int], Float) {
        var index: [Int] = []
        var error: Float = 0.0
        
//        print(matrix_1)
//        print(matrix_2)
        
        if num == 1 {
            let dx = matrix_2 - matrix_1
            error = Matft.stats.sum(Matft.stats.sum(dx * dx, axis: 1), axis: 0).scalar as! Float
            for k in 0..<matrix_1.count {
                index.append(k)
            }
        } else {
            for k in 0..<matrix_1.count {
            
                let dx = matrix_2 - matrix_1[k]
                //print(dx * dx)
                //print(Matft.stats.sum(dx * dx, axis: 1))

                //let dist = Matft.math.sqrt(Matft.stats.sum(dx * dx, axis: 1))
                let dist = Matft.stats.sum(dx * dx, axis: 1)
                //print(dist)
                //print(Matft.stats.min(dist))


                var min: Float = 100.0
                var min_index: Int = 0
                for (i,p) in dist.enumerated() {
                    let scaler = (p.scalar as? Float)!
                    if min > scaler {
                        min = scaler
                        min_index = i
                    }
                }

                index.append(min_index)
                error += min
            }
        }
        
//        print(index)
//        print(error)
        
        return (index, error)
    }
    
    func SVDMotionEstimation(matrix_1: MfArray, matrix_2: MfArray, index: [Int]) -> (MfArray, MfArray) {
        var R: MfArray
        var t: MfArray
        
        //各点群の重心
        let mm = Matft.stats.mean(matrix_1.transpose(), axis: 1)
        //print("mm : \(mm)")
        
        let nearlest_matrix_2 = Matft.arange(start: 0, to: matrix_2.count*3, by: 1, shape: [matrix_2.count, 3], mftype: .Float, mforder: .Row)
        for (i,index) in index.enumerated() {
            nearlest_matrix_2[i] = matrix_2[index]
        }
        
        let ms = Matft.stats.mean(nearlest_matrix_2.transpose(), axis: 1)
        //print("ms : \(ms)")
        
        //各点群を重心中心の座標系に変換
        let Mshift_xyz = matrix_1 - mm //20×3
        let Sshift = nearlest_matrix_2 - ms //20×3
        
        let W = Matft.matmul(Sshift.transpose(), Mshift_xyz)//matrix_convolve(Sshift: Sshift, Mshift_xyz: Mshift_xyz)
        //print(W)
        
        do {
            let svd = try Matft.linalg.svd(W)
//            print(svd.v)
//            print(svd.s)
//            print(svd.rt.transpose())
            
            R = Matft.matmul(svd.v, svd.rt).transpose()//matrix_convolve(Sshift: svd.v.transpose(), Mshift_xyz: svd.rt).transpose()
//            print("R : \(R)")
            t = mm - Matft.stats.sum((R * ms), axis: 1)
//            print("t : \(t)")
        } catch {
            fatalError()
        }
        
        return (R, t)
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
    
    @IBAction func tap_point3(_ sender: UIButton) {
        point_cloud_flag3.toggle()
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "point3", recursively: false) {
            node.removeFromParentNode()
        }
        
        if point_cloud_flag3 == true {
            let node = self.buildNode2(points: regist_points)
            node.name = "point3"
            self.scene.rootNode.addChildNode(node)
        }
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
