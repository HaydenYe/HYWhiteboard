//
//  HYConversationManager.h
//  HYEfficientWhiteBoard
//
//  Created by apple on 2017/10/24.
//  Copyright © 2017年 HaydenYe. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kTimeIntervalSendCmd    0.06f   // 发送命令的时间间隔

@class HYSocketService;

@interface HYConversationManager : NSObject

@property (nonatomic, strong)NSMutableArray                 *cmdBuff;

@property (nonatomic, strong, readonly)HYSocketService      *serveice;
@property (nonatomic, assign, readonly)BOOL                 isConnected;



+ (instancetype)shared;

- (void)startServerWithPort:(int)port
                 completion:(void(^)(NSString *host))completion
   clientConnectedSuccessed:(void(^)(HYSocketService *service))successd
                     failed:(void(^)(NSError *error))failed;

/**
 连接服务器
 
 @param host        服务器地址
 @param port        服务器端口号
 @param successd    连接成功
 @paraHYSocketService接失败
 */
- (void)connectWhiteboardServer:(NSString *)host
                           port:(int)port
                      successed:(void(^)(HYSocketService *service))successd
                         failed:(void(^)(NSError *error))failed;

@end
