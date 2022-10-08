//
//  MenuDataSource.swift
//  ARMeshNavigation
//
//  Created by yasue kouki on 2021/04/19.
//

import UIKit

struct MenuItem {
    let title: String
    let description: String
}

class MenuViewModel {
    private let dataSource = [
        MenuItem (
            title: "原点の表示",
            description: "ワールド座標系の原点表示を行うか"
        ),
        MenuItem (
            title: "メッシュの非表示",
            description: "メッシュを非表示する"
        ),
        MenuItem (
            title: "点群の表示",
            description: "点群を表示する"
        ),
        MenuItem (
            title: "原点の更新",
            description: "マップ作成毎に原点を更新する"
        ),
        MenuItem (
            title: "マッピングの支援の停止",
            description: "マッピングの可視化を停止するか"
        ),
        MenuItem (
            title: "メッシュの表示",
            description: "マッピング中にメッシュを表示するか"
        ),
    ]
    
    var count: Int {
        dataSource.count
    }
    
    func item(row: Int) -> MenuItem {
        dataSource[row]
    }
}
