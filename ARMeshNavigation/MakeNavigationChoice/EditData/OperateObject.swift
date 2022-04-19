//
//  OperateObject.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/19.
//

import SceneKit
import RealmSwift

extension EditDataController {
    
    func makeNodeData(node: SCNNode) -> Data {
        let entity = ObjectInfo_data(Position: Vector3Entity(x: node.position.x,
                                                             y: node.position.y,
                                                             z: node.position.z),
                                     Scale: Vector3Entity(x: (node.scale.x),
                                                          y: (node.scale.y),
                                                          z: (node.scale.z)),
                                     EulerAngles: Vector3Entity(x: (node.eulerAngles.x),
                                                                y: (node.eulerAngles.y),
                                                                z: (node.eulerAngles.z)))
        let json_data = try! JSONEncoder().encode(entity)
        return json_data
    }
    
    func placeObject(node: SCNNode) {
        let json_data = makeNodeData(node: node)
        let realm = try! Realm()
        try! realm.write {
            results[section_num].cells[cell_num].models[current_model_num].add_obj_count += 1
            results[section_num].cells[cell_num].models[current_model_num].obj.append(ObjectInfo(
                value: ["name": item.name,
                        "name_identify": node.name!,
                        "type": item.kind,
                        "info_data": json_data]))
        }
        
        //配置
        send_ObjectData(state: "配置", name: item.name, name_identify: node.name!, type: item.kind, info_data: json_data)
    }
    
    func operateObject(node: SCNNode) {
        let json_data = makeNodeData(node: node)
        //移動，拡大，縮小，回転
        send_operateObjectData(state: "操作", name_identify: choiceNode_name, info_data: json_data)
    }
    
    func saveObject(node: SCNNode) {
        let json_data = makeNodeData(node: node)
        let num = objectName_array.firstIndex(of: choiceNode_name)!
        let realm = try! Realm()
        try! realm.write {
            results[section_num].cells[cell_num].models[current_model_num].obj[num].info_data = json_data
        }
        
        //移動，拡大，縮小，回転
        send_operateObjectData(state: "操作", name_identify: choiceNode_name, info_data: json_data)
    }
}

