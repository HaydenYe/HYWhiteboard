//
//  HYWbLines.h
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/10/13.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HYWbPoint.h"

NS_ASSUME_NONNULL_BEGIN

@interface HYWbLines : NSObject

@property (nonatomic, strong)NSMutableArray<NSMutableArray *> *lines;
@property (nonatomic, assign)NSInteger                        dirtyCount;

@end

NS_ASSUME_NONNULL_END
