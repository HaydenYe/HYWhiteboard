//
//  HYSocketService.m
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2017/10/20.
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

@property (nonatomic, strong)HYSocket           *asyncSocket;               // socket
@property (nonatomic, strong)NSMutableData      *receiveDatas;              // 接收到的数据的缓冲区
@property (nonatomic, assign)BOOL               upload;                     // 是否为上传

@property (nonatomic, strong)dispatch_queue_t   heartbeatQueue;             // 心跳包线程
@property (nonatomic, assign)NSTimeInterval     heartbeatStamp;             // 接收到心跳包的时间戳
@property (nonatomic, strong)NSTimer            *sendTimer;                 // 发送心跳包的计时器
@property (nonatomic, strong)NSTimer            *checkTimer;                // 检测心跳包的计时器

@property (nonatomic, strong)dispatch_queue_t   streamQueue;                // 数据流线程
@property (nonatomic, strong)dispatch_queue_t   processQueue;               // 处理待发送数据的线程

@property (nonatomic, strong)dispatch_queue_t   listenQueue;                // 监听端口所在线程
@property (nonatomic, weak)id                   clientDelegate;             // 新客户端的代理

@property (nonatomic, strong)void (^connectServerBlock)(NSError *error);    // 连接服务器或客户端的回调

@end

@implementation HYSocketService

- (instancetype)init {
    if (self = [super init]) {
        _asyncSocket = [HYSocket new];
        _asyncSocket.delegate = self;
        _receiveDatas = [NSMutableData new];
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
    _connectServerBlock = completion;
    _upload = upload;
    [_asyncSocket connectServer:host port:port timeOut:kSocketConnectTimeout readAndWriteQueue:_streamQueue];
}

// 服务器监听端口号
- (void)startlisteningToPort:(int)port clientLimit:(NSInteger)clientLimit newClientDelegate:(id)delegate completion:(void (^)(NSError *))completion {
    _connectServerBlock = completion;
    _clientDelegate = delegate;
    [_asyncSocket listeningPort:port clientLimit:clientLimit asyncQueue:_listenQueue];
}

// 发送消息
- (void)sendMessage:(id)msg completion:(void (^)(BOOL, NSUInteger))completion {
    
    // 无网络
    if (self.asyncSocket.isConnected == NO) {
        return ;
    }
    
    // 消息类型
    if ([msg isKindOfClass:[NSString class]]) {
        // 序列化
        NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
        // 消息的命令和长度
        uint32_t length = htonl(msgData.length);
        uint16_t cmd = htons(kCommandNormal);
        
        NSMutableData *cmdTypeData = [NSMutableData dataWithBytes:&cmd length:CMDLENGTH_SIZE];
        NSData *lengthData = [NSData dataWithBytes:&length length:DATALENGTH_SIZE];
        [cmdTypeData appendData:lengthData];
        [cmdTypeData appendData:msgData];
        
        // 发送数据
        [self.asyncSocket writeData:cmdTypeData asyncQueue:_processQueue direct:YES completion:completion];
    }
    // 文件类型
    else if ([msg isKindOfClass:[NSData class]]) {
        // 发送数据
        [self.asyncSocket writeData:(NSData *)msg asyncQueue:_processQueue direct:NO completion:completion];
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
    
    // 服务端
    if (self.asyncSocket.socketType == HYSocketTypeServer) {
        if (_asyncSocket.isConnected) {
            if (_asyncSocket.clientList.count) {
                [_asyncSocket.clientList enumerateObjectsUsingBlock:^(HYSocket * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    [obj disconnect];
                }];
                
                [_asyncSocket.clientList removeAllObjects];
            }
            
            [_asyncSocket disconnect];
        }
        
        _connectServerBlock = nil;
        _upload = NO;
        
        _asyncSocket = nil;
    }
    // 客户端
    else {
        if (_asyncSocket.isConnected) {
            [_asyncSocket disconnect];
        }
        
        _receiveDatas = nil;
        _connectServerBlock = nil;
        _upload = NO;
        
        [_checkTimer invalidate];
        [_sendTimer invalidate];
        
        // 服务端的客户端
        if (_asyncSocket.socketType == HYSocketTypeOneClient && _asyncSocket.server) {
            if ([_asyncSocket.server.clientList containsObject:_asyncSocket]) {
                [_asyncSocket.server.clientList removeObject:_asyncSocket];
            }
        }
        
        _asyncSocket = nil;
    }
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

// 服务器检测端口是否可用
- (BOOL)portEnabled:(UInt16)port preferIPv4:(BOOL)preferIPv4 {
    int fd = -1;
    
    // ipv4
    if (preferIPv4) {
        struct sockaddr_in sin;
        memset(&sin, 0, sizeof(sin));
        sin.sin_family = AF_INET;
        sin.sin_port = htons(port);
        sin.sin_addr.s_addr = htonl(INADDR_ANY);
        
        fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        
        if(fd < 0) {
            printf("socket() error:%s\n", strerror(errno));
            return -1;
        }
        if(bind(fd, (struct sockaddr *)&sin, sizeof(sin)) != 0) {
            printf("bind() error:%s\n", strerror(errno));
            close(fd);
            return -1;
        }
        
        uint len = sizeof(sin);
        if(getsockname(fd, (struct sockaddr *)&sin, &len) != 0) {
            printf("getsockname() error:%s\n", strerror(errno));
            close(fd);
            return -1;
        }
        
        port = sin.sin_port;
        if(fd != -1)
            close(fd);
    }
    // ipv6
    else {
        struct sockaddr_in6 sin6;
        memset(&sin6, 0, sizeof(sin6));
        
        char ip[128];
        memset(ip, 0, sizeof(ip));
        
        inet_ntop(AF_INET6, &sin6.sin6_addr, ip, 128);
        sin6.sin6_family = AF_INET6;
        sin6.sin6_port = htons(0);
        
        fd = socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
        
        if(fd < 0){
            printf("socket() error:%s\n", strerror(errno));
            return -1;
        }
        
        if(bind(fd, (struct sockaddr *)&sin6, sizeof(sin6)) != 0)
        {
            printf("bind() error:%s\n", strerror(errno));
            close(fd);
            return -1;
        }
        
        uint len = sizeof(sin6);
        if(getsockname(fd, (struct sockaddr *)&sin6, &len) != 0)
        {
            printf("getsockname() error:%s\n", strerror(errno));
            close(fd);
            return -1;
        }
        
        port = sin6.sin6_port;
        
        if(fd != -1)
            close(fd);
    }
    
    return port;
}


#pragma mark - HYSocketDelegate

// 接收数据
- (void)onSocket:(HYSocket *)socket didReceiveData:(NSData *)data originBuff:(uint8_t *)buff {
    
    if (data.length >= CMDLENGTH_SIZE) {
        // 上一个包存在半包，且不是递归
        if (socket && _receiveDatas.length > 0) {
            [_receiveDatas appendData:data];
            data = [_receiveDatas copy];
        }
        
        // 清空数据
        [_receiveDatas resetBytesInRange:NSMakeRange(0, data.length)];
        [_receiveDatas setLength:0];
        
        // 命令类型
        uint16_t command = [self _commandWithData:data];
        // 心跳包
        if (command == kCommandHeartbeat) {
            _heartbeatStamp = [[NSDate date] timeIntervalSince1970];
            // 递归解析
            if (data.length > CMDLENGTH_SIZE) {
                [self onSocket:nil didReceiveData:[data subdataWithRange:NSMakeRange(CMDLENGTH_SIZE, data.length - CMDLENGTH_SIZE)] originBuff:nil];
            }
            return ;
        }
        
        if (data.length > CMDLENGTH_SIZE + DATALENGTH_SIZE) {
            // 获取数据长度
            uint32_t dataLength;
            [data getBytes:&dataLength range:NSMakeRange(CMDLENGTH_SIZE, DATALENGTH_SIZE)];
            dataLength = ntohl(dataLength);
            
            // 完整数据包
            if (dataLength == data.length - CMDLENGTH_SIZE - DATALENGTH_SIZE) {
                // 分发数据
                if (_delegate && [_delegate respondsToSelector:@selector(onSocketServiceDidReceiveData:command:service:)]) {
                    [_delegate onSocketServiceDidReceiveData:[data subdataWithRange:NSMakeRange(CMDLENGTH_SIZE + DATALENGTH_SIZE, dataLength)] command:command service:self];
                }
            }
            // 粘包
            else if (dataLength < data.length - CMDLENGTH_SIZE - DATALENGTH_SIZE) {
                // 分发完整数据
                if (_delegate && [_delegate respondsToSelector:@selector(onSocketServiceDidReceiveData:command:service:)]) {
                    [_delegate onSocketServiceDidReceiveData:[data subdataWithRange:NSMakeRange(DATALENGTH_SIZE + CMDLENGTH_SIZE, dataLength)] command:command service:self];
                }
                // 剪裁数据
                [_receiveDatas appendData:[data subdataWithRange:NSMakeRange(CMDLENGTH_SIZE + DATALENGTH_SIZE + dataLength, data.length - (CMDLENGTH_SIZE + DATALENGTH_SIZE + dataLength))]];;
                // 递归解析
                [self onSocket:nil didReceiveData:[_receiveDatas copy] originBuff:nil];
            }
            // 半包
            else {
                [_receiveDatas appendData:data];
            }
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
        
        if (_connectServerBlock) {
            _connectServerBlock(error);
            _connectServerBlock = nil;
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
    if (_connectServerBlock) {
        _connectServerBlock(error);
        _connectServerBlock = nil;
    }
}

// 新客户端连接到服务器
- (void)onSocketDidAcceptNewClient:(HYSocket *)socket withError:(NSError *)error {
    // 服务端的读写流创建失败
    if (error) {
        NSLog(@"****HY Error:%@ Code:%zd", error.domain, error.code);
    }
    else {
        HYSocketService *newservice = [[HYSocketService alloc] init];
        newservice.asyncSocket = socket;
        newservice.asyncSocket.delegate = newservice;
        newservice.delegate = _clientDelegate;
        newservice.indexTag = self.asyncSocket.clientList.count - 1;
        [newservice _startRunLoopForHeartbeat];
        
        if (_delegate && [_delegate respondsToSelector:@selector(onSocketServiceAcceptNewClient:server:)]) {
            [_delegate onSocketServiceAcceptNewClient:newservice server:self];
        }
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
    return ntohs(command);
}

// 开启心跳包线程
- (void)_startRunLoopForHeartbeat {
    _heartbeatStamp = [[NSDate date] timeIntervalSince1970];
    
    dispatch_async(_heartbeatQueue, ^{
        [self _sendHeartbeatMessage];
        [[NSRunLoop currentRunLoop] addTimer:_sendTimer forMode:NSRunLoopCommonModes];
        [[NSRunLoop currentRunLoop] addTimer:_checkTimer forMode:NSRunLoopCommonModes];
        [[NSRunLoop currentRunLoop] run];
    });
}

// 发送心跳包
- (void)_sendHeartbeatMessage {
    uint16_t command = htons(kCommandHeartbeat);
    NSData *cmdData = [NSData dataWithBytes:&command length:sizeof(command)];
    
    // 心跳在自己的线程发送
    [_asyncSocket writeData:cmdData asyncQueue:nil direct:YES completion:nil];
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
        for(interface = interfaces; interface; interface = interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            
            const struct sockaddr_in *addr = (const struct sockaddr_in *)interface->ifa_addr;
            char addrBuf[MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN)];
            if(addr && (addr->sin_family == AF_INET || addr->sin_family == AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6 *)interface->ifa_addr;
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
