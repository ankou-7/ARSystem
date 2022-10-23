//
//  DocumentsData.swift
//  ARSystem
//
//  Created by 安江洸希 on 2022/10/14.
//

import Foundation

class DataManagement {
    
    //ディレクトリ作成
    static func makeDirectory(name: String) {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let directory_pass = url.appendingPathComponent("\(name)", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: directory_pass, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("ディレクトリ作成：失敗")
            }
        }
    }
    
    //ディレクトリ削除
    static func removeDirectory(name: String) {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                try FileManager.default.removeItem(at: url.appendingPathComponent(name))
                print("ディレクトリ削除：成功")
            } catch _ {
                print("ディレクトリ削除：失敗 or 存在しない")
            }
        }
    }
    
    //データ保存
    static func saveData(name: String, Data: Data) {
        //ディレクトリ内にデータを保存
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let dataPath = url.appendingPathComponent("\(name)")
            do {
                try Data.write(to: dataPath)
            } catch {
                print("データ保存失敗", error)
            }
        }
    }
    
    //データ数取得
    static func getDataCount(name: String) {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let dataPath = url.appendingPathComponent("\(name)")
            do {
                let contentUrls = try FileManager.default.contentsOfDirectory(at: dataPath, includingPropertiesForKeys: nil)
                print(contentUrls.count)
//                let files = contentUrls.map{$0.lastPathComponent}
//                print(files)
            } catch {
                print(error)
            }
        }
    }
    
}
