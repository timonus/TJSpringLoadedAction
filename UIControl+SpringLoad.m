//
//  UIControl+SpringLoad.m
//  Close-up
//
//  Created by Tim Johnsen on 9/4/26.
//

#import "UIControl+SpringLoad.h"
#import <os/lock.h>

#define LOG_DIAGNOSTICS DEBUG

typedef NS_CLOSED_ENUM(NSUInteger, TJSpringLoadedActionState) {
    TJSpringLoadedActionStateNone,
    TJSpringLoadedActionStatePreparing,
    TJSpringLoadedActionStatePrepared,
};

@interface TJSpringLoadedAction ()

@property (nonatomic, direct) void (^prepareBlock)(void (^completion)(id));
@property (nonatomic, direct) void (^performBlock)(id);
@property (nonatomic, direct) void (^cancelBlock)(id);
@property (nonatomic, direct) UIActionIdentifier identifier;

@property (nonatomic, direct) TJSpringLoadedActionState state;
@property (nonatomic, direct, readwrite) id result;

@property (nonatomic, direct) BOOL needsPerformAction;

@end

@implementation TJSpringLoadedAction

- (instancetype)initWithAsyncPrepareBlock:(void (^)(void (^completion)(id)))prepareBlock
                             performBlock:(void (^)(_Nonnull id))performBlock
                              cancelBlock:(void (^)(_Nullable id))cancelBlock
                               identifier:(UIActionIdentifier)identifier
{
    if (self = [super init]) {
        self.prepareBlock = prepareBlock;
        self.performBlock = performBlock;
        self.cancelBlock = cancelBlock;
        self.identifier = identifier ? identifier : [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (instancetype)initWithPrepareBlock:(id  _Nullable (^)(void))prepareBlock
                        performBlock:(void (^)(id _Nullable))performBlock
                         cancelBlock:(void (^)(id _Nullable))cancelBlock
                          identifier:(UIActionIdentifier)identifier
{
    return [self initWithAsyncPrepareBlock:^(void (^ _Nonnull completion)(id _Nullable)) {
        dispatch_async(dispatch_get_main_queue(), ^{ // We perform main queue-bound prep async so touch down highlight isn't blocked
            completion(prepareBlock());
        });
    }
                         performBlock:performBlock
                          cancelBlock:cancelBlock
                           identifier:identifier];
}

- (void)setState:(TJSpringLoadedActionState)state
{
    if (state != _state) {
        _state = state;
        switch (state) {
            case TJSpringLoadedActionStateNone: {
                dispatch_async(dispatch_get_main_queue(), ^{ // We do this async just in case a context menu preview wants to grab the result.
                    if (self.cancelBlock) {
                        self.cancelBlock(self.result);
                    }
                    self.result = nil;
                });
            }
                break;
            case TJSpringLoadedActionStatePreparing: {
#if LOG_DIAGNOSTICS
                CFTimeInterval s = CACurrentMediaTime();
#endif
                self.prepareBlock(^(id result) {
#if LOG_DIAGNOSTICS
                    NSLog(@"Prepared %@: %f", self.identifier, CACurrentMediaTime() - s);
#endif
                    if (self.state == TJSpringLoadedActionStatePreparing) {
                        self.result = result;
                        self.state = TJSpringLoadedActionStatePrepared; // needsPerformAction will be handled by setting this
                    }
                });
            }
                break;
            case TJSpringLoadedActionStatePrepared: {
                if (self.needsPerformAction) {
                    [self consumePreparedResult];
                }
            }
                break;
        }
    }
}

- (void)consumePreparedResult
{
    self.performBlock(self.result);
    self.result = nil;
    _state = TJSpringLoadedActionStateNone; // Set without cancellation side effects
    self.needsPerformAction = NO;
}

@end

@implementation UIControl (SpringLoad)

- (void)addSpringLoadedAction:(TJSpringLoadedAction *)action
{
#if LOG_DIAGNOSTICS
    __block CFTimeInterval s;
#endif
    [self addAction:[UIAction actionWithTitle:@"" image:nil identifier:[action.identifier stringByAppendingFormat:@" %@", @(UIControlEventTouchDown)] handler:^(__kindof UIAction * _Nonnull a) {
#if LOG_DIAGNOSTICS
        s = CACurrentMediaTime();
#endif
        action.state = TJSpringLoadedActionStatePreparing;
    }] forControlEvents:UIControlEventTouchDown];
    
    [self addAction:[UIAction actionWithTitle:@"" image:nil identifier:[action.identifier stringByAppendingFormat:@" %@", @(UIControlEventTouchUpInside)] handler:^(__kindof UIAction * _Nonnull a) {
#if LOG_DIAGNOSTICS
        NSLog(@"Touch Down-to-Touch Up Time: %f", CACurrentMediaTime() - s);
#endif
        switch (action.state) {
            case TJSpringLoadedActionStateNone: {
#if LOG_DIAGNOSTICS
                NSLog(@"Touch Up: Unprepared");
#endif
                action.needsPerformAction = YES;
                action.state = TJSpringLoadedActionStatePreparing;
            }
                break;
            case TJSpringLoadedActionStatePreparing: {
#if LOG_DIAGNOSTICS
                NSLog(@"Touch Up: Preparing");
#endif
                action.needsPerformAction = YES;
            }
                break;
            case TJSpringLoadedActionStatePrepared:
#if LOG_DIAGNOSTICS
                NSLog(@"Touch Up: Prepared");
#endif
                [action consumePreparedResult];
                break;
        }
    }] forControlEvents:UIControlEventTouchUpInside];
    
    [self addAction:[UIAction actionWithTitle:@"" image:nil identifier:[action.identifier stringByAppendingFormat:@" %@", @(UIControlEventTouchCancel | UIControlEventTouchUpOutside)] handler:^(__kindof UIAction * _Nonnull a) {
        action.state = TJSpringLoadedActionStateNone;
    }] forControlEvents:UIControlEventTouchCancel | UIControlEventTouchUpOutside];
}

- (void)removeSpringLoadedActionWithIdentifier:(UIActionIdentifier)identifier
{
    [self removeActionForIdentifier:[identifier stringByAppendingFormat:@" %@", @(UIControlEventTouchDown)] forControlEvents:UIControlEventTouchDown];
    [self removeActionForIdentifier:[identifier stringByAppendingFormat:@" %@", @(UIControlEventTouchUpInside)] forControlEvents:UIControlEventTouchUpInside];
    [self removeActionForIdentifier:[identifier stringByAppendingFormat:@" %@", @(UIControlEventTouchCancel | UIControlEventTouchUpOutside)] forControlEvents:UIControlEventTouchCancel | UIControlEventTouchUpOutside];
}

@end
