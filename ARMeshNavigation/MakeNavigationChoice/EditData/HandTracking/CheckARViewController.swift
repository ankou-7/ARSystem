//
//  ARViewController.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/11/20.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift
import Vision
import AVFoundation

class CheckARViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, TrackerDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    let scene = SCNScene()
    
    var handPoseRequest = [VNDetectHumanHandPoseRequest]()
    
    let tracker: HandTracker = HandTracker()!
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.showsStatistics = true
        sceneView.debugOptions = [.showWorldOrigin]
        
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
        
        tracker.startGraph()
        tracker.delegate = self
        
//        let request = VNDetectHumanHandPoseRequest { (request, error) in
//            DispatchQueue.main.async(execute: {
//                if let results = request.results {
//                     self.RequestResults(results)
//                }
//            })
//        }
//        request.maximumHandCount = 1 // 検出するての数
//        handPoseRequest = [request]
//        loopUpdate()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        //imageView.image = drawFaceRectangle(points: [CGPoint(x: 100,y: 100)])
    }
    
    func handTracker(_ handTracker: HandTracker!, didOutputLandmarks landmarks: [Landmark]!) {
        for mark in landmarks {
            if mark.x == 0.0 || mark.y == 0.0 {
                return
            }
        }
        //print(landmarks)
        //print(landmarks.count)
        //makeThita(landmarks: landmarks)
        print(detectFingerPose(landmarks: landmarks))
        
        
        //print("(x, y, z) = \(landmarks[8].x), \(landmarks[8].y), \(landmarks[8].z)")
//        for mark in landmarks {
//            print("(x, y, z) = \(mark.x), \(mark.y), \(mark.z)")
//        }
    }
    
    // 2頂点の距離の計算
    func calcDistance(p0: Landmark, p1: Landmark) -> Float{
        let a1 = p1.x-p0.x
        let a2 = p1.y-p0.y
        return sqrt(a1*a1 + a2*a2)
    }
    
    // 3頂点の角度の計算
    func calcAngle(p0: Landmark, p1: Landmark, p2: Landmark) -> Float {
        let a1 = p1.x-p0.x
        let a2 = p1.y-p0.y
        let b1 = p2.x-p1.x
        let b2 = p2.y-p1.y
        let angle = acos( (a1*b1 + a2*b2) / sqrt((a1*a1 + a2*a2)*(b1*b1 + b2*b2)) ) * 180 / .pi
        return angle
    }
    
    // 指の角度の合計の計算
    func cancFingerAngle(p0: Landmark, p1: Landmark, p2: Landmark, p3: Landmark, p4: Landmark) -> Float {
        var result: Float = 0
        result += calcAngle(p0: p0, p1: p1, p2: p2)
        result += calcAngle(p0: p1, p1: p2, p2: p3)
        result += calcAngle(p0: p2, p1: p3, p2: p4)
        return result
    }
    
    func detectFingerPose(landmarks: [Landmark]) -> String {
        // 指のオープン・クローズ
        let thumbIsOpen = cancFingerAngle(p0: landmarks[0], p1: landmarks[1], p2: landmarks[2], p3: landmarks[3], p4: landmarks[4]) < 70
        let firstFingerIsOpen = cancFingerAngle(p0: landmarks[0], p1: landmarks[5], p2: landmarks[6], p3: landmarks[7], p4: landmarks[8]) < 100
        let secondFingerIsOpen = cancFingerAngle(p0: landmarks[0], p1: landmarks[9], p2: landmarks[10], p3: landmarks[11], p4: landmarks[12]) < 100
        let thirdFingerIsOpen = cancFingerAngle(p0: landmarks[0], p1: landmarks[13], p2: landmarks[14], p3: landmarks[15], p4: landmarks[16]) < 100
        let fourthFingerIsOpen = cancFingerAngle(p0: landmarks[0], p1: landmarks[17], p2: landmarks[18], p3: landmarks[19], p4: landmarks[20]) < 100
        
        // ジェスチャー
//        if (calcDistance(p0: landmarks[4], p1: landmarks[8]) < 0.1 && secondFingerIsOpen && thirdFingerIsOpen && fourthFingerIsOpen) {
//            return "OK"
//        } else if (calcDistance(p0: landmarks[4], p1: landmarks[12]) < 0.1 && calcDistance(p0: landmarks[4], p1: landmarks[16]) < 0.1 && firstFingerIsOpen && fourthFingerIsOpen) {
//            return "キツネ"
//        } else if (thumbIsOpen && !firstFingerIsOpen && !secondFingerIsOpen && !thirdFingerIsOpen && !fourthFingerIsOpen) {
//            return "いいね"
//        } else
        if (thumbIsOpen && firstFingerIsOpen && secondFingerIsOpen && thirdFingerIsOpen && fourthFingerIsOpen) {
            return "５"
        }
//        else if (!thumbIsOpen && firstFingerIsOpen && secondFingerIsOpen && thirdFingerIsOpen && fourthFingerIsOpen) {
//            return "４"
//        } else if (!thumbIsOpen && firstFingerIsOpen && secondFingerIsOpen && thirdFingerIsOpen && !fourthFingerIsOpen) {
//            return "３"
//        } else if (!thumbIsOpen && firstFingerIsOpen && secondFingerIsOpen && !thirdFingerIsOpen && !fourthFingerIsOpen) {
//            return "２"
//        } else if (!thumbIsOpen && firstFingerIsOpen && !secondFingerIsOpen && !thirdFingerIsOpen && !fourthFingerIsOpen) {
//            return "１"
//        }
        return "０"
    }
    
    func makeThita(landmarks: [Landmark]) {
        let a = 6
        let b = 5
        let c = 7
        let ve21_x = landmarks[b].x - landmarks[a].x
        let ve21_y = landmarks[b].y - landmarks[a].y
        let ve21_z = landmarks[b].z - landmarks[a].z
        
        let ve23_x = landmarks[c].x - landmarks[a].x
        let ve23_y = landmarks[c].y - landmarks[a].y
        let ve23_z = landmarks[c].z - landmarks[a].z
        
        let thita = (ve21_x * ve23_x + ve21_y * ve23_y + ve21_z * ve23_z) / (sqrt(ve21_x * ve21_x + ve21_y * ve21_y + ve21_z * ve21_z) * sqrt(ve23_x * ve23_x + ve23_y * ve23_y + ve23_z * ve23_z))
        print(acos(thita) * 180 / .pi)
    }
    
    func handTracker(_ handTracker: HandTracker!, didOutputPixelBuffer pixelBuffer: CVPixelBuffer!) {
        // mediapipeのほうでトラッキング位置に映像を付加した画像
        DispatchQueue.main.async {
            self.imageView.image = UIImage.init(ciImage: CIImage(cvPixelBuffer: pixelBuffer).oriented(CGImagePropertyOrientation(rawValue: 6)!))
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let captureImage: CVPixelBuffer = frame.capturedImage
        do {
            let bgraBuffer = try YCbCrImageBufferConverter().convertToBGRA(imageBuffer: captureImage)
            tracker.processVideoFrame(bgraBuffer)
            DispatchQueue.main.async {
                self.imageView.image = UIImage.init(ciImage: CIImage(cvPixelBuffer: bgraBuffer).oriented(CGImagePropertyOrientation(rawValue: 6)!))
            }
        } catch {
            print("fatal")
        }
    }
    
    func RequestResults(_ results: [Any]) {
        
        var recognizedPoints: [VNRecognizedPoint] = []
        //guard let observation = handPoseRequest.results?.first else { return }
        
        for observation in results where observation is VNHumanHandPoseObservation {
            guard let objectObservation = observation as? VNHumanHandPoseObservation else {
                continue
            }
            do {
                let fingers = try objectObservation.recognizedPoints(.all)
//                for fin in fingers {
//                    recognizedPoints.append(fin.value)
//                }
//                if let thumbTipPoint = fingers[.thumbTip] {
//                    recognizedPoints.append(thumbTipPoint)
//                }
                
                let fingerTips = fingers.values.filter {
                    $0.confidence > 0.0
                }.map {
                    CGPoint(x: $0.location.y*834, y: $0.location.x*1150)
                }
                
                imageView.image = drawFaceRectangle(points: fingerTips)
                
                for point in fingerTips {
                    print(point)
                }
            } catch {
                print("fatal")
            }
        }
    }
    
    private func drawFaceRectangle(points: [CGPoint]) -> UIImage? {
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        let uiImage = UIImage.init(ciImage: ciImage.oriented(CGImagePropertyOrientation(rawValue: 6)!))
        let imageSize = uiImage.size

        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
        let context = UIGraphicsGetCurrentContext()
        uiImage.draw(in: CGRect(origin: .zero, size: imageSize))
        context?.setLineWidth(4.0)
        context?.setStrokeColor(UIColor.green.cgColor)
        for point in points {
            context?.stroke(CGRect(x: point.x, y: point.y, width: 50, height: 50))
        }
        let drawnImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return drawnImage
    }
    
    func loopUpdate() {
        DispatchQueue.main.async {
            self.update_CaptureOutput()
            self.loopUpdate()
        }

    }

    func update_CaptureOutput() {
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }

        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        let uiImage = UIImage(ciImage: ciImage)
        
        //imageView.image = UIImage.init(ciImage: ciImage.oriented(CGImagePropertyOrientation(rawValue: 6)!))
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .up, options: [:])
        do {
            try handler.perform(handPoseRequest)
        } catch {
            print(error)
        }
    }
    
}
