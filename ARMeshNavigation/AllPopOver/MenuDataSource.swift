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
            title: "切り替えマーカの配置",
            description: "スキャン切り替え時に切り替え場所を示すためのマーカを配置するか"
        ),
        MenuItem (
            title: "マーカの手動配置",
            description: "マーカを手動で配置するか"
        ),
        MenuItem (
            title: "メッシュの非表示",
            description: "メッシュを非表示する"
        ),
        MenuItem (
            title: "点群の非表示",
            description: "点群を非表示する"
        ),
        MenuItem (
            title: "原点の更新",
            description: "マップ作成毎に原点を更新する"
        ),
    ]
    
    var count: Int {
        dataSource.count
    }
    
    func item(row: Int) -> MenuItem {
        dataSource[row]
    }
}
