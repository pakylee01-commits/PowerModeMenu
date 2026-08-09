#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, PowerMode) {
    PowerModeHome,
    PowerModeAway,
    PowerModeUnknown
};

@interface PowerModeAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenu *menu;
@property(nonatomic, strong) NSMenuItem *currentItem;
@property(nonatomic, strong) NSMenuItem *homeItem;
@property(nonatomic, strong) NSMenuItem *awayItem;
@property(nonatomic, strong) NSTask *caffeinateTask;
@property(nonatomic) BOOL switching;
@end

@implementation PowerModeAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self configureMenu];
    [NSUserDefaults.standardUserDefaults setObject:NSDate.date forKey:@"LastSuccessfulLaunch"];
    [self refreshState];
    [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(ensureStatusItemVisible:) userInfo:nil repeats:YES];
}

- (void)configureMenu {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setBool:YES forKey:@"NSStatusItem VisibleCC MainStatusItem"];
    [defaults setDouble:400.0 forKey:@"NSStatusItem Preferred Position MainStatusItem"];
    [defaults synchronize];

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:22.0];
    self.statusItem.autosaveName = @"MainStatusItem";
    self.statusItem.behavior = 0;
    self.statusItem.visible = YES;
    self.statusItem.button.toolTip = @"电源模式";
    self.statusItem.button.title = @"⏻";
    self.statusItem.button.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];

    self.menu = [[NSMenu alloc] init];
    self.menu.delegate = self;
    self.statusItem.menu = self.menu;

    self.currentItem = [[NSMenuItem alloc] initWithTitle:@"正在读取电源状态..." action:nil keyEquivalent:@""];
    self.currentItem.enabled = NO;
    [self.menu addItem:self.currentItem];
    [self.menu addItem:[NSMenuItem separatorItem]];

    self.homeItem = [[NSMenuItem alloc] initWithTitle:@"在家常开" action:@selector(enableHomeMode:) keyEquivalent:@"1"];
    self.homeItem.target = self;
    self.homeItem.image = [NSImage imageWithSystemSymbolName:@"house.fill" accessibilityDescription:nil];
    [self.menu addItem:self.homeItem];

    self.awayItem = [[NSMenuItem alloc] initWithTitle:@"出门睡眠" action:@selector(enableAwayMode:) keyEquivalent:@"2"];
    self.awayItem.target = self;
    self.awayItem.image = [NSImage imageWithSystemSymbolName:@"figure.walk" accessibilityDescription:nil];
    [self.menu addItem:self.awayItem];
}

- (void)ensureStatusItemVisible:(NSTimer *)timer {
    self.statusItem.visible = YES;
    if (self.statusItem.button.title.length == 0) {
        self.statusItem.button.title = @"⏻";
    }
}

- (void)menuWillOpen:(NSMenu *)menu {
    [self refreshState];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self setKeepAwakeEnabled:NO];
}

- (void)enableHomeMode:(id)sender {
    [self switchModeWithArguments:@[@"-a", @"disablesleep", @"1", @"sleep", @"0", @"disksleep", @"0", @"displaysleep", @"0", @"lowpowermode", @"0", @"ttyskeepawake", @"1", @"tcpkeepalive", @"1"]];
}

- (void)enableAwayMode:(id)sender {
    [self switchModeWithArguments:@[@"-a", @"disablesleep", @"0", @"sleep", @"1", @"disksleep", @"10", @"displaysleep", @"10", @"lowpowermode", @"0", @"ttyskeepawake", @"1", @"tcpkeepalive", @"1"]];
}

- (void)switchModeWithArguments:(NSArray<NSString *> *)arguments {
    if (self.switching) return;

    self.switching = YES;
    self.homeItem.enabled = NO;
    self.awayItem.enabled = NO;
    self.currentItem.title = @"正在切换...";
    [self updateStatusIcon:@"hourglass"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<NSString *> *touchIDArguments = [NSMutableArray arrayWithArray:@[@"-q", @"-e", @"/dev/null", @"/usr/bin/sudo", @"-k", @"/usr/bin/pmset"]];
        [touchIDArguments addObjectsFromArray:arguments];
        NSDictionary *result = [PowerModeAppDelegate run:@"/usr/bin/script" arguments:touchIDArguments];

        if ([result[@"status"] intValue] != 0) {
            NSString *command = [NSString stringWithFormat:@"/usr/bin/pmset %@", [arguments componentsJoinedByString:@" "]];
            NSString *adminScript = [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", command];
            result = [PowerModeAppDelegate run:@"/usr/bin/osascript" arguments:@[@"-e", adminScript]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.switching = NO;
            self.homeItem.enabled = YES;
            self.awayItem.enabled = YES;
            [self refreshState];

            int status = [result[@"status"] intValue];
            NSString *error = result[@"error"];
            BOOL cancelled = [error containsString:@"(-128)"] || [error localizedCaseInsensitiveContainsString:@"canceled"];
            if (status != 0 && !cancelled) {
                [self showError:error.length ? error : @"系统未能修改电源设置。"];
            }
        });
    });
}

- (void)refreshState {
    if (self.switching) return;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSDictionary *result = [PowerModeAppDelegate run:@"/usr/bin/pmset" arguments:@[@"-g"]];
        NSString *output = result[@"output"];
        PowerMode mode = PowerModeUnknown;

        if ([output rangeOfString:@"SleepDisabled\\s+1" options:NSRegularExpressionSearch].location != NSNotFound) {
            mode = PowerModeHome;
        } else if ([output rangeOfString:@"SleepDisabled\\s+0" options:NSRegularExpressionSearch].location != NSNotFound) {
            mode = PowerModeAway;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.switching) return;

            if (mode == PowerModeHome) {
                [self setKeepAwakeEnabled:YES];
                self.currentItem.title = @"当前：在家常开";
                self.homeItem.state = NSControlStateValueOn;
                self.awayItem.state = NSControlStateValueOff;
                [self updateStatusIcon:@"power.circle.fill"];
            } else if (mode == PowerModeAway) {
                [self setKeepAwakeEnabled:NO];
                self.currentItem.title = @"当前：出门睡眠";
                self.homeItem.state = NSControlStateValueOff;
                self.awayItem.state = NSControlStateValueOn;
                [self updateStatusIcon:@"power.circle"];
            } else {
                self.currentItem.title = @"当前：状态未知";
                self.homeItem.state = NSControlStateValueOff;
                self.awayItem.state = NSControlStateValueOff;
                [self updateStatusIcon:@"exclamationmark.circle"];
            }
        });
    });
}

- (void)setKeepAwakeEnabled:(BOOL)enabled {
    if (!enabled) {
        if (self.caffeinateTask.running) {
            [self.caffeinateTask terminate];
        }
        self.caffeinateTask = nil;
        return;
    }

    if (self.caffeinateTask.running) return;

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/caffeinate"];
    task.arguments = @[@"-dimsu", @"-t", @"2147483647"];
    NSFileHandle *nullHandle = [NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];
    task.standardOutput = nullHandle;
    task.standardError = nullHandle;

    if ([task launchAndReturnError:nil]) {
        self.caffeinateTask = task;
    }
}

- (void)updateStatusIcon:(NSString *)symbolName {
    self.statusItem.button.accessibilityLabel = [symbolName isEqualToString:@"power.circle.fill"]
        ? @"电源模式，在家常开"
        : @"电源模式，出门睡眠";
}

- (void)showError:(NSString *)message {
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"电源模式切换失败";
    alert.informativeText = [message stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [alert runModal];
}

+ (NSDictionary *)run:(NSString *)executable arguments:(NSArray<NSString *> *)arguments {
    NSTask *task = [[NSTask alloc] init];
    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    task.executableURL = [NSURL fileURLWithPath:executable];
    task.arguments = arguments;
    task.standardOutput = outputPipe;
    task.standardError = errorPipe;

    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
        return @{@"status": @(-1), @"output": @"", @"error": launchError.localizedDescription ?: @"无法启动系统命令。"};
    }

    [task waitUntilExit];
    NSData *outputData = [outputPipe.fileHandleForReading readDataToEndOfFile];
    NSData *errorData = [errorPipe.fileHandleForReading readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] ?: @"";
    NSString *error = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] ?: @"";
    return @{@"status": @(task.terminationStatus), @"output": output, @"error": error};
}

@end

int main(void) {
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        PowerModeAppDelegate *delegate = [[PowerModeAppDelegate alloc] init];
        application.delegate = delegate;
        [application finishLaunching];
        [application run];
    }
    return 0;
}
