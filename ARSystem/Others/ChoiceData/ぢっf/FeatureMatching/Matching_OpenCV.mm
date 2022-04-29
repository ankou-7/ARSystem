//
//  Matching_OpenCV.m
//  ARMesh
//
//  Created by yasue kouki on 2021/07/04.
//

#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/core.hpp>
#import <opencv2/features2d.hpp>
#import "Matching_OpenCV.h"

@implementation Matching_OpenCV
- (UIImage *)image { return _image; };
//- (NSDictionary *)PointsDict { return _PointsDict; }
- (NSArray *)PointsArray {return _PointsArray; }
- (NSArray *)PointsArray2 {return _PointsArray2; }

- (void)detectPoints:(UIImage *)input_img1:(UIImage *)input_img2 {
    
    //横：2880，縦：3840
    cv::Mat img_Mat, img_Mat2;
    UIImageToMat(input_img1, img_Mat);
    UIImageToMat(input_img2, img_Mat2);
    
    // 特徴点抽出
    std::vector<cv::KeyPoint> keypoints, keypoints2;
    // 特徴記述
    cv::Mat descriptor1, descriptor2;
    
    cv::AKAZE::create()->detectAndCompute(img_Mat, cv::noArray(), keypoints, descriptor1);
    cv::AKAZE::create()->detectAndCompute(img_Mat2, cv::noArray(), keypoints2, descriptor2);
    
    //true：クロスチェックを行う
    cv::BFMatcher matcher(cv::NORM_HAMMING, true);
    //cv::Ptr<cv::DescriptorMatcher> matcher = cv::DescriptorMatcher::knnMatch;
    std::vector<cv::DMatch> nn_matches;
    matcher.match(descriptor1, descriptor2, nn_matches);
    //matcher.//knnMatch(descriptor1, descriptor2, 2);
    
    printf("マッチした特徴点の個数=%lu\n",nn_matches.size());
    
    // 特徴量距離の小さい順にソートする（選択ソート）
    for (int i = 0; i < nn_matches.size() - 1; i++) {
        double min = nn_matches[i].distance;
        int n = i;
        for (int j = i + 1; j < nn_matches.size(); j++) {
            if (min > nn_matches[j].distance) {
                n = j;
                min = nn_matches[j].distance;
            }
        }
        std::swap(nn_matches[i], nn_matches[n]);
    }
    
    printf("マッチした特徴点の距離=%f\n",nn_matches[0].distance);
    printf("%d\n",nn_matches[0].queryIdx);
    printf("%d\n",nn_matches[0].trainIdx);
    printf("%d\n",nn_matches[0].imgIdx);
    
    printf("マッチした特徴点の距離=%f\n",nn_matches[nn_matches.size()-1].distance);
    
    for (int i = 0; i < nn_matches.size() - 1; i++) {
        //printf("%f\n",nn_matches[i].distance);
    }
    
    // 上位50点を残して、残りのマッチング結果を削除する。
    nn_matches.erase(nn_matches.begin() + 500, nn_matches.end());
    
    // マッチング結果の描画
    cv::Mat dest;
    cv::drawMatches(img_Mat, keypoints, img_Mat2, keypoints2, nn_matches, dest);
    
    UIImage * output_img = MatToUIImage(dest);
    _image = output_img;

    
//    NSMutableDictionary *mutableDict =  [@{} mutableCopy];
//    for (int i=0; i<nn_matches.size(); i++) {
//        auto id = i;
//        NSNumber* markerId = [NSNumber numberWithInt:id];
//        NSMutableArray* corner = [[NSMutableArray alloc] initWithCapacity:2];
//        [corner addObject:[NSValue valueWithCGPoint:CGPointMake(keypoints[nn_matches[i].queryIdx].pt.x, keypoints[nn_matches[i].queryIdx].pt.y)]];
//        mutableDict[markerId] = corner;
//    }
//    _PointsDict = mutableDict;
    
    NSMutableArray* mutableArray = [[NSMutableArray alloc] initWithCapacity:2];
    NSMutableArray* mutableArray2 = [[NSMutableArray alloc] initWithCapacity:2];
    for (int i=0; i<nn_matches.size(); i++) {
        [mutableArray addObject:[NSValue valueWithCGPoint:CGPointMake(keypoints[nn_matches[i].queryIdx].pt.x, keypoints[nn_matches[i].queryIdx].pt.y)]];
        [mutableArray2 addObject:[NSValue valueWithCGPoint:CGPointMake(keypoints2[nn_matches[i].trainIdx].pt.x, keypoints2[nn_matches[i].trainIdx].pt.y)]];
    }
    _PointsArray = mutableArray;
    _PointsArray2 = mutableArray2;
}
@end
