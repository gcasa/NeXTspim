
#import <appkit/ScrollView.h>
#import <appkit/Text.h>
#import <appkit/Font.h>

@interface TextView:ScrollView 
{
    id	theFont;
	id	theText;
	NXCoord height;
}

- initFrame:(const NXRect *)frameRect;
- newText:(const NXRect *)frameRect;
- idText;
- setText:(char *)txt;
- addText:(char *)txt;
- printPSCode:sender;
- setVertScroll:(float)val;
- scrollLine:(int)line;

@end


