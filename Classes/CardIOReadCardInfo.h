//
//  CardIOReadCardInfo.h
//  See the file "LICENSE.md" for the full license governing this code.
//

// A wrapper used for parsing the server's response,
// and containing the card info that the server read.

#import <Foundation/Foundation.h>


@interface CardIOReadCardInfo : NSObject

+ (CardIOReadCardInfo *)cardInfoWithNumber:(NSString *)cardNumber xOffsets:(NSArray *)xOffsets yOffset:(NSUInteger)yOffset;

@property(nonatomic, strong, readonly) NSString *numbers;
@property(nonatomic, strong, readonly) NSArray *xOffsets;
@property(nonatomic, assign, readonly) NSUInteger yOffset;
@property(nonatomic, assign, readonly) NSUInteger expiryYear;
@property(nonatomic, assign, readonly) NSUInteger expiryMonth;
@property(nonatomic, assign, readonly) BOOL isFlipped;

@end
