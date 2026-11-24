#import <Foundation/Foundation.h>

// LyricWall 激活码（照 China Fly 1.0.0 那套，改成 App 的做法）：
//  - 码表是 LyricWall 自己的 license/codes-lyricwall.json（master + codes），
//    线上抓 https://guhailong-repo.pages.dev/license/codes-lyricwall.json，
//    抓不到用 App 里自带的同一份（离线也能激活）。
//  - 比对不区分大小写（China Fly 的教训：输入框转大写＋比对区分大小写，
//    混合大小写的 master 永远激活不了——这里输入原样存、比对不区分大小写）。
//  - 码只放内存比对，绝不写日志；只存一个状态字 + 输过的码（供下次重查）。
//  - 抓不到名单不锁死（维持原状），只有线上明确说码不在名单里才吊销。

NS_ASSUME_NONNULL_BEGIN

@interface LWActivationManager : NSObject

// 已激活（本地存的码 + 状态字都说已激活）。
+ (BOOL)isActivated;

// 用输过的码激活。ok=YES 已激活并存下；ok=NO 码不对（errorMessage 给界面显示）。
+ (void)activateWithCode:(NSString *)code
              completion:(void (^)(BOOL ok, NSString * _Nullable errorMessage))completion;

// 后台重查存过的码：线上名单明确没有这码 → 发 LWActivationRevoked 通知
// （AppDelegate 收到就切回激活页）；抓不到名单 → 维持已激活。
+ (void)revalidateStoredCodeInBackground;

@end

extern NSString * const LWActivationRevokedNotification;
extern NSString * const LWActivationListURLString;

NS_ASSUME_NONNULL_END
