//
//  HYSocket.m
//  Test_Server
//
//  Created by apple on 2017/8/2.
//  Copyright © 2017年 HYdrate. All rights reserved.
//

#import "HYSocket.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

static HYSocket *kThisclass;        // c语言调用OC的方法

@interface HYSocket ()

@property (nonatomic, assign)HYSocketType   socketType;             // socket类型
@property (nonatomic, assign)BOOL           isInputConnected;       // 输入流是否建立连接
@property (nonatomic, assign)BOOL           isOutputConnected;      // 输出流是否建立连接
@property (nonatomic, assign)BOOL           isConnected;            // socket是否连接上
@property (nonatomic, strong)NSTimer        *timer;                 // socket连接超时计时器

@property (nonatomic, weak)HYSocket         *server;                // 服务端socket(OneClient 使用)

@property (nonatomic, strong)NSMutableArray *clientList;            // 连接上的客户端的数组(服务器端使用)
@property (nonatomic, assign)NSInteger      clientlimit;            // 允许客户端连接数量(服务端使用)

@end

@implementation HYSocket

// 服务端开始监听端口
- (void)listeningPort:(UInt16)port clientLimit:(NSInteger)clientLimit asyncQueue:(dispatch_queue_t)queue {
    kThisclass = self;
    _clientList = [NSMutableArray new];
    _socketType = HYSocketTypeServer;
    _queue = queue;
    _clientlimit = clientLimit;
    
    dispatch_async(_queue, ^{
        [self _serverListeningPort:port];
        [[NSRunLoop currentRunLoop] run];
    });
}

// 客户端连接服务端
- (void)connectServer:(NSString *)ip port:(UInt16)port timeOut:(NSTimeInterval)time readAndWriteQueue:(dispatch_queue_t)queue {
    _socketType = HYSocketTypeClient;
    _queue = queue;
    _timeOut = time;
    
    dispatch_async(_queue, ^{
        [self _clientConnectServer:ip port:port];
        [[NSRunLoop currentRunLoop] run];
    });
}

// 将数据写入输出流
- (void)writeData:(NSData *)data asyncQueue:(dispatch_queue_t)queue direct:(BOOL)direct completion:(void (^)(BOOL, NSUInteger))completion {
    if (data == nil || data.length < 1) {
        if (completion) {
            completion(NO, data.length);
        }
    }
    if (queue == nil) {
        NSUInteger length = 0;
        if (direct) {
            length = [self _writeDataDirectly:data];
        }
        else {
            length = [self _writeDataBySubpackage:data];
        }
        if (completion) {
            completion(YES, length);
        }
    }
    else {
        dispatch_async(queue, ^{
            NSUInteger length = 0;
            if (direct) {
                length = [self _writeDataDirectly:data];
            }
            else {
                length = [self _writeDataBySubpackage:data];
            }
            if (completion) {
                completion(YES, length);
            }
        });
    }
}

// 断开连接
-(void)disconnect {
    
    // 关闭数据流
    if (_inputStream != nil) {
        [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [_inputStream close];
        _inputStream = nil;
    }
    if (_outputStream != nil) {
        [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [_outputStream close];
        _outputStream = nil;
    }
    
    // 关闭socket
    if (_socketipv4 != NULL) {
        CFSocketInvalidate (_socketipv4);
        CFRelease (_socketipv4);
        _socketipv4 = NULL;
    }
    
    _nativeSocket4 = 0;
    
    _isInputConnected = NO;
    _isOutputConnected = NO;
    _isConnected = NO;
    _timeOut = -1;
    [_timer invalidate];
    _timer = nil;
}

// 获取本地ip地址(暂不使用)
- (NSString *)hostAddress {
    
    if (_nativeSocket4 <= 0) {
        if (_socketipv4 == nil) {
            return @"";
        } else {
            _nativeSocket4 = CFSocketGetNative(_socketipv4);
        }
    }
    
    return [self _getPortWithNativeHandle:_nativeSocket4 address:YES];
}

// 获取本地socket连接的端口号(暂不使用)
- (NSString *)hostPort {
    if (_nativeSocket4 <= 0) {
        if (_socketipv4 == nil) {
            return @"";
        } else {
            _nativeSocket4 = CFSocketGetNative(_socketipv4);
        }
    }
    
    return [self _getPortWithNativeHandle:_nativeSocket4 address:NO];
}


#pragma mark - NSStream delegate

-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:{
            if (aStream == _inputStream) {
                _isInputConnected = YES;
            }
            else if (aStream == _outputStream) {
                _isOutputConnected = YES;
            }
            // 连接成功
            if (_isOutputConnected && _isInputConnected) {
                _isConnected = YES;
                if (_socketType == HYSocketTypeClient) {
                    if (_timer) {
                        [_timer invalidate];
                    }
                    if (self.delegate && [self.delegate respondsToSelector:@selector(onSocketDidConnectServer:withError:)]) {
                        [self.delegate onSocketDidConnectServer:self withError:nil];
                    }
                }
                else {
                    if (self.delegate && [_delegate respondsToSelector:@selector(onSocketDidAcceptNewClient:withError:)]) {
                        [self.delegate onSocketDidAcceptNewClient:self withError:nil];
                    }
                }
            }
        }
            break;
        case NSStreamEventHasBytesAvailable:
            if (aStream == _inputStream) {
                // 可以读取数据
                [self _readData];
            }
            break;
        case NSStreamEventErrorOccurred:{
            // 网络异常
            [self disconnect];
            if (_socketType == HYSocketTypeClient) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(onSocketDidConnectServer:withError:)]) {
                    NSError *error = [NSError errorWithDomain:@"连接失败" code:kCFSocketError userInfo:nil];
                    [self.delegate onSocketDidConnectServer:self withError:error];
                }
            } else {
                if (self.delegate && [self.delegate respondsToSelector:@selector(onSocketDidDisConnect:)]) {
                    [self.delegate onSocketDidDisConnect:self];
                }
            }
            if (self.socketType == HYSocketTypeOneClient && self.server) {
                [self.server.clientList removeObject:self];
            }
        }
            break;
        case NSStreamEventEndEncountered:{
            // socket断开连接
            [self disconnect];
            if (_socketType == HYSocketTypeClient) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(onSocketDidConnectServer:withError:)]) {
                    NSError *error = [NSError errorWithDomain:@"连接失败" code:kCFSocketError userInfo:nil];
                    [self.delegate onSocketDidConnectServer:self withError:error];
                }
            } else {
                if (self.delegate && [self.delegate respondsToSelector:@selector(onSocketDidDisConnect:)]) {
                    [self.delegate onSocketDidDisConnect:self];
                }
            }
            if (self.socketType == HYSocketTypeOneClient && self.server) {
                [self.server.clientList removeObject:self];
            }
        }
            break;
        case NSStreamEventNone:
            break;
        case NSStreamEventHasSpaceAvailable:
            break;
        default:
            break;
    }
}


#pragma mark - Socket callback handler

// 服务端接收到新的客户端的连接
static void handleConnect(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    
    // 只处理kCFSocketAcceptCallBack类型的事件
    if (type != kCFSocketAcceptCallBack) {
        return;
    }
    
    // 客户端连接数量限制
    if (kThisclass.clientList.count >= kThisclass.clientlimit) {
        return;
    }
    
    CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
    [kThisclass _addOneClient:nativeSocketHandle];
}


#pragma mark - HYSocket foundation

// 读取数据流中的数据
-(void)_readData {
    
    // 从socket中读取数据
    uint8_t buff[BUFFER_SIZE];
    long length = [_inputStream read:buff maxLength:BUFFER_SIZE];
    
    if (length > 0) {
        NSData *data = [NSData dataWithBytes:buff length:length];
        uint8_t *tmpBuff = buff;
        if (self.delegate && [self.delegate respondsToSelector:@selector(onSocket:didReceiveData:originBuff:)]) {
            [self.delegate onSocket:self didReceiveData:data originBuff:tmpBuff];
        }
    }
}

// 直接写入数据流中
- (NSUInteger)_writeDataDirectly:(NSData *)data {
    BOOL sended = NO;
    NSUInteger length = 0;
    do {
        if (_outputStream == nil) {
            return 0;
        }
        
        if ([_outputStream hasSpaceAvailable]) {
            long length = data.length;
            uint8_t buff[length];
            [data getBytes:buff length:length];
            buff[length] = '\0';
            length = [_outputStream write:buff maxLength:length];
            sended = YES;
        }
    } while (!sended);
    
    return length;
}

// 先分包，再直接写入数据流中
-(NSUInteger)_writeDataBySubpackage:(NSData *)data {
    
    uint8_t buff[BUFFER_SIZE];
    NSRange window = NSMakeRange(0, BUFFER_SIZE);
    
    // 数据长度
    NSUInteger dataLength = [data length];
    NSMutableData *tmpData = [NSMutableData dataWithBytes:&dataLength length:4];
    [tmpData appendData:data];
    
    NSUInteger length = 0;
    
    do {
        if (_outputStream == nil) {
            return 0;
        }
        
        if ([_outputStream hasSpaceAvailable]) {
            if ((window.location + window.length) > [tmpData length]) {
                window.length = [tmpData length] - window.location;
                buff[window.length] = '\0';
            }
            
            [tmpData getBytes:buff range:window];
            
            if (window.length == 0) {
                buff[0] = '\0';
            }
            
            length += [_outputStream write:buff maxLength:window.length];
            window = NSMakeRange(window.location + BUFFER_SIZE, window.length);
        }
    } while (window.length == BUFFER_SIZE);
    
    return length;
}

// 开启输入输出流
-(void)_openReadStream:(CFReadStreamRef)readStream writeStream:(CFWriteStreamRef)writeStream {
    
    // 设置数据流
    _inputStream = (__bridge_transfer NSInputStream *)readStream;
    _outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    
    _inputStream.delegate = self;
    _outputStream.delegate = self;
    
    [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
    [_inputStream open];
    [_outputStream open];
}


#pragma mark - Server socket

// 服务端开始监听端口号
-(void)_serverListeningPort:(UInt16)port {
    _socketipv4 = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, handleConnect, NULL);
    
    struct sockaddr_in sin;
    
    memset(&sin, 0, sizeof(sin));
    sin.sin_len = sizeof(sin);
    sin.sin_family = AF_INET;
    sin.sin_port = htons(port);
    sin.sin_addr.s_addr = INADDR_ANY;
    
    CFDataRef sincfd = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&sin, sizeof(sin));
    
    CFSocketError setAddress = CFSocketSetAddress(_socketipv4, sincfd);
    CFRelease(sincfd);
    
    if (setAddress != kCFSocketSuccess) {
        perror("CFSocketSetAddress:");
        if (self.delegate && [self.delegate respondsToSelector:@selector(onSocketDidStartListening:withError:)]) {
            NSError *error = [NSError errorWithDomain:setAddress == kCFSocketTimeout ? @"设置监听超时" : @"监听端口失败" code:setAddress userInfo:@{@"port":[[NSNumber alloc] initWithInt:port]}];
            [self.delegate onSocketDidStartListening:self withError:error];
        }
    }
    else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(onSocketDidStartListening:withError:)]) {
            [self.delegate onSocketDidStartListening:self withError:nil];
        }
    }
    
    CFRunLoopSourceRef socketsource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socketipv4, 0);
    
    // 开始监听
    CFRunLoopAddSource(CFRunLoopGetCurrent(), socketsource, kCFRunLoopCommonModes);
}

// 添加新接收的客户端
- (void)_addOneClient:(CFSocketNativeHandle)nativeSocketHandle {
    HYSocket *client = [HYSocket new];
    client.delegate = _delegate;
    client.server = self;
    client.socketType = HYSocketTypeOneClient;
    [_clientList addObject:client];
    
    [client _handleNewNativeSocket:nativeSocketHandle readAndWriteQueue:dispatch_queue_create("com.Hayden.OneClientQueue", DISPATCH_QUEUE_CONCURRENT)];
}



#pragma mark - Client socket

// 客户端连接服务端
-(void)_clientConnectServer:(NSString *)ip port:(UInt16)port {
    //Connect To Server And Open I/O Stream
    /* Be deprecated by HY
     _socketRef = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, handleConnectServer, NULL);
     
     struct sockaddr_in sin;
     
     memset(&sin, 0, sizeof(sin));
     sin.sin_len = sizeof(sin);
     sin.sin_family = AF_INET;
     sin.sin_port = htons(port);
     sin.sin_addr.s_addr = inet_addr([ip UTF8String]);
     
     CFDataRef sincfd = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&sin, sizeof(sin));
     
     CFSocketError result = CFSocketConnectToAddress(_socketRef, sincfd, -1);
     */
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)ip, port, &readStream, &writeStream);
    
    if (readStream && writeStream) {
        [self _openReadStream:readStream writeStream:writeStream];
        
        if (_timeOut > 0) {
            _timer = [NSTimer scheduledTimerWithTimeInterval:_timeOut target:self selector:@selector(_setConnectTimeOut) userInfo:nil repeats:NO];
        }
    }
    else {
        [self disconnect];
        if (self.delegate && [self.delegate respondsToSelector:@selector(onSocketDidConnectServer:withError:)]) {
            NSError *error = [NSError errorWithDomain:@"连接失败" code:kCFSocketError userInfo:nil];
            [self.delegate onSocketDidConnectServer:self withError:error];
        }
    }
}



#pragma mark - New client

// 接收到新客户端连接的处理
-(void)_handleNewNativeSocket:(CFSocketNativeHandle)nativeSocketHandle readAndWriteQueue:(dispatch_queue_t)queue {
    _nativeSocket4 = nativeSocketHandle;
    _queue = queue;
    
    dispatch_async(_queue, ^{
        // 开启I/O数据流
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStream, &writeStream);
        
        if (readStream && writeStream) {
            [self _openReadStream:readStream writeStream:writeStream];
        }
        else {
            [self disconnect];
            if (self.delegate && [_delegate respondsToSelector:@selector(onSocketDidAcceptNewClient:withError:)]) {
                NSError *error = [NSError errorWithDomain:@"连接失败" code:kCFSocketError userInfo:nil];
                [self.delegate onSocketDidAcceptNewClient:self withError:error];
            }
        }
        [[NSRunLoop currentRunLoop] run];
    });
}

// 获取本地ip或端口号
- (NSString *)_getPortWithNativeHandle:(CFSocketNativeHandle)nativeHandle address:(BOOL)addr {
    
    uint8_t name[SOCK_MAXADDRLEN];
    socklen_t namelen = sizeof(name);
    
    if (getpeername(nativeHandle, (struct sockaddr *)name, &namelen) != kCFSocketSuccess) {
        perror("getpeername:");
        return @"";
    }
    else {
        struct sockaddr_in *addr_in = (struct sockaddr_in *)name;
        char address[20];
        uint8_t port;
        
        inet_ntop(AF_INET, &addr_in, address, sizeof(address));
        port = ntohs(addr_in->sin_port);
        
        if (addr) {
            return [NSString stringWithUTF8String:address];
        }
        else {
            return [NSString stringWithFormat:@"%zd", port];
        }
    }
}


#pragma mark - Private methods

//设置连接超时计时器
- (void)_setConnectTimeOut {
    if (!_isConnected) {
        [self disconnect];
        if (self.delegate && [self.delegate respondsToSelector:@selector(onSocketDidConnectServer:withError:)]) {
            NSError *error = [NSError errorWithDomain:@"连接超时" code:kCFSocketTimeout userInfo:nil];
            [self.delegate onSocketDidConnectServer:self withError:error];
        }
    }
}


@end
