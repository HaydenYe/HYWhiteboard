//
//  HYWbLine.m
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/10/14.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import "HYWbLine.h"

@implementation HYWbLine

- (NSMutableArray<HYWbPoint *> *)points {
    if (_points == nil) {
        _points = [NSMutableArray new];
    }
    
    return _points;
}

@end
