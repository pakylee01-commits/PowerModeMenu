#import <Cocoa/Cocoa.h>
#import <errno.h>
#import <signal.h>
#import <spawn.h>
#import <stdlib.h>
#import <string.h>
#import <sys/wait.h>
#import <unistd.h>

extern char **environ;

static const NSTimeInterval TouchIDAuthorizationTimeout = 30.0;
static const NSTimeInterval AdminAuthorizationTimeout = 120.0;
static const NSTimeInterval CommandTimeout = 10.0;
static NSString *const AutomaticTimingEnabledKey = @"AutomaticTimingEnabled";
static const NSInteger AwayLockDelaySeconds = 5 * 60;
static const NSInteger AwaySleepDelayMinutes = 10;
static NSString *const AuthorizationWatchdogScript =
    @"parent_pid=$1; shift; \"$@\" & command_pid=$!; "
     "(trap '' TERM; while kill -0 \"$parent_pid\" 2>/dev/null; do sleep 0.2; done; "
     "group_id=$$; kill -TERM -\"$group_id\" 2>/dev/null; sleep 1; kill -KILL -\"$group_id\" 2>/dev/null) & "
     "watchdog_pid=$!; wait \"$command_pid\"; status=$?; kill -KILL \"$watchdog_pid\" 2>/dev/null; "
     "wait \"$watchdog_pid\" 2>/dev/null; exit \"$status\"";

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
@property(nonatomic, strong) NSMenuItem *automaticTimingItem;
@property(nonatomic, strong) NSMenuItem *timingSummaryItem;
@property(nonatomic, strong) NSTask *caffeinateTask;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *authorizationProcessGroupIDs;
@property(nonatomic, strong) NSLock *authorizationTasksLock;
@property(nonatomic) BOOL switching;
@property(nonatomic) BOOL terminating;
@property(nonatomic) BOOL authorizationUnsafe;
@property(nonatomic) NSUInteger refreshGeneration;
@end

@implementation PowerModeAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    self.authorizationProcessGroupIDs = [NSMutableSet set];
    self.authorizationTasksLock = [[NSLock alloc] init];
    [NSUserDefaults.standardUserDefaults registerDefaults:@{AutomaticTimingEnabledKey: @YES}];
    [self configureMenu];
    [NSUserDefaults.standardUserDefaults setObject:NSDate.date forKey:@"LastSuccessfulLaunch"];
    [self refreshState];
    [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(ensureStatusItemVisible:) userInfo:nil repeats:YES];
}

- (void)configureMenu {
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

    [self.menu addItem:[NSMenuItem separatorItem]];

    self.automaticTimingItem = [[NSMenuItem alloc] initWithTitle:@"切换时同步锁屏与睡眠时间" action:@selector(toggleAutomaticTiming:) keyEquivalent:@""];
    self.automaticTimingItem.target = self;
    self.automaticTimingItem.image = [NSImage imageWithSystemSymbolName:@"timer" accessibilityDescription:nil];
    [self.menu addItem:self.automaticTimingItem];

    self.timingSummaryItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    self.timingSummaryItem.enabled = NO;
    [self.menu addItem:self.timingSummaryItem];
    [self updateAutomaticTimingMenu];

    [self.menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"退出电源模式菜单" action:@selector(quitApplication:) keyEquivalent:@"q"];
    quitItem.target = self;
    [self.menu addItem:quitItem];
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
    self.terminating = YES;
    [self cancelAuthorizationTasks];
    [self setKeepAwakeEnabled:NO];
}

- (void)enableHomeMode:(id)sender {
    [self switchToMode:PowerModeHome];
}

- (void)enableAwayMode:(id)sender {
    [self switchToMode:PowerModeAway];
}

- (void)quitApplication:(id)sender {
    if (self.terminating) return;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"退出前确认电源模式";
    alert.informativeText = @"退出会停止 PowerModeMenu 管理的 caffeinate，但不会恢复 pmset、睡眠或锁屏设置。如果当前是“在家常开”，请先切换到“出门睡眠”。";
    [alert addButtonWithTitle:@"取消"];
    [alert addButtonWithTitle:@"仍然退出"];
    if ([alert runModal] != NSAlertSecondButtonReturn) return;

    self.terminating = YES;
    self.currentItem.title = @"正在安全退出...";
    self.homeItem.enabled = NO;
    self.awayItem.enabled = NO;
    self.automaticTimingItem.enabled = NO;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self cancelAuthorizationTasks];
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSApp terminate:nil];
        });
    });
}

- (void)toggleAutomaticTiming:(id)sender {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setBool:![defaults boolForKey:AutomaticTimingEnabledKey] forKey:AutomaticTimingEnabledKey];
    [self updateAutomaticTimingMenu];
    [self refreshState];
}

- (void)updateAutomaticTimingMenu {
    BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:AutomaticTimingEnabledKey];
    self.automaticTimingItem.state = enabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.timingSummaryItem.title = enabled
        ? @"在家：永不锁屏/睡眠；出门：5 分钟锁屏、10 分钟睡眠"
        : @"关闭后仅切换合盖策略，不修改时间";
}

- (NSArray<NSString *> *)pmsetArgumentsForMode:(PowerMode)mode automaticTiming:(BOOL)automaticTiming {
    NSMutableArray<NSString *> *arguments = [NSMutableArray arrayWithArray:@[
        @"-a", @"disablesleep", mode == PowerModeHome ? @"1" : @"0", @"lowpowermode", @"0"
    ]];
    if (automaticTiming) {
        if (mode == PowerModeHome) {
            [arguments addObjectsFromArray:@[@"sleep", @"0", @"disksleep", @"0", @"displaysleep", @"0"]];
        } else {
            NSString *sleepDelay = [NSString stringWithFormat:@"%ld", (long)AwaySleepDelayMinutes];
            [arguments addObjectsFromArray:@[@"sleep", sleepDelay, @"disksleep", sleepDelay, @"displaysleep", @"5"]];
        }
    }
    return arguments;
}

- (NSDictionary *)applyLockTimingForMode:(PowerMode)mode {
    NSInteger idleTime = mode == PowerModeHome ? 0 : AwayLockDelaySeconds;
    NSDictionary *result = [self run:@"/usr/bin/defaults"
                           arguments:@[@"-currentHost", @"write", @"com.apple.screensaver", @"idleTime", @"-int", [NSString stringWithFormat:@"%ld", (long)idleTime]]];
    if ([result[@"status"] intValue] != 0 || mode == PowerModeHome) return result;

    result = [self run:@"/usr/bin/defaults" arguments:@[@"write", @"com.apple.screensaver", @"askForPassword", @"-int", @"1"]];
    if ([result[@"status"] intValue] != 0) return result;
    return [self run:@"/usr/bin/defaults" arguments:@[@"write", @"com.apple.screensaver", @"askForPasswordDelay", @"-int", @"0"]];
}

- (void)switchToMode:(PowerMode)mode {
    if (self.switching || self.authorizationUnsafe) return;

    BOOL automaticTiming = [NSUserDefaults.standardUserDefaults boolForKey:AutomaticTimingEnabledKey];
    NSArray<NSString *> *arguments = [self pmsetArgumentsForMode:mode automaticTiming:automaticTiming];
    self.switching = YES;
    self.homeItem.enabled = NO;
    self.awayItem.enabled = NO;
    self.automaticTimingItem.enabled = NO;
    self.currentItem.title = @"正在切换...";
    [self updateStatusIcon:@"hourglass"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<NSString *> *touchIDArguments = [NSMutableArray arrayWithArray:@[@"-q", @"-e", @"/dev/null", @"/usr/bin/sudo", @"-k", @"/usr/bin/pmset"]];
        [touchIDArguments addObjectsFromArray:arguments];
        NSDictionary *result = [self run:@"/usr/bin/script"
                               arguments:touchIDArguments
                                 timeout:TouchIDAuthorizationTimeout
                    trackAuthorization:YES];

        NSString *touchIDError = result[@"error"];
        BOOL touchIDCancelled = [touchIDError containsString:@"(-128)"]
            || [touchIDError localizedCaseInsensitiveContainsString:@"canceled"]
            || [touchIDError localizedCaseInsensitiveContainsString:@"cancelled"];
        if (!self.terminating && !touchIDCancelled
            && [result[@"status"] intValue] != 0 && [result[@"safeToFallback"] boolValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.currentItem.title = @"等待管理员授权...";
                self.statusItem.button.toolTip = @"电源模式：等待管理员授权";
            });

            NSString *command = [NSString stringWithFormat:@"/usr/bin/pmset %@", [arguments componentsJoinedByString:@" "]];
            NSString *adminScript = [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", command];
            result = [self run:@"/usr/bin/osascript"
                     arguments:@[@"-e", adminScript]
                       timeout:AdminAuthorizationTimeout
          trackAuthorization:YES];
        }

        if (!self.terminating && [result[@"status"] intValue] == 0 && automaticTiming) {
            result = [self applyLockTimingForMode:mode];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.terminating) return;
            self.switching = NO;

            int status = [result[@"status"] intValue];
            NSString *error = result[@"error"];
            BOOL cancelled = [error containsString:@"(-128)"]
                || [error localizedCaseInsensitiveContainsString:@"canceled"]
                || [error localizedCaseInsensitiveContainsString:@"cancelled"];
            self.authorizationUnsafe = status != 0 && ![result[@"safeToFallback"] boolValue]
                && [self authorizationProcessGroupCount] > 0;
            self.homeItem.enabled = !self.authorizationUnsafe;
            self.awayItem.enabled = !self.authorizationUnsafe;
            self.automaticTimingItem.enabled = !self.authorizationUnsafe;
            if (self.authorizationUnsafe) {
                self.currentItem.title = @"授权进程未结束，请先退出应用";
                [self updateStatusIcon:@"exclamationmark.circle"];
            } else {
                [self refreshState];
            }
            if (status != 0 && !cancelled) {
                [self showError:error.length ? error : @"系统未能修改电源设置。"];
            }
        });
    });
}

- (void)refreshState {
    if (self.switching) return;
    if (self.authorizationUnsafe) {
        [self removeExitedAuthorizationProcessGroups];
        if ([self authorizationProcessGroupCount] > 0) {
            self.currentItem.title = @"授权进程未结束，请先退出应用";
            self.homeItem.enabled = NO;
            self.awayItem.enabled = NO;
            self.automaticTimingItem.enabled = NO;
            [self updateStatusIcon:@"exclamationmark.circle"];
            return;
        }
        self.authorizationUnsafe = NO;
        self.homeItem.enabled = YES;
        self.awayItem.enabled = YES;
        self.automaticTimingItem.enabled = YES;
    }
    NSUInteger generation = ++self.refreshGeneration;
    BOOL automaticTiming = [NSUserDefaults.standardUserDefaults boolForKey:AutomaticTimingEnabledKey];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSDictionary *result = [self run:@"/usr/bin/pmset" arguments:@[@"-g"]];
        NSString *output = result[@"output"];
        PowerMode mode = PowerModeUnknown;

        BOOL isHome = [PowerModeAppDelegate output:output hasSetting:@"SleepDisabled" value:1]
            && [PowerModeAppDelegate output:output hasSetting:@"lowpowermode" value:0];
        BOOL isAway = [PowerModeAppDelegate output:output hasSetting:@"SleepDisabled" value:0]
            && [PowerModeAppDelegate output:output hasSetting:@"lowpowermode" value:0];

        if (automaticTiming) {
            NSDictionary *idleResult = [self run:@"/usr/bin/defaults" arguments:@[@"-currentHost", @"read", @"com.apple.screensaver", @"idleTime"]];
            NSInteger idleTime = [idleResult[@"output"] integerValue];
            BOOL idleTimeReadable = [idleResult[@"status"] intValue] == 0;
            isHome = isHome
                && [PowerModeAppDelegate output:output hasSetting:@"sleep" value:0]
                && [PowerModeAppDelegate output:output hasSetting:@"disksleep" value:0]
                && [PowerModeAppDelegate output:output hasSetting:@"displaysleep" value:0]
                && idleTimeReadable && idleTime == 0;

            NSDictionary *passwordResult = [self run:@"/usr/bin/defaults" arguments:@[@"read", @"com.apple.screensaver", @"askForPassword"]];
            NSDictionary *delayResult = [self run:@"/usr/bin/defaults" arguments:@[@"read", @"com.apple.screensaver", @"askForPasswordDelay"]];
            isAway = isAway
                && [PowerModeAppDelegate output:output hasSetting:@"sleep" value:AwaySleepDelayMinutes]
                && [PowerModeAppDelegate output:output hasSetting:@"disksleep" value:AwaySleepDelayMinutes]
                && [PowerModeAppDelegate output:output hasSetting:@"displaysleep" value:5]
                && idleTimeReadable && idleTime == AwayLockDelaySeconds
                && [passwordResult[@"status"] intValue] == 0 && [passwordResult[@"output"] integerValue] == 1
                && [delayResult[@"status"] intValue] == 0 && [delayResult[@"output"] integerValue] == 0;
        }

        if (isHome) {
            mode = PowerModeHome;
        } else if (isAway) {
            mode = PowerModeAway;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.switching || generation != self.refreshGeneration) return;

            if (mode == PowerModeHome) {
                if (![self setKeepAwakeEnabled:YES]) {
                    self.currentItem.title = @"在家参数已生效，但 caffeinate 启动失败";
                    self.homeItem.state = NSControlStateValueOff;
                    self.awayItem.state = NSControlStateValueOff;
                    [self updateStatusIcon:@"exclamationmark.circle"];
                    return;
                }
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

- (BOOL)setKeepAwakeEnabled:(BOOL)enabled {
    if (!enabled) {
        if (self.caffeinateTask.running) {
            [self.caffeinateTask terminate];
        }
        self.caffeinateTask = nil;
        return YES;
    }

    if (self.caffeinateTask.running) return YES;

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/caffeinate"];
    task.arguments = @[@"-dimsu", @"-w", [NSString stringWithFormat:@"%d", getpid()]];
    NSFileHandle *nullHandle = [NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];
    task.standardOutput = nullHandle;
    task.standardError = nullHandle;

    if ([task launchAndReturnError:nil]) {
        self.caffeinateTask = task;
        return YES;
    }
    return NO;
}

- (void)updateStatusIcon:(NSString *)symbolName {
    if ([symbolName isEqualToString:@"hourglass"]) {
        self.statusItem.button.title = @"…";
        self.statusItem.button.toolTip = @"电源模式：正在等待授权";
        self.statusItem.button.accessibilityLabel = @"电源模式，正在等待授权";
        return;
    }

    self.statusItem.button.title = @"⏻";
    self.statusItem.button.toolTip = @"电源模式";
    if ([symbolName isEqualToString:@"power.circle.fill"]) {
        self.statusItem.button.accessibilityLabel = @"电源模式，在家常开";
    } else if ([symbolName isEqualToString:@"power.circle"]) {
        self.statusItem.button.accessibilityLabel = @"电源模式，出门睡眠";
    } else {
        self.statusItem.button.accessibilityLabel = @"电源模式，状态未知";
    }
}

- (void)showError:(NSString *)message {
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"电源模式切换失败";
    alert.informativeText = [message stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [alert runModal];
}

- (NSDictionary *)run:(NSString *)executable arguments:(NSArray<NSString *> *)arguments {
    return [self run:executable arguments:arguments timeout:CommandTimeout];
}

- (NSDictionary *)run:(NSString *)executable arguments:(NSArray<NSString *> *)arguments timeout:(NSTimeInterval)timeout {
    return [self run:executable arguments:arguments timeout:timeout trackAuthorization:NO];
}

+ (BOOL)output:(NSString *)output hasSetting:(NSString *)setting value:(NSInteger)value {
    NSString *escapedSetting = [NSRegularExpression escapedPatternForString:setting];
    NSString *pattern = [NSString stringWithFormat:@"(?m)^\\s*%@\\s+%ld(?:\\s|$)", escapedSetting, (long)value];
    return [output rangeOfString:pattern options:NSRegularExpressionSearch].location != NSNotFound;
}

- (BOOL)processGroupHasExited:(pid_t)processGroupID {
    return processGroupID <= 0 || (kill(-processGroupID, 0) == -1 && errno == ESRCH);
}

- (BOOL)waitForProcessGroupToExit:(pid_t)processGroupID timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        int ignoredStatus = 0;
        waitpid(processGroupID, &ignoredStatus, WNOHANG);
        if ([self processGroupHasExited:processGroupID]) return YES;
        [NSThread sleepForTimeInterval:0.05];
    } while ([deadline timeIntervalSinceNow] > 0);
    return [self processGroupHasExited:processGroupID];
}

- (BOOL)terminateProcessGroup:(pid_t)processGroupID {
    if ([self processGroupHasExited:processGroupID]) return YES;
    kill(-processGroupID, SIGTERM);
    if ([self waitForProcessGroupToExit:processGroupID timeout:2.0]) return YES;
    kill(-processGroupID, SIGKILL);
    return [self waitForProcessGroupToExit:processGroupID timeout:2.0];
}

- (void)trackAuthorizationProcessGroup:(pid_t)processGroupID add:(BOOL)add {
    [self.authorizationTasksLock lock];
    if (add) {
        [self.authorizationProcessGroupIDs addObject:@(processGroupID)];
    } else {
        [self.authorizationProcessGroupIDs removeObject:@(processGroupID)];
    }
    [self.authorizationTasksLock unlock];
}

- (void)cancelAuthorizationTasks {
    [self.authorizationTasksLock lock];
    NSArray<NSNumber *> *processGroups = self.authorizationProcessGroupIDs.allObjects;
    [self.authorizationTasksLock unlock];
    for (NSNumber *processGroup in processGroups) {
        pid_t processGroupID = processGroup.intValue;
        if ([self terminateProcessGroup:processGroupID]) {
            [self trackAuthorizationProcessGroup:processGroupID add:NO];
        }
    }
}

- (void)removeExitedAuthorizationProcessGroups {
    [self.authorizationTasksLock lock];
    NSArray<NSNumber *> *processGroups = self.authorizationProcessGroupIDs.allObjects;
    [self.authorizationTasksLock unlock];
    for (NSNumber *processGroup in processGroups) {
        if ([self processGroupHasExited:processGroup.intValue]) {
            [self trackAuthorizationProcessGroup:processGroup.intValue add:NO];
        }
    }
}

- (NSUInteger)authorizationProcessGroupCount {
    [self.authorizationTasksLock lock];
    NSUInteger count = self.authorizationProcessGroupIDs.count;
    [self.authorizationTasksLock unlock];
    return count;
}

- (NSDictionary *)run:(NSString *)executable
             arguments:(NSArray<NSString *> *)arguments
               timeout:(NSTimeInterval)timeout
  trackAuthorization:(BOOL)trackAuthorization {
    NSString *spawnExecutable = executable;
    NSArray<NSString *> *spawnArguments = arguments;
    if (trackAuthorization) {
        NSMutableArray<NSString *> *watchdogArguments = [NSMutableArray arrayWithArray:@[
            @"-c", AuthorizationWatchdogScript, @"powermode-authorization",
            [NSString stringWithFormat:@"%d", getpid()], executable
        ]];
        [watchdogArguments addObjectsFromArray:arguments];
        spawnExecutable = @"/bin/sh";
        spawnArguments = watchdogArguments;
    }

    int outputPipe[2] = {-1, -1};
    int errorPipe[2] = {-1, -1};
    if (pipe(outputPipe) != 0 || pipe(errorPipe) != 0) {
        if (outputPipe[0] >= 0) close(outputPipe[0]);
        if (outputPipe[1] >= 0) close(outputPipe[1]);
        if (errorPipe[0] >= 0) close(errorPipe[0]);
        if (errorPipe[1] >= 0) close(errorPipe[1]);
        return @{@"status": @(-1), @"output": @"", @"error": @"无法创建命令输出管道。", @"safeToFallback": @YES};
    }

    posix_spawn_file_actions_t fileActions;
    posix_spawn_file_actions_init(&fileActions);
    posix_spawn_file_actions_adddup2(&fileActions, outputPipe[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&fileActions, errorPipe[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&fileActions, outputPipe[0]);
    posix_spawn_file_actions_addclose(&fileActions, errorPipe[0]);
    posix_spawn_file_actions_addclose(&fileActions, outputPipe[1]);
    posix_spawn_file_actions_addclose(&fileActions, errorPipe[1]);

    posix_spawnattr_t attributes;
    posix_spawnattr_init(&attributes);
    posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETPGROUP);
    posix_spawnattr_setpgroup(&attributes, 0);

    NSUInteger argumentCount = spawnArguments.count + 2;
    char **argv = calloc(argumentCount, sizeof(char *));
    if (argv == NULL) {
        posix_spawn_file_actions_destroy(&fileActions);
        posix_spawnattr_destroy(&attributes);
        close(outputPipe[0]);
        close(outputPipe[1]);
        close(errorPipe[0]);
        close(errorPipe[1]);
        return @{@"status": @(-1), @"output": @"", @"error": @"无法分配命令参数内存。", @"safeToFallback": @YES};
    }
    argv[0] = (char *)spawnExecutable.fileSystemRepresentation;
    for (NSUInteger index = 0; index < spawnArguments.count; index++) {
        argv[index + 1] = (char *)spawnArguments[index].fileSystemRepresentation;
    }

    pid_t processID = 0;
    int spawnStatus = posix_spawn(&processID, spawnExecutable.fileSystemRepresentation, &fileActions, &attributes, argv, environ);
    free(argv);
    posix_spawn_file_actions_destroy(&fileActions);
    posix_spawnattr_destroy(&attributes);
    close(outputPipe[1]);
    close(errorPipe[1]);

    if (spawnStatus != 0) {
        close(outputPipe[0]);
        close(errorPipe[0]);
        NSString *message = [NSString stringWithFormat:@"无法启动系统命令：%s", strerror(spawnStatus)];
        return @{@"status": @(-1), @"output": @"", @"error": message, @"safeToFallback": @YES};
    }

    if (trackAuthorization) {
        [self trackAuthorizationProcessGroup:processID add:YES];
        if (self.terminating) {
            BOOL terminated = [self terminateProcessGroup:processID];
            if (terminated) [self trackAuthorizationProcessGroup:processID add:NO];
        }
    }

    __block NSData *outputData = nil;
    __block NSData *errorData = nil;
    int outputReadDescriptor = outputPipe[0];
    int errorReadDescriptor = errorPipe[0];
    dispatch_group_t readers = dispatch_group_create();
    dispatch_group_async(readers, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSFileHandle *handle = [[NSFileHandle alloc] initWithFileDescriptor:outputReadDescriptor closeOnDealloc:YES];
        outputData = [handle readDataToEndOfFile];
    });
    dispatch_group_async(readers, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSFileHandle *handle = [[NSFileHandle alloc] initWithFileDescriptor:errorReadDescriptor closeOnDealloc:YES];
        errorData = [handle readDataToEndOfFile];
    });

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    int waitStatus = 0;
    BOOL rootExited = NO;
    do {
        pid_t waited = waitpid(processID, &waitStatus, WNOHANG);
        rootExited = waited == processID || (waited == -1 && errno == ECHILD);
        if (!rootExited) [NSThread sleepForTimeInterval:0.05];
    } while (!rootExited && [deadline timeIntervalSinceNow] > 0);

    if (!rootExited) {
        BOOL terminated = [self terminateProcessGroup:processID];
        waitpid(processID, &waitStatus, WNOHANG);
        if (trackAuthorization && terminated) [self trackAuthorizationProcessGroup:processID add:NO];
        dispatch_group_wait(readers, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC));
        NSString *error = terminated ? @"授权等待超时，请重试。" : @"授权进程组未能安全终止；已停止后续操作。";
        return @{@"status": @(124), @"output": @"", @"error": error, @"safeToFallback": @NO};
    }

    BOOL hadStragglers = ![self waitForProcessGroupToExit:processID timeout:0.5];
    BOOL groupTerminated = !hadStragglers || [self terminateProcessGroup:processID];
    if (trackAuthorization && groupTerminated) [self trackAuthorizationProcessGroup:processID add:NO];
    dispatch_group_wait(readers, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC));
    NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] ?: @"";
    NSString *error = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] ?: @"";
    if (!groupTerminated || (hadStragglers && WIFEXITED(waitStatus) && WEXITSTATUS(waitStatus) == 0)) {
        NSString *message = error.length ? error : @"授权进程组未能正常结束；已停止后续操作。";
        return @{@"status": @(125), @"output": output, @"error": message, @"safeToFallback": @NO};
    }
    int status = WIFEXITED(waitStatus) ? WEXITSTATUS(waitStatus) : 128 + WTERMSIG(waitStatus);
    return @{@"status": @(status), @"output": output, @"error": error, @"safeToFallback": @YES};
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
