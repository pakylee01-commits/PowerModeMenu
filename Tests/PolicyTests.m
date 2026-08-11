#define main PowerModeMenuApplicationMain
#import "../Source/PowerModeMenu.m"
#undef main

@interface PowerModeAppDelegate (PolicyTests)
- (NSArray<NSString *> *)pmsetArgumentsForMode:(PowerMode)mode
                                automaticTiming:(BOOL)automaticTiming;
@end

static BOOL arraysEqual(NSArray<NSString *> *actual, NSArray<NSString *> *expected) {
    if (![actual isEqualToArray:expected]) {
        NSLog(@"expected %@, got %@", expected, actual);
        return NO;
    }
    return YES;
}

int main(void) {
    @autoreleasepool {
        PowerModeAppDelegate *delegate = [[PowerModeAppDelegate alloc] init];

        BOOL homeAutomatic = arraysEqual(
            [delegate pmsetArgumentsForMode:PowerModeHome automaticTiming:YES],
            (@[@"-a", @"disablesleep", @"1", @"lowpowermode", @"0",
               @"sleep", @"0", @"disksleep", @"0", @"displaysleep", @"0"]));
        BOOL awayAutomatic = arraysEqual(
            [delegate pmsetArgumentsForMode:PowerModeAway automaticTiming:YES],
            (@[@"-a", @"disablesleep", @"0", @"lowpowermode", @"0",
               @"sleep", @"10", @"disksleep", @"10", @"displaysleep", @"5"]));
        BOOL homeManual = arraysEqual(
            [delegate pmsetArgumentsForMode:PowerModeHome automaticTiming:NO],
            (@[@"-a", @"disablesleep", @"1", @"lowpowermode", @"0"]));
        BOOL awayManual = arraysEqual(
            [delegate pmsetArgumentsForMode:PowerModeAway automaticTiming:NO],
            (@[@"-a", @"disablesleep", @"0", @"lowpowermode", @"0"]));

        NSString *validOutput = @"System-wide power settings:\n SleepDisabled\t\t1\n sleep              0\n";
        BOOL exactParsing = [PowerModeAppDelegate output:validOutput hasSetting:@"SleepDisabled" value:1]
            && [PowerModeAppDelegate output:validOutput hasSetting:@"sleep" value:0]
            && ![PowerModeAppDelegate output:validOutput hasSetting:@"SleepDisabled" value:0]
            && ![PowerModeAppDelegate output:@" NotSleepDisabled 1\n" hasSetting:@"SleepDisabled" value:1]
            && ![PowerModeAppDelegate output:@" SleepDisabled 10\n" hasSetting:@"SleepDisabled" value:1];

        return homeAutomatic && awayAutomatic && homeManual && awayManual && exactParsing ? 0 : 1;
    }
}
