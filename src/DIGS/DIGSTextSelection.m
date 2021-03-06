/*
 * DIGSTextSelection.m
 *
 * Created by Andy Lee on Mon Jun 23 2003.
 * Copyright (c) 2003, 2004 Andy Lee. All rights reserved.
 */

#import "DIGSTextSelection.h"

#pragma mark -
#pragma mark Private constants

static NSString *_DIGS_VISIBLE_RECT_PREF_KEY         = @"VisibleRect";
static NSString *_DIGS_VISIBLE_CHARS_RANGE_PREF_KEY  = @"VisibleCharsRange";
static NSString *_DIGS_SELECTED_CHARS_RANGE_PREF_KEY = @"SelectedCharsRange";

@implementation DIGSTextSelection

@synthesize visibleRect = _visibleRect;
@synthesize visibleCharsRange = _visibleCharsRange;
@synthesize selectedCharsRange = _selectedCharsRange;
@synthesize typingAttributes = _typingAttributes;

#pragma mark -
#pragma mark Init/awake/dealloc

- (id)init
{
    if ((self = [super init]))
    {
        _visibleRect = NSZeroRect;
        _visibleCharsRange = NSMakeRange(0, 0);
        _selectedCharsRange = NSMakeRange(0, 0);
        _typingAttributes = nil;
    }

    return self;
}

- (void)dealloc
{
    [_typingAttributes release];

    [super dealloc];
}

#pragma mark -
#pragma mark Interacting with text views

- (void)takeSelectionFromTextView:(NSTextView *)textView
{
    if (textView == nil)
    {
        return;
    }

    // Remember the scroll position, both as a rect and as a character range.
    NSTextContainer *textContainer = [textView textContainer];
    NSLayoutManager *layoutManager = [textContainer layoutManager];
    NSRange glyphRange = [layoutManager glyphRangeForBoundingRect:_visibleRect
                                                  inTextContainer:textContainer];
    _visibleRect = [textView visibleRect];
    _visibleCharsRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                   actualGlyphRange:nil];

    // Remember the selection range.
    _selectedCharsRange = [textView selectedRange];

    // Remember the text view's typing attributes.
    [self setTypingAttributes:[textView typingAttributes]];
}

- (void)applySelectionToTextView:(NSTextView *)textView
{
    if (textView == nil)
    {
        return;
    }

    // Apply the remembered scroll position.  If the text view's dimensions are
    // the same as when we took the snapshot, we can reset the scroll position
    // with pixel-accuracy.  Otherwise, we settle for accuracy to within about a
    // character.
    if (NSEqualSizes(_visibleRect.size, [textView visibleRect].size))
    {
        [textView scrollRangeToVisible:_visibleCharsRange];
        [textView scrollRectToVisible:_visibleRect];
    }
    else
    {
        [textView scrollRangeToVisible:_visibleCharsRange];
    }

    // Apply the remembered selection range.
    [textView setSelectedRange:_selectedCharsRange];

    // Apply the remembered typing attributes.
    [textView setTypingAttributes:_typingAttributes];
}

#pragma mark -
#pragma mark AKPrefDictionary methods

+ (instancetype)fromPrefDictionary:(NSDictionary *)prefDict
{
    if (prefDict == nil)
    {
        return nil;
    }

    DIGSTextSelection *selectionState = [[[self alloc] init] autorelease];
    NSString *visibleRectString = [prefDict objectForKey:_DIGS_VISIBLE_RECT_PREF_KEY];
    NSString *visibleRangeString = [prefDict objectForKey:_DIGS_VISIBLE_CHARS_RANGE_PREF_KEY];
    NSString *selectedRangeString = [prefDict objectForKey:_DIGS_SELECTED_CHARS_RANGE_PREF_KEY];

    if (visibleRectString)
    {
        [selectionState setVisibleRect:NSRectFromString(visibleRectString)];
    }

    if (visibleRangeString)
    {
        [selectionState setVisibleCharsRange:NSRangeFromString(visibleRangeString)];
    }

    if (selectedRangeString)
    {
        [selectionState setSelectedCharsRange:NSRangeFromString(selectedRangeString)];
    }

    return selectionState;
}

- (NSDictionary *)asPrefDictionary
{
    NSMutableDictionary *prefDict = [NSMutableDictionary dictionary];

    [prefDict setObject:NSStringFromRect(_visibleRect)
                 forKey:_DIGS_VISIBLE_RECT_PREF_KEY];
    [prefDict setObject:NSStringFromRange(_visibleCharsRange)
                 forKey:_DIGS_VISIBLE_CHARS_RANGE_PREF_KEY];
    [prefDict setObject:NSStringFromRange(_selectedCharsRange)
                 forKey:_DIGS_SELECTED_CHARS_RANGE_PREF_KEY];

    return prefDict;
}

#pragma mark -
#pragma mark NSCoding methods

- (id)initWithCoder:(NSCoder *)decoder
{
    [decoder decodeValueOfObjCType:@encode(NSRect) at:&_visibleRect];
    [decoder decodeValueOfObjCType:@encode(NSRange) at:&_visibleCharsRange];
    [decoder decodeValueOfObjCType:@encode(NSRange) at:&_selectedCharsRange];

    _typingAttributes = [decoder decodeObject];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeValueOfObjCType:@encode(NSRect) at:&_visibleRect];
    [encoder encodeValueOfObjCType:@encode(NSRange) at:&_visibleCharsRange];
    [encoder encodeValueOfObjCType:@encode(NSRange) at:&_selectedCharsRange];

    [encoder encodeObject:_typingAttributes];
}

@end
