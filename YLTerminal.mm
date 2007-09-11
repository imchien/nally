//
//  YLTerminal.m
//  MacBlueTelnet
//
//  Created by Yung-Luen Lan on 2006/9/10.
//  Copyright 2006 yllan. All rights reserved.
//

#import "YLTerminal.h"
#import "YLLGlobalConfig.h"
#import "encoding.h"

#define GRID(x, y) _grid[((_offset + (y)) % _row) * _column + (x)]
#define CURSOR_MOVETO(x, y)		do {\
									_cursorX = (x); _cursorY = (y); \
									if (_cursorX < 0) _cursorX = 0; if (_cursorX >= _column) _cursorX = _column - 1;\
									if (_cursorY < 0) _cursorY = 0; if (_cursorY >= _row) _cursorY = _row - 1;\
								} while(0);

BOOL isC0Control(unsigned char c) { return (c <= 0x1F); }
BOOL isSPACE(unsigned char c) { return (c == 0x20 || c == 0xA0); }
BOOL isIntermediate(unsigned char c) { return (c >= 0x20 && c <= 0x2F); }
BOOL isParameter(unsigned char c) { return (c >= 0x30 && c <= 0x3F); }
BOOL isUppercase(unsigned char c) { return (c >= 0x40 && c <= 0x5F); }
BOOL isLowercase(unsigned char c) { return (c >= 0x60 && c <= 0x7E); }
BOOL isDelete(unsigned char c) { return (c == 0x7F); }
BOOL isC1Control(unsigned char c) { return(c >= 0x80 && c <= 0x9F); }
BOOL isG1Displayable(unsigned char c) { return(c >= 0xA1 && c <= 0xFE); }
BOOL isSpecial(unsigned char c) { return(c == 0xA0 || c == 0xFF); }
BOOL isAlphabetic(unsigned char c) { return(c >= 0x40 && c <= 0x7E); }

ASCII_CODE asciiCodeFamily(unsigned char c) {
	if (isC0Control(c)) return C0;
	if (isIntermediate(c)) return INTERMEDIATE;
	if (isAlphabetic(c)) return ALPHABETIC;
	if (isDelete(c)) return DELETE;
	if (isC1Control(c)) return C1;
	if (isG1Displayable(c)) return G1;
	if (isSpecial(c)) return SPECIAL;
	return ERROR;
}

static SEL normal_table[256];

@implementation YLTerminal

+ (void) initialize {
	int i;
	/* C0 control character */
	for (i = 0x00; i <= 0x1F; i++)
		normal_table[i] = NULL;
	normal_table[0x07] = @selector(beep);
	normal_table[0x08] = @selector(backspace);
	normal_table[0x0A] = @selector(lf);
	normal_table[0x0D] = @selector(cr);
	normal_table[0x1B] = @selector(beginESC);
	
	/* C1 control character */
	for (i = 0x80; i <=0x9F; i++)
		normal_table[i] = NULL;
	normal_table[0x85] = @selector(newline);
	normal_table[0x9B] = @selector(beginControl);
	
}

- (id) init {
	if (self = [super init]) {
		_row = [[YLLGlobalConfig sharedInstance] row];
		_column = [[YLLGlobalConfig sharedInstance] column];
		_cursorX = 0;
		_cursorY = 0;
		_grid = (cell *) malloc(sizeof(cell) * (_row * _column));
		int i;
		for (i = 0; i < (_row * _column); i++) {
			_grid[i].fgColor = 7;
			_grid[i].bgColor = 9;
			_grid[i].byte = 0;
			_grid[i].bold = 0;
			_grid[i].underline = 0;
			_grid[i].blink = 0;
			_grid[i].reverse = 0;
		}
		_csBuf = new std::deque<unsigned char>();
		_csArg = new std::deque<int>();
		_fgColor = 7;
		_bgColor = 9;
		_state = TP_NORMAL;
	}
	return self;
}

- (void) dealloc {
	delete _csBuf;
	delete _csArg;
	free(_grid);
	[super dealloc];
}

# pragma mark -
# pragma mark Cursor Movement


# pragma mark -
# pragma mark Input Interface
- (void) feedData: (NSData *) data {
	[self feedBytes: (const unsigned char *)[data bytes] length: [data length]];
}

- (void) feedBytes: (const unsigned char *) bytes length: (int) len {
	int i, x;
//	NSLog(@"feed %d", len);
	unsigned char c;
	for (i = 0; i < len; i++) {
		c = bytes[i];
		if (_state == TP_NORMAL) {
			if (c == 0x07) { // Beep
				NSBeep();
			} else if (c == 0x08) { // Backspace
				if (_cursorX > 0)
					_cursorX--;
			} else if (c == 0x0A) { // Linefeed 
				if (_cursorY == _row - 1) {
					_offset = (_offset + 1) % _row;
					for (x = 0; x < _column; x++) GRID(x, _cursorY).byte = '\0';
				} else {
					_cursorY++;
				}
			} else if (c == 0x0D) { // Carriage Return
				_cursorX = 0;
			} else if (c == 0x1B) { // ESC
				_state = TP_ESCAPE;
			} else if (c == 0x9B) { // Control Sequence Introducer
				_csBuf->clear();
				_csArg->clear();
				_csTemp = 0;
				_state = TP_CONTROL;
			} else {
//				NSLog(@"insert %d @ %d %d", c, _cursorX, _cursorY);
				GRID(_cursorX, _cursorY).byte = c;
				GRID(_cursorX, _cursorY).fgColor = _fgColor;
				GRID(_cursorX, _cursorY).bgColor = _bgColor;
				GRID(_cursorX, _cursorY).bold = _bold;
				GRID(_cursorX, _cursorY).underline = _underline;
				GRID(_cursorX, _cursorY).blink = _blink;
				GRID(_cursorX, _cursorY).reverse = _reverse;
				_cursorX++;
			}
		} else if (_state == TP_ESCAPE) {
			if (c == 0x5B) { // 0x5B == '['
				_csBuf->clear();
				_csArg->clear();
				_csTemp = 0;
				_state = TP_CONTROL;
			} else {
				_state = TP_NORMAL;
			}
		} else if (_state == TP_CONTROL) {
			if (isParameter(c)) {
				_csBuf->push_back(c);
				if (c >= '0' && c <= '9') {
					_csTemp = _csTemp * 10 + (c - '0');
				} else if (!_csBuf->empty()) {
					_csArg->push_back(_csTemp);
					_csTemp = 0;
					_csBuf->clear();
				}
			} else {
				if (!_csBuf->empty()) {
					_csArg->push_back(_csTemp);
					_csTemp = 0;
					_csBuf->clear();
				}
				
				if (NO) {
					// just for code alignment...
				} else if (c == 'A') {		// Cursor Up
					if (_csArg->size() > 0)
						_cursorY -= _csArg->front();
					else
						_cursorY--;
					
					if (_cursorY < 0) _cursorY = 0;
				} else if (c == 'B') {		// Cursor Down
					if (_csArg->size() > 0)
						_cursorY += _csArg->front();
					else
						_cursorY++;
					
					if (_cursorY >= _row) _cursorY = _row - 1;
				} else if (c == 'C') {		// Cursor Right
					if (_csArg->size() > 0)
						_cursorX += _csArg->front();
					else
						_cursorX++;
					
					if (_cursorX >= _column) _cursorX = _column - 1;					
				} else if (c == 'D') {		// Cursor Left
					if (_csArg->size() > 0)
						_cursorX -= _csArg->front();
					else
						_cursorX--;
					
					if (_cursorX < 0) _cursorX = 0;
				} else if (c == 'f' || c == 'H') {	// Cursor Position
					/* 
						^[H			: go to row 1, column 1
						^[3H		: go to row 3, column 1
						^[3;4H		: go to row 3, column 4
					 */
					if (_csArg->size() == 0) {
						_cursorX = 0, _cursorY = 0;
					} else if (_csArg->size() == 1) {
						CURSOR_MOVETO(0, _csArg->front() - 1);
					} else {
						CURSOR_MOVETO((*_csArg)[1] - 1, (*_csArg)[0] - 1);
					}
				} else if (c == 'J') {		// Erase Region (cursor does not move)
					/* 
						^[J, ^[0J	: clear from cursor position to end
						^[1J		: clear from start to cursor position
						^[2J		: clear all
					 */
					int start = 0, end = _row * _column - 1;
					if (_csArg->size() == 0 || _csArg->front() == 0) 
						start = _cursorX + (_cursorY * _column);
					if (_csArg->size() == 1 && _csArg->front() == 1) 
						end = _cursorX + (_cursorY * _column);

					int idx;
					for (idx = start; idx <= end; idx++) {
						int memIdx = (idx + _offset * _column) % (_row * _column);
						_grid[memIdx].byte = '\0';
						_grid[memIdx].bgColor = 9;
					}
				} else if (c == 'K') {		// Erase Line (cursor does not move)
					/* 
						^[K, ^[0K	: clear from cursor position to end of line
						^[1K		: clear from start of line to cursor position
						^[2K		: clear whole line
					 */
					int start = 0, end = _column - 1;
					if (_csArg->size() == 0 || _csArg->front() == 0) 
						start = _cursorX;
					if (_csArg->size() == 1 && _csArg->front() == 1) 
						end = _cursorX;
					int idx;
					for (idx = start; idx <= end; idx++) {
						GRID(idx, _cursorY).byte = '\0';
						GRID(idx, _cursorY).bgColor = 9;
					}
				} else if (c == 'L') {
				} else if (c == 'M') {
				} else if (c == 'm') {
					if (_csArg->empty()) { // clear
						_fgColor = 7;
						_bgColor = 9;
						_bold = NO;
						_underline = NO;
						_blink = NO;
						_reverse = NO;
					} else {
						while (!_csArg->empty()) {
							int p = _csArg->front();
							_csArg->pop_front();
							if (p  == 0) {
								_fgColor = 9;
								_bgColor = 9;
								_bold = NO;
								_underline = NO;
								_blink = NO;
								_reverse = NO;
							} else if (30 <= p && p <= 39) {
								_fgColor = p - 30;
							} else if (40 <= p && p <= 49) {
								_bgColor = p - 40;
							} else if (p == 1) {
								_bold = YES;
							} else if (p == 4) {
								_underline = YES;
							} else if (p == 5) {
								_blink = YES;
							} else if (p == 7) {
								_reverse = YES;
							}
						}
					}
				} else if (c == 's') {
					
				} else if (c == 'u') {
					
				}
				_csArg->clear();
				_state = TP_NORMAL;
			}
		}
	}
	[_delegate setNeedsDisplay: YES];
}

# pragma mark -
# pragma mark 

- (BOOL) isDirtyAtRow: (int) r column:(int) c {
	return YES;
}

- (NSColor *) fgColorAtRow: (int) r column: (int) c {
	return [[YLLGlobalConfig sharedInstance] colorAtIndex: GRID(c, r).fgColor hilite: GRID(c, r).bold];
}

- (NSColor *) bgColorAtRow: (int) r column: (int) c {
	return [[YLLGlobalConfig sharedInstance] colorAtIndex: GRID(c, r).bgColor hilite: NO];	
}

- (BOOL) boldAtRow:(int) r column:(int) c {
	return GRID(c, r).bold;
}

- (int) fgColorIndexAtRow: (int) r column: (int) c {
	return GRID(c, r).fgColor;
}

- (int) bgColorIndexAtRow: (int) r column: (int) c {
	return GRID(c, r).bgColor;	
}


- (unichar) charAtRow: (int) r column: (int) c {
	int db = [self isDoubleByteAtRow: r column: c];
	if (db == 0) {
		unichar b = GRID(c, r).byte;
			return b;
	}
	if (db == 1) {
		int index = ((int)GRID(c, r).byte << 8) + GRID(c+1, r).byte - 0x8000;
		return B2U[index];
	}
	return 0;
}

- (int) isDoubleByteAtRow: (int) r column:(int) c {
	int i;
	int db = 0;
	if (c == _column - 1) return 0;
	for (i = 0; i <= c; i++) {
		unsigned char c = GRID(i, r).byte;
		if (db == 0 || db == 2) {
			if (c > 0x7F) db = 1;
			else db = 0;
		} else if (db == 1) {
			db = 2;
		} 
	}
	return db;
}


- (void) setDelegate: (id) d {
	_delegate = d; // Yes, this is delegation. We shouldn't own the delegation object.
}

- (id) delegate {
	return _delegate;
}

@end
