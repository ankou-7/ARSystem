//
//  Information.swift
//  ARMesh
//
//  Created by 安江洸希 on 2020/10/21.
//

import Foundation
import RealmSwift
import UIKit

//MARK: -
class Navi_SectionTitle: Object {
    @objc dynamic var sectionid: Int = 0
    @objc dynamic var sectionName: String = ""
    
    @objc dynamic var add_section_count: Int = -1
    @objc dynamic var add_cell_count: Int = -1
    
    let cells = List<Navi_CellTitle>()
}

class Navi_CellTitle: Object {
    @objc dynamic var cellName: String = ""
    
    let models = List<Navi_Modelname>()
}

class Navi_Modelname: Object {
    @objc dynamic var modelname: String = ""
    @objc dynamic var dayString: String = ""
    @objc dynamic var worlddata: Data!
    @objc dynamic var worldimage: Data!
    @objc dynamic var exit_mesh: Int = 0
    @objc dynamic var exit_point: Int = 0
    
    let usdz = List<Navi_Usdz_ModelInfo>()
    
    let pic = List<pic_data>()
    let json = List<json_data>()
}

class Navi_Usdz_ModelInfo: Object {
    @objc dynamic var usdz_name: String = ""
    @objc dynamic var usdz_num: Int = 0
    @objc dynamic var usdz_posi_x: Float = 0.0
    @objc dynamic var usdz_posi_y: Float = 0.0
    @objc dynamic var usdz_posi_z: Float = 0.0
    @objc dynamic var usdz_scale_x: Float = 0.0
    @objc dynamic var usdz_scale_y: Float = 0.0
    @objc dynamic var usdz_scale_z: Float = 0.0
    @objc dynamic var usdz_euler_x: Float = 0.0
    @objc dynamic var usdz_euler_y: Float = 0.0
    @objc dynamic var usdz_euler_z: Float = 0.0
}

//section,cell格納前のモデル情報を格納
//navityu → Navi_SectionTitleで格納していく
class Navityu: Object {
    @objc dynamic var modelname: String = ""
    @objc dynamic var dayString: String = ""
    @objc dynamic var worlddata: Data!
    @objc dynamic var worldimage: Data!
    @objc dynamic var exit_mesh: Int = 0
    @objc dynamic var exit_point: Int = 0
    @objc dynamic var exit_parameta: Int = 0
    
    let usdz = List<Navi_Usdz_ModelInfo>()
}

//内部パラメータ
class in_parameta: Object {
    @objc dynamic var rgb_image: Data!
    @objc dynamic var depth_image: Data!
}

//内部パラメータ用
class Data_parameta: Object {
    @objc dynamic var modelname: String = ""
    
    let pic = List<pic_data>()
    let json = List<json_data>()
}

class pic_data: Object {
    @objc dynamic var pic_name: String = ""
    @objc dynamic var pic_data: Data!
}

class json_data: Object {
    @objc dynamic var json_name: String = ""
    @objc dynamic var json_data: Data!
}


//メッシュアンカー用
class Anchors_data: Object {
    @objc dynamic var num: Int = 0
    @objc dynamic var pic: Data!
    
    let anchor = List<anchor_data>()
}

class anchor_data: Object {
    @objc dynamic var mesh: Data!
    @objc dynamic var texcoords: Data!
}
