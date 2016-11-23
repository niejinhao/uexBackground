/**
 *
 *	@file   	: uexBackgroundManager.m  in EUExBackground Project .
 *
 *	@author 	: CeriNo.
 * 
 *	@date   	: Created on 16/3/7.
 *
 *	@copyright 	: 2016 The AppCan Open Source Project.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "uexBackgroundManager.h"
#import "ACEJSCHandler.h"
#import "uexBackgroundTimer.h"
#import <AppCanKit/ACJSValueSupport.h>



@interface uexBackgroundManager()<AppCanWebViewEngineObject>
@property (nonatomic,strong)JSContext *context;
@property (nonatomic,strong)ACEJSCHandler *JSCHandler;
@property (nonatomic,strong)RACSubject *resetSignal;
@property (nonatomic,strong)NSMutableArray<uexBackgroundTimer *> *timers;
@property (nonatomic,strong)dispatch_semaphore_t arrayLock;
@property (nonatomic,strong)RACDisposable *taskDisposable;

@property (nonatomic,assign)BOOL shouldEndBackgroundTask;

@property (nonatomic,strong)dispatch_queue_t jsQueue;


@end


NSString *kUexBackgroundCallbackPluginName = @"uexBackground";
NSString *kUexBackgroundOnLoadName = @"onLoad";
@implementation uexBackgroundManager

+ (instancetype)sharedManager{
    static uexBackgroundManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc]init];
    });
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _timers = [NSMutableArray array];
        _arrayLock = dispatch_semaphore_create(1);
        _jsResources = [NSMutableArray array];
        _jsQueue = dispatch_queue_create("com.appcan.uexBackground.jsRuntime", DISPATCH_QUEUE_SERIAL);

        
        
    }
    return self;
}
- (void)reset{

    if (self.JSCHandler) {
        [self.JSCHandler clean];
        self.JSCHandler = nil;
    }
    if(self.context){
        self.context = nil;
    }
    if (self.taskDisposable) {
        [self.taskDisposable dispose];
    }
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    [self.timers removeAllObjects];
    [self.resetSignal sendNext:nil];
    [self.jsResources removeAllObjects];
}


- (void)dealloc{
    [self reset];
}
#pragma mark - Lazy Getters

- (JSContext *)context{
    if (!_context) {
        _context = [[JSContext alloc]init];
    }
    return _context;
}

- (ACEJSCHandler *)JSCHandler{
    if (!_JSCHandler) {
        _JSCHandler = [[ACEJSCHandler alloc]initWithWebViewEngine:self];
        [_JSCHandler initializeWithJSContext:self.context];
    }
    return _JSCHandler;
}



- (RACSubject *)resetSignal{
    if (!_resetSignal) {
        _resetSignal = [RACSubject subject];
    }
    return _resetSignal;
}

#pragma mark - Public Methods


- (BOOL)startWithJSScript:(NSString *)js{
    if (self.isRunning) {
        return NO;
    }
    self.isRunning = YES;
    [self.JSCHandler initializeWithJSContext:self.context];
    for (int i = 0; i < self.jsResources.count; i++) {
        [self evaluateScript:self.jsResources[i]];
    }
    [self evaluateScript:js];
    NSString *onLoadJS = [NSString stringWithFormat:@"if(%@.%@){%@.%@();}",kUexBackgroundCallbackPluginName,kUexBackgroundOnLoadName,kUexBackgroundCallbackPluginName,kUexBackgroundOnLoadName];
    [self evaluateScript:onLoadJS];

    
    [[[NSNotificationCenter defaultCenter] rac_addObserverForName:UIApplicationDidBecomeActiveNotification object:nil]
     subscribeNext:^(id x){
         if (self.taskDisposable) {
             [self.taskDisposable dispose];
         }
    }];
    
    [[[NSNotificationCenter defaultCenter] rac_addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil]subscribeNext:^(id x) {
        //NSLog(@"enter background");
        __block UIBackgroundTaskIdentifier bgTask;
        bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            self.shouldEndBackgroundTask = NO;
            [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        }];
        self.shouldEndBackgroundTask = YES;
        @weakify(self);
        self.taskDisposable = [RACDisposable disposableWithBlock:^{
            @strongify(self);
            if (self.shouldEndBackgroundTask) {
                self.shouldEndBackgroundTask = NO;
                //NSLog(@"stop task!");
                [[UIApplication sharedApplication] endBackgroundTask:bgTask];
            }
            self.taskDisposable = nil;
        }];
    }];
    

    return YES;
}

- (BOOL)stop{
    if(!self.isRunning){
        return NO;
    }
    [self reset];
    self.isRunning = NO;
    return YES;
}




- (BOOL)addTimerWithIdentifier:(NSString *)identifier
                  callbackName:(NSString *)callbackName
                  timeInterval:(NSTimeInterval)timeInterval
                   repeatTimes:(NSInteger)repeatTimes{
    [self lock];
    if (![self isIdentifierValid:identifier]) {
        [self unlock];
        return NO;
    }
    if (![self isCallbackNameValid:identifier]) {
        [self unlock];
        return NO;
    }
    [self unlock];
    if (!self.isRunning) {
        return NO;
    }
    if (timeInterval <= 0) {
        return NO;
    }
    __block uexBackgroundTimer *timer = [[uexBackgroundTimer alloc]initWithIdentifier:identifier callbackName:callbackName timeInterval:timeInterval repeatTimes:repeatTimes];
    if (!timer) {
        return NO;
    }
    [self lock];
    [self.timers addObject:timer];
    [self unlock];
    @weakify(self,timer);
    RACSignal *timerSignal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self,timer);
        __block NSInteger count = 1;
        [timer.timerSignal subscribeNext:^(id x) {
            [subscriber sendNext:@(count)];
            count++;
        } completed:^{
            [subscriber sendCompleted];
        }];
        [self.resetSignal subscribeNext:^(id x) {
            [subscriber sendCompleted];
        }];
        @weakify(self,timer);
        return [RACDisposable disposableWithBlock:^{
            @strongify(self,timer);
            [self.timers removeObject:timer];
        }];
    }];
    
    timer.disposable = [timerSignal subscribeNext:^(NSNumber *count) {
        @strongify(self,timer);
        NSString *jsStr = [NSString stringWithFormat:@"if(%@.%@){%@.%@(%@);}",kUexBackgroundCallbackPluginName,timer.callbackName,kUexBackgroundCallbackPluginName,timer.callbackName,count];
        [self evaluateScript:jsStr];
    }];
    
    
    return YES;
    
}

- (BOOL)cancelTimerWithIdentifier:(NSString *)identifier{
    if (!identifier || identifier.length == 0) {
        return NO;
    }
    uexBackgroundTimer *timer = [self.timers.rac_sequence objectPassingTest:^BOOL(uexBackgroundTimer *aTimer) {
        return [aTimer.identifier isEqual:identifier];
    }];
    if (!timer) {
        return NO;
    }
    [timer.disposable dispose];
    return YES;
}

- (void)cancelAllTimers{
    RACSequence *timerSequence= [self.timers.rac_sequence map:^id(uexBackgroundTimer *aTimer) {
        return aTimer.identifier;
    }];
    [timerSequence all:^BOOL(NSString *identifier) {
        [self cancelTimerWithIdentifier:identifier];
        return YES;
    }];
    
}

#pragma mark - Private Methods




- (BOOL)isIdentifierValid:(NSString *)identifier{
    if (!identifier ||![identifier isKindOfClass:[NSString class]] || identifier.length == 0) {
        return NO;
    }
    return [self.timers.rac_sequence all:^BOOL(uexBackgroundTimer *timer) {
        return ![identifier isEqual:timer.identifier];
    }];
}

- (BOOL)isCallbackNameValid:(NSString *)callbackName{
    if (!callbackName || ![callbackName isKindOfClass:[NSString class]] || callbackName.length == 0) {
        return NO;
    }
    if([callbackName isEqual:@"onLoad"]){
        return NO;
    }
    return [self.timers.rac_sequence all:^BOOL(uexBackgroundTimer *timer) {
        return ![callbackName isEqual:timer.callbackName];
    }];
}

- (void)lock{
    dispatch_semaphore_wait(self.arrayLock, DISPATCH_TIME_FOREVER);
}

- (void)unlock{
    dispatch_semaphore_signal(self.arrayLock);
}


#pragma mark - AppCanEngineObject Protocol

- (__kindof UIView *)webView{
    return nil;
}

- (__kindof UIScrollView *)webScrollView{
    return nil;
}

- (id<AppCanWidgetObject>)widget{
    return AppCanMainWidget();
}

- (__kindof UIViewController *)viewController{
    return nil;
}

- (NSURL *)currentURL{
    return nil;
}

- (void)evaluateScript:(NSString *)jsScript{
    dispatch_async(self.jsQueue, ^{
        [self.context evaluateScript:jsScript];
    });
    
}

- (void)callbackWithFunctionKeyPath:(NSString *)JSKeyPath arguments:(NSArray *)arguments completion:(void (^)(JSValue * ))completion{
    
    JSValue *func = [self.context ac_JSValueForKeyPath:JSKeyPath];
    [func ac_callWithArguments:arguments completionHandler:completion];
}

- (void)callbackWithFunctionKeyPath:(NSString *)JSKeyPath arguments:(NSArray *)arguments{
    [self callbackWithFunctionKeyPath:JSKeyPath arguments:arguments completion:nil];
}




@end
