#import "ViewController.h"
#import <WebKit/WebKit.h>

// 歌词墙 App：单 WKWebView 载本地 3D 水面立体歌词墙（分屏播放器同一份 index.html），
// 下面一条原生工具栏：下一首 / 换主题 / 搜索 / 随机一首（皇上定的四个）。
// 只看不听：音频用“假成功”桩顶掉——页面以为试听在放，歌词行照常流动、
// 涟漪照常起，实际不发声、不联网取音频。3D 墙本身一字未改。

@interface ViewController () <WKNavigationDelegate, WKUIDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIToolbar *toolbar;
@end

@implementation ViewController

// 音频桩（document-start 注入）：所有 <audio> 的 play() 直接“假装成功”。
// 墙里试听逻辑照常走（playing=true，歌词行随时间流动），但从不调原生播放，
// 也不触发网络取音频。分屏那份墙里合成钢琴已删，无 AudioContext 可用。
static NSString * const kLWNoAudioJS =
@"(function(){"
@"  try {"
@"    HTMLMediaElement.prototype.play = function () { return Promise.resolve(); };"
@"  } catch (e) {}"
@"})();";

// 页面适配（document-end 注入）：
//  - 藏掉播放/进度/外链/导入 UI（工具栏接管控制；导入是放歌用的，不在只看范围）；
//  - 开场点一下第一首歌，让墙流动起来（只看画面，无声）。
static NSString * const kLWAdaptJS =
@"(function(){"
@"  var css = '#bigPlay,#tapHint,#playerNote,#dyBtn,#pvToast,.btn-row,.seek-row,.dy-link,.pl-foot{display:none!important}';"
@"  var st = document.createElement('style'); st.textContent = css;"
@"  (document.head || document.documentElement).appendChild(st);"
@"  function kick(){ var it = document.querySelector('.song-item'); if (it) { it.click(); return true; } return false; }"
@"  if (!kick()) { var n = 0; var t = setInterval(function(){ if (kick() || ++n > 10) { clearInterval(t); } }, 300); }"
@"})();";

- (void)viewDidLoad {
    [super viewDidLoad];
    // #17112b：分屏播放器容器底色，有缝也不露黑。
    self.view.backgroundColor = [UIColor colorWithRed:23.0/255.0 green:17.0/255.0 blue:43.0/255.0 alpha:1.0];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    WKUserScript *noAudio = [[WKUserScript alloc] initWithSource:kLWNoAudioJS
                                                   injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                forMainFrameOnly:YES];
    WKUserScript *adapt = [[WKUserScript alloc] initWithSource:kLWAdaptJS
                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                               forMainFrameOnly:YES];
    [config.userContentController addUserScript:noAudio];
    [config.userContentController addUserScript:adapt];

    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.backgroundColor = [UIColor colorWithRed:23.0/255.0 green:17.0/255.0 blue:43.0/255.0 alpha:1.0];
    self.webView.opaque = YES;
    // 跟分屏 1.0.111 捏合缩放锁一样：只关捏合，滚动点按不动。
    self.webView.scrollView.pinchGestureRecognizer.enabled = NO;
    self.webView.scrollView.maximumZoomScale = 1.0;
    self.webView.scrollView.bouncesZoom = NO;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.webView];

    // ---- 工具栏：下一首 / 换主题 / 搜索 / 随机一首（皇上定的四个） ----
    self.toolbar = [[UIToolbar alloc] init];
    self.toolbar.barStyle = UIBarStyleBlack;
    self.toolbar.barTintColor = [UIColor colorWithRed:13.0/255.0 green:82.0/255.0 blue:94.0/255.0 alpha:1.0]; // #0D525E，样子图工具栏同色
    self.toolbar.tintColor = [UIColor whiteColor]; // 样子图：白字
    self.toolbar.translucent = NO;
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"下一首" style:UIBarButtonItemStylePlain target:self action:@selector(onNext:)];
    UIBarButtonItem *theme = [[UIBarButtonItem alloc] initWithTitle:@"换主题" style:UIBarButtonItemStylePlain target:self action:@selector(onTheme:)];
    UIBarButtonItem *search = [[UIBarButtonItem alloc] initWithTitle:@"搜索" style:UIBarButtonItemStylePlain target:self action:@selector(onSearch:)];
    UIBarButtonItem *random = [[UIBarButtonItem alloc] initWithTitle:@"随机一首" style:UIBarButtonItemStylePlain target:self action:@selector(onRandom:)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    self.toolbar.items = @[flex, next, flex, theme, flex, search, flex, random, flex];
    [self.view addSubview:self.toolbar];

    [NSLayoutConstraint activateConstraints:@[
        [self.toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.toolbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.webView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:self.toolbar.topAnchor],
    ]];

    // 跟分屏播放器一样：单 webview，本地 lyricwall/index.html，读整个 lyricwall 目录。
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html" subdirectory:@"lyricwall"];
    if (fileURL) {
        [self.webView loadFileURL:fileURL allowingReadAccessToURL:[fileURL URLByDeletingLastPathComponent]];
    }
}

// ---- 工具栏动作：全部走墙里现成的按钮/列表（DOM 点按），不改墙文件 ----
- (void)runJS:(NSString *)js {
    [self.webView evaluateJavaScript:js completionHandler:nil];
}
- (void)onNext:(id)sender { [self runJS:@"document.getElementById('nextBtn').click()"]; }
- (void)onTheme:(id)sender { [self runJS:@"document.getElementById('wallBtn').click()"]; } // 打开墙面（51 种主题）面板
- (void)onRandom:(id)sender {
    [self runJS:@"(function(){var items=document.querySelectorAll('.song-item');if(!items.length)return;var i=Math.floor(Math.random()*items.length);items[i].click();})()"];
}
- (void)onSearch:(id)sender {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"搜索" message:@"输入歌名或歌手" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"例如：晴天 / 周杰伦"; tf.clearButtonMode = UITextFieldViewModeWhileEditing; }];
    UIAlertAction *go = [UIAlertAction actionWithTitle:@"搜索" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *q = [ac.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (q.length == 0) return;
        [self searchSong:q];
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:go];
    [self presentViewController:ac animated:YES completion:nil];
}
- (void)searchSong:(NSString *)query {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[query] options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]; // ["query"]
    NSString *js = [NSString stringWithFormat:
        @"(function(q){"
        @"  q=(q||'').toLowerCase().trim(); if(!q) return '';"
        @"  var items=document.querySelectorAll('.song-item');"
        @"  for(var i=0;i<items.length;i++){"
        @"    var nm=items[i].querySelector('.nm'); var ar=items[i].querySelector('.ar');"
        @"    var t=((nm?nm.textContent:'')+' '+(ar?ar.textContent:'')).toLowerCase();"
        @"    if(t.indexOf(q)>=0){ items[i].click(); return (nm?nm.textContent:'')+' - '+(ar?ar.textContent:''); }"
        @"  }"
        @"  return '';"
        @"})(%@[0])", json];
    __weak typeof(self) weakSelf = self;
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        NSString *hit = [result isKindOfClass:[NSString class]] ? (NSString *)result : nil;
        if (!hit || hit.length == 0) {
            UIAlertController *nf = [UIAlertController alertControllerWithTitle:@"没找到" message:[NSString stringWithFormat:@"歌单里没有「%@」", query] preferredStyle:UIAlertControllerStyleAlert];
            [nf addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
            [weakSelf presentViewController:nf animated:YES completion:nil];
        }
    }];
}

#pragma mark - WKNavigationDelegate / WKUIDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    if (url && [url.scheme isEqualToString:@"file"]) { decisionHandler(WKNavigationActionPolicyAllow); return; }
    decisionHandler(WKNavigationActionPolicyCancel); // 外链（抖音等）一律不出 App
}
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    return nil; // 新窗口链接不打开
}

@end
