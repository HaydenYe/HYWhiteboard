//
//  HYWbAllLines.m
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/10/13.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import "HYWbAllLines.h"

@implementation HYWbAllLines

- (instancetype)init {
    if (self = [super init]) {
        _dirtyCount = 0;
    }
    
    return self;
}

- (NSMutableArray<HYWbLine *> *)allLines {
    if (_allLines == nil) {
        _allLines = [NSMutableArray new];
    }
    
    return _allLines;
}

- (NSMutableDictionary *)lastLineIndex {
    if (_lastLineIndex == nil) {
        _lastLineIndex = [NSMutableDictionary new];
    }
    
    return _lastLineIndex;
}

@end
