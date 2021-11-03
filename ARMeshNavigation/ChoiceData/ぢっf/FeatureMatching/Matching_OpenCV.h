//
//  Matching_OpenCV.h
//  ARMesh
//
//  Created by yasue kouki on 2021/07/04.
//

#ifndef Matching_OpenCV_h
#define Matching_OpenCV_h

#import <UIKit/UIKit.h>

@interface Matching_OpenCV : NSObject {
    UIImage *_image;
    //NSDictionary *_PointsDict;
    NSArray *_PointsArray;
    NSArray *_PointsArray2;
}
- (UIImage *)image; // 検出された点を描画した画像
//- (NSDictionary *)PointsDict; // 検出された点の (id, rect) の辞書
- (NSArray *)PointsArray;
- (NSArray *)PointsArray2;

//(返り値の型 *)関数名:(引数の型 *)引数名;
- (void)detectPoints:(UIImage *)input_img1:(UIImage *)input_img2;
@end

#endif /* Matching_OpenCV_h */
