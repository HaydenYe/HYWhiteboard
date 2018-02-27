//
//  AppDelegate.m
//  HYEfficientWhiteBoard
//
//  Created by apple on 2017/10/20.
//  Copyright © 2017年 HaydenYe. All rights reserved.
//

#import "AppDelegate.h"
#import "HYHomeViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (self.window == nil) {
        self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        self.window.backgroundColor = [UIColor whiteColor];
    }
    UINavigationController *nav = [[UINavigationController alloc ]initWithRootViewController:[HYHomeViewController new]];
    self.window.rootViewController = nav;
    
    [self.window makeKeyAndVisible];
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self didEnterBackground:application];
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    [self willEnterForeground:application];
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

// 设置永久后台运行
- (void)didEnterBackground:(UIApplication *)application {
    UIApplication *app = application;
    __block UIBackgroundTaskIdentifier bgTask;
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bgTask != UIBackgroundTaskInvalid) {
                bgTask = UIBackgroundTaskInvalid;
            }
        });
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bgTask != UIBackgroundTaskInvalid) {
                bgTask = UIBackgroundTaskInvalid;
            }
        });
    });
}

// 进入前台后 endBackgroundTask
- (void)willEnterForeground:(UIApplication *)application
{
    UIApplication *app = application;
    __block UIBackgroundTaskIdentifier bgTask;
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bgTask != UIBackgroundTaskInvalid) {
                bgTask = UIBackgroundTaskInvalid;
            }
        });
    }];
    
    if (bgTask != UIBackgroundTaskInvalid) {
        NSLog(@"Debug - Ending background task %tu without expiration (when applicationWillEnterForeground)",bgTask);
        [app endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }
    
}


@end
