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

// c语言调用OC的方法
static HYSocket *kThisclass;

@interface HYSocket ()

@property (nonatomic, assign)HYSocketType   socketType;             // socket类型

@property (nonatomic, assign)BOOL           isInputConnected;       // 
@property (nonatomic, assign)BOOL           isOutputConnected;
@property (nonatomic, assign)BOOL           isConnected;

@property (nonatomic, strong)NSTimer        *timer;

// OneClient 使用
@property (nonatomic, weak)HYSocket         *server;

// 服务器端使用
@property (nonatomic, strong)NSMutableArray *clientList;

@end

@implementation HYSocket

//Server Start Listening Port
- (void)listeningPort:(int)port asyncQueue:(dispatch_queue_t)queue {
    kThisclass = self;
    _clientList = [NSMutableArray new];
    _socketType = HYSocketTypeServer;
    _queue = queue;
    
    dispatch_async(_queue, ^{
        [self _serverListeningPort:port];
        [[NSRunLoop currentRunLoop] run];
    });
}

//Client Connect To Server
- (void)connectServer:(NSString *)ip port:(int)port timeOut:(NSTimeInterval)time readAndWriteQueue:(dispatch_queue_t)queue {
    _socketType = HYSocketTypeClient;
    _queue = queue;
    _timeOut = time;

    dispatch_async(_queue, ^{
        [self _clientConnectServer:ip port:port];
        [[NSRunLoop currentRunLoop] run];
    });
}

// Write Data
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

//Disconnect
-(void)disconnect {
    
    //Close Data Stream
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
    
    // Close sockets.
    if (_socketipv4 != NULL)
    {
        CFSocketInvalidate (_socketipv4);
        CFRelease (_socketipv4);
        _socketipv4 = NULL;
    }
    
    // Closing the streams or sockets resulted in closing the underlying native socket
    _nativeSocket4 = 0;
    
    _isInputConnected = NO;
    _isOutputConnected = NO;
    _isConnected = NO;
    _timeOut = -1;
    [_timer invalidate];
    _timer = nil;
}

// Get Host Address
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

//
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

//Handle Event
-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:{
            if (aStream == _inputStream) {
                _isInputConnected = YES;
            }
            else if (aStream == _outputStream) {
                _isOutputConnected = YES;
            }
            //Connect Successed
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
                //Read Data Available
                [self _readData];
            }
            break;
        case NSStreamEventErrorOccurred:{
            //Network exception
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
            //Socket Is Disconneted
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

//Handle Connect (C Function)
static void handleConnect(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    
    //When CFSocketCallBackType Is KCFSocketAcceptCallBack Type
    if (type != kCFSocketAcceptCallBack) {
        return;
    }
    
    CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
    [kThisclass _addOneClient:nativeSocketHandle];
}



#pragma mark - HYSocket foundation

//Read Data
-(void)_readData {
    //Read Data From Socket
    uint8_t buff[BUFFER_SIZE];
    long length = [_inputStream read:buff maxLength:BUFFER_SIZE];
    
    //Receive Data Callback
    if (length > 0) {
        NSData *data = [NSData dataWithBytes:buff length:length];
        uint8_t *tmpBuff = buff;
        if (self.delegate && [self.delegate respondsToSelector:@selector(onSocket:didReceiveData:originBuff:)]) {
            [self.delegate onSocket:self didReceiveData:data originBuff:tmpBuff];
        }
    }
}

//Write Data directly
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

//Write Data By Subpackage
-(NSUInteger)_writeDataBySubpackage:(NSData *)data {
    //Write Data To Socket
    uint8_t buff[BUFFER_SIZE];
    NSRange window = NSMakeRange(0, BUFFER_SIZE);
    
    //Data Length
    NSUInteger dataLength = [data length];
    NSMutableData *tmpData = [NSMutableData dataWithBytes:&dataLength length:DATALENGTH_SIZE];
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

//Open Readstream And Writestream
-(void)_openReadStream:(CFReadStreamRef)readStream writeStream:(CFWriteStreamRef)writeStream {
    //Set Data Stream
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

//Server start Lisenting Port
-(void)_serverListeningPort:(int)port {
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
    
    //Server Begin Listening
    CFRunLoopAddSource(CFRunLoopGetCurrent(), socketsource, kCFRunLoopCommonModes);
}

//Add New Client
- (void)_addOneClient:(CFSocketNativeHandle)nativeSocketHandle {
    HYSocket *client = [HYSocket new];
    client.delegate = _delegate;
    client.server = self;
    client.socketType = HYSocketTypeOneClient;
    [_clientList addObject:client];
    
    [client _handleNewNativeSocket:nativeSocketHandle readAndWriteQueue:dispatch_queue_create("com.Hayden.OneClientQueue", DISPATCH_QUEUE_CONCURRENT)];
}



#pragma mark - Client socket

//Client Start Connecting Server
-(void)_clientConnectServer:(NSString *)ip port:(int)port {
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

//Handle New Native Socket
-(void)_handleNewNativeSocket:(CFSocketNativeHandle)nativeSocketHandle readAndWriteQueue:(dispatch_queue_t)queue {
    _nativeSocket4 = nativeSocketHandle;
    _queue = queue;
    
    dispatch_async(_queue, ^{
        //Set And Open I/O Stream
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStream, &writeStream);
        
        //New Client Callback
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
    });
}

//Host Port
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

//Set Timer
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
