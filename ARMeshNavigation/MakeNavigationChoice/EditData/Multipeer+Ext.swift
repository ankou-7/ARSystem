//
//  Multipeer+Ext.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/18.
//

import MultipeerConnectivity

extension EditDataController {
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async() { [self] in
            switch state {
                case MCSessionState.connected: //接続中
                    print("Connected: \(peerID.displayName)")
                    colabInfoLabel.text = "Connecting: \(peerID.displayName)"
                    browserButton.isHidden = true
                    colabStopButton.isHidden = false
                case MCSessionState.connecting: //接続開始時
                    print("Connecting: \(peerID.displayName)")
                    colabInfoLabel.text = "Connecting: \(peerID.displayName)"
                case MCSessionState.notConnected: //接続中断
                    print("Not Connected: \(peerID.displayName)")
                    colabInfoLabel.text = "Not Connect"
                    browserButton.isHidden = false
                    colabStopButton.isHidden = true
                @unknown default:
                    colabInfoLabel.text = "Not Connect"
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
    }
    
    //MARK: - データ送信関数
    
    func send_meshData() {
        print("送信")
        guard let startData = try? NSKeyedArchiver.archivedData(withRootObject: "メッシュ送信開始:\(anchors.count)" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(startData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        //テクスチャData
        try? self.session.send(results[section_num].cells[cell_num].models[current_model_num].texture_pic!, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        //メッシュData
        for i in 0..<anchors.count {
            let vertexData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertices!
            let normalData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].normals!
            let count = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertice_count
            let facesData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].faces!
            let texcoordsData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].texcoords!
            
            guard let countData = try? NSKeyedArchiver.archivedData(withRootObject: "\(count)" as NSString, requiringSecureCoding: true)
            else { return }
            try? self.session.send(countData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
            try? self.session.send(vertexData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable) //
            try? self.session.send(normalData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable) //
            try? self.session.send(facesData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable) //
            try? self.session.send(texcoordsData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable) //
        }
    }
    
    func send_worldmapData() {
        guard let startData = try? NSKeyedArchiver.archivedData(withRootObject: "ワールドマップ送信開始" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(startData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        //スキャンのヒントになる画像
        try? self.session.send(results[section_num].cells[cell_num].models[current_model_num].worldimage!, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        //worldmap
        try? self.session.send(results[self.section_num].cells[self.cell_num].models[self.current_model_num].worlddata! as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
    }
    
    func send_ObjectData(state: String, name: String, name_identify: String, type: String, info_data: Data) {
        guard let startData = try? NSKeyedArchiver.archivedData(withRootObject: "オブジェクト\(state)情報送信開始" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(startData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        guard let StringData = try? NSKeyedArchiver.archivedData(withRootObject: "\(name):\(name_identify):\(type)" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(StringData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        try? self.session.send(info_data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
    }
    
    func send_operateObjectData(state: String, name_identify: String, info_data: Data) {
        guard let startData = try? NSKeyedArchiver.archivedData(withRootObject: "オブジェクト\(state)情報送信開始" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(startData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        guard let StringData = try? NSKeyedArchiver.archivedData(withRootObject: "\(name_identify)" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(StringData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        try? self.session.send(info_data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
    }
    
    func send_deleteObjectData(state: String, name_identify: String) {
        guard let startData = try? NSKeyedArchiver.archivedData(withRootObject: "オブジェクト\(state)情報送信開始" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(startData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        guard let StringData = try? NSKeyedArchiver.archivedData(withRootObject: "\(name_identify)" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(StringData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
    }
    
    func send_remoteSupportObjectData(state: String, name_identify: String, info_data_array: [Data]) {
        guard let startData = try? NSKeyedArchiver.archivedData(withRootObject: "オブジェクト\(state)情報送信開始" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(startData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        try? self.session.send(info_data_array[0], toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        try? self.session.send(info_data_array[1], toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
    }
    
}
