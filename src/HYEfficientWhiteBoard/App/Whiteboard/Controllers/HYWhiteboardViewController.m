//
//  HYWhiteboardViewController.m
//  HYEfficientWhiteBoard
//
//  Created by apple on 2018/2/27.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import "HYWhiteboardViewController.h"
#import "HYColorPanel.h"
#import "HYWhiteboardView.h"

@interface HYWhiteboardViewController () <HYColorPanelDelegate, HYWbDataSource>

@property (nonatomic, strong)HYColorPanel       *colorPanel;    // 颜色盘
@property (nonatomic, strong)HYWhiteboardView   *wbView;        // 白板视图

@property (nonatomic, assign)NSInteger          lineColorIndex; // 画线颜色的索引
@property (nonatomic, assign)NSInteger          lineWidth;      // 画线宽度

@property (nonatomic, strong)NSMutableDictionary*allLines;      // 所有画线
@property (nonatomic, strong)NSMutableArray     *cancelLines;   // 被撤销画线
@property (nonatomic, assign)BOOL               isEraser;       // 是否为橡皮模式
@property (nonatomic, assign)BOOL               needUpdate;     // 需要更新白板视图

@end

@implementation HYWhiteboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"白板";
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self _configOwnViews];
    
    [self _configWhiteboardDataSource];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark - HYWbDataSource

// 所有的画线
- (NSDictionary<NSString *, NSArray *> *)allLines {
    _needUpdate = NO;
    return _allLines;
}

// 颜色数组
- (NSArray<UIColor *> *)colorArr {
    return _colorPanel.colorArr;
}

// 当前是否为橡皮擦模式
- (BOOL)isEraser {
    return _isEraser;
}

// 需要更新视图
- (BOOL)needUpdate {
    return _needUpdate;
}


#pragma HYColorPanelDelegate

// 点击按钮
- (void)onClickColorPanelButton:(UIButton *)button {
    switch (button.tag) {
        // 颜色
        case 10:
        case 11:
        case 12:
        case 13:
        case 14:{
            _lineColorIndex = button.tag - 10;
            _isEraser = NO;
            break;
        }
            
        // 橡皮
        case 15:{
            _lineColorIndex = button.tag - 10;
            _isEraser = YES;
            break;
        }
        
        // 画线粗细
        case 20:
        case 21:
        case 22:{
            _lineWidth = [_colorPanel.lineWidthArr[button.tag - 20] integerValue];
            break;
        }
            
        // 撤销
        case 23:{
            if (_allLines[UserOfLinesMine] && [_allLines[UserOfLinesMine] count]) {
                NSArray *line = [_allLines[UserOfLinesMine] lastObject];
                [_cancelLines addObject:line];
                [_allLines[UserOfLinesMine] removeObject:line];
                _needUpdate = YES;
            }
            break;
        }
            
        // 恢复
        case 24:{
            if (_cancelLines.count) {
                [_allLines[UserOfLinesMine] addObject:_cancelLines.lastObject];
                [_cancelLines removeObjectAtIndex:_cancelLines.count - 1];
                _needUpdate = YES;
            }
            break;
        }
            
        // 清除
        case 25:{
            [_allLines removeAllObjects];
            _needUpdate = YES;
            break;
        }
        
        default:
            break;
    }
}


#pragma mark - Private methods

// 设置子视图
- (void)_configOwnViews {
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"插入图片" style:UIBarButtonItemStylePlain target:self action:@selector(_insertImage)];
    [self.navigationItem setRightBarButtonItem:item];
    
    [self.view addSubview:self.wbView];
    [self.view addSubview:self.colorPanel];
    
    [self _addGestureRecognizerToView:_wbView];
}

// 设置线条数据源
- (void)_configWhiteboardDataSource {
    _lineColorIndex = 0;
    _lineWidth = [_colorPanel.lineWidthArr.firstObject integerValue];
    
    _allLines = [NSMutableDictionary new];
    _cancelLines = [NSMutableArray new];
}

// 添加所有的手势
- (void)_addGestureRecognizerToView:(UIView *)view {
    // 画线手势
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_onPanGesture:)];
    panGestureRecognizer.maximumNumberOfTouches = 1;
    [view addGestureRecognizer:panGestureRecognizer];
}

// 画线手势
- (void)_onPanGesture:(UIPanGestureRecognizer *)panGestureRecognizer {
    CGPoint p = [panGestureRecognizer locationInView:panGestureRecognizer.view];
    
    // 画线之后无法恢复撤销的线
    [_cancelLines removeAllObjects];
    
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            [self _onPointCollected:p type:HYWbPointTypeStart];
            break;
        case UIGestureRecognizerStateChanged:
            [self _onPointCollected:p type:HYWbPointTypeMove];
            break;
        default:
            [self _onPointCollected:p type:HYWbPointTypeEnd];
            break;
    }
}

// 收集画线的点
- (void)_onPointCollected:(CGPoint)p type:(HYWbPointType)type  {
    HYWbPoint *point = [HYWbPoint new];
    point.type = type;
    point.xScale = (p.x)/_wbView.frame.size.width;
    point.yScale = (p.y)/_wbView.frame.size.height;
    point.colorIndex = _lineColorIndex;
    point.lineWidth = _lineWidth;
    [self _addPoint:point userId:UserOfLinesMine];
    
    // 橡皮擦直接渲染到视图上
    if (_isEraser) {
        point.isEraser = YES;
        [_wbView drawEraserLineByPoint:point];
    }
}

// 保存点
- (void)_addPoint:(HYWbPoint *)point userId:(NSString *)userId {
    if (point == nil || userId == nil || userId.length < 1) {
        return;
    }
    
    NSMutableArray *lines = [_allLines objectForKey:userId];
    
    if (lines == nil) {
        lines = [[NSMutableArray alloc] init];
        [_allLines setObject:lines forKey:userId];
    }
    
    if (point.type == HYWbPointTypeStart) {
        [lines addObject:[NSMutableArray arrayWithObject:point]];
    }
    else if (lines.count == 0){
        point.type = HYWbPointTypeStart;
        [lines addObject:[NSMutableArray arrayWithObject:point]];
    }
    else {
        NSMutableArray *lastLine = [lines lastObject];
        [lastLine addObject:point];
    }
    
    _needUpdate = YES;
}

// 插入图片
- (void)_insertImage {
    
}


#pragma Property

// 颜色盘
- (HYColorPanel *)colorPanel {
    if (_colorPanel == nil) {
        _colorPanel = [HYColorPanel new];
        _colorPanel.delegate = self;
    }
    
    return _colorPanel;
}

// 白板视图
- (HYWhiteboardView *)wbView {
    if (_wbView == nil) {
        _wbView = [HYWhiteboardView new];
        _wbView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
        _wbView.dataSource = self;
    }
    
    return _wbView;
}

@end
