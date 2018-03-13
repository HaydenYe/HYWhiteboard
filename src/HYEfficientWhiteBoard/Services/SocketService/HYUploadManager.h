//
//  HYUploadManager.h
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/3/3.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class HYSocketService;

#define kSocketUploadPort       57777   // 上传端口号

#define kMsgImageInfoFormatter          @"%zd,%d,%d,%d"     // 图片信息的命令:@"HYUploadCmd,size.width,size.height,data.length"
#define kMsgUploadCompletionFormatter   @"%zd"              // 上传完成的命令:@"HYUploadCmd"

typedef NS_ENUM(NSUInteger, HYUploadCmd) {
    HYUploadCmdNone = 0,                // 占位
    HYUploadCmdImageInfo = 101,         // 图片信息
    HYUploadCmdUploadCompletion = 102,  // 上传完成
};


@protocol HYUploadDelegate <NSObject>

/**
 接收到新图片

 @param image 图片
 */
- (void)onNewImage:(UIImage *)image;

@optional

/**
 上传socket断开
 */
- (void)onUploadServiceDisconnect;

@end


@interface HYUploadManager : NSObject

@property (nonatomic, strong, readonly)HYSocketService      *service;
@property (nonatomic, assign, readonly)BOOL                 isConnected;

@property (nonatomic, weak)id<HYUploadDelegate>             delegate;


+ (instancetype)shared;


/**
 建立上传socket通道
 
 @param successd    连接成功
 @param failed      连接失败
 */
- (void)connectUploadServerSuccessed:(void(^)(HYSocketService *service))successd
                              failed:(void(^)(NSError *error))failed;


/**
 添加新客户端的服务
 
 @param clientService 新客户端的服务
 */
- (void)addNewClient:(HYSocketService *)clientService;


/**
 发送图片信息

 @param size 图片尺寸
 @param length 图片文件大小
 */
- (void)sendImageInfoSize:(CGSize)size
               fileLength:(uint32_t)length;


/**
 发送图片上传完成的消息
 */
- (void)sendImageUploadCompletion;


/**
 上传文件

 @param image 是否为图片
 @param data 文件数据
 @param progress 上传进度
 @param completion 上传完成回调
 */
- (void)uploadImage:(BOOL)image
               data:(NSData *)data
           progress:(void(^)(CGFloat progress))progress
         completion:(void(^)(BOOL success, NSUInteger length))completion;


/**
 断开socket连接
 */
- (void)disconnectUpload;

@end
