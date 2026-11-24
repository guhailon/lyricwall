#import <UIKit/UIKit.h>

// 激活页：首次打开先输授权码，输对才进歌词墙；已激活过直接进墙，不再弹。
// 样子跟 App 一个风格：#17112b 底、#0D525E 钮、白字。
NS_ASSUME_NONNULL_BEGIN

@interface LWActivationViewController : UIViewController

// 激活成功后调：AppDelegate 把 root 切到歌词墙。
@property (nonatomic, copy, nullable) void (^onActivated)(void);

@end

NS_ASSUME_NONNULL_END
