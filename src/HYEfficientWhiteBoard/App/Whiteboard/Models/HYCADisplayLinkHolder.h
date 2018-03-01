//
//  HYCADisplayLinkHolder.h
//  HYEfficientWhiteBoard
//
//  Created by apple on 2018/2/28.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class HYCADisplayLinkHolder;


@protocol HYCADisplayLinkHolderDelegate <NSObject>

// 在此回调中渲染
- (void)onDisplayLinkFire:(HYCADisplayLinkHolder *)holder
                 duration:(NSTimeInterval)duration
              displayLink:(CADisplayLink *)displayLink;

@end


@interface HYCADisplayLinkHolder : NSObject {
    
    CADisplayLink *_displayLink;
}

@property (nonatomic, weak)id<HYCADisplayLinkHolderDelegate>    delegate;       // 代理
@property (nonatomic, assign)NSInteger                          frameInterval;  // 默认为1，每秒刷新60次


// 开始启动渲染计时器
- (void)startCADisplayLinkWithDelegate:(id<HYCADisplayLinkHolderDelegate>)delegate;

// 停止计时器
- (void)stop;

@end
