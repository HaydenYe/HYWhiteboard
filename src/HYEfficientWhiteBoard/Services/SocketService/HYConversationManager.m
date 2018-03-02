//
//  HYConversationManager.m
//  HYEfficientWhiteBoard
//
//  Created by apple on 2017/10/24.
//  Copyright © 2017年 HaydenYe. All rights reserved.
//

#import "HYConversationManager.h"
#import "HYSocketService.h"
#import "HYWbPoint.h"

@interface HYConversationManager () <HYSocketServiceDelegate>

@property (nonatomic, strong)HYSocketService    *serveice;
@property (nonatomic, copy)NSString             *host;
@property (nonatomic, assign)int                port;

@property (nonatomic, assign)BOOL               isConnected;
@property (nonatomic, strong)NSDictionary       *whiteboardCmdDic;

@property (nonatomic, strong)NSTimer            *cmdTimer;
@property (nonatomic, strong)dispatch_queue_t   cmdQueue;

@end

@implementation HYConversationManager

+ (instancetype)shared {
    static HYConversationManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[HYConversationManager alloc] init];
        manager.cmdBuff = [NSMutableArray new];
        manager.cmdQueue = dispatch_queue_create("com.Hayden.WhiteCmdQueue", NULL);
    });
    
    return manager;
}

// 连接服务端
- (void)connectWhiteboardServer:(NSString *)host port:(int)port successed:(void (^)(HYSocketService *))successd failed:(void (^)(NSError *))failed {
    _host = host;
    _port = port;
    
    __weak typeof(self) ws = self;
    [self.serveice connectToHost:host onPort:port forUpload:NO completion:^(NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                ws.serveice = nil;
                if (failed) {
                    failed(error);
                }
            });
        }
        else {
            ws.isConnected = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (successd) {
                    successd(ws.serveice);
                }
                
                [ws _startSendingCmd];
            });
        }
    }];
}

// 发送画点的消息
- (void)sendPointMsg:(HYWbPoint *)point {
    NSString *msg = [NSString stringWithFormat:kMsgPointFormatter, point.isEraser ? HYMessageCmdEraserPoint : HYMessageCmdDrawPoint, point.xScale, point.yScale, (uint8_t)point.type];
    [_cmdBuff addObject:msg];
}

// 发送画笔样式
- (void)sendPenStyleColor:(uint8_t)colorIndex lineWidth:(uint8_t)lineIndex {
    NSString *msg = [NSString stringWithFormat:kMsgPenFormatter, HYMessageCmdPenStyle, colorIndex, lineIndex];
    [_cmdBuff addObject:msg];
}

// 发送撤销，恢复，清除所有
- (void)sendEditAction:(HYMessageCmd)action {
    NSString *msg = [NSString stringWithFormat:kMsgEidtFormatter, action];
    [self _sendWhiteboardMessage:msg successed:nil failed:nil];
}

// 断开连接
- (void)disconnectWhiteboard {
    [_serveice disconnectService];
    _converDelegate = nil;
    _serveice = nil;
    
    _isConnected = NO;
}


#pragma mark - ArtSocketServiceDelegate

// 新消息
- (void)onSocketServiceDidReceiveData:(NSData *)msgData service:(HYSocketService *)service {
    NSMutableString *msg = [[NSMutableString alloc] initWithData:msgData encoding:NSUTF8StringEncoding];
    NSArray *dataArr = [msg componentsSeparatedByString:@","];
    
    if (dataArr.count <= 0) {
        return ;
    }
    
    HYMessageCmd cmd = [dataArr.firstObject integerValue];
    switch (cmd) {
        // 画点
        case HYMessageCmdDrawPoint:
            
        // 橡皮
        case HYMessageCmdEraserPoint:{
            if (_converDelegate && [_converDelegate respondsToSelector:@selector(onReceivePoint:type:isEraser:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_converDelegate onReceivePoint:CGPointMake([dataArr[1] floatValue], [dataArr[2] floatValue]) type:[dataArr[3] intValue] isEraser:cmd == HYMessageCmdDrawPoint ? NO : YES];
                });
            }
            break ;
        }
            
        // 画笔样式
        case HYMessageCmdPenStyle:{
            if (_converDelegate && [_converDelegate respondsToSelector:@selector(onReceivePenColor:lineWidth:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_converDelegate onReceivePenColor:[dataArr[1] integerValue] lineWidth:[dataArr[2] integerValue]];
                });
            }
            break;
        }
            
        // 撤销
        case HYMessageCmdCancel:
        // 恢复
        case HYMessageCmdResume:
        // 清除所有
        case HYMessageCmdClearAll:{
            if (_converDelegate && [_converDelegate respondsToSelector:@selector(onReceiveEditAction:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_converDelegate onReceiveEditAction:cmd];
                });
            }
            break;
        }
            
        default:
            NSLog(@"****HY Error:无此类型的命令(<%zd>)", cmd);
            break;
    }
}

// 断线
- (void)onSocketServiceDidDisconnect:(HYSocketService *)service {
    _serveice = nil;
    
    if (_isConnected) {
        _isConnected = NO;
        
        if (_cmdTimer) {
            [_cmdTimer invalidate];
            _cmdTimer = nil;
        }
    }
}


#pragma mark - Property getter and setter

// socket
- (HYSocketService *)serveice {
    if (_serveice == nil) {
        _serveice = [HYSocketService new];
        _serveice.delegate = self;
        _serveice.indexTag = 0;
    }
    return _serveice;
}



#pragma mark - Private methods

// 发送消息
- (void)_sendWhiteboardMessage:(NSString *)msg successed:(void (^)(NSString *))successed failed:(void (^)(NSInteger))failed {
    [self.serveice sendMessage:msg completion:^(BOOL success, NSUInteger length) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
//                NSLog(@"YHP send command:%zd", type);
                if (successed) {
                    successed(msg);
                }
            }
            else {
                if (failed) {
                    failed(length);
                }
            }
        });
    }];
}

// 开启白板命令定时器
- (void)_startSendingCmd {
    if (_cmdTimer) {
        [_cmdTimer invalidate];
        _cmdTimer = nil;
    }
    _cmdTimer = [NSTimer timerWithTimeInterval:kTimeIntervalSendCmd target:self selector:@selector(_sendWhiteboardCommand) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.cmdTimer forMode:NSRunLoopCommonModes];
}

// 发送白板命令
- (void)_sendWhiteboardCommand {
    if (_cmdBuff.count > 0) {
        NSArray<NSString *> *cmds = [NSArray arrayWithArray:_cmdBuff];
        [cmds enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self _sendWhiteboardMessage:obj successed:nil failed:nil];
        }];
        [_cmdBuff removeAllObjects];
    }
}


@end
