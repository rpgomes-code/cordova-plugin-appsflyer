//
//  AppsFlyerAttribution.m
//  react-native-appsflyer
//
//  Created by Amit Kremer on 11/02/2021.
//

#import <Foundation/Foundation.h>
#import "AppsFlyerAttribution.h"

@implementation AppsFlyerAttribution

+ (id)shared {
    static AppsFlyerAttribution *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (id)init {
    if (self = [super init]) {
        self.options = nil;
        self.restorationHandler = nil;
        self.url = nil;
        self.userActivity = nil;
        self.annotation = nil;
        self.sourceApplication = nil;
        self.isBridgeReady = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(receiveBridgeReadyNotification:)
                                                     name:AF_BRIDGE_SET
                                                   object:nil];
  }
  return self;
}

- (void) continueUserActivity: (NSUserActivity*_Nullable) userActivity restorationHandler: (void (^_Nullable)(NSArray * _Nullable))restorationHandler{
    if(self.isBridgeReady == YES){
        [[AppsFlyerLib shared] continueUserActivity:userActivity restorationHandler:restorationHandler];
    }else{
        [AppsFlyerAttribution shared].userActivity = userActivity;
        [AppsFlyerAttribution shared].restorationHandler = restorationHandler;
    }
}

- (BOOL) isSelfOpenedUrl:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    // Skip URLs whose scheme is the app's own custom scheme (e.g. pt.nos.fera.dev://...)
    // These are internal navigations (e.g. OutSystems ExternalSite) and re-processing them
    // causes an infinite loop via AppsFlyer's swizzled application:openURL: handler.
    if (url.scheme && bundleId && [url.scheme caseInsensitiveCompare:bundleId] == NSOrderedSame) {
        NSLog(@"AppsFlyer: Skipping self-opened URL with app scheme: %@", url.scheme);
        return YES;
    }
    // Also skip if the source application is the app itself
    if (sourceApplication && bundleId && [sourceApplication isEqualToString:bundleId]) {
        NSLog(@"AppsFlyer: Skipping URL opened by app itself: %@", sourceApplication);
        return YES;
    }
    return NO;
}

- (void) handleOpenUrl:(NSURL *)url options:(NSDictionary *)options{
    NSString *sourceApp = options[UIApplicationOpenURLOptionsSourceApplicationKey];
    if ([self isSelfOpenedUrl:url sourceApplication:sourceApp]) {
        return;
    }
    if(self.isBridgeReady == YES){
        [[AppsFlyerLib shared] handleOpenUrl:url options:options];
    }else{
        [AppsFlyerAttribution shared].url = url;
        [AppsFlyerAttribution shared].options = options;
    }
}

- (void) handleOpenUrl:(NSURL *)url sourceApplication:(NSString*)sourceApplication annotation:(id)annotation{
    if ([self isSelfOpenedUrl:url sourceApplication:sourceApplication]) {
        return;
    }
    if(self.isBridgeReady == YES){
        [[AppsFlyerLib shared] handleOpenURL:url sourceApplication:sourceApplication withAnnotation:annotation];
    }else{
        [AppsFlyerAttribution shared].url = url;
        [AppsFlyerAttribution shared].sourceApplication = sourceApplication;
        [AppsFlyerAttribution shared].annotation = annotation;
    }

}

- (void) receiveBridgeReadyNotification:(NSNotification *) notification
{
    NSLog (@"AppsFlyer Debug: handle deep link");
    if(self.url && self.sourceApplication && self.annotation){
        [[AppsFlyerLib shared] handleOpenURL:self.url sourceApplication:self.sourceApplication withAnnotation:self.annotation];
        self.url = nil;
        self.sourceApplication = nil;
        self.annotation = nil;
    }else if(self.options && self.url){
        [[AppsFlyerLib shared] handleOpenUrl:self.url options:self.options];
        self.options = nil;
        self.url = nil;
    }else if(self.userActivity){
        [[AppsFlyerLib shared] continueUserActivity:self.userActivity restorationHandler:self.restorationHandler];
        self.userActivity = nil;
        self.restorationHandler = nil;
    }
}
@end
