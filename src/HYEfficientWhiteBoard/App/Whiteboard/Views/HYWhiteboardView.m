//
//  HYWhiteboardView.m
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/2/28.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import "HYWhiteboardView.h"
#import "HYCADisplayLinkHolder.h"

static float const kMaxDif = 1.f;               // 计算橡皮轨迹时候，两个橡皮位置的最大偏移
NSString *const UserOfLinesMine = @"Mine";      // 自己画线的key
NSString *const UserOfLinesOther = @"Other";    // 其他人画线的key


@interface HYWhiteboardView () <HYCADisplayLinkHolderDelegate>

@property (nonatomic, strong)HYCADisplayLinkHolder  *displayLinkHolder;     // 渲染的计时器

@property (nonatomic, strong)CAShapeLayer           *realTimeLy;            // 实时显示层
@property (nonatomic, assign)CGPoint                controlPoint;           // 二阶贝塞尔曲线的控制点

@property (nonatomic, assign)BOOL                   isEraserLine;           // 是否正在渲染橡皮画线
@property (nonatomic, assign)CGPoint                lastEraserPoint;        // 上一个橡皮的画点

@end


@implementation HYWhiteboardView

- (instancetype)init {
    if (self = [super init]) {
        self.layer.contentsScale = [UIScreen mainScreen].scale;
        self.backgroundColor = [UIColor clearColor];
        
        // 设置刷新率，1秒60帧
        _displayLinkHolder = [HYCADisplayLinkHolder new];
        [_displayLinkHolder setFrameInterval:1];
        [_displayLinkHolder startCADisplayLinkWithDelegate:self];
        
        _controlPoint = CGPointZero;
    }
    
    return self;
}

- (void)dealloc {
    [_displayLinkHolder stop];
}

+ (Class)layerClass {
    return [CAShapeLayer class];
}

// 重绘所有画线在视图层
- (void)drawRect:(CGRect)rect {
    [self _drawLines];
}

// 打开或停止渲染画线的计时器
- (void)startCADisplayLink:(BOOL)start {
    if (start) {
        [_displayLinkHolder startCADisplayLinkWithDelegate:self];
    }
    else {
        [_displayLinkHolder stop];
    }
}

// 橡皮直接渲染到视图
- (void)drawEraserLineByPoint:(HYWbPoint *)wbPoint {
    
    // 一条线已画完，渲染到视图层
    if (wbPoint.type == HYWbPointTypeEnd) {
        _isEraserLine = NO;
        [self.layer setNeedsDisplay];
        [self.layer display];
        return ;
    }
    
    _isEraserLine = YES;
    
#warning iOS12版本setNeedsDisplayInRect:不能局部绘制，等待修复
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 12.f) {
        [self.layer setNeedsDisplay];
        [self.layer display];
        return ;
    }
    
    CGPoint point = CGPointMake(wbPoint.xScale * self.frame.size.width, wbPoint.yScale * self.frame.size.height);
    if (wbPoint.type == HYWbPointTypeStart) {
        _lastEraserPoint = point;
    }
    
    // 计算橡皮的两点之间的画点
    [self _addEraserPointFromPoint:point lineWidth:wbPoint.lineWidth];
    
    _lastEraserPoint = point;
}


#pragma mark - HYCADisplayLinkHolderDelegate

// 渲染非橡皮的画线(只渲染实时显示层)
- (void)onDisplayLinkFire:(HYCADisplayLinkHolder *)holder duration:(NSTimeInterval)duration displayLink:(CADisplayLink *)displayLink {
    if (_dataSource && [_dataSource needUpdate]) {
        
        // 清除所有人画线
        if ([_dataSource allLines].count == 0) {
            [self.layer setNeedsDisplay];
            _realTimeLy.hidden = YES;
            return ;
        }
        
        // 是否需要重绘所有线
        BOOL needUpdateLayer = NO;
        
        // 是否为撤销操作
        NSInteger cancelCount = 0;

        for (NSString *user in [[_dataSource allLines] allKeys]) {
            
            // 先将画线渲染到实时显示层(优化画线卡顿)
            HYWbLines *lines = [[_dataSource allLines] objectForKey:user];
            
            // 橡皮的画线需要直接渲染到视图层，所以不再此渲染
            if (_isEraserLine) {
                continue;
            }
            
            // 此用户的所有点已经渲染完，可能是撤销操作
            if (lines.dirtyCount >= lines.lines.count) {
                cancelCount += 1;
                continue;
            }
            
            // 未渲染的画线
            NSArray *lastLines = [lines.lines subarrayWithRange:NSMakeRange(lines.dirtyCount, lines.lines.count - lines.dirtyCount)];
            for (NSArray *line in lastLines) {
                HYWbPoint *firstPoint = [line objectAtIndex:0];
                CGColorRef color = [[_dataSource colorArr][firstPoint.colorIndex] CGColor];
                // 将画线渲染到实时显示层
                [self _drawLineOnRealTimeLayer:line color:color];
                
                // 是否画完一条线
                HYWbPoint *lastPoint = [line lastObject];
                if (lastPoint.type == HYWbPointTypeEnd) {
                    lines.dirtyCount += 1;
                    needUpdateLayer = YES;
                }
            }
        }
        
        // 标记图层需要重新绘制，或者为撤销操作也需要更新
        if (needUpdateLayer || cancelCount == [_dataSource allLines].count) {
            [self.layer setNeedsDisplay];
            _realTimeLy.hidden = YES;
        }
    }
}


#pragma mark - Private methods

// 将画线渲染到实时显示层
- (void)_drawLineOnRealTimeLayer:(NSArray *)line color:(CGColorRef)color {
    UIBezierPath *path = [self _singleLine:line needStroke:NO];
    self.realTimeLy.path = path.CGPath;
    _realTimeLy.strokeColor = color;
    _realTimeLy.fillColor = [UIColor clearColor].CGColor;
    _realTimeLy.lineWidth = path.lineWidth;
    _realTimeLy.lineCap = kCALineCapRound;
    _realTimeLy.hidden = NO;
}

// 刷新视图，重绘所有画线
- (void)_drawLines {
    // 正在渲染橡皮画线的时候，不刷新视图
    if (_isEraserLine == NO) {
        NSDictionary *allLines = [_dataSource allLines];
        for (NSString *key in allLines.allKeys) {
            HYWbLines *lines = allLines[key];
            for (NSArray *line in lines.lines) {
                [self _singleLine:line needStroke:YES];
            }
        }
    }
#warning iOS12版本setNeedsDisplayInRect:不能局部绘制，等待修复
    else if ([[UIDevice currentDevice].systemVersion floatValue] >= 12.f) {
        NSDictionary *allLines = [_dataSource allLines];
        for (NSString *key in allLines.allKeys) {
            HYWbLines *lines = allLines[key];
            for (NSArray *line in lines.lines) {
                [self _singleLine:line needStroke:YES];
            }
        }
    }
}

// 获取一条贝塞尔曲线
- (UIBezierPath *)_singleLine:(NSArray<HYWbPoint *> *)line needStroke:(BOOL)needStroke {
    
    // 取线的起始点，获取画线的信息
    HYWbPoint *firstPoint = line.firstObject;
    
    // 初始化贝塞尔曲线
    UIBezierPath *path = [UIBezierPath new];
    path.lineJoinStyle = kCGLineJoinRound;
    path.lineWidth = firstPoint.isEraser ? firstPoint.lineWidth * 2.f : firstPoint.lineWidth;
    path.lineCapStyle = firstPoint.isEraser ? kCGLineCapSquare : kCGLineCapRound;
    
    // 画线颜色
    UIColor *lineColor = [_dataSource colorArr][firstPoint.colorIndex];
    
    // 生成贝塞尔曲线
    for (HYWbPoint *point in line) {
        CGPoint p = CGPointMake(point.xScale * self.frame.size.width, point.yScale * self.frame.size.height);
        
        if (point.type == HYWbPointTypeStart) {
            [path moveToPoint:p];
        }
        // 优化曲线的圆滑度，二阶贝塞尔
        else {
            if (_controlPoint.x != p.x || _controlPoint.y != p.y) {
                [path addQuadCurveToPoint:CGPointMake((_controlPoint.x + p.x) / 2, (_controlPoint.y + p.y) / 2) controlPoint:_controlPoint];
            }
        }
        
        _controlPoint = p;
    }
    
    // 需要渲染
    if (needStroke) {
        if (firstPoint.isEraser) {
            [lineColor setStroke];
            [path strokeWithBlendMode:kCGBlendModeCopy alpha:1.0];
        }
        else {
            [lineColor setStroke];
            [path strokeWithBlendMode:kCGBlendModeNormal alpha:1.0];
        }
    }
    
    return path;
}

// 计算橡皮的两点之间的画点
- (void)_addEraserPointFromPoint:(CGPoint)point lineWidth:(NSInteger)lineWidth {
    
    // 两个点之间，x、y的偏移量
    CGFloat offsetX = point.x - self.lastEraserPoint.x;
    CGFloat offsetY = point.y - self.lastEraserPoint.y;
    
    // 起始点x、y偏移量为零，直接绘制，防止Nan崩溃（也可以不绘制）
    if (offsetX == 0 && offsetY == 0) {
        [self _drawEraserPoint:point lineWidth:lineWidth];
        return ;
    }
    
    // 每个点之间，x、y的间隔
    CGFloat difX = kMaxDif;
    CGFloat difY = kMaxDif;
    
    // 计算需要补充的画点的个数，以及间隔
    NSInteger temPCount = 0;
    if (fabs(offsetX) > fabs(offsetY)) {
        difY = fabs(offsetY) / fabs(offsetX);
        temPCount = fabs(offsetX);
    } else {
        difX = fabs(offsetX) / fabs(offsetY);
        temPCount = fabs(offsetY);
    }
    
    // 渲染补充的画点
    // 确认x、y分量上面的点方向
    if (offsetX > kMaxDif) {
        for (int i = 0; i < temPCount ; i ++) {
            CGPoint addP = CGPointMake(_lastEraserPoint.x + difX * i, _lastEraserPoint.y);
            if (offsetY > kMaxDif) {
                addP.y = addP.y + difY * i;
            }
            else if (offsetY < - kMaxDif) {
                addP.y = addP.y - difY * i;
            }
            
            [self _drawEraserPoint:addP lineWidth:lineWidth];
        }
    }
    else if (offsetX < - kMaxDif) {
        for (int i = 0; i < temPCount ; i ++) {
            CGPoint addP = CGPointMake(_lastEraserPoint.x - difX * i, _lastEraserPoint.y);
            if (offsetY > kMaxDif) {
                addP.y = addP.y + difY * i;
            }
            else if (offsetY < - kMaxDif) {
                addP.y = addP.y - difY * i;
            }
            [self _drawEraserPoint:addP lineWidth:lineWidth];
        }
    }
    else if (offsetY > kMaxDif) {
        for (int i = 0; i < temPCount ; i ++) {
            CGPoint addP = CGPointMake(_lastEraserPoint.x, _lastEraserPoint.y + difY * i);
            if (offsetX > kMaxDif) {
                addP.x = addP.x + difX * i;
            }
            else if (offsetX < - kMaxDif) {
                addP.x = addP.x - difX * i;
            }
            
            [self _drawEraserPoint:addP lineWidth:lineWidth];
        }
    }
    else if (offsetY < - kMaxDif) {
        for (int i = 0; i < temPCount ; i ++) {
            CGPoint addP = CGPointMake(_lastEraserPoint.x, _lastEraserPoint.y - difY * i);
            if (offsetX > kMaxDif) {
                addP.x = addP.x + difX * i;
            }
            else if (offsetX < - kMaxDif) {
                addP.x = addP.x - difX * i;
            }
            
            [self _drawEraserPoint:addP lineWidth:lineWidth];
        }
    }
    // 不需要补充画点
    else {
        [self _drawEraserPoint:point lineWidth:lineWidth];
    }
}

// 渲染橡皮画线
- (void)_drawEraserPoint:(CGPoint)point lineWidth:(NSInteger)width {
    CGFloat lineWidth = width * 2.f / 1.414f;
    
    // 只重绘局部，提高效率
    CGRect brushRect = CGRectMake(point.x - lineWidth /2.f, point.y - lineWidth/2.f, lineWidth, lineWidth);
    [self.layer setNeedsDisplayInRect:brushRect];
    
    // 十分关键，需要立即渲染
    [self.layer display];
}


#pragma mark - Property

// 实时显示层
- (CAShapeLayer *)realTimeLy {
    if (!_realTimeLy) {
        _realTimeLy = [CAShapeLayer layer];
        _realTimeLy.frame = self.bounds;
        _realTimeLy.backgroundColor = [UIColor clearColor].CGColor;
        [_realTimeLy setNeedsDisplay];
        [self.layer addSublayer:_realTimeLy];
    }
    
    return _realTimeLy;
}

@end
