//
//  HYHomeViewController.m
//  HYEfficientWhiteBoard
//
//  Created by apple on 2017/10/20.
//  Copyright © 2017年 HaydenYe. All rights reserved.
//

#import "HYHomeViewController.h"
#import "HYConversationManager.h"
#import "HYServerManager.h"

#import "HYWhiteboardViewController.h"

@interface HYHomeViewController () <UITextFieldDelegate, HYServerDelegate>

@property (nonatomic, strong)UIButton    *serverBtn;     // 选择按钮
@property (nonatomic, strong)UILabel     *serverLb;      // 显示服务器ip地址
@property (nonatomic, strong)UIButton    *refreshPortBtn;// 刷新端口号

@property (nonatomic, strong)UIButton    *clientBtn;     // 选择按钮
@property (nonatomic, strong)UITextField *clientTf;      // 输入连接服务器的地址

@property (nonatomic, strong)UILabel     *loadingLb;     // loading...

@property (nonatomic, strong)UIButton    *whiteboardBtn; // 白板按钮

@end

@implementation HYHomeViewController

#pragma mark - Life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"网络连接";
    [self _configOwnViews];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - HYServerDelegate

// 有客户端连接
- (void)onServerAcceptNewClient {
    // 跳转白板页面
    HYWhiteboardViewController *vc = [HYWhiteboardViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    
    if (textField.text.length < 1) {
        textField.text = [HYSocketService getIPAddress:YES];
    }
    
    return YES;
}

// 输入ip地址完成
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.view endEditing:YES];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.loadingLb.text = @"连接中...";
    
    // 连接服务器
    NSMutableString *text = [[NSMutableString alloc] initWithString:textField.text];
    NSArray *strArr = [text componentsSeparatedByString:@" "];
    if (strArr.count != 2) {
        self.loadingLb.text = @"ip输入格式有误,例:172.168.2.2 43999";
        return ;
    }
    
    __weak typeof(self) ws = self;
    [[HYConversationManager shared] connectWhiteboardServer:strArr[0] port:[strArr[1] intValue] successed:^(HYSocketService *service) {
        // 跳转白板页面
        HYWhiteboardViewController *vc = [HYWhiteboardViewController new];
        [ws.navigationController pushViewController:vc animated:YES];
        
        ws.loadingLb.text = @"连接成功";
    } failed:^(NSError *error) {
        NSLog(@"****HY Error:%@", error.domain);
        ws.loadingLb.text = error.domain;
    }];
}


#pragma mark - Private methods

// 设置子视图
- (void)_configOwnViews {
    self.serverBtn.frame = CGRectMake(0, 225.f, [UIScreen mainScreen].bounds.size.width, 44.f);
    self.clientBtn.frame = CGRectMake(0, 275.f, [UIScreen mainScreen].bounds.size.width, 44.f);
    self.whiteboardBtn.frame = CGRectMake(0, 325, [UIScreen mainScreen].bounds.size.width, 44.f);
    [self.view addSubview:_serverBtn];
    [self.view addSubview:_clientBtn];
    [self.view addSubview:_whiteboardBtn];
}


// 选择按钮点击事件
- (void)_didClickButton:(UIButton *)sender {
    
    // 服务器
    if (sender.tag == 100) {
        _serverBtn.hidden = YES;
        _clientBtn.hidden = YES;
        _whiteboardBtn.hidden = YES;
        
        [HYServerManager shared].serverDelegate = self;
        
        self.serverLb.frame = CGRectMake(0, 250.f, [UIScreen mainScreen].bounds.size.width, 44.f);
        [self.view addSubview:_serverLb];
        
        self.refreshPortBtn.frame = CGRectMake(0, 300.f, [UIScreen mainScreen].bounds.size.width, 44.f);
        [self.view addSubview:_refreshPortBtn];
        
        // 开启上传服务器监听
        [[HYServerManager shared] startServerForListeningUpload:YES successed:^(NSString *ip, int port) {
            NSLog(@"HY 上传地址：%@", [NSString stringWithFormat:@"服务器ip: %@ 端口号: %zd", ip, port]);
        } failed:^(NSError *error) {
            NSLog(@"****HY Error:监听上传端口失败");
        }];
        
        // 开启服务器监听
        __weak typeof(self) ws = self;
        [[HYServerManager shared] startServerForListeningUpload:NO successed:^(NSString *ip, int port) {
            ws.serverLb.text = [NSString stringWithFormat:@"服务器ip: %@ 端口号: %zd", ip, port];
        } failed:^(NSError *error) {
            NSLog(@"****HY Error:监听会话端口失败");
            ws.serverLb.text = error.domain;
        }];
        
        
    }
    // 刷新端口号
    else if (sender.tag == 110) {
        [[HYServerManager shared] stopListeningPort];
        
        // 开启会话服务器监听
        __weak typeof(self) ws = self;
        [[HYServerManager shared] startServerForListeningUpload:NO successed:^(NSString *ip, int port) {
            ws.serverLb.text = [NSString stringWithFormat:@"服务器ip: %@ 端口号: %zd", ip, port];
        } failed:^(NSError *error) {
            NSLog(@"****HY Error:监听会话端口失败");
            ws.serverLb.text = error.domain;
        }];
        
        // 开启上传服务器监听
        [[HYServerManager shared] startServerForListeningUpload:YES successed:^(NSString *ip, int port) {
            NSLog(@"HY 上传地址：%@", [NSString stringWithFormat:@"服务器ip: %@ 端口号: %zd", ip, port]);
        } failed:^(NSError *error) {
            NSLog(@"****HY Error:监听上传端口失败");
        }];
    }
    // 客户端
    else if (sender.tag == 200) {
        _serverBtn.hidden = YES;
        _clientBtn.hidden = YES;
        _whiteboardBtn.hidden = YES;
        
        self.clientTf.frame = CGRectMake(0, 250.f, [UIScreen mainScreen].bounds.size.width, 44.f);
        [self.view addSubview:_clientTf];
    }
    // 直接进入白板
    else {
        HYWhiteboardViewController *vc = [HYWhiteboardViewController new];
        [self.navigationController pushViewController:vc animated:YES];
    }
}


#pragma mark - Property

// 选择按钮（服务器）
- (UIButton *)serverBtn {
    if (_serverBtn == nil) {
        _serverBtn = [UIButton new];
        [_serverBtn setTitle:@"将此设备设置为服务器" forState:UIControlStateNormal];
        [_serverBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        _serverBtn.titleLabel.font = [UIFont systemFontOfSize:15.f];
        _serverBtn.layer.borderColor = [UIColor blackColor].CGColor;
        _serverBtn.layer.borderWidth = 1.f;
        _serverBtn.tag = 100;
        [_serverBtn addTarget:self action:@selector(_didClickButton:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _serverBtn;
}

// 显示服务器ip地址
- (UILabel *)serverLb {
    if (_serverLb == nil) {
        _serverLb = [UILabel new];
        _serverLb.textAlignment = NSTextAlignmentCenter;
        _serverLb.font = [UIFont systemFontOfSize:15.f];
    }
    
    return _serverLb;
}

// 刷新服务器端口号
- (UIButton *)refreshPortBtn {
    if (_refreshPortBtn == nil) {
        _refreshPortBtn = [UIButton new];
        [_refreshPortBtn setTitle:@"刷新端口号" forState:UIControlStateNormal];
        [_refreshPortBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        _refreshPortBtn.titleLabel.font = [UIFont systemFontOfSize:15.f];
        _refreshPortBtn.layer.borderColor = [UIColor blackColor].CGColor;
        _refreshPortBtn.layer.borderWidth = 1.f;
        _refreshPortBtn.tag = 110;
        [_refreshPortBtn addTarget:self action:@selector(_didClickButton:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _refreshPortBtn;
}

// 选择按钮（客户端）
- (UIButton *)clientBtn {
    if (_clientBtn == nil) {
        _clientBtn = [UIButton new];
        [_clientBtn setTitle:@"将此设备设置为客户端" forState:UIControlStateNormal];
        [_clientBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        _clientBtn.titleLabel.font = [UIFont systemFontOfSize:15.f];
        _clientBtn.layer.borderColor = [UIColor blackColor].CGColor;
        _clientBtn.layer.borderWidth = 1.f;
        _clientBtn.tag = 200;
        [_clientBtn addTarget:self action:@selector(_didClickButton:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _clientBtn;
}

// 输入连接服务器的地址
- (UITextField *)clientTf {
    if (_clientTf == nil) {
        _clientTf = [UITextField new];
        _clientTf.placeholder = @"输入服务器ip地址和端口(ip和端口用空格隔开)";
        _clientTf.delegate = self;
        _clientTf.textAlignment = NSTextAlignmentCenter;
        _clientTf.font = [UIFont systemFontOfSize:14.f];
        _clientTf.borderStyle = UITextBorderStyleLine;
        _clientTf.returnKeyType = UIReturnKeyDone;
    }
    
    return _clientTf;
}

// loading...
- (UILabel *)loadingLb {
    if (_loadingLb == nil) {
        _loadingLb = [UILabel new];
        _loadingLb.textAlignment = NSTextAlignmentCenter;
        _loadingLb.font = [UIFont systemFontOfSize:15.f];
        [self.view addSubview:_loadingLb];
        self.loadingLb.frame = CGRectMake(0, 300.f, [UIScreen mainScreen].bounds.size.width, 44.f);
    }
    
    return _loadingLb;
}

// 白板按钮
- (UIButton *)whiteboardBtn {
    if (_whiteboardBtn == nil) {
        _whiteboardBtn = [UIButton new];
        [_whiteboardBtn setTitle:@"进入白板(不使用网络)" forState:UIControlStateNormal];
        [_whiteboardBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        _whiteboardBtn.titleLabel.font = [UIFont systemFontOfSize:15.f];
        _whiteboardBtn.layer.borderColor = [UIColor blackColor].CGColor;
        _whiteboardBtn.layer.borderWidth = 1.f;
        _whiteboardBtn.tag = 300;
        [_whiteboardBtn addTarget:self action:@selector(_didClickButton:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _whiteboardBtn;
}

@end
