//
//  HYUploadManager.m
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/3/3.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import "HYUploadManager.h"
#import "HYConversationManager.h"

@interface HYUploadManager () <HYSocketServiceDelegate>

@property (nonatomic, strong)HYSocketService    *service;

@property (nonatomic, assign)BOOL               isConnected;

@end


@implementation HYUploadManager

+ (instancetype)shared {
    static HYUploadManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[HYUploadManager alloc] init];
    });
    
    return manager;
}

// 建立上传socket通道
- (void)connectUploadServerSuccessed:(void (^)(HYSocketService *))successd failed:(void (^)(NSError *))failed {
    
    __weak typeof(self) ws = self;
    [self.service connectToHost:[HYConversationManager shared].host onPort:kSocketUploadPort forUpload:YES completion:^(NSError *error) {
        if (error) {
            ws.isConnected = NO;
            if (failed) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failed(error);
                });
            }
        }
        else {
            ws.isConnected = YES;
            if (successd) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    successd(ws.service);
                });
            }
        }
    }];
}

// 添加新客户端的服务
- (void)addNewClient:(HYSocketService *)clientService {
    _service = clientService;
}

// 上传文件
- (void)uploadImage:(BOOL)image data:(NSData *)data progress:(void (^)(CGFloat))progress completion:(void (^)(BOOL, NSUInteger))completion {
    [self.service sendMessage:data completion:^(BOOL success, NSUInteger length) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(success, length);
            });
        }
    }];
}

// 断开socket连接
- (void)disconnectUpload:(NSInteger)tag {
    [_service disconnectService];
    
    _isConnected = NO;
    _delegate = nil;
    _service = nil;
}


#pragma mark - HYSocketServiceDelegate

// 新消息
- (void)onSocketServiceDidReceiveData:(NSData *)msgData service:(HYSocketService *)service {
    
    // CGImage生成UIimage，不会产生中间bit图
    CGImageSourceRef sourceRef = CGImageSourceCreateWithData((__bridge CFDataRef)msgData, nil);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(sourceRef, 0, NULL);
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef];
    
    if (_delegate && [_delegate respondsToSelector:@selector(onNewImage:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate onNewImage:image];
        });
    }
}

// 断开连接
- (void)onSocketServiceDidDisconnect:(HYSocketService *)service {
    _isConnected = NO;
    _service = nil;
    
    if (_delegate && [_delegate respondsToSelector:@selector(onSocketServiceDisconnect:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate onSocketServiceDisconnect:service];
        });
    }
}


#pragma mark - Property getter and setter

// socket
- (HYSocketService *)service {
    if (_service == nil) {
        _service = [HYSocketService new];
        _service.delegate = self;
        _service.indexTag = 300;
    }
    return _service;
}

@end
