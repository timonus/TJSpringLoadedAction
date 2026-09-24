//
//  UIControl+SpringLoad.h
//  Close-up
//
//  Created by Tim Johnsen on 9/4/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TJSpringLoadedAction<__covariant Type> : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithAsyncPrepareBlock:(void (^)(void (^completion)(_Nullable Type)))prepareBlock
                             performBlock:(void (^)(_Nullable Type))performBlock // This may receive nil if preparation fails
                              cancelBlock:(void (^_Nullable)(_Nullable Type))cancelBlock
                               identifier:(nullable UIActionIdentifier)identifier NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithPrepareBlock:(_Nullable Type (^)(void))prepareBlock
                        performBlock:(void (^)(_Nullable Type))performBlock // This may receive nil if preparation fails
                         cancelBlock:(void (^_Nullable)(_Nullable Type))cancelBlock
                          identifier:(nullable UIActionIdentifier)identifier;

@property (nonatomic, direct, readonly) id result;

@end

@interface UIControl (SpringLoad)

- (void)addSpringLoadedAction:(TJSpringLoadedAction *)action;
- (void)removeSpringLoadedActionWithIdentifier:(UIActionIdentifier)identifier;

@end

NS_ASSUME_NONNULL_END
