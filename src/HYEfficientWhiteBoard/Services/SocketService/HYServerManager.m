//
//  HYServerManager.m
//  HYEfficientWhiteBoard
//
//  Created by apple on 2018/2/26.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import "HYServerManager.h"
#import "HYSocketService.h"
#import "HYConversationManager.h"

@interface HYServerManager () <HYSocketServiceDelegate>

@property (nonatomic, strong)HYSocketService *serveice;
@property (nonatomic, assign)int             currentPort;

@end

@implementation HYServerManager

+ (instancetype)shared {
    static HYServerManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[HYServerManager alloc] init];
    });
    
    return manager;
}

// 开启监听端口
- (void)startServerForListeningSuccessed:(void (^)(NSString *, int))successd failed:(void (^)(NSError *))failed {
    
    __weak typeof(self) ws = self;
    _currentPort = [self _dynamicPortForListening];
    [self.serveice startlisteningToPort:_currentPort clientLimit:1 newClientDelegate:[HYConversationManager shared] completion:^(NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                ws.serveice = nil;
                if (failed) {
                    failed(error);
                }
            });
            
        }
        else {
            // 开启监听成功
            dispatch_async(dispatch_get_main_queue(), ^{
                if (successd) {
                    successd([HYSocketService getIPAddress:YES], ws.currentPort);
                }
            });
        }
    }];
}


#pragma mark - HYSocketServiceDelegate

// 有新的客户端连接
- (void)onSocketServiceAcceptNewClient:(HYSocketService *)client server:(HYSocketService *)server {
    if (_serverDelegate && [_serverDelegate respondsToSelector:@selector(onServerAcceptNewClient)]) {
        [_serverDelegate onServerAcceptNewClient];
    }
}


#pragma mark - Property getter and setter

// socket
- (HYSocketService *)serveice {
    if (_serveice == nil) {
        _serveice = [HYSocketService new];
        _serveice.delegate = self;
        
    }
    return _serveice;
}


#pragma mark - Pravite methods

// 动态端口
- (int)_dynamicPortForListening {
    int offset = arc4random() % (65535 - 49152 + 1);
    return 49152 + offset;
}

@end
