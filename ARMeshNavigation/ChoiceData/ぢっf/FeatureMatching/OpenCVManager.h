//
//  OpenCVManager.h
//  ARMesh
//
//  Created by yasue kouki on 2021/06/23.
//

#ifndef OpenCVManager_h
#define OpenCVManager_h

#import <UIKit/UIKit.h>

//OpenCVマネージャ
@interface OpenCVManager : NSObject
+ (UIImage*)rgb2gray:(UIImage*)image;
+ (UIImage*)akaze:(UIImage*)image:(UIImage*)image2;
+ (UIImage*)akaze2:(UIImage*)image:(UIImage*)image2:(NSMutableArray*)center;
+ (UIImage*)orb:(UIImage*)image;
@end


#endif /* OpenCVManager_h */
