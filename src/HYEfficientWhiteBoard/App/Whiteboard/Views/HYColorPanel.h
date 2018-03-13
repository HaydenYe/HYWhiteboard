//
//  HYColorPanel.h
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/2/27.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol HYColorPanelDelegate <NSObject>

// 点击按钮的代理
- (void)onClickColorPanelButton:(UIButton *)button;

@end


@interface HYColorPanel : UIView

@property (nonatomic, weak)id<HYColorPanelDelegate> delegate;   // 代理

@property (nonatomic, strong)NSArray *colorArr;                 // 颜色数组
@property (nonatomic, strong)NSArray *lineWidthArr;             // 画线粗细数组

@end
