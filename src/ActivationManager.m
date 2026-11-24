#import "ActivationManager.h"

NSString * const LWActivationRevokedNotification = @"LWActivationRevokedNotification";
NSString * const LWActivationListURLString = @"https://guhailong-repo.pages.dev/license/codes-lyricwall.json";

static NSString * const kLWActivatedKey = @"LWActivated";
static NSString * const kLWCodeKey = @"LWActivationCode";
static NSString * const kLWStateKey = @"LWActivationState";

@implementation LWActivationManager

+ (BOOL)isActivated {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    return [d boolForKey:kLWActivatedKey] && [[d stringForKey:kLWCodeKey] length] > 0;
}

+ (NSString *)trimmedCode:(NSString *)code {
    if (!code) return @"";
    return [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// 名单里的 master / codes 有没有这码（不区分大小写；码不写日志）。
+ (BOOL)list:(NSDictionary *)list containsCode:(NSString *)want {
    if (!want || want.length == 0) return NO;
    id master = list[@"master"];
    if ([master isKindOfClass:[NSString class]] &&
        [(NSString *)master caseInsensitiveCompare:want] == NSOrderedSame) return YES;
    id codes = list[@"codes"];
    if ([codes isKindOfClass:[NSArray class]]) {
        for (id entry in (NSArray *)codes) {
            if ([entry isKindOfClass:[NSString class]] &&
                [(NSString *)entry caseInsensitiveCompare:want] == NSOrderedSame) return YES;
        }
    }
    return NO;
}

// 读名单：先线上抓（3 秒超时，照 China Fly），抓不到／解不开就读 App 自带那份。
// completion(list, fromNetwork)：list 为 nil 表示两边都读不到。
+ (void)fetchListWithCompletion:(void (^)(NSDictionary * _Nullable list, BOOL fromNetwork))completion {
    NSURL *url = [NSURL URLWithString:LWActivationListURLString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 3.0;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSDictionary *remote = nil;
        if (!error && data) {
            @try {
                id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([parsed isKindOfClass:[NSDictionary class]]) remote = (NSDictionary *)parsed;
            } @catch (NSException *e) { (void)e; }
        }
        if (remote) { if (completion) completion(remote, YES); return; }
        NSDictionary *bundled = [self bundledList];
        if (completion) completion(bundled, NO);
    }];
    [task resume];
}

+ (NSDictionary * _Nullable)bundledList {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"codes-lyricwall" ofType:@"json" inDirectory:@"license"];
    if (!path) return nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    @try {
        id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([parsed isKindOfClass:[NSDictionary class]]) return (NSDictionary *)parsed;
    } @catch (NSException *e) { (void)e; }
    return nil;
}

+ (void)activateWithCode:(NSString *)code
              completion:(void (^)(BOOL ok, NSString * _Nullable errorMessage))completion {
    NSString *want = [self trimmedCode:code];
    if (want.length == 0) {
        if (completion) completion(NO, @"请输入授权码");
        return;
    }
    [self fetchListWithCompletion:^(NSDictionary * _Nullable list, BOOL fromNetwork) {
        (void)fromNetwork;
        BOOL ok = list ? [self list:list containsCode:want] : NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) {
                NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
                [d setObject:want forKey:kLWCodeKey];
                [d setBool:YES forKey:kLWActivatedKey];
                [d setObject:@"authorized" forKey:kLWStateKey];
                [d synchronize];
            }
            if (completion) completion(ok, ok ? nil : @"授权码不正确，请重新输入");
        });
    }];
}

+ (void)revalidateStoredCodeInBackground {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *stored = [d stringForKey:kLWCodeKey];
    if (!stored || stored.length == 0) return;
    [self fetchListWithCompletion:^(NSDictionary * _Nullable list, BOOL fromNetwork) {
        // 只有线上名单明确说没有这码才吊销；抓不到名单（走自带那份）维持已激活。
        if (fromNetwork && list && ![self list:list containsCode:stored]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSUserDefaults *dd = [NSUserDefaults standardUserDefaults];
                [dd setBool:NO forKey:kLWActivatedKey];
                [dd setObject:@"locked" forKey:kLWStateKey];
                [dd synchronize];
                [[NSNotificationCenter defaultCenter] postNotificationName:LWActivationRevokedNotification object:nil];
            });
        }
    }];
}

@end
