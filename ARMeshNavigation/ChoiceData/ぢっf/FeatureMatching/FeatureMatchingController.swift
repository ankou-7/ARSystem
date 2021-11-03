//
//  FeatureMatchingContller.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/06/23.
//

import UIKit
//import CoreImage.CIFilterBuiltins

class FeatureMatchingController: UIViewController {

    @IBOutlet weak var imageView1: UIImageView!
    @IBOutlet weak var imageView2: UIImageView!
    @IBOutlet weak var imageView3: UIImageView!
    @IBOutlet weak var time_label: UILabel!
    var image: UIImage!
    var image2: UIImage!
    
    let image_name1 = "try_74"
    let image_name2 = "try_184"
    
    let openCV = Matching_OpenCV()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let clipRect = CGRect(x: (1440.0-(834.0*1920.0)/1194.0), y: 0.0, width: ((2.0*834.0*1920.0)/1194.0), height: 3840.0)
        
//        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
//            let file_name = documentDirectoryFileURL.appendingPathComponent("rgb_\(image_name1).jpeg")
//            let Image1 = UIImage(contentsOfFile: file_name.path)
//
//            //let Image1 = UIImage.init(named: "rgb_try_1")!
//            let cripImageRef = Image1?.cgImage!.cropping(to: clipRect)
//            image = UIImage(cgImage: cripImageRef!)
//            print(image.size)
//            imageView2.image = image
//
//            let file_name2 = documentDirectoryFileURL.appendingPathComponent("rgb_\(image_name2).jpeg")
//            let Image2 = UIImage(contentsOfFile: file_name2.path)
//            //let Image2 = UIImage.init(named: "rgb_try_16")!
//            let cripImageRef2 = Image2?.cgImage!.cropping(to: clipRect)
//            image2 = UIImage(cgImage: cripImageRef2!)
//            imageView1.image = image2
//
//        }

        
        //imageView2.image = OpenCVManager.rgb2gray(image)
        //imageView1.image = UIImage.init(named: "try_1")
    }
    
    @IBAction func push_start(_ sender: UIButton) {
        let start = Date()
        //let circles = NSMutableArray()
        //imageView3.image = OpenCVManager.akaze2(image,image2, circles)
        
        openCV.detectPoints(image2, image)
        imageView3.image = openCV.image()
//        guard let points = openCV.pointsDict() else { return }
//        print(points)
        
        guard let pointsArray = openCV.pointsArray() else { return }
        //print(pointsArray)
        guard let pointsArray2 = openCV.pointsArray2() else { return }
        //print(pointsArray2)
        
        //let array = OpenCVManager.akaze2(image,image2)
        //imageView2.image = OpenCVManager.orb(image)
        let elapsed = Date().timeIntervalSince(start)
        time_label.text = "実行時間：" + String(round(elapsed*1000)/1000) + "s"
        print("実行時間：\(elapsed)")
    }
    
    @IBAction func push_Model(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Make3DModel", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "Make3DModelController") as! Make3DModelController
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
