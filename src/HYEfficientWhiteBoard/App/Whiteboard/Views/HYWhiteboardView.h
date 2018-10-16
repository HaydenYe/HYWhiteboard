//
//  HYWhiteboardView.h
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/2/28.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HYWbAllLines.h"

extern NSString *const UserOfLinesMine;         // 自己画线的key
extern NSString *const UserOfLinesOther;        // 其他人画线的key


@protocol HYWbDataSource <NSObject>

// 所有的画线
- (HYWbAllLines *)allLines;

// 当前是否为橡皮擦模式
- (BOOL)isEraser;

// 需要更新视图
- (BOOL)needUpdate;

@end


@interface HYWhiteboardView : UIView

@property (nonatomic, weak)id<HYWbDataSource> dataSource;      // 白板数据源


/**
 打开或停止渲染画线的计时器

 @param start 开始或停止计时器
 */
- (void)startCADisplayLink:(BOOL)start;


/**
 渲染橡皮的画线

 @param wbPoint 橡皮点
 */
- (void)drawEraserLineByPoint:(HYWbPoint *)wbPoint;

@end
