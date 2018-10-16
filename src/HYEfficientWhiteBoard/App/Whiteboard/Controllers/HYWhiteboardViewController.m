//
//  HYWhiteboardViewController.m
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/2/27.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import "HYWhiteboardViewController.h"
#import "HYColorPanel.h"
#import "HYWhiteboardView.h"
#import "HYConversationManager.h"
#import "HYUploadManager.h"

@interface HYWhiteboardViewController () <HYColorPanelDelegate, HYWbDataSource, HYConversationDelegate, HYUploadDelegate, UIScrollViewDelegate>

@property (nonatomic, strong)HYColorPanel       *colorPanel;    // 颜色盘
@property (nonatomic, strong)HYWhiteboardView   *wbView;        // 白板视图
@property (nonatomic, strong)UIImageView        *imageView;     // 图片
@property (nonatomic, strong)UIScrollView       *scrollView;    // scroll view
@property (nonatomic, strong)UIButton           *drawingBtn;    // 画笔模式开关

@property (nonatomic, assign)NSInteger          lineColorIndex; // 画线颜色的索引
@property (nonatomic, assign)NSInteger          lineWidth;      // 画线宽度

@property (nonatomic, strong)HYWbAllLines       *allLines;      // 所有画线
@property (nonatomic, strong)NSMutableDictionary*cancelLines;   // 被撤销画线
@property (nonatomic, assign)BOOL               isEraser;       // 是否为橡皮模式
@property (nonatomic, assign)BOOL               needUpdate;     // 需要更新白板视图
@property (nonatomic, assign)CGPoint            lastPoint;      // 上一个点的位置
@property (nonatomic, assign)CGFloat            difMin;         // 距离上一个点的最小距离

@property (nonatomic, assign)BOOL               drawable;       // 是否可以画线

@end

@implementation HYWhiteboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"白板";
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    self.navigationController.automaticallyAdjustsScrollViewInsets = NO;
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    [HYConversationManager shared].converDelegate = self;
    [HYUploadManager shared].delegate = self;
    
    [self _configOwnViews];
    
    [self _configWhiteboardDataSource];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    // 断网
    [[HYConversationManager shared] disconnectWhiteboard];
    [[HYUploadManager shared] disconnectUpload];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark - HYWbDataSource

// 所有的画线
- (HYWbAllLines *)allLines {
    _needUpdate = NO;
    return _allLines;
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
            [[HYConversationManager shared] sendPenStyleColor:_lineColorIndex lineWidth:_lineWidth];
            break;
        }
            
        // 橡皮
        case 15:{
            _lineColorIndex = button.tag - 10;
            _isEraser = YES;
            [[HYConversationManager shared] sendPenStyleColor:_lineColorIndex lineWidth:_lineWidth];
            break;
        }
        
        // 画线粗细
        case 20:
        case 21:
        case 22:{
            _lineWidth = [_colorPanel.lineWidthArr[button.tag - 20] integerValue];
            [[HYConversationManager shared] sendPenStyleColor:_lineColorIndex lineWidth:_lineWidth];
            break;
        }
            
        // 撤销
        case 23:{
            [self _cancelLinesWithUserId:UserOfLinesMine];
            break;
        }
            
        // 恢复
        case 24:{
            [self _resumeLineWithUserId:UserOfLinesMine];
            break;
        }
            
        // 清除
        case 25:{
            [self _clearAllUserLinesWithUserId:UserOfLinesMine];
            break;
        }
        
        default:
            break;
    }
}


#pragma mark - HYConversationDelegate

// 接收到画线的点
- (void)onReceivePoint:(HYWbPoint *)point {

    // 同时只能绘制一个人的画线
    if (point.type == HYWbPointTypeEnd) {
        _drawable = YES;
    }
    else {
        _drawable = NO;
    }
    
    point.lineWidth = _lineWidth;
    point.colorIndex = _lineColorIndex;
    [self _addPoint:point userId:UserOfLinesOther];
    
    // 橡皮擦直接渲染到视图上
    if (point.isEraser) {
        [_wbView drawEraserLineByPoint:point];
    }
}

// 接收到画笔颜色、宽度
- (void)onReceivePenColor:(NSInteger)colorIndex lineWidth:(NSInteger)lineWidth {
    _lineWidth = lineWidth;
    _lineColorIndex = colorIndex;
    if (colorIndex == 5) {
        _isEraser = YES;
    }
    else {
        _isEraser = NO;
    }
}

// 接收到撤销，恢复，全部擦除消息
- (void)onReceiveEditAction:(HYMessageCmd)type {
    switch (type) {
        // 撤销
        case HYMessageCmdCancel:{
            [self _cancelLinesWithUserId:UserOfLinesOther];
            break;
        }
            
        // 恢复
        case HYMessageCmdResume:{
            [self _resumeLineWithUserId:UserOfLinesOther];
            break;
        }
            
        // 清除
        case HYMessageCmdClearAll:{
            [self _clearAllUserLinesWithUserId:UserOfLinesOther];
            break;
        }
            
        default:
            break;
    }
}

// 网络断开
- (void)onNetworkDisconnect {
    [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark - HYUploadDelegate

// 接收到新图片
- (void)onNewImage:(UIImage *)image {
    [self.scrollView setZoomScale:1.f];
    _imageView.image = image;
}

// 上传连接断开
- (void)onUploadServiceDisconnect {
    self.navigationItem.rightBarButtonItem.enabled = YES;
}


#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _imageView;
}


#pragma mark - Private methods

// 设置子视图
- (void)_configOwnViews {
    if (!_isServer) {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"插入图片" style:UIBarButtonItemStylePlain target:self action:@selector(_insertImage:)];
        [self.navigationItem setRightBarButtonItem:item];
    }
    
    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.imageView];
    [self.imageView addSubview:self.wbView];
    [self.view addSubview:self.colorPanel];
    [self.view addSubview:self.drawingBtn];
    
    [self _addGestureRecognizerToView:_wbView];
    
    if (_isUnConnected) {
        [self onNewImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"1424*2144-398KB" ofType:@"jpg"]]];
    }
}

// 设置线条数据源
- (void)_configWhiteboardDataSource {
    _lineColorIndex = 0;
    _lineWidth = [_colorPanel.lineWidthArr.firstObject integerValue];
    
    _allLines = [HYWbAllLines new];
    _cancelLines = [NSMutableDictionary new];
    
    _drawable = YES;
    
    // 固定数值，适用所有尺寸
    _difMin = 6.f / 768.f;
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
    
    // 是否正在渲染别人的画线
    if (_drawable == NO) {
        return ;
    }
    
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
- (void)_onPointCollected:(CGPoint)p type:(HYWbPointType)type {
    HYWbPoint *point = [HYWbPoint new];
    point.type = type;
    point.xScale = (p.x) / _wbView.frame.size.width;
    point.yScale = (p.y) / _wbView.frame.size.height;
    point.colorIndex = _lineColorIndex;
    point.lineWidth = _lineWidth;
    [self _addPoint:point userId:UserOfLinesMine];
    
    // 橡皮擦直接渲染到视图上
    if (_isEraser) {
        point.isEraser = YES;
        [_wbView drawEraserLineByPoint:point];
    }
    
    [[HYConversationManager shared] sendPointMsg:point];
}

// 保存点
- (void)_addPoint:(HYWbPoint *)point userId:(NSString *)userId {
    if (point == nil || userId == nil || userId.length < 1) {
        return;
    }
    
    // 画线的起始点，生成新的Line
    if (point.type == HYWbPointTypeStart) {
        HYWbLine *line = [HYWbLine new];
        line.color = _colorPanel.colorArr[point.colorIndex];
        line.lineWidth = point.lineWidth;
        line.lineIndex = _allLines.allLines.count;
        if (_allLines.lastLineIndex[userId]) {
            line.lastLineIndex = [_allLines.lastLineIndex[userId] integerValue];
        }
        else {
            line.lastLineIndex = -1;
        }
        [line.points addObject:point];
        
        [_allLines.allLines addObject:line];
        [_allLines.lastLineIndex setObject:@(line.lineIndex) forKey:userId];
        
        _lastPoint = CGPointMake(point.xScale, point.yScale);
    }
    // 没有任何点，则认为该点为起始点
    else if (_allLines.allLines.count == 0){
        point.type = HYWbPointTypeStart;
        HYWbLine *line = [HYWbLine new];
        line.color = _colorPanel.colorArr[point.colorIndex];
        line.lineWidth = point.lineWidth;
        line.lineIndex = 0;
        line.lastLineIndex = -1;
        [line.points addObject:point];
        [_allLines.allLines addObject:line];
        [_allLines.lastLineIndex setObject:@(line.lineIndex) forKey:userId];
        
        _lastPoint = CGPointMake(point.xScale, point.yScale);
    }
    // 非起始点
    else {
        // 过滤非关键点，减少数据量
        if (fabs(point.xScale - _lastPoint.x) > _difMin || fabs(point.yScale - _lastPoint.y) > _difMin || point.type == HYWbPointTypeEnd) {
            NSInteger index = [_allLines.lastLineIndex[userId] integerValue];
            HYWbLine *lastLine = _allLines.allLines[index];
            [lastLine.points addObject:point];

            _lastPoint = CGPointMake(point.xScale, point.yScale);
        }
    }
    
    
    _needUpdate = YES;
}

// 撤销操作
- (void)_cancelLinesWithUserId:(NSString *)userId {
    if (_allLines.lastLineIndex[userId]) {
        // 获取userId对应的最后一条画线
        NSInteger index = [_allLines.lastLineIndex[userId] integerValue];
        if (index > -1 && index < _allLines.allLines.count) {
            HYWbLine *line = _allLines.allLines[index];
            NSMutableArray *cancelLines = _cancelLines[userId];
            if (cancelLines == nil) {
                cancelLines = [NSMutableArray new];
                [_cancelLines setObject:cancelLines forKey:userId];
            }
            [cancelLines addObject:line];
            
            // 用空模型占位，做逻辑删除
            [_allLines.allLines setObject:[HYWbLine new] atIndexedSubscript:line.lineIndex];
            
            // 调整userId的指针位置
            [_allLines.lastLineIndex setObject:[NSNumber numberWithInteger:line.lastLineIndex] forKey:userId];
            
            _needUpdate = YES;
            
            // 发送消息
            if ([userId isEqualToString:UserOfLinesMine]) {
                [[HYConversationManager shared] sendEditAction:HYMessageCmdCancel];
            }
        }
    }
}

// 恢复操作
- (void)_resumeLineWithUserId:(NSString *)userId {
    if (_cancelLines[userId] && [_cancelLines[userId] count]) {
        NSMutableArray *cancelLines = _cancelLines[userId];
        HYWbLine *line = cancelLines.lastObject;
        
        // 替换掉用来的空模型
        [_allLines.allLines setObject:line atIndexedSubscript:line.lineIndex];
        [cancelLines removeObject:line];
        
        // 调整userId的指针位置
        [_allLines.lastLineIndex setObject:[NSNumber numberWithInteger:line.lineIndex] forKey:userId];
        
        _needUpdate = YES;
        
        // 发送消息
        if ([userId isEqualToString:UserOfLinesMine]) {
            [[HYConversationManager shared] sendEditAction:HYMessageCmdResume];
        }
    }
}

// 清除所有人的画线
- (void)_clearAllUserLinesWithUserId:(NSString *)userId {
    if (_allLines.allLines.count) {
        [_allLines.allLines removeAllObjects];
        [_cancelLines removeAllObjects];
        _needUpdate = YES;
        
        // 发送消息
        if ([userId isEqualToString:UserOfLinesMine]) {
            [[HYConversationManager shared] sendEditAction:HYMessageCmdClearAll];
        }
    }
}

// 插入图片
- (void)_insertImage:(UIBarButtonItem *)sender {
    
    sender.enabled  = NO;
    
    // 连接上传服务器
    __weak typeof(self) ws = self;
    [[HYUploadManager shared] connectUploadServerSuccessed:^(HYSocketService *service) {
        // 上传图片
        [ws _uploadImage];
    } failed:^(NSError *error) {
        NSLog(@"****HY Error:%@", error.domain);
        sender.enabled = YES;
    }];
}

// 上传图片
- (void)_uploadImage {
    
    // 发送图片信息
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"1424*2144-398KB" ofType:@"jpg"];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    
    [[HYUploadManager shared] sendImageInfoSize:CGSizeMake(4096, 4096) fileLength:(uint32_t)data.length];
    
    __weak typeof(self) ws = self;
    [[HYUploadManager shared] uploadImage:YES data:data progress:^(CGFloat progress) {
        NSLog(@"HY upload progress:%f", progress);
    } completion:^(BOOL success, NSUInteger length) {
        if (success) {
            // 显示图片
            [ws onNewImage:[UIImage imageWithContentsOfFile:filePath]];
            
            // 发送上传完成
            [[HYUploadManager shared] sendImageUploadCompletion];
        }
        else {
            NSLog(@"****HY upload Failed.");
        }
    }];
}

// 画笔模式按钮开关
- (void)_onClickDrawingBtn:(UIButton *)sender {
    
    // 退出画笔模式
    if (sender.isSelected) {
        _imageView.userInteractionEnabled = NO;
        _scrollView.scrollEnabled = YES;
        [sender setSelected:NO];
        sender.layer.borderColor = [UIColor grayColor].CGColor;
    }
    // 进入画笔模式
    else {
        _imageView.userInteractionEnabled = YES;
        _scrollView.scrollEnabled = NO;
        [sender setSelected:YES];
        sender.layer.borderColor = [UIColor redColor].CGColor;
    }
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
        _wbView.frame = self.imageView.frame;
        _wbView.dataSource = self;
    }
    
    return _wbView;
}

// scroll view
- (UIScrollView *)scrollView {
    if (_scrollView == nil) {
        _scrollView = [UIScrollView new];
        _scrollView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
        _scrollView.maximumZoomScale = 3.f;
        _scrollView.bounces = NO;
        _scrollView.bouncesZoom = NO;
        _scrollView.delegate = self;
        _scrollView.contentSize = CGSizeMake(_scrollView.frame.size.width, _scrollView.frame.size.height - 44.f - STATUS_BAR_HEIGHT);
        _scrollView.backgroundColor = [UIColor whiteColor];
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
    }
    
    return _scrollView;
}

// 图片
- (UIImageView *)imageView {
    if (_imageView == nil) {
        _imageView = [UIImageView new];
        _imageView.frame = CGRectMake(0, 0, _scrollView.contentSize.width, _scrollView.contentSize.height);
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.backgroundColor = [UIColor whiteColor];
        _imageView.userInteractionEnabled = _drawingBtn.isSelected ? YES : NO;
    }
    
    return _imageView;
}

// 画笔模式开关
- (UIButton *)drawingBtn {
    if (_drawingBtn == nil) {
        _drawingBtn = [UIButton new];
        _drawingBtn.frame = CGRectMake(15.f, 44.f + STATUS_BAR_HEIGHT + 10.f, 56.f, 56.f);
        _drawingBtn.layer.masksToBounds = YES;
        _drawingBtn.layer.cornerRadius = 28.f;
        _drawingBtn.layer.borderWidth = 1.f;
        _drawingBtn.backgroundColor = [UIColor whiteColor];
        _drawingBtn.layer.borderColor = [UIColor grayColor].CGColor;
        [_drawingBtn setTitle:@"画笔" forState:UIControlStateNormal];
        [_drawingBtn setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        [_drawingBtn setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
        _drawingBtn.titleLabel.font = [UIFont systemFontOfSize:14.f];
        [_drawingBtn addTarget:self action:@selector(_onClickDrawingBtn:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _drawingBtn;
}

@end
