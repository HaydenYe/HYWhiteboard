//
//  HYWhiteboardView.m
//  HYEfficientWhiteBoard
//
//  Created by apple on 2018/2/28.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import "HYWhiteboardView.h"
#import "HYCADisplayLinkHolder.h"

static float const kMaxDif = 1.f;               // 计算橡皮轨迹时候，两个橡皮位置的最大偏移
NSString *const UserOfLinesMine = @"Mine";      // 自己画线的key
NSString *const UserOfLinesOther = @"Other";    // 其他人画线的key


@interface HYWhiteboardView () <HYCADisplayLinkHolderDelegate, CALayerDelegate>

@property (nonatomic, strong)HYCADisplayLinkHolder  *displayLinkHolder;     // 渲染的计时器

@property (nonatomic, strong)CAShapeLayer           *realTimeLy;            // 实时显示层
@property (nonatomic, assign)CGPoint                controlPoint;           // 贝塞尔曲线的控制点

@property (nonatomic, assign)BOOL                   isEraserLine;           // 是否正在渲染橡皮画线
@property (nonatomic, assign)CGPoint                lastEraserPoint;        // 上一个橡皮的画点

@end


@implementation HYWhiteboardView

- (instancetype)init {
    if (self = [super init]) {
        CAShapeLayer *shapeLayer = (CAShapeLayer *)self.layer;
        shapeLayer.masksToBounds = YES;
        self.layer.delegate = self;
        
        self.backgroundColor = [UIColor clearColor];
        
        // 设置刷新率，1秒30帧
        _displayLinkHolder = [HYCADisplayLinkHolder new];
        [_displayLinkHolder setFrameInterval:2];
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
    
    CGPoint point = CGPointMake(wbPoint.xScale * self.frame.size.width, wbPoint.yScale * self.frame.size.height);
    if (wbPoint.type == HYWbPointTypeStart) {
        _lastEraserPoint = point;
    }
    
    // 计算橡皮的两点之间的画点
    [self _addEraserPointFromPoint:point lineWidth:wbPoint.lineWidth];
    
    _lastEraserPoint = point;
}

// 渲染橡皮画线
- (void)drawEraserPoint:(CGPoint)point lineWidth:(NSInteger)width {
    CGFloat lineWidth = width * 2.f / 1.414f;
    CGRect brushRect = CGRectMake(point.x - lineWidth /2.f, point.y - lineWidth/2.f, lineWidth, lineWidth);
    [self.layer setNeedsDisplayInRect:brushRect];
    [self.layer display];
}


#pragma mark - CALayerDelegate

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    UIGraphicsPushContext(ctx);
    [self _drawLines];
    UIGraphicsPopContext();
}


#pragma mark - HYCADisplayLinkHolderDelegate

// 渲染非橡皮的画线(只渲染实时显示层)
- (void)onDisplayLinkFire:(HYCADisplayLinkHolder *)holder duration:(NSTimeInterval)duration displayLink:(CADisplayLink *)displayLink {

    if (_dataSource && [_dataSource needUpdate]) {
        
        // 自己画的线需要实时显示层(优化画线卡顿)
        NSArray *lines = [[_dataSource allLines] objectForKey:UserOfLinesMine];
        
        // 清除画线的渲染
        if (lines.count <= 0) {
            [self setNeedsDisplay];
            [self.layer setNeedsDisplay];
            self.realTimeLy.hidden = YES;
            return;
        }
        
        // 橡皮的画线需要直接渲染到视图层，所以不再此渲染
        NSArray *currentLine = lines.lastObject;
        HYWbPoint *firstPoint = [currentLine objectAtIndex:0];
        if (_isEraserLine) {
            return;
        }
        
        // 将画线渲染到实时显示层
        UIBezierPath *path = [self _singleLine:currentLine needStroke:NO];
        self.realTimeLy.path = path.CGPath;
        _realTimeLy.strokeColor = [[_dataSource colorArr][firstPoint.colorIndex] CGColor];
        _realTimeLy.fillColor = [UIColor clearColor].CGColor;
        _realTimeLy.lineWidth = path.lineWidth;
        _realTimeLy.lineCap = firstPoint.isEraser ? kCALineCapSquare : kCALineCapRound;
        _realTimeLy.hidden = NO;
        
        // 如果是最后一个点，更新视图层，将线画到视图层
        HYWbPoint *theLastPoint = [currentLine lastObject];
        if (theLastPoint.type == HYWbPointTypeEnd) {
            [self setNeedsDisplay];
            [self.layer setNeedsDisplay];
            _realTimeLy.hidden = YES;
        }
    }
}


#pragma mark - Private methods

// 刷新视图，重绘所有画线
- (void)_drawLines {
    // 正在渲染橡皮画线的时候，不刷新视图
    if (_isEraserLine == NO) {
        NSDictionary *allLines = [_dataSource allLines];
        for (NSString *key in allLines.allKeys) {
            for (NSArray *line in allLines[key]) {
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
    UIColor *lineColor = firstPoint.isEraser ? [UIColor clearColor] : [_dataSource colorArr][firstPoint.colorIndex];
    
    // 生成贝塞尔曲线
    for (HYWbPoint *point in line) {
        CGPoint p = CGPointMake(point.xScale * self.frame.size.width, point.yScale * self.frame.size.height);
        
        if (point.type == HYWbPointTypeStart) {
            [path moveToPoint:p];
        }
        // 优化曲线的圆滑度
        else {
            if (_controlPoint.x != p.x || _controlPoint.y != p.y) {
                [path addQuadCurveToPoint:CGPointMake((_controlPoint.x + p.x) / 2, (_controlPoint.y + p.y) / 2) controlPoint:_controlPoint];
            }
        }
        
        _controlPoint = p;
    }
    
    // 需要渲染
    if (needStroke) {
        [lineColor setStroke];
        
        if (firstPoint.isEraser) {
            [path strokeWithBlendMode:kCGBlendModeCopy alpha:1.0];
        }
        else {
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
            
            [self drawEraserPoint:addP lineWidth:lineWidth];
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
            [self drawEraserPoint:addP lineWidth:lineWidth];
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
            
            [self drawEraserPoint:addP lineWidth:lineWidth];
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
            
            [self drawEraserPoint:addP lineWidth:lineWidth];
        }
    }
    // 不需要补充画点
    else {
        [self drawEraserPoint:point lineWidth:lineWidth];
    }
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
