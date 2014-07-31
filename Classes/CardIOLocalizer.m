//
//  CardIOLocalizer.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOLocalizer.h"
#import "CardIOBundle.h"

#pragma mark CardIOLocalizer

@interface CardIOLocalizer ()

@property (nonatomic, copy, readwrite)   NSString *languageOrLocale;
@property (nonatomic, strong, readwrite) NSBundle *bundle;
@property (nonatomic, strong, readwrite) NSDictionary *stringsDictionary;
@property (nonatomic, strong, readwrite) NSArray *sortedKeys;

@end

@implementation CardIOLocalizer

static CardIOLocalizer *sLocalizer = nil; // hang onto the most recently created CardIOLocalizer, since it will usually be used repeatedly
static CardIOLocalizer *sFallbackLocalizer = nil;

+ (CardIOLocalizer *)localizerForLanguageOrLocale:(NSString *)languageOrLocale forBundle:(NSBundle *)bundle {
  if (sLocalizer != nil && [sLocalizer.languageOrLocale isEqualToString:languageOrLocale] && [sLocalizer.bundle isEqual:bundle]) {
    return sLocalizer;
  }

  sLocalizer = [[CardIOLocalizer alloc] initWithLanguageOrLocale:languageOrLocale forBundle:bundle];
  return sLocalizer;
}

+ (CardIOLocalizer *)fallbackLocalizerForBundle:(NSBundle *)bundle {
  if (sFallbackLocalizer == nil) {
    sFallbackLocalizer = [[CardIOLocalizer alloc] initWithLanguageOrLocale:@"en_US" forBundle:bundle];
  }
  
  return sFallbackLocalizer;
}

- (CardIOLocalizer *)initWithLanguageOrLocale:(NSString*)languageOrLocale forBundle:(NSBundle *)bundle {
  if ((self = [self init])) {
    self.bundle = bundle;
    
    NSString* filename = nil;

    // Deal with a few special cases:
    if ([languageOrLocale caseInsensitiveCompare:@"zh_CN"] == NSOrderedSame) {
      filename = @"zh-Hans";
    }
    else if ([languageOrLocale caseInsensitiveCompare:@"zh_TW"] == NSOrderedSame) {
      filename = @"zh-Hant_TW";
    }
    else if ([languageOrLocale caseInsensitiveCompare:@"zh_HK"] == NSOrderedSame) {
      filename = @"zh-Hant";
    }
    else if ([languageOrLocale caseInsensitiveCompare:@"en_UK"] == NSOrderedSame || [languageOrLocale caseInsensitiveCompare:@"en_IE"] == NSOrderedSame) {
      filename = @"en_GB";
    }
    else if ([languageOrLocale caseInsensitiveCompare:@"no"] == NSOrderedSame) {
      filename = @"nb";
    }
    else {
      filename = languageOrLocale;
    }

    // First try for <language>_<COUNTRY>:
    NSString *path = [self.bundle pathForResource:[NSString stringWithFormat:@"strings/%@", filename] ofType:@"strings"];

    // Next, fall back to just <language>:
    if ([path length] == 0) {
      NSRange range = [languageOrLocale rangeOfString:@"_"];
      if (range.location != NSNotFound) {
        filename = [languageOrLocale substringToIndex:range.location];
        path = [self.bundle pathForResource:[NSString stringWithFormat:@"strings/%@", filename] ofType:@"strings"];
      }
    }

    // Finally, fall back to American English:
    if ([path length] == 0) {
      path = [self.bundle pathForResource:@"strings/en" ofType:@"strings"];
    }

    self.languageOrLocale = languageOrLocale;
    self.stringsDictionary = [NSDictionary dictionaryWithContentsOfFile:path];
    self.sortedKeys = [[self.stringsDictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
  }

  return self;
}

- (NSString *)localizeString:(NSString *)key adaptedForCountry:(NSString *)adaptedForCountry {
  if ([key length] == 0) {
    return @"";
  }
  
  NSString *adaptedKey = key;
  
  if ([adaptedForCountry length] == 0) {
    adaptedForCountry = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
  }
  
  if ([adaptedForCountry length] > 0) {
    // First look for a key of:
    //  <key>|<comma-separated country list that contains <adaptedForCountry>>
    // and then for a key of:
    //  <key>
    // (Note: Wallet app also checks for <key>|EU, for any European Union country,
    //        and for <key>|commercialOnly, for any country that supports only commercial accounts.
    //        We can add either or both of those here if/when we actually need them.)
    
    NSString* searchString = [NSString stringWithFormat:@"%@|", key];
    NSUInteger searchStringLength = [searchString length];
    NSRange stringRange = NSMakeRange(0, searchStringLength);
    
    // Find the first key that matches "<keyStr>|"
    NSUInteger index = [self.sortedKeys indexOfObject:searchString
                                        inSortedRange:NSMakeRange(0, [self.sortedKeys count])
                                              options:NSBinarySearchingFirstEqual
                                      usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                        return [(NSString*)obj1 compare:(NSString*)obj2
                                                                options:NSAnchoredSearch
                                                                  range:stringRange];
                                      }];
    
    if (index != NSNotFound) {
      while (index < [self.sortedKeys count]) {
        NSString* possibleKeyString = self.sortedKeys[index];
        
        // If possibleKeyString doesn't match "<keyStr>|*" (for non-empty "*"), we're done searching.
        if ([possibleKeyString length] <= searchStringLength || ![possibleKeyString hasPrefix:searchString]) {
          break;
        }
        
        NSArray* possibleCountries = [[possibleKeyString substringFromIndex:searchStringLength] componentsSeparatedByString:@","];
        
        if ([possibleCountries containsObject:adaptedForCountry]) {
          adaptedKey = possibleKeyString;
          break;
        }
        
        index++;
      }
    }
  }
  
  return [self filterOutCommonErrors:self.stringsDictionary[adaptedKey]];
}

- (NSString *)filterOutCommonErrors:(NSString *)value {
  NSString *filteredValue = value;
  
  filteredValue = [filteredValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  filteredValue = [filteredValue stringByReplacingOccurrencesOfString:@"  " withString:@" "];
  filteredValue = [filteredValue stringByReplacingOccurrencesOfString:@"..." withString:@"…"];
  
  return filteredValue;
}

#if CARDIO_DEBUG

+ (NSArray *)allLanguages {
  return @[@"ar", @"da", @"de", @"en", @"en_AU", @"en_GB", @"en_SE", @"en_DE", @"en_IL", @"en_JP", @"es", @"es_MX", @"fr", @"he", @"it", @"ja", @"ko", @"ms", @"nb", @"nl", @"pl", @"pt", @"pt_BR", @"ru", @"sv", @"th", @"tr", @"zh-Hans", @"zh-Hant", @"zh-Hant_TW"];
}

+ (NSError *)selfTestErrorWithMessage:(NSString *)errorMessage {
  NSLog(@"%@", errorMessage);
  return [NSError errorWithDomain:@"CardIOLocalizer"
                             code:-1
                         userInfo:[NSDictionary dictionaryWithObject:errorMessage
                                                              forKey:NSLocalizedDescriptionKey]];
}

+ (BOOL)passesSelfTest:(NSError **)error {
  bool errorDetected = NO;
  
  NSArray *allLanguages = [CardIOLocalizer allLanguages];

  NSDictionary *enDictionary = [NSDictionary dictionaryWithContentsOfFile:[[[CardIOBundle sharedInstance] NSBundle] pathForResource:@"strings/en" ofType:@"strings"]];
  
  // First, a few tests for the en strings (the L10n team should be applying these same tests to their files)
  
  for (NSString *key in enDictionary) {
    NSString *value = enDictionary[key];
    
    if ([value rangeOfString:@"'"].location != NSNotFound) {
      if(error) {
        *error = [self selfTestErrorWithMessage:[NSString stringWithFormat:@"\n******\nEnglish string '%@' contains a non-curly apostophe.\n******\n", key]];
      }
      errorDetected = YES;
    }
    
    if ([value rangeOfString:@"\""].location != NSNotFound) {
      if(error) {
        *error = [self selfTestErrorWithMessage:[NSString stringWithFormat:@"\n******\nEnglish string '%@' contains a non-curly double-quote.\n******\n", key]];
      }
      errorDetected = YES;
    }
    
    if ([value rangeOfString:@"..."].location != NSNotFound) {
      if(error) {
        *error = [self selfTestErrorWithMessage:[NSString stringWithFormat:@"\n******\nEnglish string '%@' contains three dots rather than an ellipsis.\n******\n", key]];
      }
      errorDetected = YES;
    }
    
    if ([value hasPrefix:@" "]) {
      if(error) {
        *error = [self selfTestErrorWithMessage:[NSString stringWithFormat:@"\n******\nEnglish string '%@' contains a leading space.\n******\n", key]];
      }
      errorDetected = YES;
    }
    
    if ([value hasSuffix:@" "]) {
      if(error) {
        *error = [self selfTestErrorWithMessage:[NSString stringWithFormat:@"\n******\nEnglish string '%@' contains a trailing space.\n******\n", key]];
      }
      errorDetected = YES;
    }
    
    NSUInteger firstPercentLocation = [CardIOLocalizer nextPercentLocationIn:value startingAtLocation:0];
    NSUInteger secondPercentLocation;
    while (firstPercentLocation != NSNotFound && firstPercentLocation < [value length] - 1) {
      secondPercentLocation = [CardIOLocalizer nextPercentLocationIn:value startingAtLocation:firstPercentLocation + 1];
      if (secondPercentLocation == NSNotFound) {
        break;
      }
      if (![CardIOLocalizer isPositionalSpecifier:value atLocation:firstPercentLocation + 1] ||
          ![CardIOLocalizer isPositionalSpecifier:value atLocation:secondPercentLocation + 1]) {
        if(error) {
          *error = [self selfTestErrorWithMessage:[NSString stringWithFormat:@"\n******\nEnglish string '%@' contains multiple substitutions, not all with positional specifiers.\n******\n", key]];
        }
        errorDetected = YES;
        break;
      }
      firstPercentLocation = secondPercentLocation;
    }
  }
  
  // Confirm that all languages are present
  
  for (NSString *lang in allLanguages) {
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:[[[CardIOBundle sharedInstance] NSBundle] pathForResource:[NSString stringWithFormat:@"strings/%@", lang] ofType:@"strings"]];
    if ([dictionary count] == 0) {
      if(error) {
        *error = [self selfTestErrorWithMessage:[NSString stringWithFormat:@"\n******\n'%@.strings' is missing.\n******\n", lang]];
      }
      errorDetected = YES;
    }
  }

  // Test a couple of strings in a few different languages

  NSDictionary *testTranslations = @{@"en_US" : @[@"camera", @"Camera"],
                                     @"es" : @[@"camera", @"Cámara"],
                                     @"zh-Hans" : @[@"camera", @"摄像头"],
                                     @"zh_HK" : @[@"camera", @"相機"],
                                     @"en_AU" : @[@"app_not_authorized_title", @"Application Not Authorised"],
                                     @"fr_FR" : @[@"app_not_authorized_title", @"Application non autorisée"],
                                     @"en_XX" : @[@"app_not_authorized_title", @"Application Not Authorized"],
                                     @"xx" : @[@"app_not_authorized_title", @"Application Not Authorized"],
                                     };

  for(NSString *lang in testTranslations) {
    NSArray *testTranslation = testTranslations[lang];
    NSString *translation = CardIOLocalizedString(testTranslation[0], lang, nil);
    if (![translation isEqualToString:testTranslation[1]]) {
      if(error) {
        *error = [self selfTestErrorWithMessage:[NSString stringWithFormat:@"\n******\nThe correct translation for '%@' in %@ is '%@'; received '%@'\n******\n", testTranslation[0], lang, testTranslation[1], translation]];
      }
      errorDetected = YES;
    }
  }

  // Confirm that each key in the "en" file is also present in each of the other expected language files, and vice-versa
  //
  // Exception: if we are between L10n cycles, then the content of en.strings might legitimately differ from all the other *.strings files.
  // To test for this exceptional case, let's assume that the difference shows up in the *number* of strings in the files.
  // I.e., all the non-en.strings files have the same number of strings, and that number differs from the count for en.strings.

  bool allOthersStringCountsMatch = YES;
  NSUInteger enStringCount = [enDictionary count];
  NSUInteger allOthersStringCount = 0;
  for (NSString *lang in allLanguages) {
    if (![lang isEqualToString:@"en"] && ![lang isEqualToString:@"en_PS"] && ![lang isEqualToString:@"en_SE"]) {
      NSDictionary *otherDictionary = [NSDictionary dictionaryWithContentsOfFile:[[[CardIOBundle sharedInstance] NSBundle] pathForResource:[NSString stringWithFormat:@"strings/%@", lang] ofType:@"strings"]];
      
      NSUInteger otherStringCount = [otherDictionary count];
      if (allOthersStringCount == 0) {
        allOthersStringCount = otherStringCount;
      }
      else {
        if (otherStringCount != allOthersStringCount) {
          allOthersStringCountsMatch = NO;
          break;
        }
      }
    }
  }
  
  if (!(allOthersStringCountsMatch && allOthersStringCount != enStringCount)) {
    for (NSString *lang in allLanguages) {
      if (![lang isEqualToString:@"en"]) {
        NSDictionary *otherDictionary = [NSDictionary dictionaryWithContentsOfFile:[[[CardIOBundle sharedInstance] NSBundle] pathForResource:[NSString stringWithFormat:@"strings/%@", lang] ofType:@"strings"]];
        
        for (NSString *key in enDictionary) {
          if ([otherDictionary[key] length] == 0) {
            if(error) {
              *error = [self selfTestErrorWithMessage:[NSString stringWithFormat:@"\n******\nMissing key '%@' for '%@'\n******\n", key, lang]];
            }
            errorDetected = YES;
          }
        }
        
        for (NSString *key in otherDictionary) {
          if ([enDictionary[key] length] == 0) {
            if(error) {
              *error = [self selfTestErrorWithMessage:[NSString stringWithFormat:@"\n******\nExtraneous key '%@' for '%@'\n******\n", key, lang]];
            }
            errorDetected = YES;
          }
        }
      }
    }
  }

  return !errorDetected;
}

+ (NSUInteger)nextPercentLocationIn:(NSString *)string startingAtLocation:(NSUInteger)startingLocation {
  NSUInteger nextPercentLocation = startingLocation - 1;
  
  do {
    nextPercentLocation = [string rangeOfString:@"%"
                                         options:0
                                           range:NSMakeRange(nextPercentLocation + 1, [string length] - (nextPercentLocation + 1))].location;
  } while (nextPercentLocation != NSNotFound &&
           nextPercentLocation > 0 &&
           nextPercentLocation < [string length] - 1 &&
           [string characterAtIndex:nextPercentLocation - 1] == '\\');
  
  return nextPercentLocation;
}

+ (BOOL)isPositionalSpecifier:(NSString *)string atLocation:(NSUInteger)location {
  BOOL isPositionalSpecifier = NO;
  
  if (location < [string length] - 1 && isdigit([string characterAtIndex:location])) {
    do {
      location++;
    } while (location < [string length] - 1 && isdigit([string characterAtIndex:location]));

    if (location < [string length] && [string characterAtIndex:location] == '$') {
      isPositionalSpecifier = YES;
    }
  }
  
  return isPositionalSpecifier;
}

#endif

#pragma mark - Text Alignment

+ (NSTextAlignment)textAlignmentForLanguageOrLocale:(NSString *)languageOrLocale {
  // If no language is specified, then start with the device's current language:
  if ([languageOrLocale length] == 0) {
    languageOrLocale = [NSLocale preferredLanguages][0];
  }

  if ([NSLocale characterDirectionForLanguage:[languageOrLocale substringToIndex:2]] == NSLocaleLanguageDirectionRightToLeft) {
    return NSTextAlignmentRight;
  }
  else {
    return NSTextAlignmentLeft;
  }
}
@end

#pragma mark - CardIOLocalizedString

NSString *CardIOLocalizedStringWithAlert(NSString *key,
                                         NSString *languageOrLocale,
                                         NSString *adaptedForCountry,
                                         NSBundle *bundle,
                                         bool showMissingKeyAlert) {
  // If no language is specified, then start with the device's current language:
  if ([languageOrLocale length] == 0) {
    languageOrLocale = [NSLocale preferredLanguages][0];
  }
  
  // Treat dialect, if present, as region (except for Chinese, where it's a bit more than just a dialect):
  // For example, "en-GB" ("British English", as of iOS 7) -> "en_GB"; and "en-GB_HK" -> "en_GB".
  if (![languageOrLocale hasPrefix:@"zh"]) {
    if ([languageOrLocale rangeOfString:@"-"].location != NSNotFound) {
      NSUInteger underscoreLocation = [languageOrLocale rangeOfString:@"_"].location;
      if (underscoreLocation != NSNotFound) {
        languageOrLocale = [languageOrLocale substringToIndex:underscoreLocation];
      }
      languageOrLocale = [languageOrLocale stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    }
  }
  
  // If no region is specified, then start with the device's current locale (if the language matches):
  if ([languageOrLocale rangeOfString:@"_"].location == NSNotFound) {
    NSString* localeIdentifier = [[NSLocale currentLocale] localeIdentifier];
    if ([localeIdentifier hasPrefix:languageOrLocale]) {
      languageOrLocale = localeIdentifier;
    }
    else {
      // For language-matching here, treat missing device dialect as wildcard; e.g, "zh" matches either "zh-Hans" or "zh-Hant":
      NSString *deviceRegion = [localeIdentifier componentsSeparatedByString:@"_"][1];
      if ([deviceRegion length]) {
        NSUInteger targetHyphenLocation = [languageOrLocale rangeOfString:@"-"].location;
        if (targetHyphenLocation != NSNotFound) {
          NSString *targetLanguage = [languageOrLocale substringToIndex:targetHyphenLocation];
          if ([localeIdentifier hasPrefix:targetLanguage]) {
            languageOrLocale = [NSString stringWithFormat:@"%@_%@", languageOrLocale, deviceRegion];
          }
          else if ([languageOrLocale caseInsensitiveCompare:@"zh-Hant"] == NSOrderedSame &&
                   ([deviceRegion isEqualToString:@"HK"] || [deviceRegion isEqualToString:@"TW"])) {
            // Very special case: target language is zh-Hant, and device region is either xx_HK or xx_TW,
            // for *any* "xx" (because device region could be en_HK or en_TW):
            languageOrLocale = [NSString stringWithFormat:@"%@_%@", languageOrLocale, deviceRegion];
          }
        }
      }
    }
  }
  
  if (bundle == nil) {
    bundle = [[CardIOBundle sharedInstance] NSBundle];
  }
  
  NSString *string = [[CardIOLocalizer localizerForLanguageOrLocale:languageOrLocale forBundle:bundle] localizeString:key adaptedForCountry:adaptedForCountry];
  if ([string length] == 0) {
    if (showMissingKeyAlert) {
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Missing Key"
                                                      message:[NSString stringWithFormat:@"No %@ string for key '%@'", languageOrLocale, key]
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
      [alert show];
    }
    string = [[CardIOLocalizer fallbackLocalizerForBundle:bundle] localizeString:key adaptedForCountry:adaptedForCountry];
  }
  return string;
}

NSString *CardIOLocalizedString(NSString *key,
                                NSString *languageOrLocale,
                                NSBundle *bundle) {
#if CARDIO_DEBUG
  return CardIOLocalizedStringWithAlert(key, languageOrLocale, nil, bundle, true);
#else
  return CardIOLocalizedStringWithAlert(key, languageOrLocale, nil, bundle, false);
#endif
}
