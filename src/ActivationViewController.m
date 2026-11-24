#import "ActivationViewController.h"
#import "ActivationManager.h"

@interface LWActivationViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *codeField;
@property (nonatomic, strong) UIButton *activateButton;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation LWActivationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 跟歌词墙容器一个底色 #17112b。
    self.view.backgroundColor = [UIColor colorWithRed:23.0/255.0 green:17.0/255.0 blue:43.0/255.0 alpha:1.0];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"歌词墙";
    title.font = [UIFont boldSystemFontOfSize:40];
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:title];

    UILabel *sub = [[UILabel alloc] init];
    sub.text = @"输入授权码，开启歌词墙";
    sub.font = [UIFont systemFontOfSize:17];
    sub.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.75];
    sub.textAlignment = NSTextAlignmentCenter;
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:sub];

    // 输入框：不转大写、不自动纠错（China Fly 的教训：框里转大写＋比对区分
    // 大小写，混合大小写的 master 永远激活不了）。
    self.codeField = [[UITextField alloc] init];
    self.codeField.placeholder = @"授权码，例如 LW-XXXX-XXXX-XXXX";
    self.codeField.textColor = [UIColor whiteColor];
    self.codeField.font = [UIFont systemFontOfSize:18];
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.codeField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.codeField.keyboardType = UIKeyboardTypeASCIICapable;
    self.codeField.returnKeyType = UIReturnKeyGo;
    self.codeField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.codeField.delegate = self;
    self.codeField.backgroundColor = [UIColor colorWithRed:36.0/255.0 green:26.0/255.0 blue:69.0/255.0 alpha:1.0];
    self.codeField.layer.cornerRadius = 12;
    self.codeField.layer.borderWidth = 1;
    self.codeField.layer.borderColor = [[UIColor colorWithRed:13.0/255.0 green:82.0/255.0 blue:94.0/255.0 alpha:1.0] CGColor];
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.codeField];

    self.activateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.activateButton setTitle:@"激活" forState:UIControlStateNormal];
    self.activateButton.titleLabel.font = [UIFont boldSystemFontOfSize:19];
    [self.activateButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.activateButton.backgroundColor = [UIColor colorWithRed:13.0/255.0 green:82.0/255.0 blue:94.0/255.0 alpha:1.0]; // #0D525E，工具栏同色
    self.activateButton.layer.cornerRadius = 12;
    self.activateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.activateButton addTarget:self action:@selector(onActivate:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.activateButton];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.font = [UIFont systemFontOfSize:15];
    self.errorLabel.textColor = [UIColor colorWithRed:1.0 green:0.42 blue:0.42 alpha:1.0];
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.errorLabel];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [UIColor whiteColor];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.spinner];

    UILabel *foot = [[UILabel alloc] init];
    foot.text = @"歌词墙 · 仅供学习参考";
    foot.font = [UIFont systemFontOfSize:13];
    foot.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.45];
    foot.textAlignment = NSTextAlignmentCenter;
    foot.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:foot];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [title.centerXAnchor constraintEqualToAnchor:g.centerXAnchor],
        [title.topAnchor constraintEqualToAnchor:g.topAnchor constant:140],
        [sub.centerXAnchor constraintEqualToAnchor:g.centerXAnchor],
        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:14],
        [self.codeField.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:36],
        [self.codeField.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-36],
        [self.codeField.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:44],
        [self.codeField.heightAnchor constraintEqualToConstant:52],
        [self.activateButton.leadingAnchor constraintEqualToAnchor:self.codeField.leadingAnchor],
        [self.activateButton.trailingAnchor constraintEqualToAnchor:self.codeField.trailingAnchor],
        [self.activateButton.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:20],
        [self.activateButton.heightAnchor constraintEqualToConstant:52],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:self.codeField.leadingAnchor],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:self.codeField.trailingAnchor],
        [self.errorLabel.topAnchor constraintEqualToAnchor:self.activateButton.bottomAnchor constant:16],
        [self.spinner.centerXAnchor constraintEqualToAnchor:g.centerXAnchor],
        [self.spinner.topAnchor constraintEqualToAnchor:self.errorLabel.bottomAnchor constant:12],
        [foot.centerXAnchor constraintEqualToAnchor:g.centerXAnchor],
        [foot.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-28],
    ]];
}

- (void)onActivate:(id)sender {
    [self.codeField resignFirstResponder];
    self.errorLabel.text = @"";
    self.activateButton.enabled = NO;
    self.codeField.enabled = NO;
    [self.spinner startAnimating];
    __weak typeof(self) weakSelf = self;
    [LWActivationManager activateWithCode:self.codeField.text completion:^(BOOL ok, NSString * _Nullable errorMessage) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.spinner stopAnimating];
        strongSelf.activateButton.enabled = YES;
        strongSelf.codeField.enabled = YES;
        if (ok) {
            if (strongSelf.onActivated) strongSelf.onActivated();
        } else {
            strongSelf.errorLabel.text = errorMessage ?: @"授权码不正确，请重新输入";
        }
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self onActivate:nil];
    return YES;
}

@end
