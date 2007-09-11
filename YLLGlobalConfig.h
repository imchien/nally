//
//  YLLGlobalConfig.h
//  MacBlueTelnet
//
//  Created by Yung-Luen Lan on 2006/11/12.
//  Copyright 2006 Yllan.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#define NUM_COLOR 10

@interface YLLGlobalConfig : NSObject {
@public
	int _row;
	int _column;
	
	int _cellWidth;
	int _cellHeight;
	
	NSFont *_eFont;
	NSFont *_cFont;
	
	NSColor *_colorTable[2][NUM_COLOR];
	NSDictionary *_cDictTable[2][NUM_COLOR];
	NSDictionary *_eDictTable[2][NUM_COLOR];
}

+ (YLLGlobalConfig *) sharedInstance;

- (int)row;
- (void)setRow:(int)value;

- (int)column;
- (void)setColumn:(int)value;

- (int)cellWidth;
- (void)setCellWidth:(int)value;

- (int)cellHeight;
- (void)setCellHeight:(int)value;

- (NSFont *)eFont;
- (void)setEFont:(NSFont *)value;

- (NSFont *)cFont;
- (void)setCFont:(NSFont *)value;

- (NSColor *) colorAtIndex: (int) i hilite: (BOOL) h ;
- (void) setColor: (NSColor *) c hilite: (BOOL) h atIndex: (int) i ;


- (NSDictionary *) cFontAttributeForColorIndex: (int) i hilite: (BOOL) h ;
- (NSDictionary *) eFontAttributeForColorIndex: (int) i hilite: (BOOL) h ;

@end
