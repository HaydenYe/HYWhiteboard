//
//  HYConversationManager.m
//  HYEfficientWhiteBoard
//
//  Created by apple on 2017/10/24.
//  Copyright © 2017年 HaydenYe. All rights reserved.
//

#import "HYConversationManager.h"
#import "HYSocketService.h"

@interface HYConversationManager () <HYSocketServiceDelegate>

@property (nonatomic, strong)HYSocketService   *serveice;
@property (nonatomic, copy)NSString             *host;
@property (nonatomic, assign)int                port;

@property (nonatomic, assign)BOOL               isConnected;
@property (nonatomic, strong)NSDictionary       *whiteboardCmdDic;

@property (nonatomic, strong)NSTimer            *cmdTimer;
@property (nonatomic, strong)dispatch_queue_t   cmdQueue;

@property (nonatomic, assign)NSInteger          reconnectCount;

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

- (void)startServerWithPort:(int)port completion:(void (^)(NSString *))completion clientConnectedSuccessed:(void (^)(HYSocketService *))successd failed:(void (^)(NSError *))failed {
    _port = port;
    
    __weak typeof(self) ws = self;
    [self.serveice startlisteningToPort:port completion:^(NSString *host) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(host);
            });
        }
    } newClient:^(NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                ws.serveice = nil;
                if (failed) {
                    failed(error);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (successd) {
                    successd(ws.serveice);
                }
//                [ws _startSendingCmd];
            });
        }
    }];
    
}

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
                
//                [ws _startSendingCmd];
            });
        }
    }];
}



#pragma mark - Property getter and setter

// socket
- (HYSocketService *)serveice {
    if (_serveice == nil) {
        _serveice = [HYSocketService new];
        _serveice.delegate = self;
    }
    return _serveice;
}



#pragma mark - Private methods

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
        NSArray *cmds = [NSArray arrayWithArray:_cmdBuff];
//        [ArtWhiteboardMessage sendWhiteboardCommand:cmds];
        [_cmdBuff removeAllObjects];
    }
}


@end
