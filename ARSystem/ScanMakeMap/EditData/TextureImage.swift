//
//  TextureImage.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import UIKit

class TextureImage {
    private var width: CGFloat
    private var height: CGFloat
    private var imageArray: [UIImage]
    private var yoko: Float
    private var num: CGFloat
    
    init(W: CGFloat, H: CGFloat, array: [UIImage], yoko: Float, num: CGFloat) {
        self.width = W
        self.height = H
        self.imageArray = array
        self.yoko = yoko
        self.num = num
    }
    
    func makeTexture() -> UIImage? {
        // 指定された画像の大きさのコンテキストを用意
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        
        //        let context = UIGraphicsGetCurrentContext()
        //        context!.setFillColor(UIColor.white.cgColor)
        
        var tate_count = -1
        for (i,image) in imageArray.enumerated() {
            if i % Int(yoko) == 0 {
                tate_count += 1
            }
            // コンテキストに画像を描画する
            image.draw(in: CGRect(x: CGFloat(i % Int(yoko)) * image.size.width/num, y: CGFloat(tate_count) * image.size.height/num, width: image.size.width/num, height: image.size.height/num))
        }
        // コンテキストからUIImageを作る
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    
    func triming(pointA: CGPoint, pointB: CGPoint) -> [CGPoint] {
        let Ax = Int(pointA.x)
        let Ay = Int(pointA.y)
        let Bx = Int(pointB.x)
        let By = Int(pointB.y)
        let n = abs(Bx - Ax) //横
        let m = abs(By - Ay) //縦
        
        var index: [CGPoint] = []
        var r_x = 1
        var r_y = -1
        if Bx - Ax < 0 {
            r_x = -1
        }
        if By - Ay > 0 {
            r_y = 1
        }
        
        if n == 0 {
            let nx = Ax
            var ny = Ay
            index.append(CGPoint(x: nx, y: ny))
            for _ in 1...m {
                ny += r_y
                index.append(CGPoint(x: nx, y: ny))
            }
        } else if m == 0 {
            var nx = Ax
            let ny = Ay
            index.append(CGPoint(x: nx, y: ny))
            for _ in 1...n {
                nx += r_x
                index.append(CGPoint(x: nx, y: ny))
            }
        } else {
            if m >= n {
                if (m % n) == 0 {
                    let p = m / n
                    var nx = Ax
                    var ny = Ay
                    index.append(CGPoint(x: nx, y: ny))
                    for _ in 1...n {
                        nx += r_x
                        for _ in 0..<p {
                            ny += r_y
                            index.append(CGPoint(x: nx, y: ny))
                        }
                    }
                }
                if (m % n) != 0 {
                    let p = Int(floor(Double(m / n)))//m / n
                    let q = m % n
                    //let r = Int(floor(Double(n / q)))
                    var nx = Ax
                    var ny = Ay
                    index.append(CGPoint(x: nx, y: ny))
                    for i in 1...n {
                        nx += r_x
                        for _ in 0..<p {
                            ny += r_y
                            index.append(CGPoint(x: nx, y: ny))
                        }
                        if i == n {
                            for _ in 0..<q {
                                ny += r_y
                                index.append(CGPoint(x: nx, y: ny))
                            }
                        }
                    }
                }
            } else if m < n {
                if (n % m) == 0 {
                    let p = m / n
                    var nx = Ax
                    var ny = Ay
                    index.append(CGPoint(x: nx, y: ny))
                    for _ in 1...m {
                        ny += r_y
                        for _ in 0..<p {
                            nx += r_x
                            index.append(CGPoint(x: nx, y: ny))
                        }
                    }
                }
                if (n % m) != 0 {
                    let p = Int(floor(Double(n / m)))//m / n
                    let q = m % n
                    var nx = Ax
                    var ny = Ay
                    index.append(CGPoint(x: nx, y: ny))
                    for i in 1...m {
                        ny += r_y
                        for _ in 0..<p {
                            nx += r_x
                            index.append(CGPoint(x: nx, y: ny))
                        }
                        if i == m {
                            for _ in 0..<q {
                                nx += r_x
                                index.append(CGPoint(x: nx, y: ny))
                            }
                        }
                    }
                }
            }
        }
        
        return index
    }
    
    func makeX(y: Int, pointA: CGPoint, pointB: CGPoint) -> Int {
        let a = Float(pointB.y - pointA.y) / Float(pointB.x - pointA.x)
        let x = (CGFloat(y) - pointA.y) / CGFloat(a) + pointA.x
        //print(x)
        return Int(round(x))
    }
    
    var pixelData: [UInt8] = []
    var new_pixelData: [UInt8] = [UInt8](repeating: 0, count: 44236800)
    
    func get_pixelData(pixelData: [UInt8], pointA: CGPoint, pointB: CGPoint, pointC: CGPoint) {
        //let XArray = [Int(pointA.x), Int(pointB.x), Int(pointC.x)]
        let YArray = [Int(pointA.y), Int(pointB.y), Int(pointC.y)]
        let points = [pointA, pointB, pointC]
        //let sortedXArray = XArray.enumerated().sorted{ $0.element < $1.element }.map{ $0.offset }
        let sortedYArray = YArray.enumerated().sorted{ $0.element < $1.element }.map{ $0.offset }
        //print(sortedYArray)
        
        //        XArray.sort()
        //        YArray.sort()
        //        print(XArray)
        //        print(YArray)
        
        for y in YArray[sortedYArray[0]]...YArray[sortedYArray[1]] {
            if (points[sortedYArray[1]].x < points[sortedYArray[2]].x) {
                let left = makeX(y: y, pointA: points[sortedYArray[0]], pointB: points[sortedYArray[1]])
                let right = makeX(y: y, pointA: points[sortedYArray[0]], pointB: points[sortedYArray[2]])
                //print("i, left, right = \(y), \(left), \(right)")
                if left < right {
                    for i in left...right {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                } else {
                    for i in right...left {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                }
            } else if (points[sortedYArray[1]].x > points[sortedYArray[2]].x) {
                let left = makeX(y: y, pointA: points[sortedYArray[0]], pointB: points[sortedYArray[2]])
                let right = makeX(y: y, pointA: points[sortedYArray[0]], pointB: points[sortedYArray[1]])
                //print("i, left, right = \(y), \(left), \(right)")
                if left < right {
                    for i in left...right {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                } else {
                    for i in right...left {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                }
            }
        }
        for y in YArray[sortedYArray[1]]...YArray[sortedYArray[2]] {
            if (points[sortedYArray[0]].x < points[sortedYArray[1]].x) {
                let left = makeX(y: y, pointA: points[sortedYArray[2]], pointB: points[sortedYArray[0]])
                let right = makeX(y: y, pointA: points[sortedYArray[2]], pointB: points[sortedYArray[1]])
                //print("i, left, right = \(y), \(left), \(right)")
                if left < right {
                    for i in left...right {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                } else {
                    for i in right...left {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                }
            } else if (points[sortedYArray[0]].x > points[sortedYArray[1]].x) {
                let left = makeX(y: y, pointA: points[sortedYArray[2]], pointB: points[sortedYArray[1]])
                let right = makeX(y: y, pointA: points[sortedYArray[2]], pointB: points[sortedYArray[0]])
                //print("i, left, right = \(y), \(left), \(right)")
                if left < right {
                    for i in left...right {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                } else {
                    for i in right...left {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                }
            }
        }
    }
    
    
    //        let image = UIImage(data: results[section_num].cells[cell_num].models[current_model_num].pic[0].pic_data!)
    //        imageView.image = image
    //        pixelData = (image?.cgImage!.pixelData())!
    //        //print(pixel_image)
    //        print(pixelData.count)
    //        print(pixelData[0..<20])
            
    //        var new_pixelData: [UInt8] = [UInt8](repeating: 0, count: pixelData!.count)
    //        for i in 4*2880*1000 ..< 4*2880*1050 + 1 {
    //            new_pixelData[i] = pixelData![i]
    //        }
    //        for (i, n) in pixelData!.enumerated() {
    //            if i > 4*2880*100 && i < 4*2880*1000 {
    //                new_pixelData.append(n)
    //            } else {
    //                new_pixelData.append(255)
    //            }
    //        }
    
    
}
