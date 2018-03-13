//
//  HYSocket.h
//  Test_Server
//
//  Created by HaydenYe on 2017/8/2.
//  Copyright © 2017年 HYdrate. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HYSocket;

#define BUFFER_SIZE DATABUFFER_SIZE + DATALENGTH_SIZE + CMDLENGTH_SIZE // socketI/O数据流的缓冲池总大小
#define DATABUFFER_SIZE     1024    // 设置数据分包大小
#define DATALENGTH_SIZE     4       // 数据的长度占4个字节
#define CMDLENGTH_SIZE      2       // 消息类型长度占2个字节

#define kCommandDefault     11      // 默认分包的命令类型

typedef NS_ENUM(NSUInteger, HYSocketType) {
    HYSocketTypeNone = 0,       // 未知
    HYSocketTypeClient,         // 客户端
    HYSocketTypeOneClient,      // 服务器的客户端
    HYSocketTypeServer,         // 服务器监听端口
};


@protocol HYSocketDelegate <NSObject>

@required
/**
 接收数据
 
 @param socket 接收数据的socket
 @param data   接收到的数据
 @param buff   接收到的原始数据
 */
- (void)onSocket:(HYSocket *)socket
  didReceiveData:(NSData *)data
      originBuff:(uint8_t *)buff;

@optional
/**
 服务端开启监听端口
 
 @param socket  服务端监听端口的socket
 @param error   error为nil，则监听成功
 */
- (void)onSocketDidStartListening:(HYSocket *)socket
                        withError:(NSError *)error;


/**
 客户端连接服务器
 
 @param socket  客户端socket
 @param error   error为nil，则连接服务器成功
 */
- (void)onSocketDidConnectServer:(HYSocket *)socket
                       withError:(NSError *)error;


/**
 socket断开
 
 @param socket 断开的socket
 */
- (void)onSocketDidDisConnect:(HYSocket *)socket;


/**
 服务端收到新客户端的连接
 
 @param socket  新建立的与客户端的socket
 @param error   error为nil，建立连接成功
 */
- (void)onSocketDidAcceptNewClient:(HYSocket *)socket
                         withError:(NSError *)error;

@end


@interface HYSocket : NSObject <NSStreamDelegate> {
    CFSocketRef _socketipv4;
    CFSocketRef _socketipv6;
    
    CFSocketNativeHandle _nativeSocket4;
    CFSocketNativeHandle _nativeSocket6;
    
    NSInputStream   *_inputStream;
    NSOutputStream  *_outputStream;
        
    dispatch_queue_t _queue;
    
    NSTimeInterval _timeOut;
}

@property (nonatomic, assign)id<HYSocketDelegate>                   delegate;     // 代理

@property (nonatomic, assign, readonly)HYSocketType                 socketType;   // socket类型
@property (nonatomic, assign, readonly)BOOL                         isConnected;  // 是否连接上

@property (nonatomic, strong, readonly)NSMutableArray<HYSocket *>   *clientList;  // 连接上的客户端的数组(服务器端使用)
@property (nonatomic, weak, readonly)HYSocket                       *server;      // 服务端socket(OneClient 使用)


/**
 服务端设置监听端口

 @param port        端口号
 @param clientLimit 允许客户端连接数量
 @param queue       监听端口的线程
 */
- (void)listeningPort:(UInt16)port
          clientLimit:(NSInteger)clientLimit
           asyncQueue:(dispatch_queue_t)queue;


/**
 客户端链接服务器

 @param ip      服务器ip地址
 @param port    服务器端口号
 @param time    超时时间
 @param queue   接收，写入数据的队列
 */
- (void)connectServer:(NSString *)ip
                 port:(UInt16)port
              timeOut:(NSTimeInterval)time
    readAndWriteQueue:(dispatch_queue_t)queue;


/**
 写入数据
 
 @param data        数据
 @param direct      是否直接发送（不分包）
 @param queue       发送的线程
 @param completion  发送完成的回调
 */
- (void)writeData:(NSData *)data
       asyncQueue:(dispatch_queue_t)queue
           direct:(BOOL)direct
       completion:(void(^)(BOOL success, NSUInteger length))completion;


/**
 断开连接
 */
- (void)disconnect;


// 暂不使用
- (NSString *)hostAddress;
- (NSString *)hostPort;

@end
