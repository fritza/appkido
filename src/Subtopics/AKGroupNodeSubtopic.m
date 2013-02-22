/*
 * AKGroupNodeSubtopic.m
 *
 * Created by Andy Lee on Sun Mar 28 2004.
 * Copyright (c) 2003, 2004 Andy Lee. All rights reserved.
 */

#import "AKGroupNodeSubtopic.h"

#import "DIGSLog.h"

#import "AKSortUtils.h"
#import "AKFileSection.h"
#import "AKGlobalsNode.h"
#import "AKGroupNode.h"
#import "AKNodeDoc.h"

@implementation AKGroupNodeSubtopic


#pragma mark -
#pragma mark Init/awake/dealloc

- (id)initWithGroupNode:(AKGroupNode *)groupNode
{
    if ((self = [super init]))
    {
        _groupNode = groupNode;
    }

    return self;
}

- (id)init
{
    DIGSLogError_NondesignatedInitializer();
    return nil;
}


#pragma mark -
#pragma mark AKSubtopic methods

- (NSString *)subtopicName
{
    return [_groupNode nodeName];
}

- (void)populateDocList:(NSMutableArray *)docList
{
    for (AKGlobalsNode *globalsNode in [AKSortUtils arrayBySortingArray:[_groupNode subnodes]])
    {
        AKDoc *newDoc =
            [[AKNodeDoc alloc] initWithNode:globalsNode];

        [docList addObject:newDoc];
    }
}

@end
