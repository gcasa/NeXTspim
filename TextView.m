/*
**  TextView.m, implementation of scrolling text stuff for TextLab.
**  Copyright 1989 NeXT, Inc.  All Rights Reserved.
**  Author: Bruce Blumberg
**
**  Heavily modified by Mark Gritter, 1993.
**
*/


#import <appkit/appkit.h>
#import "TextView.h"

@implementation TextView:ScrollView

- initFrame:(const NXRect *)frameRect
{
    NXRect rect = {0.0, 0.0, 0.0, 0.0};
	/* initialize view */
    [super initFrame:frameRect];
    
    /* specify scrollbars and style*/
    [[self setVertScrollerRequired:YES] setHorizScrollerRequired:NO];
	[self setBorderType:NX_BEZEL];

    [self getContentSize:&(rect.size)];
    theText = [self newText:&rect];
    [self setDocView:theText];
    [theText setSel:0 :0];	

	theFont = [Font newFont:"Courier" size:12];

	[theText setBackgroundGray:NX_LTGRAY]; 
	[theText setFont:theFont];
	
  	height = [theText lineHeight];
	[self setLineScroll:height];
	[self setPageScroll:height];
	// The following two lines allow the resizing of the scrollview
    // to be passed down to the docView (in this case, the text view 
    // itself).

    [contentView setAutoresizeSubviews:YES];
    [contentView setAutosizing:NX_HEIGHTSIZABLE | NX_WIDTHSIZABLE];
	
	return self;
}

- newText:(const NXRect *)frameRect
{
    id	text;
    NXSize aSize = {1.0E38, 1.0E38};
    
    text = [[Text alloc] initFrame:frameRect
    			 text:NULL
			 alignment:NX_LEFTALIGNED];
    [text setOpaque:YES];
    [[[[[text notifyAncestorWhenFrameChanged:YES]
				setVertResizable:YES]
				    setHorizResizable:NO]
					setMonoFont:YES]
					    setDelegate:self];
    
    [text setMinSize:&(frameRect->size)];
    [text setMaxSize:&aSize];
    [text setAutosizing:NX_HEIGHTSIZABLE | NX_WIDTHSIZABLE];
    
    [text setCharFilter:NXEditorFilter];
    return text;
}

- idText
{
	return theText;
}

- setText:(char *)txt
{
	[[theText setText:txt] sizeToFit];
	return theText;
}

- addText:(char *)txt
{
	int l = [theText textLength];
	[[[theText setSel:l:l] replaceSel:txt] sizeToFit];
	[vScroller setFloatValue:1.0];
	[self perform:[vScroller action] with:vScroller];
	return theText;
}

- printPSCode:sender
{
	id smallerFont;
	smallerFont = [Font newFont:"Courier" size:8];
	[[theText setBackgroundGray:NX_WHITE] setFont:smallerFont];
	[theText printPSCode:sender];
	[[theText setFont:theFont] setBackgroundGray:NX_LTGRAY];
	[smallerFont free];
	[self update];
	return self;	
}

- setVertScroll:(float)val
{
	[vScroller setFloatValue:val];
	[self perform:[vScroller action] with:vScroller];
	return vScroller;
}

- scrollLine:(int)line
{
	NXPoint coord;
	NXRect rect;
	[contentView getDocVisibleRect:&rect];
	coord.x = rect.origin.x;
	coord.y = height * (line - 1);
	[contentView rawScroll:&coord];
	[self reflectScroll:contentView];
	return self;
}

@end
