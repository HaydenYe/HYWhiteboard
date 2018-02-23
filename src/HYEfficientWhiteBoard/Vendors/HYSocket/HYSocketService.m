//
//  HYSocketService.m
//  HYEfficientWhiteBoard
//
//  Created by apple on 2017/10/20.
//  Copyright © 2017年 HaydenYe. All rights reserved.
//

#import "HYSocketService.h"
#import "HYSocket.h"

#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>

#define IOS_WWAN        @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IOS_VPN         @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

@interface HYSocketService () <HYSocketDelegate>

@property (nonatomic, strong)HYSocket           *asyncSocket;
@property (nonatomic, strong)NSMutableData      *receiveDatas;
@property (nonatomic, assign)BOOL               upload;
@property (nonatomic, assign)NSInteger          clientCount;

@property (nonatomic, strong)dispatch_queue_t   heartbeatQueue;
@property (nonatomic, assign)NSTimeInterval     heartbeatStamp;
@property (nonatomic, strong)NSTimer            *sendTimer;
@property (nonatomic, strong)NSTimer            *checkTimer;

@property (nonatomic, strong)dispatch_queue_t   streamQueue;
@property (nonatomic, strong)dispatch_queue_t   processQueue;

@property (nonatomic, strong)dispatch_queue_t   listenQueue;

@property (nonatomic, strong)void (^connectServer)(NSError *error);
@property (nonatomic, strong)void (^startListening)(NSString *host);

@end

@implementation HYSocketService

- (instancetype)init {
    if (self = [super init]) {
        _asyncSocket = [HYSocket new];
        _asyncSocket.delegate = self;
        _heartbeatQueue = dispatch_queue_create("com.Hayden.heartbeatQueue", DISPATCH_QUEUE_CONCURRENT);
        _processQueue = dispatch_queue_create("com.Hayden.processQueue", NULL);
        _streamQueue = dispatch_queue_create("com.Hayden.streamQueue", NULL);
        _listenQueue = dispatch_queue_create("com.Hayden.listenPortQueue", DISPATCH_QUEUE_CONCURRENT);
        _sendTimer = [NSTimer timerWithTimeInterval:kTimeSendHeartbeat target:self selector:@selector(_sendHeartbeatMessage) userInfo:nil repeats:YES];
        _checkTimer = [NSTimer timerWithTimeInterval:kTimeCheckHeartbeat target:self selector:@selector(_checkHeartbeatMessage) userInfo:nil repeats:YES];
    }
    return self;
}

// 连接服务器
- (void)connectToHost:(NSString *)host onPort:(int)port forUpload:(BOOL)upload completion:(void (^)(NSError *))completion {
    _connectServer = completion;
    _upload = upload;
    _receiveDatas = [NSMutableData new];
    [_asyncSocket connectServer:host port:port timeOut:kSocketConnectTimeout readAndWriteQueue:_streamQueue];
}

// 服务器监听端口号
- (void)startlisteningToPort:(int)port completion:(void (^)(NSString *))completion newClient:(void (^)(NSError *))handler {
    _startListening = completion;
    _connectServer = handler;
    [_asyncSocket listeningPort:port asyncQueue:_listenQueue];
}

// 发送消息
- (void)sendMessage:(id)msg commandType:(NSInteger)type completion:(void (^)(BOOL, NSUInteger))completion {
    
    // 消息类型
    if ([msg isKindOfClass:[NSString class]]) {
        // 序列化
        NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
        
        // 发送数据
        [self.asyncSocket writeData:msgData asyncQueue:_processQueue direct:NO completion:completion];
    }
    // 文件类型
    else if ([msg isKindOfClass:[NSData class]]) {
        // 发送数据
        [self.asyncSocket writeData:msg asyncQueue:_processQueue direct:NO completion:completion];
    }
    // 未知
    else {
        NSLog(@"****HY Error:未知类型的消息");
    }
}

// 服务器地址是否正确
- (NSError *)isValidAddress:(NSString *)ip port:(int)port {
    if (ip == nil || ip.length < 1 || port < 1) {
        return [NSError errorWithDomain:@"服务器地址错误" code:kCFSocketError userInfo:@{@"ip":ip, @"port":[NSString stringWithFormat:@"%zd", port]}];
    }
    else {
        return nil;
    }
}

// 断开连接
- (void)disconnectService {
    
    if (_asyncSocket.isConnected) {
        [_asyncSocket disconnect];
    }
    
    _receiveDatas = nil;
    _connectServer = nil;
    _upload = NO;
    
    [_checkTimer invalidate];
    [_sendTimer invalidate];
    
    _asyncSocket = nil;
}

// 获取本地ip地址
+ (NSString *)getIPAddress:(BOOL)preferIPv4 {
    NSArray *searchArray = preferIPv4 ?
    @[ /*IOS_VPN @"/" IP_ADDR_IPv4, IOS_VPN @"/" IP_ADDR_IPv6,*/ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WWAN @"/" IP_ADDR_IPv4, IOS_WWAN @"/" IP_ADDR_IPv6 ] :
    @[ /*IOS_VPN @"/" IP_ADDR_IPv6, IOS_VPN @"/" IP_ADDR_IPv4,*/ IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WWAN @"/" IP_ADDR_IPv6, IOS_WWAN @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [self _getIPAddresses];
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         if(address) *stop = YES;
     } ];
    return address ? address : @"0.0.0.0";
}



#pragma mark - HYSocketDelegate

// 接收数据
- (void)onSocket:(HYSocket *)socket didReceiveData:(NSData *)data originBuff:(uint8_t *)buff {
    
    if (data.length >= DATALENGTH_SIZE) {
        // 上一个包存在半包，且不是递归
        if (socket && _receiveDatas.length > 0) {
            [_receiveDatas appendData:data];
            data = [_receiveDatas copy];
        }
        
        // 清空数据
        [_receiveDatas resetBytesInRange:NSMakeRange(0, data.length)];
        [_receiveDatas setLength:0];
        
        // 获取数据长度
        uint32_t dataLength;
        [data getBytes:&dataLength range:NSMakeRange(0, DATALENGTH_SIZE)];
        
        // 完整数据包
        if (dataLength == data.length - DATALENGTH_SIZE) {
            // 心跳包
            NSData *msgData = [data subdataWithRange:NSMakeRange(DATALENGTH_SIZE, dataLength)];
            if (dataLength == 2 + DATALENGTH_SIZE && [self _commandWithData:msgData] == kCommandHeartbeat) {
                _heartbeatStamp = [[NSDate date] timeIntervalSince1970];
            }
            // 其他数据
            else {
                // 分发数据
                if (_delegate && [_delegate respondsToSelector:@selector(onSocketServiceDidReceiveData:)]) {
                    [_delegate onSocketServiceDidReceiveData:[data subdataWithRange:NSMakeRange(DATALENGTH_SIZE, dataLength)]];
                }
            }
        }
        // 粘包
        else if (dataLength < data.length - DATALENGTH_SIZE) {
            // 分发完整数据
            if (_delegate && [_delegate respondsToSelector:@selector(onSocketServiceDidReceiveData:)]) {
                [_delegate onSocketServiceDidReceiveData:[data subdataWithRange:NSMakeRange(DATALENGTH_SIZE, dataLength)]];
            }
            // 剪裁数据
            [_receiveDatas appendData:[data subdataWithRange:NSMakeRange(DATALENGTH_SIZE + dataLength, data.length - (DATALENGTH_SIZE + dataLength))]];;
            // 递归解析
            [self onSocket:nil didReceiveData:[_receiveDatas copy] originBuff:nil];
        }
        // 半包
        else {
            [_receiveDatas appendData:data];
        }
    }
    // 半包
    else if (data.length > 0) {
        [_receiveDatas appendData:data];
    }
}

// 连接服务器
- (void)onSocketDidConnectServer:(HYSocket *)socket withError:(NSError *)error {
    if (socket.socketType == HYSocketTypeClient) {
        if (error == nil) {
            // 开启心跳包
            [self _startRunLoopForHeartbeat];
        }
        
        if (_connectServer) {
            _connectServer(error);
            _connectServer = nil;
        }
        else if (error) {
            [self onSocketDidDisConnect:nil];
        }
    }
}

// 连接断开
- (void)onSocketDidDisConnect:(HYSocket *)socket {
    [self disconnectService];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(onSocketServiceDidDisconnect:)]) {
        [self.delegate onSocketServiceDidDisconnect:self];
    }
}

// 服务器开启监听
- (void)onSocketDidStartListening:(HYSocket *)socket withError:(NSError *)error {
    
    if (error) {
        if (_startListening) {
            _startListening(@"端口监听失败...");
            _startListening = nil;
        }
    }
    else {
        if (_startListening) {
            _startListening([HYSocketService getIPAddress:YES]);
            _startListening = nil;
        }
    }
}

// 新客户端连接到服务器
- (void)onSocketDidAcceptNewClient:(HYSocket *)socket withError:(NSError *)error {
    // 连接成功
    if (error == nil) {
        _clientCount = _asyncSocket.clientList.count;
        // 开启心跳包
        [self _startRunLoopForHeartbeat];
    }
    
    if (_connectServer) {
        _connectServer(error);
        _connectServer = nil;
    }
    else if (error) {
        [self onSocketDidDisConnect:nil];
    }
}



#pragma mark - Property setter and getter

// 接收到的数据
- (NSMutableData *)receiveDatas {
    if (_receiveDatas == nil) {
        _receiveDatas = [NSMutableData new];
    }
    return _receiveDatas;
}


#pragma mark - Private methods

// int转字节
- (void)_integer:(NSInteger)number getBytes:(void *)buff length:(NSInteger)length {
    NSData *data = [NSData dataWithBytes:&number length:length];
    [data getBytes:buff length:sizeof(buff)];
}

// data转int
- (uint16_t)_commandWithData:(NSData *)data {
    uint16_t command;
    [data getBytes:&command length:sizeof(command)];
    return command;
}

// 开启心跳包线程
- (void)_startRunLoopForHeartbeat {
    dispatch_async(_heartbeatQueue, ^{
        [self _sendHeartbeatMessage];
        [[NSRunLoop currentRunLoop] addTimer:_sendTimer forMode:NSRunLoopCommonModes];
        [[NSRunLoop currentRunLoop] addTimer:_checkTimer forMode:NSRunLoopCommonModes];
        [[NSRunLoop currentRunLoop] run];
    });
}

// 发送心跳包
- (void)_sendHeartbeatMessage {
    uint16_t command = kCommandHeartbeat;
    NSData *cmdData = [NSData dataWithBytes:&command length:sizeof(command)];
    NSInteger length = cmdData.length;
    NSMutableData *data = [NSMutableData dataWithBytes:&length length:DATALENGTH_SIZE];
    [data appendData:cmdData];
    
    // 心跳在自己的线程发送
    [_asyncSocket writeData:data asyncQueue:nil direct:YES completion:nil];
}

// 检测心跳包，没收到则断开连接
- (void)_checkHeartbeatMessage {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - _heartbeatStamp > kTimeCheckHeartbeat) {
        [self.asyncSocket disconnect];
        [self onSocketDidDisConnect:self.asyncSocket];
    }
}

// 获取ip地址
+ (NSDictionary *)_getIPAddresses {
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}


@end
