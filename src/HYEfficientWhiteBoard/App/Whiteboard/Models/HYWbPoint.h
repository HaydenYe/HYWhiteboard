//
//  HYWbPoint.h
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/3/1.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, HYWbPointType){
    HYWbPointTypeStart    = 1,      // 开始点
    HYWbPointTypeMove     = 2,      // 移动中的点
    HYWbPointTypeEnd      = 3,      // 结束点
};


@interface HYWbPoint : NSObject

@property (nonatomic, assign)HYWbPointType  type;               // 点类型
@property (nonatomic, assign)Float32        xScale;             // x 轴比例
@property (nonatomic, assign)Float32        yScale;             // y 轴比例

@property (nonatomic, assign)uint8_t        colorIndex;         // 线的颜色
@property (nonatomic, assign)uint8_t        lineWidth;          // 线的宽度
@property (nonatomic, assign)BOOL           isEraser;           // 是否为橡皮的点

@end
