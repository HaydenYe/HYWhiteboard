//
//  HYSocketService.h
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2017/10/20.
//  Copyright © 2017年 HaydenYe. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HYSocket, HYSocketService;

#define kSocketConnectTimeout 20        // 连接服务器超时时间

#define kTimeSendHeartbeat    3         // 心跳发送的时间间隔
#define kTimeCheckHeartbeat   7         // 检测心跳包时间间隔

#define kCommandNormal        101       // 普通消息
#define kCommandFile          1001      // 文件消息
#define kCommandHeartbeat     10001     // 心跳包命令


@protocol HYSocketServiceDelegate <NSObject>

@optional

/**
 接收到消息的回调

 @param msgData 消息数据
 @param command 消息类型(默认分包的消息类型，普通消息，文件消息)
 @param service 接收到消息的socket服务
 */
- (void)onSocketServiceDidReceiveData:(NSData *)msgData
                              command:(uint16_t)command
                              service:(HYSocketService *)service;


/**
 socket断开连接的回调
 
 @param service socket服务
 */
- (void)onSocketServiceDidDisconnect:(HYSocketService *)service;


/**
 服务端接收到新的客户端的连接
 
 @param client 新客户端socket服务
 @param server 服务端socket服务
 */
- (void)onSocketServiceAcceptNewClient:(HYSocketService *)client
                                server:(HYSocketService *)server;

@end



@interface HYSocketService : NSObject

@property (nonatomic, weak)id<HYSocketServiceDelegate>  delegate;           // socket服务代理
@property (nonatomic, assign)NSInteger                  indexTag;           // socket服务的索引

@property (nonatomic, strong, readonly)HYSocket         *asyncSocket;       // socket
@property (nonatomic, strong, readonly)dispatch_queue_t processQueue;       // 处理待发送数据的线程


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
 @param clientLimit 允许客户端连接数量
 @param delegate    新客户端的代理
 @param completion  端口绑定完成，error为nil，则绑定成功
 */
- (void)startlisteningToPort:(int)port
                 clientLimit:(NSInteger)clientLimit
           newClientDelegate:(id)delegate
                  completion:(void(^)(NSError *error))completion;


/**
 发送消息
 
 @param msg         消息体
 @param completion  发送完成
 */
- (void)sendMessage:(id)msg
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


/**
 服务器端用于检测端口可用性（暂不使用）
 
 @param port        端口号
 @param preferIPv4  是否为ipv4
 @return 是否可用
 */
- (BOOL)portEnabled:(UInt16)port
         preferIPv4:(BOOL)preferIPv4;

@end
