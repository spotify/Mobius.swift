#import "MobiusThrowableAssertion.h"

@implementation MobiusThrowableAssertion

- (instancetype)initWithMessage:(NSString *)message file:(NSString *)file line:(NSUInteger)line
{
    self = [super init];
    if (self != nil) {
        _message = message;
        _file = file;
        _line = line;
    }
    return self;
}

- (void)throw
{
    @throw(self);
}

+ (nullable MobiusThrowableAssertion *)catchInBlock:(NS_NOESCAPE void(^)(void))block
{
    @try {
        block();
    }
    @catch(MobiusThrowableAssertion *assertion) {
        return assertion;
    }
    return nil;
}

@end
