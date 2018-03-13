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

@property (nonatomic, strong)NSMutableData      *receivedData;
@property (nonatomic, assign)CGSize             imageSize;
@property (nonatomic, assign)NSInteger          imageLength;

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

// 发送图片信息
- (void)sendImageInfoSize:(CGSize)size fileLength:(uint32_t)length {
    NSString *msg = [NSString stringWithFormat:kMsgImageInfoFormatter, HYUploadCmdImageInfo, (uint32_t)size.width, (uint32_t)size.height, length];
    [self.service sendMessage:msg completion:nil];
}

// 发送图片上传完成的消息
- (void)sendImageUploadCompletion {
    NSString *msg = [NSString stringWithFormat:kMsgUploadCompletionFormatter, HYUploadCmdUploadCompletion];
    [self.service sendMessage:msg completion:nil];
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
- (void)disconnectUpload {
    if (_service == nil) {
        return ;
    }
    
    [_service disconnectService];
    
    _isConnected = NO;
    _delegate = nil;
    _service = nil;
}


#pragma mark - HYSocketServiceDelegate

// 新消息
- (void)onSocketServiceDidReceiveData:(NSData *)msgData command:(uint16_t)command service:(HYSocketService *)service {
    
    // 普通消息
    if (command == kCommandNormal) {
        NSMutableString *msg = [[NSMutableString alloc] initWithData:msgData encoding:NSUTF8StringEncoding];
        NSArray *dataArr = [msg componentsSeparatedByString:@","];
        
        if (dataArr.count <= 0) {
            return ;
        }
        
        HYUploadCmd cmd = [dataArr.firstObject integerValue];
        switch (cmd) {
                
            // 图片信息
            case HYUploadCmdImageInfo:{
                _imageSize = CGSizeMake([dataArr[1] floatValue], [dataArr[2] floatValue]);
                _imageLength = [dataArr.lastObject integerValue];
                if (_receivedData) {
                    [_receivedData resetBytesInRange:NSMakeRange(0, _receivedData.length)];
                    [_receivedData setLength:0];
                }
                break;
            }
                
            // 图片已上传完
            case HYUploadCmdUploadCompletion:{
                
                if (self.receivedData.length != _imageLength) {
                    NSLog(@"****HY 接受图片失败，数据不全");
                    return ;
                }
                
                // CGImage生成UIimage，不会产生中间bit图
                CGImageSourceRef sourceRef = CGImageSourceCreateWithData((__bridge CFDataRef)_receivedData, nil);
                CGImageRef imageRef = CGImageSourceCreateImageAtIndex(sourceRef, 0, NULL);
                UIImage *image = [[UIImage alloc] initWithCGImage:imageRef];
                
                if (_delegate && [_delegate respondsToSelector:@selector(onNewImage:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_delegate onNewImage:image];
                    });
                }
                
                // 断开连接
                [_service disconnectService];
                break;
            }
                
            default:
                break;
        }
    }
    // 文件数据
    else {
        [self.receivedData appendData:msgData];
    }
}

// 断开连接
- (void)onSocketServiceDidDisconnect:(HYSocketService *)service {
    _isConnected = NO;
    _service = nil;
    
    if (_delegate && [_delegate respondsToSelector:@selector(onUploadServiceDisconnect)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate onUploadServiceDisconnect];
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

// 接收到的图片数据
- (NSMutableData *)receivedData {
    if (_receivedData == nil) {
        _receivedData = [NSMutableData new];
    }
    
    return _receivedData;
}

@end
