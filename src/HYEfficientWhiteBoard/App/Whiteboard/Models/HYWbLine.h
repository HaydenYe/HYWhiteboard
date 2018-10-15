//
//  HYWbLine.h
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/10/14.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HYWbPoint.h"

NS_ASSUME_NONNULL_BEGIN

@interface HYWbLine : NSObject

@property (nonatomic, strong)NSMutableArray<HYWbPoint *> *points;           // 此条线中，所有的点
@property (nonatomic, copy)NSString                      *user;             // 画线所属用户
@property (nonatomic, strong)UIColor                     *color;            // 画线颜色
@property (nonatomic, assign)uint8_t                     lineWidth;         // 线的宽度
@property (nonatomic, assign)NSInteger                   lastLineIndex;     // 上一条次用户的画线在所有画线数组中的索引
@property (nonatomic, assign)NSInteger                   lineIndex;         // 此画线在所有画线数组中的索引

@end

NS_ASSUME_NONNULL_END
