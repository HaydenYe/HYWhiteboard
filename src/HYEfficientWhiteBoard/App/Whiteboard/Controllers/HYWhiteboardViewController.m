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

@property (nonatomic, strong)NSMutableDictionary*allLines;      // 所有画线
@property (nonatomic, strong)NSMutableArray     *cancelLines;   // 被撤销画线
@property (nonatomic, assign)BOOL               isEraser;       // 是否为橡皮模式
@property (nonatomic, assign)BOOL               needUpdate;     // 需要更新白板视图

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
            if (_allLines[UserOfLinesMine] && [_allLines[UserOfLinesMine] count]) {
                NSArray *line = [_allLines[UserOfLinesMine] lastObject];
                [_cancelLines addObject:line];
                [_allLines[UserOfLinesMine] removeObject:line];
                _needUpdate = YES;
                
                [[HYConversationManager shared] sendEditAction:HYMessageCmdCancel];
            }
            break;
        }
            
        // 恢复
        case 24:{
            if (_cancelLines.count) {
                [_allLines[UserOfLinesMine] addObject:_cancelLines.lastObject];
                [_cancelLines removeObjectAtIndex:_cancelLines.count - 1];
                _needUpdate = YES;
                
                [[HYConversationManager shared] sendEditAction:HYMessageCmdResume];
            }
            break;
        }
            
        // 清除
        case 25:{
            if (_allLines.count) {
                [_allLines removeAllObjects];
                _needUpdate = YES;
                
                [[HYConversationManager shared] sendEditAction:HYMessageCmdClearAll];
            }
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
}

// 接收到撤销，恢复，全部擦除消息
- (void)onReceiveEditAction:(HYMessageCmd)type {
    switch (type) {
        // 撤销
        case HYMessageCmdCancel:{
            if (_allLines[UserOfLinesOther] && [_allLines[UserOfLinesOther] count]) {
                NSArray *line = [_allLines[UserOfLinesOther] lastObject];
                [_cancelLines addObject:line];
                [_allLines[UserOfLinesMine] removeObject:line];
                _needUpdate = YES;
            }
            break;
        }
            
        // 恢复
        case HYMessageCmdResume:{
            if (_cancelLines.count) {
                [_allLines[UserOfLinesOther] addObject:_cancelLines.lastObject];
                [_cancelLines removeObjectAtIndex:_cancelLines.count - 1];
                _needUpdate = YES;
            }
            break;
        }
            
        // 清除
        case HYMessageCmdClearAll:{
            [_allLines removeAllObjects];
            _needUpdate = YES;
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
    
    _allLines = [NSMutableDictionary new];
    _cancelLines = [NSMutableArray new];
    
    _drawable = YES;
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
