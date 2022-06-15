//
//  Data_to_Cloud.swift
//  ARSystem
//
//  Created by yasue kouki on 2022/06/06.
//

import SVProgressHUD
import FirebaseFirestore
import SceneKit
import SSZipArchive

extension EditDataController {
    
    func save_mapData_to_Cloud(name: String) {
        print("\(name)のクラウド化")
        let archivePath = url.appendingPathComponent("\(models.dayString)/\(current_model_num)/\(name).zip")
        var targetFilePath = url.appendingPathComponent("\(models.dayString)/\(current_model_num)/\(name).data")
        if name != "worldMap" {
            targetFilePath = url.appendingPathComponent("\(models.dayString)/\(current_model_num)/\(name).jpg")
        }
        print(targetFilePath)
        let data = try! Data(contentsOf: targetFilePath)
        if !toZip(data: data, archivePath: archivePath.path, targetFilePaths: [targetFilePath.path]) {
            print("zip化失敗")
        } else {
            //print("zip化成功")
            print(try! Data(contentsOf: archivePath))
            dataStore.collection("\(models.dayString)").document("\(current_model_num)").setData([
                "\(name)": try! Data(contentsOf: archivePath)
            ], merge: true) { err in
                if let err = err {
                    print("Error writing document: \(err)")
                } else {
                    print("zipをFireStoreに書き込み完了")
                }
            }
        }
    }
    
    func save_texData_to_Cloud(fileName: [String]) {
        for name in fileName {
            print("\(name)のクラウド化")
            for i in 0..<models.meshNum {
                let archivePath = url.appendingPathComponent("\(models.dayString)/\(current_model_num)/\(name)/\(name)\(i).zip")
                var targetFilePath = url.appendingPathComponent("\(models.dayString)/\(current_model_num)/\(name)/\(name)\(i).data")
                let data = try! Data(contentsOf: targetFilePath)
                if !toZip(data: data, archivePath: archivePath.path, targetFilePaths: [targetFilePath.path]) {
                    print("zip化失敗")
                } else {
                    //print("zip化成功")
                    let dataStore = Firestore.firestore()
                    dataStore.collection("\(models.dayString)").document("\(current_model_num)").collection("texMesh").document("\(name)").setData([
                        "\(name)\(i)": try! Data(contentsOf: archivePath)
                    ], merge: true) { err in
                        if let err = err {
                            print("Error writing document: \(err)")
                        } else {
                            //print("zipをFireStoreに書き込み完了")
                        }
                    }
                }
            }
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//    func saveWorldMapData() {
//        let archivePath = url.appendingPathComponent("\(models.dayString)/\(current_model_num)/worldMap.zip")
//        let targetFilePath = url.appendingPathComponent("\(models.dayString)/\(current_model_num)/worldMap.data")
//        let data = try! Data(contentsOf: targetFilePath)
//        if !toZip(data: data, archivePath: archivePath.path, targetFilePaths: [targetFilePath.path]) {
//            print("zip化失敗")
//        } else {
//            print("zip化成功")
//            let dataStore = Firestore.firestore()
//            dataStore.collection("\(models.dayString)").document("\(current_model_num)").setData([
//                "worldMap": try! Data(contentsOf: archivePath)
//            ]) { err in
//                if let err = err {
//                    print("Error writing document: \(err)")
//                } else {
//                    print("zipPicをFireStoreに書き込み完了")
//                }
//            }
//        }
//    }
//
//    @IBAction func TapedSaveButton(_ sender: UIButton) {
//        sceneView.scene?.rootNode.childNode(withName: "meshNode", recursively: false)?.removeFromParentNode()
//        DispatchQueue.main.async {
//            SVProgressHUD.show()
//            self.savePicDocument()
//            //self.saveWorldDataDocument()
//            self.saveDocument()
//        }
//    }
//
//    @IBAction func ReadAndBuild(_ sender: UIButton) {
//        SVProgressHUD.show()
//        zipReadFireStore() { [self] in
//            print("build処理開始")
//            buildNode()
//            sceneView.scene?.rootNode.addChildNode(texmeshNode)
//            SVProgressHUD.dismiss()
//        }
//    }
//
//    func savePicDocument() {
//        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
//            //フォルダ作成
//            let directory = url.appendingPathComponent("pic", isDirectory: true)
//            do {
//                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
//            } catch {
//                print("失敗した")
//            }
//
//            let archivePath = url.appendingPathComponent("pic/pic.zip")
//            let targetFilePaths = ["\(url.appendingPathComponent("pic/pic.data").path)"]
//            let data = [models.texture_pic]
//            if !toZips(data: data, archivePath: archivePath.path, targetFilePaths: targetFilePaths) {
//                print("zip化失敗")
//            } else {
//                print("zip化成功")
//                let dataStore = Firestore.firestore()
//                dataStore.collection("\(section_num!)\(cell_num!)").document("pic").setData([
//                    "data": try! Data(contentsOf: archivePath)
//                ]) { err in
//                    if let err = err {
//                        print("Error writing document: \(err)")
//                    } else {
//                        //print("zipPicをFireStoreに書き込み完了")
//                    }
//                }
//            }
//        }
//    }
//
//    func saveWorldDataDocument() {
//        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
//            //フォルダ作成
//            let directory = url.appendingPathComponent("world", isDirectory: true)
//            do {
//                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
//            } catch {
//                print("失敗した")
//            }
//
//            let archivePath = url.appendingPathComponent("world/world.zip")
//            let targetFilePaths = ["\(url.appendingPathComponent("world/world.data").path)"]
//            let data = [models.worlddata]
//            if !toZips(data: data, archivePath: archivePath.path, targetFilePaths: targetFilePaths) {
//                print("zip化失敗")
//            } else {
//                print("zip化成功")
//                let dataStore = Firestore.firestore()
//                dataStore.collection("\(section_num!)\(cell_num!)").document("world").setData([
//                    "data": try! Data(contentsOf: archivePath)
//                ]) { err in
//                    if let err = err {
//                        print("Error writing document: \(err)")
//                    } else {
//                        //print("zipPicをFireStoreに書き込み完了")
//                    }
//                }
//            }
//        }
//    }
//
//    func saveDocument() {
//        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
//            for num in 0..<models.mesh_anchor.count {
//                //フォルダ作成
//                let directory = url.appendingPathComponent("\(num)", isDirectory: true)
//                do {
//                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
//                } catch {
//                    print("失敗した")
//                }
//
//                let archivePath = url.appendingPathComponent("\(num)/mesh.zip")
//                let targetFilePaths = ["\(url.appendingPathComponent("\(num)/mesh.data").path)",
//                                       "\(url.appendingPathComponent("\(num)/texcoords.data").path)",
//                                       "\(url.appendingPathComponent("\(num)/vertices.data").path)",
//                                       "\(url.appendingPathComponent("\(num)/normals.data").path)",
//                                       "\(url.appendingPathComponent("\(num)/faces.data").path)"]
//                let data = [models.mesh_anchor[num].mesh, models.mesh_anchor[num].texcoords, models.mesh_anchor[num].vertices, models.mesh_anchor[num].normals, models.mesh_anchor[num].faces]
//
//                if !toZips(data: data, archivePath: archivePath.path, targetFilePaths: targetFilePaths) {
//                    print("zip化失敗")
//                } else {
//                    //print("zip\(num) : 成功")
//                    zipSaveFireStore(num: num, archivePath: archivePath)
//                }
//            }
//        }
//    }
//
//    func zipSaveFireStore(num: Int, archivePath: URL) {
//        let dataStore = Firestore.firestore()
//        dataStore.collection("\(section_num!)\(cell_num!)").document("data\(num)").setData([
//            "data": try! Data(contentsOf: archivePath)
//        ]) { err in
//            //DispatchQueue.main.async {
//                if let err = err {
//                    print("Error writing document: \(err)")
//                } else {
//                    //print("zipをFireStoreに書き込み完了")
//                    if num == self.models.mesh_anchor.count - 1 {
//                        SVProgressHUD.dismiss()
//                        print("書き込み終了")
//                    }
//                }
//            //}
//        }
//    }
//
//    func zipReadFireStore(completionHandler: @escaping () -> ()) {
//        let dataStore = Firestore.firestore()
//        dataStore.collection("\(section_num!)\(cell_num!)").getDocuments() { (querySnapshot, err) in
//            if let err = err {
//                print("Error getting documents: \(err)")
//            } else {
//                for (i, document) in querySnapshot!.documents.enumerated() {
//                    //print(document)
//                    let data = document.data()["data"]! as! Data
//
//                    //保存
//                    guard let dirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
//                        fatalError("フォルダURL取得エラー")
//                    }
//                    let path_file_name = dirURL.appendingPathComponent( "zip\(i).zip" )
//                    let unzipURL = dirURL.appendingPathComponent("unzip\(i)")
//
//                    try? data.write(to: path_file_name)
//                    //解凍処理
//                    let unzip = SSZipArchive.unzipFile(atPath: path_file_name.path, toDestination: unzipURL.path)
//                    if unzip {
//                        //print("解凍成功")
//                    }
//
//                }
//                completionHandler()
//            }
//        }
//    }
//
//    func buildNode() {
//        guard let dirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
//            fatalError("フォルダURL取得エラー")
//        }
//
//        //let picURL = dirURL.appendingPathComponent("pic/pic.data")
//        //let pic = UIImage(data: try! Data(contentsOf: picURL))
//
//        var pic: UIImage!
//        let docRef = Firestore.firestore().collection("\(section_num!)\(cell_num!)").document("pic")
//        docRef.getDocument { (document, error) in
//            if let document = document, document.exists {
//                let data = document.get("data") as! Data //data()!["data"]! as! Data
//                pic = UIImage(data: data)
//                print("pic読み込み")
//            } else {
//                print("Document does not exist")
//            }
//        }
//
//        for i in 0..<models.mesh_anchor.count {
//            let verticesURL = dirURL.appendingPathComponent("unzip\(i)/vertices.data")
//            let normalsURL = dirURL.appendingPathComponent("unzip\(i)/normals.data")
//            let facesURL = dirURL.appendingPathComponent("unzip\(i)/faces.data")
//            let texcoordsURL = dirURL.appendingPathComponent("unzip\(i)/texcoords.data")
//
//            let vertexData = try! Data(contentsOf: verticesURL)
//            let normalData = try! Data(contentsOf: normalsURL)
//
//            let faces = (try? decoder.decode([Int32].self, from: try! Data(contentsOf: facesURL)))!
//            let texcoords = (try? decoder.decode([SIMD2<Float>].self, from: try! Data(contentsOf: texcoordsURL)))!
//            let count = faces.count
//
//            let verticeSource = SCNGeometrySource(
//                data: vertexData,
//                semantic: SCNGeometrySource.Semantic.vertex,
//                vectorCount: count,
//                usesFloatComponents: true,
//                componentsPerVector: 3,
//                bytesPerComponent: MemoryLayout<Float>.size,
//                dataOffset: 0,
//                dataStride: MemoryLayout<SIMD3<Float>>.size
//            )
//            let normalSource = SCNGeometrySource(
//                data: normalData,
//                semantic: SCNGeometrySource.Semantic.normal,
//                vectorCount: count,
//                usesFloatComponents: true,
//                componentsPerVector: 3,
//                bytesPerComponent: MemoryLayout<Float>.size,
//                dataOffset: MemoryLayout<Float>.size * 3,
//                dataStride: MemoryLayout<SIMD3<Float>>.size
//            )
//            let faceSource = SCNGeometryElement(indices: faces, primitiveType: .triangles)
//            let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords)
//
//            let nodeGeometry = SCNGeometry(sources: [verticeSource, normalSource, textureCoordinates], elements: [faceSource])
//            nodeGeometry.firstMaterial?.diffuse.contents = pic
//
//            let node = SCNNode(geometry: nodeGeometry)
//            texmeshNode.addChildNode(node)
//        }
//    }
    
    //複数のファイルのzip化
    private func toZips(data: [Data?], archivePath: String, targetFilePaths: [String]) -> Bool {
        for (i,path) in targetFilePaths.enumerated() {
            FileManager.default.createFile(atPath: path, contents: data[i], attributes: nil)
        }
        return SSZipArchive.createZipFile(atPath: archivePath, withFilesAtPaths: targetFilePaths)
    }
    
    //単一ファイルのzip化
    private func toZip(data: Data, archivePath: String, targetFilePaths: [String]) -> Bool {
        targetFilePaths.forEach { path in
            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        }
        return SSZipArchive.createZipFile(atPath: archivePath, withFilesAtPaths: targetFilePaths)
    }
    
}
