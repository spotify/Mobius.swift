#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Class that wraps the Objective-C exception handling system for use by Swift tests.

 @c throw() raises an exception that will be cought by an enclosing @c MobiusThrowableAssertion.catch(in:) invocation.
 If an exception is uncaught, the process will crash.

 @note Since Swift doesn’t have a concept of exception unwinding, this will generally result in memory leaks.
 */
@interface MobiusThrowableAssertion : NSObject

@property (nonatomic, readonly, strong) NSString *message;
@property (nonatomic, readonly, strong) NSString *file;
@property (nonatomic, readonly) NSUInteger line;

- (instancetype)initWithMessage:(NSString *)message file:(NSString *)file line:(NSUInteger)line;

- (void)throw OS_NORETURN;

+ (nullable MobiusThrowableAssertion *)catchInBlock:(NS_NOESCAPE void(^)(void))block
NS_SWIFT_NAME(catch(in:));

@end

NS_ASSUME_NONNULL_END
