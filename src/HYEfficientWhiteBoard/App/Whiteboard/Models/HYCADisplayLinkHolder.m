//
//  HYCADisplayLinkHolder.m
//  HYEfficientWhiteBoard
//
//  Created by apple on 2018/2/28.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import "HYCADisplayLinkHolder.h"

@implementation HYCADisplayLinkHolder

- (instancetype)init {
    if (self = [super init]) {
        _frameInterval = 1;
    }
    return self;
}

- (void)dealloc {
    [self stop];
    _delegate = nil;
}

- (void)startCADisplayLinkWithDelegate:(id<HYCADisplayLinkHolderDelegate>)delegate {
    _delegate = delegate;
    [self stop];
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onDisplayLink:)];
    [_displayLink setFrameInterval:_frameInterval];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stop {
    if (_displayLink){
        [_displayLink invalidate];
        _displayLink = nil;
    }
}

- (void)onDisplayLink:(CADisplayLink *)displayLink {
    if (_delegate && [_delegate respondsToSelector:@selector(onDisplayLinkFire:duration:displayLink:)]){
        [_delegate onDisplayLinkFire:self
                            duration:displayLink.duration
                         displayLink:displayLink];
    }
}

@end
