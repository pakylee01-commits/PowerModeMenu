#define main PowerModeMenuApplicationMain
#import "../Source/PowerModeMenu.m"
#undef main

@interface PowerModeAppDelegate (CommandRunnerTests)
- (NSDictionary *)run:(NSString *)executable
             arguments:(NSArray<NSString *> *)arguments
               timeout:(NSTimeInterval)timeout;
@end

int main(void) {
    @autoreleasepool {
        PowerModeAppDelegate *delegate = [[PowerModeAppDelegate alloc] init];
        delegate.authorizationProcessGroupIDs = [NSMutableSet set];
        delegate.authorizationTasksLock = [[NSLock alloc] init];

        CFAbsoluteTime timeoutStartedAt = CFAbsoluteTimeGetCurrent();
        NSDictionary *timeoutResult = [delegate run:@"/bin/sh"
                                          arguments:@[@"-c", @"/bin/sleep 5"]
                                            timeout:0.2];
        CFTimeInterval timeoutElapsed = CFAbsoluteTimeGetCurrent() - timeoutStartedAt;

        CFAbsoluteTime orphanStartedAt = CFAbsoluteTimeGetCurrent();
        NSDictionary *orphanResult = [delegate run:@"/bin/sh"
                                         arguments:@[@"-c", @"(/bin/sleep 5 &) ; exit 1"]
                                           timeout:1.0];
        CFTimeInterval orphanElapsed = CFAbsoluteTimeGetCurrent() - orphanStartedAt;

        CFAbsoluteTime watchdogStartedAt = CFAbsoluteTimeGetCurrent();
        NSDictionary *watchdogResult = [delegate run:@"/bin/sh"
                                           arguments:@[@"-c", AuthorizationWatchdogScript, @"watchdog-test", @"999999", @"/bin/sleep", @"5"]
                                             timeout:3.0];
        CFTimeInterval watchdogElapsed = CFAbsoluteTimeGetCurrent() - watchdogStartedAt;

        BOOL timeoutPassed = [timeoutResult[@"status"] intValue] == 124
            && ![timeoutResult[@"safeToFallback"] boolValue]
            && timeoutElapsed < 3.0;
        BOOL orphanPassed = [orphanResult[@"status"] intValue] != 0
            && [orphanResult[@"safeToFallback"] boolValue]
            && orphanElapsed < 3.0;
        BOOL watchdogPassed = [watchdogResult[@"status"] intValue] != 0
            && watchdogElapsed < 2.5;

        printf("timeout status=%d elapsed=%.3f safe=%d\n",
               [timeoutResult[@"status"] intValue], timeoutElapsed,
               [timeoutResult[@"safeToFallback"] boolValue]);
        printf("orphan status=%d elapsed=%.3f safe=%d\n",
               [orphanResult[@"status"] intValue], orphanElapsed,
               [orphanResult[@"safeToFallback"] boolValue]);
        printf("watchdog status=%d elapsed=%.3f\n",
               [watchdogResult[@"status"] intValue], watchdogElapsed);
        return timeoutPassed && orphanPassed && watchdogPassed ? 0 : 1;
    }
}
