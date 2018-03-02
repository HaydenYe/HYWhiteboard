//
//  HYColorPanel.m
//  HYEfficientWhiteBoard
//
//  Created by apple on 2018/2/27.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import "HYColorPanel.h"

@implementation HYColorPanel

- (instancetype)init {
    if (self = [super init]) {
        _colorArr = @[COLOR_WITH_HEX(0x326ed9, 1.f), COLOR_WITH_HEX(0x306c00, 1.f), COLOR_WITH_HEX(0x66d552, 1.f), COLOR_WITH_HEX(0xff1ecf, 1.f), COLOR_WITH_HEX(0x4ea1b7, 1.f), [UIColor clearColor]];
        _lineWidthArr = @[@3, @6, @9];
        
        self.backgroundColor = [UIColor colorWithWhite:1.f alpha:.4f];
        self.frame = CGRectMake(([UIScreen mainScreen].bounds.size.width - 325.f) / 2.f, [UIScreen mainScreen].bounds.size.height - 105.f, 325.f, 105.f);
        
        [self _configOwnViews];
    }
    
    return self;
}

#pragma mark - Private methods

// 设置子视图
- (void)_configOwnViews {
    
    // 颜色按钮
    [_colorArr enumerateObjectsUsingBlock:^(UIColor *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        UIButton *colorBtn = [UIButton new];
        colorBtn.layer.cornerRadius = 22.f;
        colorBtn.layer.masksToBounds = YES;
        colorBtn.tag = idx + 10;
        [colorBtn setBackgroundColor:obj];
        colorBtn.frame = CGRectMake(8.7 + idx * (44 + 8.7), 5.f, 44.f, 44.f);
        [colorBtn addTarget:self action:@selector(_didClickBtn:) forControlEvents:UIControlEventTouchUpInside];
        if (idx == 5) {
            [colorBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            colorBtn.titleLabel.font = [UIFont systemFontOfSize:14.f];
            [colorBtn setTitle:@"橡皮" forState:UIControlStateNormal];
        }
        
        [self addSubview:colorBtn];
    }];
    
    // 画线宽度
    [_lineWidthArr enumerateObjectsUsingBlock:^(NSNumber *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        UIButton *widthBtn = [UIButton new];
        widthBtn.tag = idx + 20;
        widthBtn.frame = CGRectMake(8.7 + idx * (44 + 8.7), 55.f, 44.f, 40.f);
        [widthBtn addTarget:self action:@selector(_didClickBtn:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:widthBtn];
        
        UIView *roundView = [UIView new];
        roundView.backgroundColor = [UIColor blackColor];
        roundView.bounds = CGRectMake(0, 0, [obj integerValue], [obj integerValue]);
        roundView.center = widthBtn.center;
        [self addSubview:roundView];
    }];
    
    // 撤销，恢复，清除
    for (int i = 3; i < 6; i++) {
        UIButton *editBtn = [UIButton new];
        editBtn.titleLabel.font = [UIFont systemFontOfSize:14.f];
        [editBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        if (i == 3) {
            [editBtn setTitle:@"撤销" forState:UIControlStateNormal];
        }
        else if (i == 4) {
            [editBtn setTitle:@"恢复" forState:UIControlStateNormal];
        }
        else {
            [editBtn setTitle:@"清除" forState:UIControlStateNormal];
        }
        editBtn.tag = i + 20;
        editBtn.frame = CGRectMake(8.7 + i * (44 + 8.7), 55.f, 44.f, 40.f);
        [editBtn addTarget:self action:@selector(_didClickBtn:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:editBtn];
    }
}

// 按钮点击事件
- (void)_didClickBtn:(UIButton *)sender {
    if (_delegate && [_delegate respondsToSelector:@selector(onClickColorPanelButton:)]) {
        [_delegate onClickColorPanelButton:sender];
    }
}

@end
