//
//  OpenCVManager.m
//  ARMesh
//
//  Created by yasue kouki on 2021/06/23.
//

#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/core.hpp>
#import <opencv2/features2d.hpp>
#import "OpenCVManager.h"

//OpenCVマネージャ
@implementation OpenCVManager

//RGB→Gray
+ (UIImage*)rgb2gray:(UIImage*)image {
    cv::Mat img_Mat;
    UIImageToMat(image, img_Mat);
    cv::cvtColor(img_Mat, img_Mat, cv::COLOR_BGR2GRAY);
    return MatToUIImage(img_Mat);
}

//AKAZEを使ってみる
+ (UIImage*)akaze:(UIImage*)image:(UIImage*)image2 {
    //横：2880，縦：3840
    cv::Mat img_Mat, img_Mat2;
    UIImageToMat(image, img_Mat);
    UIImageToMat(image2, img_Mat2);
    
    // 特徴点抽出
    std::vector<cv::KeyPoint> keypoints, keypoints2;
    cv::AKAZE::create()->detect(img_Mat, keypoints);
    cv::AKAZE::create()->detect(img_Mat2, keypoints2);

    // 特徴記述
    cv::Mat descriptor1, descriptor2;
    cv::AKAZE::create()->compute(img_Mat, keypoints, descriptor1);
    cv::AKAZE::create()->compute(img_Mat2, keypoints2, descriptor2);
    
    // マッチング (アルゴリズムにはBruteForceを使用)
    cv::Ptr<cv::DescriptorMatcher> matcher = cv::DescriptorMatcher::create("BruteForce");
    std::vector<cv::DMatch> match, match12, match21;
    matcher->match(descriptor1, descriptor2, match12);
    matcher->match(descriptor2, descriptor1, match21);
    
    //クロスチェック(1→2と2→1の両方でマッチしたものだけを残して精度を高める)
    for (size_t i = 0; i < match12.size(); i++)
    {
        cv::DMatch forward = match12[i];
        cv::DMatch backward = match21[forward.trainIdx];
        if (backward.trainIdx == forward.queryIdx)
        {
            match.push_back(forward);
        }
    }
    
    printf("特徴点の個数=%lu\n",keypoints.size());
    printf("特徴点の個数2=%lu\n",keypoints2.size());
    printf("マッチした特徴点の個数=%lu\n",match12.size());
    printf("マッチした特徴点の個数2=%lu\n",match21.size());
    printf("対応点の個数=%lu\n",match.size());
    
    // 特徴点を描画
    cv::Mat dst_Mat;
    
    // マッチング結果の描画
    cv::Mat dest;
    cv::drawMatches(img_Mat, keypoints, img_Mat2, keypoints2, match, dest);
    
//
//    dst_Mat = img_Mat.clone();
//    printf("特徴点の個数=%lu",keypoints.size());
//    for(int i = 0; i < keypoints.size(); i++) {
//        cv::KeyPoint *point = &(keypoints[i]);
//        printf("(x = %lf,y = %lf)",point->pt.x, point->pt.y);
//        cv::Point center;
//        int radius;
//        center.x = cvRound(point->pt.x);
//        center.y = cvRound(point->pt.y);
//        radius = cvRound(point->size*0.25);
//
//        cv::circle(dst_Mat, center, radius, (255,0,0));
//    }
    
    return MatToUIImage(dest);
}

+ (UIImage*)akaze2:(UIImage*)image:(UIImage*)image2:(NSMutableArray*)center {
    //横：2880，縦：3840
    cv::Mat img_Mat, img_Mat2;
    UIImageToMat(image, img_Mat);
    UIImageToMat(image2, img_Mat2);
    
    // 特徴点抽出
    std::vector<cv::KeyPoint> keypoints, keypoints2;
    // 特徴記述
    cv::Mat descriptor1, descriptor2;
    
    cv::AKAZE::create()->detectAndCompute(img_Mat, cv::noArray(), keypoints, descriptor1);
    cv::AKAZE::create()->detectAndCompute(img_Mat2, cv::noArray(), keypoints2, descriptor2);
    
//    cv::AKAZE::create()->detect(img_Mat, keypoints);
//    cv::AKAZE::create()->detect(img_Mat2, keypoints2);
//    cv::AKAZE::create()->compute(img_Mat, keypoints, descriptor1);
//    cv::AKAZE::create()->compute(img_Mat2, keypoints2, descriptor2);
    
    cv::BFMatcher matcher(cv::NORM_HAMMING, true);
    //cv::Ptr<cv::DescriptorMatcher> matcher = cv::DescriptorMatcher::knnMatch;
    std::vector<cv::DMatch> nn_matches;
    matcher.match(descriptor1, descriptor2, nn_matches);
    //matcher.//knnMatch(descriptor1, descriptor2, 2);
    
    // マッチング (アルゴリズムにはBruteForceを使用)
//    cv::Ptr<cv::DescriptorMatcher> matcher = cv::DescriptorMatcher::create("BruteForce");
//    std::vector<cv::DMatch> match, match12, match21;
//    matcher->match(descriptor1, descriptor2, match12);
//    matcher->match(descriptor2, descriptor1, match21);
    
//    //クロスチェック(1→2と2→1の両方でマッチしたものだけを残して精度を高める)
//    for (size_t i = 0; i < match12.size(); i++)
//    {
//        cv::DMatch forward = match12[i];
//        cv::DMatch backward = match21[forward.trainIdx];
//        if (backward.trainIdx == forward.queryIdx)
//        {
//            match.push_back(forward);
//        }
//    }
    
//    //特徴量がある程度近いもののみピックアップする
//    std::vector<cv::DMatch> goodMatches;
//    for (int i = 0; i < nn_matches.size(); i++){
//        if (nn_matches[i].distance < 25){
//            goodMatches.push_back(nn_matches[i]);
//        }
//    }
    
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
    
    // 上位50点を残して、残りのマッチング結果を削除する。
    nn_matches.erase(nn_matches.begin() + 20, nn_matches.end());
    
    //マッチした点のインデックスから座標を取得
    std::vector<cv::KeyPoint> match_cordinates;
    std::vector<std::vector<float>> cordinates;
    for (int i = 0; i < nn_matches.size() - 1; i++) {
//        cordinates[i].push_back(keypoints[nn_matches[i].queryIdx].pt.x);
//        cordinates[i].push_back(keypoints[nn_matches[i].queryIdx].pt.y);
        cordinates[i][0] = keypoints[nn_matches[i].queryIdx].pt.x;
        //std::cout << "x = " << cordinates[i][0] << ", y = " << cordinates[i][1] <<"\n";
    }
    
//
//    printf("特徴点の個数=%lu\n",keypoints.size());
//    printf("特徴点の個数2=%lu\n",keypoints2.size());
//    printf("マッチした特徴点の個数=%lu\n",match12.size());
//    printf("マッチした特徴点の個数2=%lu\n",match21.size());
//    printf("対応点の個数=%lu\n",match.size());
    printf("%f\n",nn_matches[1].distance);
    printf("%d\n",nn_matches[1].imgIdx);
    printf("%d\n",nn_matches[1].queryIdx);
    printf("%d\n",nn_matches[1].trainIdx);
    printf("対応点の個数=%lu\n",nn_matches.size());
    //printf("対応点の個数=%lu\n",goodMatches.size());
    
    // 特徴点を描画
    cv::Mat dst_Mat;
    
    // マッチング結果の描画
    cv::Mat dest;
    cv::drawMatches(img_Mat, keypoints, img_Mat2, keypoints2, nn_matches, dest);
    
    return MatToUIImage(dest);
}


//ORBを使ってみる
+ (UIImage*)orb:(UIImage*)image {
    cv::Mat img_Mat;
    UIImageToMat(image, img_Mat);
    
    // 特徴点抽出
    std::vector<cv::KeyPoint> keypoints;
    cv::ORB::create()->detect(img_Mat, keypoints);
    
    // 特徴点を描画
    cv::Mat dst_Mat;
    
    dst_Mat = img_Mat.clone();
    for(int i = 0; i < keypoints.size(); i++) {
        cv::KeyPoint *point = &(keypoints[i]);
        cv::Point center;
        int radius;
        center.x = cvRound(point->pt.x);
        center.y = cvRound(point->pt.y);
        radius = cvRound(point->size*0.25);
        
        cv::circle(dst_Mat, center, radius, (static_cast<void>(255),static_cast<void>(255),0));
    }
    
    return MatToUIImage(dst_Mat);
}
@end
