//
//  ObjectDataSource.swift
//  ARMeshNavigation
//
//  Created by yasue kouki on 2021/04/27.
//

import UIKit

struct ObjectItem {
    let name: String
    let id: Int
    let kind: String
}

class ObjectModel {
    private let dataSource = [
        ObjectItem (
            name: "arrow100",
            id: 6,
            kind: "scn"
        ),
        ObjectItem (
            name: "toy_drummer",
            id: 0,
            kind: "usdz"
        ),
        ObjectItem (
            name: "toy_robot_vintage",
            id: 1,
            kind: "usdz"
        ),
        ObjectItem (
            name: "chair_swan",
            id: 2,
            kind: "usdz"
        ),
        ObjectItem (
            name: "toy_biplane",
            id: 3,
            kind: "usdz"
        ),
        ObjectItem (
            name: "tv_retro",
            id: 4,
            kind: "usdz"
        ),
        ObjectItem (
            name: "flower_tulip",
            id: 5,
            kind: "usdz"
        ),
//        ObjectItem (
//            name: "start",
//            id: 6,
//            kind: "scn"
//        ),
//        ObjectItem (
//            name: "goal",
//            id: 7,
//            kind: "scn"
//        ),
//        ObjectItem (
//            name: "kirikae",
//            id: 8,
//            kind: "scn"
//        ),
    ]
    
    var count: Int {
        dataSource.count
    }
    
    func item(row: Int) -> ObjectItem {
        dataSource[row]
    }
}
