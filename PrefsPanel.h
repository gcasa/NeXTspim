#import <AppKit/AppKit.h>

@interface PrefsPanel : NSPanel
{
}

+ initialize;
- loadPrefs;
- savePrefs:sender;
- switch:sender;

@end
