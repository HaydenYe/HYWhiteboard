//
//  HYSocketService.h
//  HYEfficientWhiteBoard
//
//  Created by apple on 2017/10/20.
//  Copyright © 2017年 HaydenYe. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kSocketConnectTimeout 20        // 连接服务器超时时间

#define kTimeSendHeartbeat    3         // 心跳发送的时间间隔
#define kTimeCheckHeartbeat   6         // 检测心跳包时间间隔
#define kCommandHeartbeat     10001     // 心跳包命令

@class HYSocket, HYSocketService;

@protocol HYSocketServiceDelegate <NSObject>

/**
 接收到消息的回调

 @param msgData 消息数据
 */
- (void)onSocketServiceDidReceiveData:(NSData *)msgData;

@optional

/**
 socket断开连接的回调
 
 @param service socket服务
 */
- (void)onSocketServiceDidDisconnect:(HYSocketService *)service;

@end



@interface HYSocketService : NSObject

@property (nonatomic, weak)id<HYSocketServiceDelegate>  delegate;
@property (nonatomic, assign)NSInteger                  tag;

@property (nonatomic, strong, readonly)HYSocket         *asyncSocket;
@property (nonatomic, strong, readonly)dispatch_queue_t processQueue;
@property (nonatomic, assign, readonly)NSInteger        clientCount;



/**
 连接服务器
 
 @param host        服务器ip地址
 @param port        服务器端口号
 @param upload      是否为上传通道
 @param completion  连接完成的回调，error为nil，则连接成功
 */
- (void)connectToHost:(NSString *)host
               onPort:(int)port
            forUpload:(BOOL)upload
           completion:(void(^)(NSError *error))completion;


/**
 服务器绑定端口
 
 @param port        被监听的端口号
 @param completion  端口绑定完成，host为ip地址，则绑定成功
 @param handler     新客户端连接的回调
 */
- (void)startlisteningToPort:(int)port
                  completion:(void(^)(NSString *host))completion
                   newClient:(void(^)(NSError *error))handler;


/**
 发送消息
 
 @param msg         消息体
 @param type        消息类型
 @param completion  发送完成
 */
- (void)sendMessage:(id)msg
        commandType:(NSInteger)type
         completion:(void(^)(BOOL success, NSUInteger length))completion;


/**
 校验服务器地址
 
 @param ip      服务器ip地址
 @param port    服务器端口号
 @return error为nil，则通过检验
 */
- (NSError *)isValidAddress:(NSString *)ip
                       port:(int)port;


/**
 断开socket连接
 */
- (void)disconnectService;


/**
 获取本机的ip地址
 
 @param preferIPv4 是否为IPv4地址
 @return 本机IP地址
 */
+ (NSString *)getIPAddress:(BOOL)preferIPv4;

@end
