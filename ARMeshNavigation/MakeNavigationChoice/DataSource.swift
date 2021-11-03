//
//  DataSource.swift
//  ARMeshNavigation
//
//  Created by yasue kouki on 2021/04/18.
//

import UIKit

struct Sample {
    let title: String
    let detail: String
    let classPrefix: String
    
//    func controller() -> UIViewController {
//        let storyboard = UIStoryboard(name: classPrefix, bundle: nil)
//        guard let controller = storyboard.instantiateInitialViewController() else {fatalError()}
//        controller.title = title
//        return controller
//    }
}

struct DataSource {
    let samples = [
        Sample(
            title: "新しく作成",
            detail: "新しくナビゲーション情報の作成を行います。目的地までの道を順番にマッピングして作成を行います。",
            classPrefix: "RealtimeDepth"
        ),
        Sample(
            title: "編集",
            detail: "作成済みのナビゲーション情報の編集を行います。新しく作成したものを追加したりオブジェクトの配置などが可能です。",
            classPrefix: "RealtimeDepthMask"
        ),
        Sample(
            title: "保存データの閲覧",
            detail: "",
            classPrefix: "DepthFromCameraRoll"
        ),
        ]
}
