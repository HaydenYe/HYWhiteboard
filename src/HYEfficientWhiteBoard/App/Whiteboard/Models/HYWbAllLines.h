//
//  HYWbAllLines.h
//  HYEfficientWhiteBoard
//
//  Created by HaydenYe on 2018/10/13.
//  Copyright © 2018年 HaydenYe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HYWbLine.h"

NS_ASSUME_NONNULL_BEGIN

@interface HYWbAllLines : NSObject

@property (nonatomic, strong)NSMutableArray<HYWbLine *> *allLines;          // 所有用户的所有画线的集合
@property (nonatomic, assign)NSInteger                  dirtyCount;         // 已经渲染过的画线数量
@property (nonatomic, strong)NSMutableDictionary        *lastLineIndex;     // 维护每个用户的最后一条画线的索引

@end

NS_ASSUME_NONNULL_END
