//
//  HYServerManager.h
//  HYEfficientWhiteBoard
//
//  Created by apple on 2018/2/26.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HYSocketService;


@protocol HYServerDelegate <NSObject>

/**
 服务端接收新的客户端连接
 */
- (void)onServerAcceptNewClient;

@end


@interface HYServerManager : NSObject

@property (nonatomic, strong, readonly)HYSocketService *serveice;
@property (nonatomic, weak)id<HYServerDelegate>        serverDelegate;


+ (instancetype)shared;


/**
 开启监听端口
 
 @param successd 监听端口成功
 @param failed 监听失败
 */
- (void)startServerForListeningSuccessed:(void (^)(NSString *ip, int port))successd
                                  failed:(void (^)(NSError *error))failed;


/**
 停止监听端口，断开连接
 */
- (void)stopListeningPort;

@end
