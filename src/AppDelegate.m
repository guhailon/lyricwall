#import "AppDelegate.h"
#import "ViewController.h"
#import "ActivationManager.h"
#import "ActivationViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    if ([LWActivationManager isActivated]) {
        // 已激活：直接进墙；后台悄悄重查存过的码，被线上名单吊销才切回激活页。
        self.window.rootViewController = [[ViewController alloc] init];
        [LWActivationManager revalidateStoredCodeInBackground];
    } else {
        // 未激活：墙锁在激活页后面，先输码。
        LWActivationViewController *act = [[LWActivationViewController alloc] init];
        __weak typeof(self) weakSelf = self;
        act.onActivated = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.window.rootViewController = [[ViewController alloc] init];
        };
        self.window.rootViewController = act;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onActivationRevoked:)
                                                 name:LWActivationRevokedNotification
                                               object:nil];
    [self.window makeKeyAndVisible];
    return YES;
}

// 线上名单明确说存过的码已不在 → 切回激活页（抓不到名单不会走到这里）。
- (void)onActivationRevoked:(NSNotification *)note {
    (void)note;
    if (![self.window.rootViewController isKindOfClass:[LWActivationViewController class]]) {
        LWActivationViewController *act = [[LWActivationViewController alloc] init];
        __weak typeof(self) weakSelf = self;
        act.onActivated = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.window.rootViewController = [[ViewController alloc] init];
        };
        self.window.rootViewController = act;
    }
}

@end
