/*
 * AKTopicBrowserViewController.m
 *
 * Created by Andy Lee on Tue Jul 30 2002.
 * Copyright (c) 2003, 2004 Andy Lee. All rights reserved.
 */

#import "AKTopicBrowserViewController.h"

#import "DIGSLog.h"

#import "AKBrowser.h"
#import "AKClassNode.h"
#import "AKClassTopic.h"
#import "AKDatabase.h"
#import "AKDocLocator.h"
#import "AKFrameworkTopic.h"
#import "AKLabelTopic.h"
#import "AKPrefUtils.h"
#import "AKProtocolNode.h"
#import "AKSortUtils.h"
#import "AKSubtopicListViewController.h"
#import "AKTopic.h"
#import "AKWindowController.h"
#import "AKWindowLayout.h"

@implementation AKTopicBrowserViewController

@synthesize topicBrowser = _topicBrowser;

static const NSInteger AKMinBrowserColumns = 2;

#pragma mark -
#pragma mark Init/dealloc/awake

- (id)initWithNibName:nibName windowController:(AKWindowController *)windowController
{
    self = [super initWithNibName:@"TopicBrowserView" windowController:windowController];
    if (self)
    {
        _topicListsForBrowserColumns = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)dealloc
{
    [_topicListsForBrowserColumns release];

    [super dealloc];
}

- (void)awakeFromNib
{
    [_topicBrowser setPathSeparator:AKTopicBrowserPathSeparator];
    [_topicBrowser setReusesColumns:NO];
    [_topicBrowser loadColumnZero];
    [_topicBrowser selectRow:1 inColumn:0];  // selects "NSObject"
}

#pragma mark -
#pragma mark Action methods

- (IBAction)addBrowserColumn:(id)sender
{
    NSInteger numColumns = [_topicBrowser maxVisibleColumns];

    [_topicBrowser setMaxVisibleColumns:(numColumns + 1)];
}

- (IBAction)removeBrowserColumn:(id)sender
{
    NSInteger numColumns = [_topicBrowser maxVisibleColumns];

    if (numColumns > AKMinBrowserColumns)
    {
        [_topicBrowser setMaxVisibleColumns:(numColumns - 1)];
    }
}

- (IBAction)doBrowserAction:(id)sender
{
    [[self owningWindowController] selectTopic:[[_topicBrowser selectedCell] representedObject]];
}

#pragma mark -
#pragma mark AKViewController methods

- (void)goFromDocLocator:(AKDocLocator *)whereFrom toDocLocator:(AKDocLocator *)whereTo
{
    // Handle cases where there's nothing to do.
    if ([whereFrom isEqual:whereTo])
    {
        return;
    }

    if (whereTo == nil)
    {
        DIGSLogInfo(@"can't navigate to a nil locator");
        return;
    }

    if ([whereTo topicToDisplay] == nil)
    {
        DIGSLogInfo(@"can't navigate to a nil topic");
        return;
    }

    // Is the topic changing?  (The "!=" check handles nil cases.)
    AKTopic *currentTopic = [whereFrom topicToDisplay];
    AKTopic *newTopic = [whereTo topicToDisplay];
    if ((currentTopic != newTopic) && ![currentTopic isEqual:newTopic])
    {
        NSString *newBrowserPath = [newTopic pathInTopicBrowser];
        if (newBrowserPath == nil)
        {
            DIGSLogInfo(@"couldn't compute new browser path");
            return;
        }

        // Update the topic browser.
        if (![_topicBrowser setPath:newBrowserPath])
        {
            DIGSLogError_ExitingMethodPrematurely(([NSString stringWithFormat:
                                                    @"can't navigate to browser path [%@]",
                                                    newBrowserPath]));
            return;
        }

        // Workaround for -setPath: annoyance: make the browser
        // columns as right-justified as possible.
        [[_topicBrowser window] disableFlushWindow];
        [_topicBrowser scrollColumnToVisible:0];
        [_topicBrowser scrollColumnToVisible:[_topicBrowser lastColumn]];
        [[_topicBrowser window] enableFlushWindow];
    }
}

#pragma mark -
#pragma mark AKUIController methods

- (void)applyUserPreferences
{
    // You'd think since NSBrowser is an NSControl, you could send it setFont:
    // directly, but no.
    NSString *fontName = [AKPrefUtils stringValueForPref:AKListFontNamePrefName];
    NSInteger fontSize = [AKPrefUtils intValueForPref:AKListFontSizePrefName];
    NSFont *font = [NSFont fontWithName:fontName size:fontSize];

    [[_topicBrowser cellPrototype] setFont:font];

    // Make the browser redraw to reflect its new display attributes.
    NSString *savedPath = [_topicBrowser path];

    [_topicBrowser loadColumnZero];
    [_topicBrowser setPath:savedPath];
}

- (void)takeWindowLayoutFrom:(AKWindowLayout *)windowLayout
{
    if (windowLayout == nil)
    {
        return;
    }

    // Restore the number of browser columns.
    if ([windowLayout numberOfBrowserColumns])
    {
        [_topicBrowser setMaxVisibleColumns:[windowLayout numberOfBrowserColumns]];
    }
    else
    {
        [_topicBrowser setMaxVisibleColumns:3];
    }
}

- (void)putWindowLayoutInto:(AKWindowLayout *)windowLayout
{
    if (windowLayout == nil)
    {
        return;
    }

    [windowLayout setNumberOfBrowserColumns:[_topicBrowser maxVisibleColumns]];
}

#pragma mark -
#pragma mark NSUserInterfaceValidations methods

- (BOOL)validateUserInterfaceItem:(id)anItem
{
    SEL itemAction = [anItem action];

    if (itemAction == @selector(addBrowserColumn:))
    {
        return ([[self view] frame].size.height > 0.0);
    }
    else if (itemAction == @selector(removeBrowserColumn:))
    {
        return (([[self view] frame].size.height > 0.0)
                && ([_topicBrowser maxVisibleColumns] > AKMinBrowserColumns));
    }
    else
    {
        return NO;
    }
}

#pragma mark -
#pragma mark NSBrowser delegate methods

- (void)browser:(NSBrowser *)sender createRowsForColumn:(NSInteger)column inMatrix:(NSMatrix *)matrix
{
    [matrix renewRows:[self _numberOfRowsInColumn:column] columns:1];
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column
{
    NSArray *topicList = [_topicListsForBrowserColumns objectAtIndex:column];
    AKTopic *topic = [topicList objectAtIndex:row];

    [cell setRepresentedObject:topic];
    [cell setTitle:[topic stringToDisplayInTopicBrowser]];
    [cell setEnabled:[topic browserCellShouldBeEnabled]];
    [cell setLeaf:![topic browserCellHasChildren]];
}

- (BOOL)browser:(NSBrowser *)sender isColumnValid:(int)column
{
    return YES;
}

#pragma mark -
#pragma mark Private methods

- (NSInteger)_numberOfRowsInColumn:(NSInteger)column
{
    // Defensive programming: see if we are trying to populate a
    // browser column that's too far to the right.
    if (column > (int)[_topicListsForBrowserColumns count])
    {
        DIGSLogError(@"_topicListsForBrowserColumns has too few elements");
        return 0;
    }

    // Discard data for columns we will no longer displaying.
    NSInteger numBrowserColumns = [_topicBrowser lastColumn] + 1;
    if (column > numBrowserColumns)  // gmd
    {
        DIGSLogError(@"_topicListsForBrowserColumns has too few elements /gmd");
        return 0;
    }
    while (numBrowserColumns < (int)[_topicListsForBrowserColumns count])
    {
        [_topicListsForBrowserColumns removeLastObject];
    }

    // Compute browser values for this column if we don't have them already.
    if (column == (int)[_topicListsForBrowserColumns count])
    {
        [self _setUpChildTopics];
        if (column >= (int)[_topicListsForBrowserColumns count]) // gmd
        {
            // This Framework has no additional topics like Functions,
            // Protocols, etc. (happens for PDFKit, PreferencePanes, which
            // just have classes)
            return 0;
        }
    }

    // Now that the data ducks have been lined up, simply pluck our answer
    // from _topicListsForBrowserColumns.
    return [[_topicListsForBrowserColumns objectAtIndex:column] count];
}

- (void)_setUpChildTopics
{
    NSInteger columnNumber = [_topicListsForBrowserColumns count];

    if (columnNumber == 0)
    {
        [self _setUpTopicsForZeroethBrowserColumn];
    }
    else
    {
        AKTopic *prevTopic = [[_topicBrowser selectedCellInColumn:(columnNumber - 1)] representedObject];
        NSArray *columnValues = [prevTopic childTopics];

        if ([columnValues count] > 0)
        {
            [_topicListsForBrowserColumns addObject:columnValues];
        }
    }
}

// On entry, _topicListsForBrowserColumns must be empty. The items in the
// zeroeth column are in two sections: "classes" (root classes), and
// "other topics" (list of frameworks so that we can navigate to things like
// functions and protocols).
- (void)_setUpTopicsForZeroethBrowserColumn
{
    NSMutableArray *columnValues = [NSMutableArray array];
    AKDatabase *db = [[self owningWindowController] database];

    // Set up the "classes" section.
    [columnValues addObject:[AKLabelTopic topicWithLabel:AKClassesLabelTopicName]];

    for (AKClassNode *classNode in [AKSortUtils arrayBySortingArray:[db rootClasses]])
    {
        [columnValues addObject:[AKClassTopic topicWithClassNode:classNode]];
    }

    // Set up the "other topics" section.
    [columnValues addObject:[AKLabelTopic topicWithLabel:AKOtherTopicsLabelTopicName]];

    for (NSString *fwName in [db sortedFrameworkNames])
    {
        [columnValues addObject:[AKFrameworkTopic topicWithFrameworkNamed:fwName inDatabase:db]];
    }

    [_topicListsForBrowserColumns addObject:columnValues];
}

@end
