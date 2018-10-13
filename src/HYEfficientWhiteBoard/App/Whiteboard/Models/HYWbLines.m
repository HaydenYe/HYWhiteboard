//
//  HYWbLines.m
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/10/13.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import "HYWbLines.h"

@implementation HYWbLines

- (instancetype)init {
    if (self = [super init]) {
        _dirtyCount = 0;
    }
    
    return self;
}

- (NSMutableArray<NSMutableArray *> *)lines {
    if (_lines == nil) {
        _lines = [NSMutableArray new];
    }
    
    return _lines;
}

@end
