//
//  Make3DModelViewController.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/07/05.
//

import UIKit
import SceneKit
import ARKit
import Accelerate
import Matft

class Make3DModelController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    
    var vertice_data: [PointCloudVertex] = []
    var json_data: json_pointcloudUniforms!
    var IntrinsicsInversed: simd_float3x3!
    var localToworld: simd_float4x4!
    var depthDataArray: [Float32] = []
    var pixelDataColor: [UInt8] = []
    var pixelDataColor2: [UInt8] = []
    var r_value:Float = 255
    var g_value:Float = 255
    var b_value:Float = 255
    
    //使用点群格納
    var points1: [PointCloudVertex]!
    var points2: [PointCloudVertex]!
    
    var pointsArray: Array<CGPoint>!
    var pointsArray2: Array<CGPoint>!
    
    var matrix_1: MfArray!
    var matrix_2: MfArray!
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageView2: UIImageView!
    @IBOutlet weak var imageView3: UIImageView!
    @IBOutlet weak var imageView4: UIImageView!
    @IBOutlet weak var imageView5: UIImageView!
    @IBOutlet weak var imageView6: UIImageView!
    var flag = true
    var ci_image: CIImage!
    
    var image1: UIImage!
    var image2: UIImage!
    
    let image_name1 = "try_70" //74
    let image_name2 = "try_94" //184
    
    var cameraNode = SCNNode()

    var regist_flag = false
    var point_cloud_flag1 = false
    var point_cloud_flag2 = false
    
    var first_flag = false //1つ目の視点から３D点群表示
    var icp_flag = false //
    var third_flag = false //パラメータ推定後の3D点群表示
    
    var finish_flag = false
    var start: Date!
    
    var regist_points: [PointCloudVertex] = []
    
    let openCV = Matching_OpenCV()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self //delegateのセット
        sceneView.scene = scene
        sceneView.allowsCameraControl = true //カメラ位置をタップでコントロール可能にする
        sceneView.debugOptions = .showWorldOrigin
        
        _ = Timer.scheduledTimer(timeInterval: 1/60, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        
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
        
        points1 = read_points(name: "NaviModel00-0")
        print(points1.count)
        
        points2 = read_points(name: "NaviModel00-1")
        print(points2.count)
        
//        make_matlab_points(points: points1, name: "points1")
//        make_matlab_points(points: points2, name: "points2")
        
        
//        let sphere_geo:SCNGeometry = SCNSphere(radius: 0.01)
//        sphere_geo.firstMaterial?.diffuse.contents = UIColor.red
//        let sphere = SCNNode(geometry: sphere_geo)
//        sphere.position = SCNVector3(x: -1.7605813, y: -1.0955766, z: 0.73825026)
//        scene.rootNode.addChildNode(sphere)
        
        
        //RGB画像 → 横：2880，縦：3840
        //depth画像 → 横：384，縦：512
        //depthMap → width:256, height:192
        
        let imageWidth = 2682
        let imageHeight = 3765
        
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            let file_name = documentDirectoryFileURL.appendingPathComponent("rgb_\(image_name1).jpeg")
            let image = UIImage(contentsOfFile: file_name.path)
            //let clipRect = CGRect(x: ((2880-((2*834*1920)/1194))/2), y: 0, width: ((2*834*1920)/1194), height: 3840)
            //let clipRect = CGRect(x: 1440 - (2682/2), y: 0, width: 2682, height: 3840)
            let clipRect = CGRect(x: 1440 - (imageWidth/2), y: 1920 - (imageHeight/2), width: imageWidth, height: imageHeight)
            let cripImageRef = image?.cgImage!.cropping(to: clipRect)
            image1 = UIImage(cgImage: cripImageRef!, scale: image!.scale, orientation: image!.imageOrientation)
            print(image1.size)

//            (pixelDataColor, ci_image) = read_pixel(colorImage: image1)
//            print(pixelDataColor.count)
            //image1 = UIImage(named: "rgb_try_16")
            imageView.image = image1
            //imageView3.image = UIImage(ciImage: ci_image.transformed(by: CGAffineTransform(scaleX: 1, y: -1)))
            imageView6.image = image1
            imageView6.alpha = 0.25
        }

        //imageView6.isHidden = true


        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            let file_name = documentDirectoryFileURL.appendingPathComponent("rgb_\(image_name2).jpeg")
            let image = UIImage(contentsOfFile: file_name.path)
            //let clipRect = CGRect(x: (1440-((834*1920)/1194)), y: 0, width: ((2*834*1920)/1194), height: 3840)
            let clipRect = CGRect(x: 1440 - (imageWidth/2), y: 1920 - (imageHeight/2), width: imageWidth, height: imageHeight)
            let cripImageRef = image?.cgImage!.cropping(to: clipRect)
            image2 = UIImage(cgImage: cripImageRef!, scale: image!.scale, orientation: image!.imageOrientation)

//            (pixelDataColor2, ci_image) = read_pixel(colorImage: image2)
            //image2 = UIImage(named: "rgb_try_1")
            imageView2.image = image2
            //imageView4.image = UIImage(ciImage: ci_image.transformed(by: CGAffineTransform(scaleX: 1, y: -1)))
        }
        
    }
    
    @IBAction func try_tap_location(_ sender: UIButton) {
//        let location = CGPoint(x: 500, y: 1194)
//        print(location)
//        let hitResults = sceneView.hitTest(location, options: [:])
//        print(hitResults)
//        if !hitResults.isEmpty {
//            let posi = hitResults[0].worldCoordinates
//            print(posi)
//            let sphere_geo:SCNGeometry = SCNSphere(radius: 0.01)
//            sphere_geo.firstMaterial?.diffuse.contents = UIColor.blue
//            let sphere = SCNNode(geometry: sphere_geo)
//            sphere.position = posi
//            scene.rootNode.addChildNode(sphere)
//        }
        
        flag.toggle()
        if flag == true {
            imageView6.image = image1
        } else {
            imageView6.image = image2
        }
        
//        DispatchQueue.main.async { [self] in
//            sceneView.allowsCameraControl = false
//            json_data = read_json(name: "try_107")
//            let cameraPosition = SCNVector3(json_data.cameraPosition.x,
//                                            json_data.cameraPosition.y,
//                                            json_data.cameraPosition.z)
//            let cameraEulerAngles = SCNVector3(json_data.cameraEulerAngles.x,
//                                               json_data.cameraEulerAngles.y,
//                                               json_data.cameraEulerAngles.z)
//
//            cameraNode.position = cameraPosition
//            cameraNode.eulerAngles = cameraEulerAngles
//            scene.rootNode.addChildNode(cameraNode)
//            sceneView.allowsCameraControl = true
//        }
    }
    
    @IBAction func push(_ sender: UIButton) {
        start = Date()
        
        imageView.isHidden = true
        imageView2.isHidden = true
        
        //start_flag = true
        
        openCV.detectPoints(image1, image2)
        imageView5.image = openCV.image()
        
        pointsArray = openCV.pointsArray() as? Array<CGPoint>
        pointsArray2 = openCV.pointsArray2() as? Array<CGPoint>
        print(pointsArray.count)
//        print(pointsArray[0].x)
//        print(pointsArray[0].y)
        print(pointsArray2.count)
        
        print("特徴マッチング完了")
        
        make_3dPoints(meshname: "NaviModel00-0.scn", filename: image_name1, pointsArray: pointsArray, f_b: 0)
        //make_3dPoints(meshname: "NaviModel00-1.scn", filename: image_name2, pointsArray: pointsArray2, f_b: 1)
        
        //print(depthDataArray[1...500])
        //print(depthDataArray.count)
        //print(fixedArray[width*200+400]) //(400,200)に対応する深度値
        
//        let dispatchGroup = DispatchGroup()
//            // 直列キュー / attibutes指定なし
//        let dispatchQueue = DispatchQueue(label: "queue")
//        dispatchQueue.async(group: dispatchGroup) { [self] in
            //node作成
//            let (node, matrix_1) = make_3d_nodes2(json_data: read_json(name: "try_102"),
//                                                 pixelArray: pixelDataColor,
//                                                 pointsArray: pointsArray,
//                                                 f_b: 0)
//    //            make_3d_nodes(json: read_json(name: "try_16"),
//    //                                             depthArray: read_depth_data(name: "try_16"),
//    //                                             pixelArray: pixelDataColor,
//    //                                             pointsArray: pointsArray,
//    //                                             f_b: 0)
//
//            self.scene.rootNode.addChildNode(node)
            //print("matrix_1 : \(matrix_1)")
            //print(matrix_1[1~<])
            
    //        //node作成
//            let (node2, matrix_2) = make_3d_nodes2(json_data: read_json(name: "try_107"),
//                                                   pixelArray: pixelDataColor2,
//                                                   pointsArray: pointsArray2,
//                                                   f_b: 1)
//    ////            make_3d_nodes(json: read_json(name: "try_1"),
//    ////                                              depthArray: read_depth_data(name: "try_1"),
//    ////                                              pixelArray: pixelDataColor2,
//    ////                                              pointsArray: pointsArray2,
//    ////                                              f_b: 1)
//            self.scene.rootNode.addChildNode(node2)
//            //print("matrix_2 : \(matrix_2)")
//        }
    }
    
    func read_points(name: String) -> [PointCloudVertex] {
        var points: [PointCloudVertex]!
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
            points = points_data
        }
        return points
    }
    
    func make_matlab_points(points: [PointCloudVertex], name: String) {
        //deta = [1,2,3;4,5,6]
        var p_string = "["
        for (i,p) in points.enumerated() {
            if i != points.count-1 {
                p_string += "\(p.x),\(p.y),\(p.z);"
            } else {
                p_string += "\(p.x),\(p.y),\(p.z)]"
            }
        }
        
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
            let targetTextFilePath = documentDirectoryFileURL.appendingPathComponent("\(name).txt")
            do {
                try p_string.write(to: targetTextFilePath, atomically: true, encoding: String.Encoding.ascii)
            } catch {
                print("Failed to write PLY file", error)
            }
        }
    }
    
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

//        x : 0.40738428, -1.4394194
//        y : 1.2834383, -0.7681716
//        z : -0.024282593, -1.1715853
        
        return (x_min, x_max, y_min, y_max, z_min, z_max)
    }
    
    func remove_points(x_min: Float, x_max: Float, y_min: Float, y_max: Float, z_min: Float, z_max: Float, points: [PointCloudVertex]) -> [PointCloudVertex]{
        var new_points: [PointCloudVertex] = []
        for p in points {
            if (x_min <= p.x && x_max >= p.x && y_min <= p.y && y_max >= p.y && z_min <= p.z && z_max >= p.z) {
                new_points.append(p)
            }
        }
        return new_points
    }
    
    //入力点群をボクセルグリッドによる量子化
    func voxcel_grid(x_min: Float, x_max: Float, y_min: Float, y_max: Float, z_min: Float, z_max: Float, points0: [PointCloudVertex], num: Int) {
        let size: Float = 0.1
        let x_count = ceil(abs(x_max - x_min) / size)
        let y_count = ceil(abs(y_max - y_min) / size)
        let z_count = ceil(abs(z_max - z_min) / size)
        print("x_count, y_count, z_count = \(x_count), \(y_count), \(z_count)")
        
        var points = points0
        var voxcel_points: [PointCloudVertex] = []
        var count = 0
        
        for x in 1...Int(x_count) {
            print(x)
            for y in 1...Int(y_count) {
                for z in 1...Int(z_count) {
                    let p = points.indices.filter{points[$0].x >= x_min + (size * Float(x-1)) && points[$0].x < x_min  + (size * Float(x)) && points[$0].y >= y_min + (size * Float(y-1)) && points[$0].y < y_min + (size * Float(y)) && points[$0].z >= z_min + (size * Float(z-1)) && points[$0].z < z_min + (size * Float(z))}
                    if p.count > 0 {
                        //voxcel_points.append(points[p[0]])
                        if num == 0 {
                            voxcel_points.append(PointCloudVertex(x: (x_min+(size*Float(x-1)) + x_min+(size*Float(x)))/2,
                                                                  y: (y_min+(size*Float(y-1)) + y_min+(size*Float(y)))/2,
                                                                  z: (z_min+(size*Float(z-1)) + z_min+(size*Float(z)))/2,
                                                                  r: 0, g: 0, b: 255))
                        } else {
                            voxcel_points.append(PointCloudVertex(x: (x_min+(size*Float(x-1)) + 0.01 + x_min+(size*Float(x)))/2,
                                                                  y: (y_min+(size*Float(y-1)) + 0.01 + y_min+(size*Float(y)))/2,
                                                                  z: (z_min+(size*Float(z-1)) + 0.01 + z_min+(size*Float(z)))/2,
                                                                  r: 255, g: 0, b: 0))
                        }
                        count += p.count
                        for (i, index) in p.enumerated() {
                            //削除した時にインデックスがズレるため補正が必要
                            points.remove(at: index - i)
                        }
                    }
                }
            }
        }
        
        print(points.count)
        print(count)
        print(voxcel_points.count)
        
        let node = self.buildNode2(points: voxcel_points)
        node.name = "point"
        self.scene.rootNode.addChildNode(node)
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
                    if (xyz_voxcel_points1[x-1][y-1][z-1].count > 5 && xyz_voxcel_points2[x-1][y-1][z-1].count == 0) {
                        diff_voxcel_points.append(PointCloudVertex(x: (x_min+(size*Float(x-1)) + x_min+(size*Float(x)))/2,
                                                                   y: (y_min+(size*Float(y-1)) + y_min+(size*Float(y)))/2,
                                                                   z: (z_min+(size*Float(z-1)) + z_min+(size*Float(z)))/2,
                                                                   r: 0, g: 0, b: 255))
                    }
//                    if (xyz_voxcel_points2[x-1][y-1][z-1].count > 2) { //&& xyz_voxcel_points1[x-1][y-1][z-1].count == 0) {
//                        diff_voxcel_points.append(PointCloudVertex(x: (x_min+(size*Float(x-1)) + 0.03 + x_min+(size*Float(x)))/2,
//                                                                   y: (y_min+(size*Float(y-1)) + 0.03 + y_min+(size*Float(y)))/2,
//                                                                   z: (z_min+(size*Float(z-1)) + 0.03 + z_min+(size*Float(z)))/2,
//                                                                   r: 255, g: 0, b: 0))
//                    }
                }
            }
        }
    
        print(diff_voxcel_points.count)
        //print(diff_voxcel_points)
        print("voxcel_gridによる差分化完了")
        
        let new_voxcel_points = remove_voxcel_points(points: diff_voxcel_points) //余分なvoxcelを削除

        let (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: new_voxcel_points)

        let new_points1 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points1)

        let node = self.buildNode2(points: new_points1)
        node.name = "point"
        self.scene.rootNode.addChildNode(node)
    }
    
    //ボクセル化して差分をとった点群から適切な穂ウンディングボックスを推定する
    func remove_voxcel_points(points: [PointCloudVertex]) -> [PointCloudVertex]{
        var voxcel_points: [PointCloudVertex] = []
        var voxcel_points_x: [PointCloudVertex] = []
        var voxcel_points_z: [PointCloudVertex] = []
        
        var pre_voxcel_points = points
        //y
        while pre_voxcel_points.count > 0 {
            let p = pre_voxcel_points.indices.filter{pre_voxcel_points[$0].y == pre_voxcel_points[0].y}
            if p.count > 7 {
                for (i, index) in p.enumerated() {
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
            if p.count > 7 {
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
            if p.count > 7 {
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
    
    @IBAction func make_Box(_ sender: UIButton) {
        //let points = read_points(name: "NaviModel00-0")
        let points = regist_points
        print(points.count)
        
        let points2 = read_points(name: "NaviModel00-1")
        print(points2.count)
        
        let (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: points)
        
        let new_points2 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points2)
        
        let start2 = Date()
//        voxcel_grid(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points0: points, num: 0)
//        voxcel_grid(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points0: new_points2, num: 1)
        diff_voxcel_grid(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points1: points, points2: new_points2)
        let elapsed2 = Date().timeIntervalSince(start2)
        print("実行時間：\(elapsed2)")
        
        //size = 0.1　→ 62.51046097278595秒
        //点群を減らすように変更
        //size = 0.1　→ 39.43629801273346
        
        //1237.2765120267868
        
        
//        let new_points2 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points2)
//        print(new_points2.count)
//
//        let node = self.buildNode2(points: new_points2)
//        node.name = "point"
//        self.scene.rootNode.addChildNode(node)
    }
    
    
    @IBAction func All_ICP(_ sender: UIButton) {
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
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        
//        if let camera = self.sceneView.pointOfView {
//            let cameraPosition = camera.position
//            let cameraEulerAngles = camera.eulerAngles
//
//            print("position : \(cameraPosition)")
//            print("EulerAngles : \(cameraEulerAngles)")
//
//            //"cameraEulerAngles":{"x":0.0042598117142915726,"y":1.4142813682556152,"z":0.18692776560783386}
//            //EulerAngles : SCNVector3(x: -0.01260643, y: 1.4144374, z: 0.18712252)
//            //0.0168
//
//            //"cameraEulerAngles":{"x":1.0414915084838867,"y":1.3960708379745483,"z":1.4188430309295654}
//            //EulerAngles : SCNVector3(x: 1.0307517, y: 1.3960705, z: 1.4188436)
//            //EulerAngles : SCNVector3(x: 1.0280659, y: 1.3960708, z: 1.418843)
//        }
    }
    
    @objc func update() {
    }
    
    func make_3dPoints(meshname: String, filename: String, pointsArray: Array<CGPoint>, f_b: Int) {
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
        
        json_data = read_json(name: filename)
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
                            if f_b == 0 {
                                matrix_1 = make_Matlix(pointsArray: pointsArray) //対応点をmatrix化
                                //self.make_3d_nodes3(pointsArray: pointsArray, f_b: f_b)
                                make_3d_nodes3(matrix: matrix_1, f_b: 0) //対応点のnodeを表示
                                print("matrix_1: \(matrix_1)")
                                make_3dPoints(meshname: "NaviModel00-1.scn", filename: image_name2, pointsArray: pointsArray2, f_b: 1)
                            } else if f_b == 1 {
                                matrix_2 = make_Matlix(pointsArray: pointsArray2)
                                //self.make_3d_nodes3(pointsArray: pointsArray, f_b: f_b)
                                make_3d_nodes3(matrix: matrix_2, f_b: 1)
                                print("matrix_2: \(matrix_2)")
                                //icp_flag = true
                                let (use_matrix_1, use_matrix_2) = ignor_point(matrix_1: matrix_1, matrix_2: matrix_2)
                                print("use_matrix1 : \(use_matrix_1)")
                                print("use_matrix2 : \(use_matrix_2)")
                                
                                let (R_matrix, t_matrix) = ICPMatching(matrix_1: use_matrix_2, matrix_2: use_matrix_1)
                                
                                let matrix_3 = Matft.matmul(R_matrix, matrix_1.transpose()).transpose() + t_matrix.transpose()
                                make_3d_nodes3(matrix: matrix_3, f_b: 2)
                                
                                let re_points = regist(points: points1, R_matrix: R_matrix, t_matrix: t_matrix)
                                
                                DispatchQueue.main.async {
                                    imageView5.isHidden = true
                                    imageView6.isHidden = true
                                }
                                
                                //差分化処理
                                let start2 = Date()
                                let (x_min, x_max, y_min, y_max, z_min, z_max) = xyz_min_max(points: re_points)
                                
                                let new_points2 = remove_points(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points: points2)
                                
                                diff_voxcel_grid(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max, z_min: z_min, z_max: z_max, points1: re_points, points2: new_points2)
                                
                                let elapsed = Date().timeIntervalSince(start)
                                print("全体の実行時間：\(elapsed)")
                                let elapsed2 = Date().timeIntervalSince(start2)
                                print("差分化処理の実行時間：\(elapsed2)")
                            }
                           })
        }
    }
    
    func make_Matlix(pointsArray: Array<CGPoint>) -> (MfArray) {
        let matrix = Matft.arange(start: 0, to: pointsArray.count*3, by: 1, shape: [pointsArray.count, 3], mftype: .Float, mforder: .Row)
        
        for (i,p) in pointsArray.enumerated() {
            let points = CGPoint(x: p.x * 834 / 2682, y: p.y * 1194 / 3840)
            let hitResults = sceneView.hitTest(points, options: [:])
            //print(hitResults)
            //print(hitResults.count)
            if !hitResults.isEmpty {
                var point: SCNVector3!
                for i in 0..<hitResults.count {
                    //print(hitResults[i].node.name!)
                    let name = hitResults[i].node.name!
                    if name == "mesh" {
                        point = hitResults[i].worldCoordinates
                        break
                    }
                }
                point = hitResults[0].worldCoordinates
                
                matrix[i,0] = point.x
                matrix[i,1] = point.y
                matrix[i,2] = point.z
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
        
//
//        for (i,p) in points.enumerated() {
//            matrix[i,0] = p.x
//            matrix[i,1] = p.y
//            matrix[i,2] = p.z
//
////            let point = MfArray([p.x, p.y, p.z], mftype: .Float)
////            let new_point = Matft.stats.sum(R_matrix * point, axis: 1) + t_matrix
////            regist_points.append(PointCloudVertex(x: new_point[0].scalar as! Float,
////                                                  y: new_point[1].scalar as! Float,
////                                                  z: new_point[2].scalar as! Float, r: p.r, g: p.g, b: p.b))
//        }

        print(re_points[0])
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

            var (index, error) = FindNearestPoint(matrix_1: matrix_1, matrix_2: new_matrix_2) //最近傍点探索
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
    
    func FindNearestPoint(matrix_1: MfArray, matrix_2: MfArray) -> ([Int], Float) {
        var index: [Int] = []
        var error: Float = 0.0
        
//        print(matrix_1)
//        print(matrix_2)
        
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
            //print(min)
            //print(min_index)
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
    
    
    @IBAction func point1(_ sender: UIButton) {
        point_cloud_flag1.toggle()
        
        if point_cloud_flag1 == true {
            if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
//                let txt_model_name = documentDirectoryFileURL.appendingPathComponent("NaviModel00-0.txt")
//                guard let fileContents = try? String(contentsOf: txt_model_name) else {
//                    fatalError("ファイル読み込みエラー")
//                }
//                let row = fileContents.components(separatedBy: "\n")
//                let vertice_count = Int(row[0])!
                
                let data_model_name = documentDirectoryFileURL.appendingPathComponent("NaviModel00-0.data")
                //let data = try NSData(contentsOf: data_model_name)
                
                guard let data = try? Data(contentsOf: data_model_name) else {
                    fatalError("ファイル読み込みエラー")
                }
                let decoder = JSONDecoder()
                guard let datas = try? decoder.decode([PointCloudVertex].self, from: data) else {
                    fatalError("JSON読み込みエラー")
                }
                
                let node = self.buildNode2(points: datas)
                //node.position = SCNVector3(x: 0, y: 0, z: 0)
                node.name = "point"
                self.scene.rootNode.addChildNode(node)
            }
        } else {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: "point", recursively: false) {
                node.removeFromParentNode()
            }
        }
    }
    
    @IBAction func point2(_ sender: UIButton) {
        point_cloud_flag2.toggle()
        
        if point_cloud_flag2 == true {
            if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
//                let txt_model_name2 = documentDirectoryFileURL.appendingPathComponent("NaviModel00-1.txt")
//                guard let fileContents = try? String(contentsOf: txt_model_name2) else {
//                    fatalError("ファイル読み込みエラー")
//                }
//                let row2 = fileContents.components(separatedBy: "\n")
//                let vertice_count2 = Int(row2[0])!
                
                let data_model_name2 = documentDirectoryFileURL.appendingPathComponent("NaviModel00-1.data")
                //let data2 = try NSData(contentsOf: data_model_name2)
                
                guard let data2 = try? Data(contentsOf: data_model_name2) else {
                    fatalError("ファイル読み込みエラー")
                }
                let decoder = JSONDecoder()
                guard let datas2 = try? decoder.decode([PointCloudVertex].self, from: data2) else {
                    fatalError("JSON読み込みエラー")
                }
                let node2 = self.buildNode2(points: datas2)
                //node2.position = SCNVector3(x: 0, y: 0, z: 0)
                node2.name = "point2"
                self.scene.rootNode.addChildNode(node2)
            }
        } else {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: "point2", recursively: false) {
                node.removeFromParentNode()
            }
        }
    }
    
    @IBAction func point3(_ sender: UIButton) {
        point_cloud_flag1.toggle()
        
        if point_cloud_flag1 == true {
                let node3 = self.buildNode2(points: regist_points)
                //node.position = SCNVector3(x: 0, y: 0, z: 0)
                node3.name = "point"
                self.scene.rootNode.addChildNode(node3)
        } else {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: "point", recursively: false) {
                node.removeFromParentNode()
            }
        }
    }
    
    //行列の畳み込み(a*3  b*3 → 3*3)
    func matrix_convolve(Sshift: MfArray, Mshift_xyz: MfArray) -> MfArray {
        let W =  Matft.arange(start: 0, to: 9, by: 1, shape: [3, 3], mftype: .Float, mforder: .Row)
        
        let Mshift_yzx = Matft.arange(start: 0, to: Mshift_xyz.count*3, by: 1, shape: [Mshift_xyz.count, 3], mftype: .Float, mforder: .Row)
        let Mshift_zxy = Matft.arange(start: 0, to: Mshift_xyz.count*3, by: 1, shape: [Mshift_xyz.count, 3], mftype: .Float, mforder: .Row)
        
        for i in 0..<Mshift_xyz.count {
            Mshift_yzx[i,0] = Mshift_xyz[i,1]
            Mshift_yzx[i,1] = Mshift_xyz[i,2]
            Mshift_yzx[i,2] = Mshift_xyz[i,0]
            Mshift_zxy[i,0] = Mshift_xyz[i,2]
            Mshift_zxy[i,1] = Mshift_xyz[i,0]
            Mshift_zxy[i,2] = Mshift_xyz[i,1]
        }
        
        let e1 = Matft.stats.sum((Sshift * Mshift_xyz), axis: 0)
        let e2 = Matft.stats.sum((Sshift * Mshift_yzx), axis: 0)
        let e3 = Matft.stats.sum((Sshift * Mshift_zxy), axis: 0)
        
        W[0,0] = e1[0]
        W[0,1] = e3[1]
        W[0,2] = e2[2]
        W[1,0] = e2[0]
        W[1,1] = e1[1]
        W[1,2] = e3[2]
        W[2,0] = e3[0]
        W[2,1] = e2[1]
        W[2,2] = e1[2]
        
        return W
    }
    
    func make_3d_nodes2(json_data: json_pointcloudUniforms, pixelArray: [UInt8], pointsArray: Array<CGPoint>, f_b: Int) -> (SCNNode, MfArray) {
        
        let matrix = Matft.arange(start: 0, to: pointsArray.count*3, by: 1, shape: [pointsArray.count, 3], mftype: .Float, mforder: .Row)
        var node = SCNNode()
        
//        let dispatchGroup = DispatchGroup()
//            // 直列キュー / attibutes指定なし
//        let dispatchQueue = DispatchQueue(label: "queue")
//        dispatchQueue.async(group: dispatchGroup) { [self] in
//
//            dispatchGroup.enter()
//
//            let dispatchSemaphore = DispatchSemaphore(value: 0)
//
//            sceneView.allowsCameraControl = false
//            let cameraPosition = SCNVector3(json_data.cameraPosition.x,
//                                            json_data.cameraPosition.y,
//                                            json_data.cameraPosition.z)
//            let cameraEulerAngles = SCNVector3(json_data.cameraEulerAngles.x,
//                                               json_data.cameraEulerAngles.y,
//                                               json_data.cameraEulerAngles.z)
//
//            cameraNode.position = cameraPosition
//            cameraNode.eulerAngles = cameraEulerAngles
//            scene.rootNode.addChildNode(cameraNode)
//            print("カメラ移動")
//            sceneView.allowsCameraControl = true
//
//            dispatchGroup.leave()
//            dispatchSemaphore.signal()
//
//            dispatchSemaphore.wait()
//        }
        
        
            
        
        //dispatchGroup.notify(queue: .main) { [self] in
//            let resizeScale_x = CGFloat(268) / CGFloat(2684)
//            let resizeScale_y = CGFloat(384) / CGFloat(3840)
//            var new_points: [CGPoint] = []
        for (i,p) in pointsArray.enumerated() {
                let points = CGPoint(x: p.x * 834 / 2684, y: p.y * 1194 / 3840)
                //print(points)
                let hitResults = sceneView.hitTest(points, options: [:])
                //print(hitResults)
                if !hitResults.isEmpty {
                    let worldPoint = hitResults[0].worldCoordinates
                    print(worldPoint)
                    let sphere_geo:SCNGeometry = SCNSphere(radius: 0.002)
                    if f_b == 0 {
                        sphere_geo.firstMaterial?.diffuse.contents = UIColor.red
                    } else {
                        sphere_geo.firstMaterial?.diffuse.contents = UIColor.blue
                    }
                    let sphere = SCNNode(geometry: sphere_geo)
                    sphere.position = worldPoint
                    matrix[i,0] = worldPoint.x
                    matrix[i,1] = worldPoint.y
                    matrix[i,2] = worldPoint.z
                    self.scene.rootNode.addChildNode(sphere)
                }
            }
            
//            for y in 0 ..< 11 {
//                for x in 0 ..< 834 {
//                    let location = CGPoint(x: x, y: y)
//                    let hitResults = sceneView.hitTest(location, options: [:])
//                    if !hitResults.isEmpty {
//                        let worldPoint = hitResults[0].worldCoordinates
//                        //print(worldPoint)
//                        r_value = Float(pixelArray[(y * 384 + x) * 4]) / Float(255)
//                        g_value = Float(pixelArray[(y * 384 + x) * 4 + 1]) / Float(255)
//                        b_value = Float(pixelArray[(y * 384 + x) * 4 + 2]) / Float(255)
//                        vertice_data.append(PointCloudVertex_3d(x: worldPoint.x,
//                                                                y: worldPoint.y,
//                                                                z: worldPoint.z,
//                                                                r: r_value,
//                                                                g: g_value,
//                                                                b: b_value))
//                    }
//                }
//            }
            print("終了")
            print(vertice_data.count)
            
            node = buildNode(points: vertice_data)
        //}
            
        return (node, matrix)
    }
    
    func make_3d_nodes(json: json_pointcloudUniforms, depthArray: [Float32], pixelArray: [UInt8], pointsArray: Array<CGPoint>, f_b: Int) -> (SCNNode, MfArray) {
        
        var points_3d: [[Float]] = []
        let matrix = Matft.arange(start: 0, to: pointsArray.count*3, by: 1, shape: [pointsArray.count, 3], mftype: .Float, mforder: .Row)
        
        let resizeScale_x = CGFloat(184) / CGFloat(2880)
        let resizeScale_y = CGFloat(184) / CGFloat(3840)
        var new_points: [CGPoint] = []
        for p in pointsArray {
            let points = CGPoint(x: (p.x * resizeScale_x), y: 184 - (p.y * resizeScale_y))
            new_points.append(points)
        }
        //print(new_points)
        
        IntrinsicsInversed = simd_float3x3(
            json.Intrinsics.x,
            json.Intrinsics.y,
            json.Intrinsics.z)
        
        localToworld = simd_float4x4(json.ViewMatrix.x,
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
            
            points_3d.append([worldPoint.x, worldPoint.y, worldPoint.z])
            matrix[i,0] = worldPoint.x
            matrix[i,1] = worldPoint.y
            matrix[i,2] = worldPoint.z
            
//            if i % 3 == 0 {
//                r_value = 255; g_value = 0; b_value = 0
//            }
//            if i % 4 == 0 {
//                r_value = 0; g_value = 255; b_value = 0
//            }
//            if i % 5 == 0 {
//                r_value = 0; g_value = 0; b_value = 255
//            }
            vertice_data.append(PointCloudVertex(x: worldPoint.x,
                                                    y: worldPoint.y,
                                                    z: worldPoint.z,
                                                    r: r_value,
                                                    g: g_value,
                                                    b: b_value))
        }
        
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
//                //print(worldPoint.w) //1.0
//
////                let r = Float(pixelArray[((y+4) * 256 + (x+36)) * 4]) / Float(r_value)
////                let g = Float(pixelArray[((y+4) * 256 + (x+36)) * 4 + 1]) / Float(g_value)
////                let b = Float(pixelArray[((y+4) * 256 + (x+36)) * 4 + 2]) / Float(b_value)
//                let r = Float(pixelArray[(y * 184 + x) * 4]) / Float(255)
//                let g = Float(pixelArray[(y * 184 + x) * 4 + 1]) / Float(255)
//                let b = Float(pixelArray[(y * 184 + x) * 4 + 2]) / Float(255)
//                vertice_data.append(PointCloudVertex_3d(x: worldPoint.x,
//                                                        y: worldPoint.y,
//                                                        z: worldPoint.z,
//                                                        r: r,
//                                                        g: g,
//                                                        b: b))
//            }
//        }
    
        let node = buildNode(points: vertice_data)
        
        return (node, matrix)
    }
    
    private func buildNode(points: [PointCloudVertex]) -> SCNNode {
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
        print("geometry作成")
        
        return SCNNode(geometry: pointsGeometry)
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
    
    func read_json(name: String) -> json_pointcloudUniforms {
        /// ①プロジェクト内にある"employees.json"ファイルのパス取得
//        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
//            fatalError("ファイルが見つからない")
//        }
        var datas: json_pointcloudUniforms!
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            let file_name = documentDirectoryFileURL.appendingPathComponent("\(name).json")
            /// ②employees.jsonの内容をData型プロパティに読み込み
            guard let data = try? Data(contentsOf: file_name) else {
                fatalError("ファイル読み込みエラー")
            }
            /// ③JSONデコード処理
            let decoder = JSONDecoder()
            datas = try? decoder.decode(json_pointcloudUniforms.self, from: data)
        }
        
        return datas
    }
    
    func read_depth_data(name: String) -> [Float32] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "data") else {
            fatalError("ファイルが見つからない")
        }
        guard let data = try? Data(contentsOf: url) else {
            fatalError("ファイル読み込みエラー")
        }
        let decoder = JSONDecoder()
        guard let datas = try? decoder.decode([depthMap_data].self, from: data) else {
            fatalError("JSON読み込みエラー")
        }
        var depthArray: [Float32] = []
        for i in 0...datas.count-1 {
            depthArray.append(datas[i].depth)
        }
        return depthArray
    }
    
    func read_pixel(colorImage: UIImage) -> ([UInt8], CIImage) {
        //let colorImage = UIImage(named: name)!
        print("colorImage.size.width:\(colorImage.size.width)")
        print("colorImage.size.height:\(colorImage.size.height)")
//        let resizeScale = CGFloat(184) / CGFloat(colorImage.size.width)
//        let resizeScale_y = CGFloat(184) / CGFloat(colorImage.size.height)
        let resizeScale = CGFloat(268) / CGFloat(colorImage.size.width)
        let resizeScale_y = CGFloat(384) / CGFloat(colorImage.size.height)
        let resizedColorImage = CIImage(cgImage: colorImage.cgImage!).transformed(by: CGAffineTransform(scaleX: resizeScale, y: -resizeScale_y))
        
        print("colorImage.size.width : \(colorImage.size.width)") //2880
        print("colorImage.size.height : \(colorImage.size.height)") //3840
        //print(resizedColorImage.extent)
        //imageView.image = UIImage(ciImage: resizedColorImage)
        //let uiImage = UIImage.init(ciImage: resizedColorImage.oriented(CGImagePropertyOrientation(rawValue: 6)!))
        //imageview.image = UIImage(ciImage: resizedColorImage)//uiImage
        
        return (resizedColorImage.createCGImage().pixelData()!, resizedColorImage)
    }
    
    @IBAction func mesh_valued(_ sender: UISlider) {
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "mesh", recursively: false) {
            node.opacity =  CGFloat(sender.value)
        }
    }
    
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}

extension CGImage {

    func pixelData() -> [UInt8]? {
//        guard let colorSpace = colorSpace else { return nil }
//
//        let totalBytes = height * bytesPerRow
//        var pixelData = [UInt8](repeating: 0, count: totalBytes)

        let totalBytes = height * bytesPerRow
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
//        print("bytesPerRow:\(bytesPerRow)")
//        print("bitsPerComponent:\(bitsPerComponent)")
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent, //8
            bytesPerRow: bytesPerRow, //1024
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue)
            else { fatalError() }
        context.draw(self, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
        
        return pixelData
    }
}


//        var points_2d = [[[simd_float2]]](repeating: [[simd_float2]](repeating: [simd_float2(0,0)], count: 384), count: 512)
//        //var points_2d: [[[Float]]] = [[[]]]
//        for i in 0...512-1 {
//            for j in 0...384-1 {
//                points_2d[i][j] = [simd_float2(Float(j+1),Float(i+1))]
//            }
//        }
        
//        print(points_2d[0].count) //384
//        print(points_2d.count) //512
//        //print(points_2d)
//        print(points_2d[0][1].count) //2
//
////        print(points_2d[0]) //座標
////        print(points_2d[511])
//        print(points_2d[0][1])
//        print(points_2d[0][1][0])
        
        //var points_3d = [[[simd_float3]]](repeating: [[simd_float3]](repeating: [simd_float3(0,0,0)], count: 384), count: 512)

//        for i in 0...512-1 {
//            for j in 0...384-1 {
//                let localPoint = IntrinsicsInversed * simd_float3(points_2d[i][j][0], 1) * depthArray[i*384 + j]
//                let worldPoint = localToworld * simd_float4(localPoint, 1)
//                vertice_data.append(PointCloudVertex_3d(x: worldPoint.x/worldPoint.w, y: worldPoint.y/worldPoint.w, z: worldPoint.z/worldPoint.w))
//            }
//        }
//        print(vertice_data.count)
//
//        let node = buildNode(points: vertice_data)



//   func getCVPixelBuffer(_ image: CGImage) -> CVPixelBuffer? {
//        let imageWidth = Int(image.width)
//        let imageHeight = Int(image.height)
//
//        let attributes : [NSObject:AnyObject] = [
//            kCVPixelBufferCGImageCompatibilityKey : true as AnyObject,
//            kCVPixelBufferCGBitmapContextCompatibilityKey : true as AnyObject
//        ]
//
//        var pxbuffer: CVPixelBuffer? = nil
//        CVPixelBufferCreate(kCFAllocatorDefault,
//                            imageWidth,
//                            imageHeight,
//                            kCVPixelFormatType_32ARGB,
//                            attributes as CFDictionary?,
//                            &pxbuffer)
//
//        if let _pxbuffer = pxbuffer {
//            let flags = CVPixelBufferLockFlags(rawValue: 0)
//            CVPixelBufferLockBaseAddress(_pxbuffer, flags)
//            let pxdata = CVPixelBufferGetBaseAddress(_pxbuffer)
//
//            let rgbColorSpace = CGColorSpaceCreateDeviceRGB();
//            let context = CGContext(data: pxdata,
//                                    width: imageWidth,
//                                    height: imageHeight,
//                                    bitsPerComponent: 8,
//                                    bytesPerRow: CVPixelBufferGetBytesPerRow(_pxbuffer),
//                                    space: rgbColorSpace,
//                                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
//
//            if let _context = context {
//                _context.draw(image, in: CGRect.init(x: 0, y: 0, width: imageWidth, height: imageHeight))
//            }
//            else {
//                CVPixelBufferUnlockBaseAddress(_pxbuffer, flags);
//                return nil
//            }
//
//            CVPixelBufferUnlockBaseAddress(_pxbuffer, flags);
//            return _pxbuffer;
//        }
//
//        return nil
//    }
//   func read_depth() -> [Float32] {
//        let sample = UIImage(named: "depth_try_13")
//        let depthMap = getCVPixelBuffer((sample?.cgImage)!)!
//        //print(depthMap)
//
//        // depthMapのCPU配置(?)
//        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
//        let base = CVPixelBufferGetBaseAddress(depthMap) // 先頭ポインタの取得
//        let width = CVPixelBufferGetWidth(depthMap) // 横幅の取得
//        let height = CVPixelBufferGetHeight(depthMap) // 縦幅の取得
//
//        // UnsafeMutableRawPointer -> UnsafeMutablePointer<Float32>
//        let bindPtr = base?.bindMemory(to: Float32.self, capacity: width * height)
//
//        // UnsafeMutablePointer -> UnsafeBufferPointer<Float32>
//        let bufPtr = UnsafeBufferPointer(start: bindPtr, count: width * height)
//
//        // UnsafeBufferPointer<Float32> -> Array<Float32>
//        let depthArray = Array(bufPtr)
//
//        // depthMapのCPU解放(?)
//        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
//
//        let fixedArray = depthArray.map({ $0.isNaN ? 0 : $0 })
//
//        return fixedArray
//    }
