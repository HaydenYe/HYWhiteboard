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
#import "HYUploadManager.h"

@interface HYServerManager () <HYSocketServiceDelegate>

@property (nonatomic, strong)HYSocketService *conService;
@property (nonatomic, strong)HYSocketService *uploadService;
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
- (void)startServerForListeningUpload:(BOOL)upload successed:(void (^)(NSString *, int))successd failed:(void (^)(NSError *))failed {
    __weak typeof(self) ws = self;
    
    // 监听上传端口
    if (upload) {
        [self.uploadService startlisteningToPort:kSocketUploadPort clientLimit:1 newClientDelegate:[HYUploadManager shared] completion:^(NSError *error) {
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    ws.conService = nil;
                    if (failed) {
                        failed(error);
                    }
                });
                
            }
            else {
                // 开启监听成功
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (successd) {
                        successd([HYSocketService getIPAddress:YES], kSocketUploadPort);
                    }
                });
            }
        }];
    }
    // 监听会话端口
    else {
        _currentPort = [self _dynamicPortForListening];
        [self.conService startlisteningToPort:_currentPort clientLimit:1 newClientDelegate:[HYConversationManager shared] completion:^(NSError *error) {
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    ws.conService = nil;
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
}

// 停止监听端口，断开连接
- (void)stopListeningPort {
    [_conService disconnectService];
    _conService = nil;
    
    [_uploadService disconnectService];
    _uploadService = nil;
}


#pragma mark - HYSocketServiceDelegate

// 有新的客户端连接
- (void)onSocketServiceAcceptNewClient:(HYSocketService *)client server:(HYSocketService *)server {
    
    // 会话服务器
    if (server.indexTag == 101) {
        [[HYConversationManager shared] addNewClient:client];
        if (_serverDelegate && [_serverDelegate respondsToSelector:@selector(onServerAcceptNewClient)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_serverDelegate onServerAcceptNewClient];
            });
        }
    }
    // 上传服务器
    else {
        [[HYUploadManager shared] addNewClient:client];
    }
}


#pragma mark - Property getter and setter

// 会话的服务器的服务
- (HYSocketService *)conService {
    if (_conService == nil) {
        _conService = [HYSocketService new];
        _conService.delegate = self;
        _conService.indexTag = 101;
    }
    return _conService;
}

// 上传的服务器的服务
- (HYSocketService *)uploadService {
    if (_uploadService == nil) {
        _uploadService = [HYSocketService new];
        _uploadService.delegate = self;
        _uploadService.indexTag = 102;
    }
    return _uploadService;
}


#pragma mark - Pravite methods

// 动态端口
- (int)_dynamicPortForListening {
    int offset = arc4random() % (65535 - 49152 + 1);
    if (offset == kSocketUploadPort - 49152) {
        return [self _dynamicPortForListening];
    }
    return 49152 + offset;
}

@end
