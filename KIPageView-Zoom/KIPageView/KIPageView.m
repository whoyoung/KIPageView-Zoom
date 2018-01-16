//
//  KIPageView.m
//  KIPageView
//
//  Created by SmartWalle on 15/8/14.
//  Copyright (c) 2015年 SmartWalle. All rights reserved.
//

#import "KIPageView.h"

#pragma mark - Category KIPageViewCell(KIPageView)
@interface KIPageViewCell (KIPageView)
@end

@implementation KIPageViewCell (KIPageView)

- (NSInteger)_pageViewCellIndex {
    return [[self valueForKey:@"_cellIndex"] integerValue];
}

- (void)_setPageViewCellIndex:(NSInteger)index {
    [self setValue:@(index) forKey:@"_cellIndex"];
}

@end


#pragma mark - Extension KIPageView
@interface KIPageView () <UIScrollViewDelegate>

#pragma mark - Property
@property (nonatomic, assign) KIPageViewOrientation pageViewOrientation;
@property (nonatomic, strong) NSMutableSet          *visibleItems;
@property (nonatomic, strong) NSMutableSet          *recycledItems;
@property (nonatomic, strong) NSMutableDictionary   *reusableItems;
@property (nonatomic, strong) NSMutableArray        *rectForItems;

@property (nonatomic, assign) NSInteger     totalPages;
@property (nonatomic, assign) NSInteger     pageIndexForCellInVisibileList; //显示列表中的第一个cell的index
@property (nonatomic, assign) NSInteger     selectedIndex; //当前选中cell的index
@property (nonatomic, strong) UIScrollView  *scrollView;

@property (nonatomic,assign) CGFloat XRatio;
@property (nonatomic,assign) CGFloat YRatio;
@property (nonatomic,assign) CGPoint beganPoint;
@property (nonatomic,assign) CGPoint changedPoint;
@property (nonatomic,assign) CGFloat beganPointXPercent;
@property (nonatomic,assign) CGFloat beganPointYPercent;
@property (nonatomic,assign) CGPoint convertPoint;
@property (nonatomic,assign) NSUInteger changeDirection; //YHPageViewZoomDirectionXOrY时，0：方向未确定、1：X轴方向缩放、2：Y轴方向缩放
@property (nonatomic,assign) CGSize beganScrollSize;
@end

@implementation KIPageView

- (instancetype)initWithOrientation:(KIPageViewOrientation)orientation {
    if (self = [super init]) {
        [self _initFinishedWithOrientation:orientation];
    }
    return self;
}

- (instancetype)init {
    if (self = [super init]) {
        [self _initFinishedWithOrientation:KIPageViewHorizontal];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self _initFinishedWithOrientation:KIPageViewHorizontal];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self _initFinishedWithOrientation:KIPageViewHorizontal];
    }
    return self;
}

- (void)layoutSubviews {
    CGRect rect = self.bounds;
    [self.scrollView setFrame:rect];
    
    if (self.delegate != nil) {
        if ([self indexOutOfBounds:self.pageIndexForCellInVisibileList]) {
            [self setPageIndexForCellInVisibileList:0];
        }
        [self reloadDataAndScrollToIndex:self.pageIndexForCellInVisibileList];
    }
}

#pragma mark - KIPageViewCellDelegate
- (void)pageViewCell:(KIPageViewCell *)cell updateSelectedStatus:(BOOL)selected {
    if (selected) {
        [self didSelectedCellAtIndex:[cell _pageViewCellIndex]];
    } else {
        [self didDeselectedCellAtIndex:[cell _pageViewCellIndex]];
    }
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updatePageViewItemsFromOffset:scrollView.contentOffset];
}

#pragma mark - Methods
#pragma mark **************************************************
#pragma mark 【初始化】
#pragma mark **************************************************
- (void)_initFinishedWithOrientation:(KIPageViewOrientation)orientation {
    [self setPageViewOrientation:orientation];
    [self setSelectedIndex:-1];
    [self setTotalPages:0];
    [self setPageIndexForCellInVisibileList:-1];
    [self setBackgroundColor:[UIColor whiteColor]];
    [self setClipsToBounds:YES];
    self.XRatio = 1.0;
    self.YRatio = 1.0;
    _cellMargin = 0;
    _changeDirection = 0;
}

#pragma mark **************************************************
#pragma mark 【KIPageViewDelegate】
#pragma mark **************************************************
- (NSInteger)numberOfPages {
    if (self.totalPages <= 0 && self.delegate != nil && [self.delegate respondsToSelector:@selector(numberOfCellsInPageView:)]) {
        self.totalPages = [self.delegate numberOfCellsInPageView:self];
    }
    return self.totalPages;
}

- (KIPageViewCell *)cellAtIndex:(NSInteger)index {
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:cellAtIndex:)]) {
        return [self.delegate pageView:self cellAtIndex:index];
    }
    return nil;
}

- (void)willDisplayCell:(KIPageViewCell *)cell atIndex:(NSInteger)index {
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:willDisplayCell:atIndex:)]) {
        [self.delegate pageView:self willDisplayCell:cell atIndex:index];
    }
}

- (void)didEndDisplayingCell:(KIPageViewCell *)cell atIndex:(NSInteger)index {
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:didEndDisplayingCell:atIndex:)]) {
        [self.delegate pageView:self didEndDisplayingCell:cell atIndex:index];
    }
}

- (CGFloat)widthForCellAtIndex:(NSInteger)index {
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:widthForCellAtIndex:)]) {
        return [self.delegate pageView:self widthForCellAtIndex:index];
    }
    return 0;
}

- (CGFloat)heightForCellAtIndex:(NSInteger)index {
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:heightForCellAtIndex:)]) {
        return [self.delegate pageView:self heightForCellAtIndex:index];
    }
    return 0;
}

- (void)didSelectedCellAtIndex:(NSInteger)index {
    if (self.selectedIndex >= 0) {
        [self deselectCellAtIndex:self.selectedIndex animated:NO];
    }
    
    [self setSelectedIndex:index];
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:didSelectedCellAtIndex:)]) {
        [self.delegate pageView:self didSelectedCellAtIndex:index];
    }
}

- (void)didDeselectedCellAtIndex:(NSInteger)index {
    if (self.selectedIndex != index) {
        return ;
    }
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:didDeselectedCellAtIndex:)]) {
        [self.delegate pageView:self didDeselectedCellAtIndex:index];
    }
}

- (void)updateRectForCells {
    [self.rectForItems removeAllObjects];
    
    CGFloat x = 0, y = 0;
    CGFloat width = [self width], height = [self height];
    
    for (int i=0; i<[self numberWithInfinitCells]; i++) {
        CGRect rect;
        if (self.pageViewOrientation == KIPageViewVertical) {
            height = [self heightForCellAtIndex:i];
            y += _cellMargin/2;
            rect = CGRectMake(x, y, width, height);
            y += height;
        } else {
            width = [self widthForCellAtIndex:i];
            x += _cellMargin/2;
            rect = CGRectMake(x, y, width, height);
            x += width;
        }
        [self.rectForItems addObject:NSStringFromCGRect(rect)];
    }
}

- (void)updateContentSize {
    
    CGFloat width = 0;
    CGFloat height = 0;
    
    if (self.pageViewOrientation == KIPageViewVertical) {
        width = [self width] * _XRatio;
    } else {
        height = [self height] * _YRatio;
    }

    CGFloat totalWidth = 0, totalHeight = 0;
    CGRect lastRect = [self scaledRect:[self.rectForItems objectAtIndex:[self numberWithInfinitCells]-1]];
    if (self.pageViewOrientation == KIPageViewVertical) {
        totalHeight += lastRect.origin.y + lastRect.size.height + _cellMargin/2*_YRatio;
        totalWidth = lastRect.size.width;
    } else {
        totalWidth += lastRect.origin.x + lastRect.size.width + _cellMargin/2*_XRatio;
        totalHeight = lastRect.size.height;
    }
    [self.scrollView setContentSize:CGSizeMake(totalWidth, totalHeight)];
}

- (CGRect)rectForPageViewCellAtIndex:(NSInteger)index {
    if ([self indexOutOfBounds:index]) {
        return CGRectZero;
    }
    CGRect rect = [self scaledRect:[self.rectForItems objectAtIndex:index]];
    return rect;
}

- (NSInteger)indexOfPageViewCell:(KIPageViewCell *)cell {
    if (cell == nil || ![cell isKindOfClass:[KIPageViewCell class]]) {
        return -1;
    }
    
    return [cell _pageViewCellIndex];
}

/*
 获取指定index的KIPageViewCell
 */
- (KIPageViewCell *)pageViewCellAtIndex:(NSInteger)index {
    if ([self indexOutOfBounds:index]) {
        return nil;
    }
    
    KIPageViewCell *cell = nil;
    cell = [self pageViewCellInVisibleListAtIndex:index];
    if (cell == nil) {
        cell = [self cellAtIndex:index];
    }
    return cell;
}

- (KIPageViewCell *)pageViewCellInVisibleListAtIndex:(NSInteger)index {
    __block KIPageViewCell *pageViewCell = nil;
    [self.visibleItems enumerateObjectsUsingBlock:^(KIPageViewCell *cell, BOOL *stop) {
        if (index == [cell _pageViewCellIndex]) {
            pageViewCell = cell;
        }
    }];
    return pageViewCell;
}

- (KIPageViewCell *)pageViewCellInReusableListWithIndex:(NSInteger)index {
    __block KIPageViewCell *pageViewCell = nil;
    [self.visibleItems enumerateObjectsUsingBlock:^(KIPageViewCell *cell, BOOL *stop) {
        if (index == [cell _pageViewCellIndex]) {
            pageViewCell = cell;
        }
    }];
    
    if (pageViewCell == nil) {
        [self.recycledItems enumerateObjectsUsingBlock:^(KIPageViewCell *cell, BOOL *stop) {
            if (index == [cell _pageViewCellIndex]) {
                pageViewCell = cell;
            }
        }];
    }
    return pageViewCell;
}

- (NSInteger)numberWithInfinitCells {
    NSInteger count = [self numberOfPages];
    return count;
}

#pragma mark **************************************************
#pragma mark 【检测Index是否越界】
#pragma mark **************************************************
- (BOOL)indexOutOfBounds:(NSInteger)index {
    if (index < 0 || index >= [self numberWithInfinitCells]) {
        return YES;
    }
    return NO;
}

#pragma mark **************************************************
#pragma mark 【获取可以重用的Cell】
#pragma mark **************************************************
- (KIPageViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier {
    return [[self recycledCellsWithIdentifier:identifier] anyObject];
}

- (NSMutableDictionary *)reusableItemsWithIdentifier:(NSString *)identifier {
    NSMutableDictionary *reusableItems = [[self reusableItems] objectForKey:identifier];
    if (reusableItems == nil) {
        reusableItems = [[NSMutableDictionary alloc] init];
        [[self reusableItems] setObject:reusableItems forKey:identifier];
    }
    return reusableItems;
}

- (NSMutableSet *)recycledCellsWithIdentifier:(NSString *)identifier {
    NSMutableSet *recycledCells = [[self reusableItemsWithIdentifier:identifier] objectForKey:@"recycledCells"];
    if (recycledCells == nil) {
        recycledCells = [[NSMutableSet alloc] init];
        [[self reusableItemsWithIdentifier:identifier] setObject:recycledCells forKey:@"recycledCells"];
    }
    return recycledCells;
}

#pragma mark **************************************************
#pragma mark 【跳转到指定index】
#pragma mark **************************************************
- (void)scrollToPageViewCellAtIndex:(NSInteger)index {
    [self scrollToPageViewCellAtIndex:index animated:NO];
}

- (void)scrollToPageViewCellAtIndex:(NSInteger)index animated:(BOOL)animated {
    [self scrollToPageViewCellAtIndex:index animated:animated init:NO];
}

- (void)scrollToPageViewCellAtIndex:(NSInteger)index animated:(BOOL)animated init:(BOOL)init {
    if ([self indexOutOfBounds:index]) {
        return ;
    }
    
    if (index == 0 && self.pageIndexForCellInVisibileList == [self numberWithInfinitCells] - 2) {
        return ;
    }
    
    if (index == 0 && init) {
    } else {
        CGRect rect = [self rectForPageViewCellAtIndex:index];
        [self.scrollView scrollRectToVisible:rect animated:animated];
    }
}

- (void)scrollToPageAtIndex:(NSInteger)pageIndex {
    [self scrollToPageViewCellAtIndex:pageIndex animated:YES];
}

- (void)selectCellAtIndex:(NSInteger)index animated:(BOOL)animated {
    if ([self indexOutOfBounds:index]) {
        return ;
    }
    
    NSInteger scrollToIndex = index;
    
    [self scrollToPageViewCellAtIndex:scrollToIndex animated:animated];
    
    if (index == self.selectedIndex) {
        return ;
    }
    
    KIPageViewCell *cell = [self pageViewCellInVisibleListAtIndex:index];
    if (cell != nil) {
        [cell setSelected:YES animated:animated];
    } else {
        if (self.selectedIndex > -1) {
            [self deselectCellAtIndex:self.selectedIndex animated:animated];
        }
    }
    
    [self didSelectedCellAtIndex:index];
}

- (void)deselectCellAtIndex:(NSInteger)index animated:(BOOL)animated {
    if ([self indexOutOfBounds:index]) {
        return ;
    }
    
    KIPageViewCell *cell = [self pageViewCellInVisibleListAtIndex:self.selectedIndex];
    if (cell != nil) {
        [cell setSelected:NO animated:animated];
    } else {
        [self didDeselectedCellAtIndex:self.selectedIndex];
    }
    
    [self setSelectedIndex:-1];
}

#pragma mark **************************************************
#pragma mark 【重新加载数据】
#pragma mark **************************************************
- (void)reloadData {
    [self setSelectedIndex:-1];
    [self setTotalPages:0];
    [self setPageIndexForCellInVisibileList:-1];
    
    [self.scrollView setContentOffset:CGPointZero animated:NO];
    
    [self updateRectForCells];
    [self updateContentSize];
    [self updatePageViewItemsFromOffset:_scrollView.contentOffset];
    
    [self scrollToPageViewCellAtIndex:0 animated:NO init:YES];
}

- (void)reloadDataAndScrollToIndex:(NSInteger)index {
    [self setTotalPages:0];
    
    if ([self indexOutOfBounds:index]) {
        index = 0;
    }
    
    [self updateRectForCells];
    
    [self updateContentSize];
    [self updatePageViewItemsFromOffset:self.scrollView.contentOffset];
    
    [self reloadVisibleItems];
    
    [self scrollToPageViewCellAtIndex:index animated:NO init:YES];
}

- (void)recycleItemsWithoutIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex {
    [self.visibleItems enumerateObjectsUsingBlock:^(KIPageViewCell *item, BOOL *stop) {
        NSInteger index = [item _pageViewCellIndex];
        if (index < fromIndex || index > toIndex) {
            NSMutableSet *recycledItems = [self recycledCellsWithIdentifier:item.reuseIdentifier];
            [recycledItems addObject:item];
            
            [self.recycledItems addObject:item];
            [item removeFromSuperview];
            
            [self didEndDisplayingCell:item atIndex:index];
        }
    }];
    [self.visibleItems minusSet:self.recycledItems];
}

- (void)reloadItemAtIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex {
    for (NSInteger index = fromIndex; index <= toIndex; index++) {
        if (![self isDisplayingItemAtIndex:index]) {
            KIPageViewCell *pageViewItem = [self pageViewCellAtIndex:index];
            if (pageViewItem != nil) {
                [self willDisplayCell:pageViewItem atIndex:index];
                
                [pageViewItem _setPageViewCellIndex:index];
                [pageViewItem setFrame:[self rectForPageViewCellAtIndex:index]];
                
                if (index == self.selectedIndex) {
                    [pageViewItem setSelected:YES animated:NO];
                } else {
                    [pageViewItem setSelected:NO animated:NO];
                }
                
                [self.scrollView addSubview:pageViewItem];
                
                [self.visibleItems addObject:pageViewItem];
                [self.recycledItems removeObject:pageViewItem];
                
                [[self recycledCellsWithIdentifier:pageViewItem.reuseIdentifier] removeObject:pageViewItem];
            }
        }
    }
}

- (void)reloadVisibleItems {
    for (KIPageViewCell *item in self.visibleItems) {
        NSInteger index = [item _pageViewCellIndex];
        [item setFrame:[self rectForPageViewCellAtIndex:index]];
    }
}

- (BOOL)isDisplayingItemAtIndex:(NSInteger)index {
    BOOL foundItem = NO;
    for (KIPageViewCell *item in self.visibleItems) {
        if ([item _pageViewCellIndex] == index) {
            foundItem = YES;
            break;
        }
    }
    return foundItem;
}

#pragma mark - Getters and setters
- (CGFloat)width {
    return CGRectGetWidth(self.frame);
}

- (CGFloat)height {
    return CGRectGetHeight(self.frame);
}

- (UIScrollView *)scrollView {
    if (_scrollView == nil) {
        _scrollView = [[UIScrollView alloc] init];
        [_scrollView setDelegate:self];
        [_scrollView setShowsHorizontalScrollIndicator:YES];
        [_scrollView setShowsVerticalScrollIndicator:YES];
        [_scrollView setBackgroundColor:[UIColor clearColor]];
        [_scrollView setDelaysContentTouches:NO];
        _scrollView.bounces = NO;
        UIPinchGestureRecognizer *pinGes = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinGestureChange:)];
        [_scrollView addGestureRecognizer:pinGes];
        [self addSubview:_scrollView];
    }
    return _scrollView;
}
#pragma mark ********************************
#pragma mark UIPinchGestureRecognizerDelegate
- (void)pinGestureChange:(UIPinchGestureRecognizer *)pinGesture {
    if (_zoomDirection == YHPageViewZoomDirectionNone) return;
    switch (pinGesture.state) {
        case UIGestureRecognizerStateBegan: {
            _changeDirection = 0;
            _beganPoint = [pinGesture locationInView:_scrollView];
            NSLog(@"_beganPoint=%@",NSStringFromCGPoint(_beganPoint));
            _beganPointXPercent = _beganPoint.x/self.scrollView.contentSize.width;
            _beganPointYPercent = _beganPoint.y/self.scrollView.contentSize.height;
            _convertPoint = [self.scrollView convertPoint:_beganPoint toView:self];
            _beganScrollSize = _scrollView.contentSize;
            NSLog(@"convertPoint=%@",NSStringFromCGPoint(_convertPoint));
        }
            break;
        case UIGestureRecognizerStateChanged: {
            _changedPoint = [pinGesture locationInView:_scrollView];
            NSLog(@"pinGesture.scale=%f",pinGesture.scale);
            NSLog(@"_changedPoint=%@,_beganPoint=%@",NSStringFromCGPoint(_changedPoint),NSStringFromCGPoint(_beganPoint));
            if (_zoomDirection == YHPageViewZoomDirectionXOrY && _changeDirection == 0) {
                if (fabs(_changedPoint.y-_beganPoint.y) == fabs(_changedPoint.x-_beganPoint.x)) break; //这种情况无法判断是应该缩放X轴还是Y轴
                _changeDirection = fabs(_changedPoint.y-_beganPoint.y) > fabs(_changedPoint.x-_beganPoint.x) ? 2 : 1;
            }
            
            CGFloat adjustScale = pinGesture.scale;
            switch (_zoomDirection) {
                case YHPageViewZoomDirectionX: {
                    if (pinGesture.scale < 1 && _beganScrollSize.width < self.frame.size.width) break;
                    if (pinGesture.scale*_beganScrollSize.width < self.frame.size.width) {
                        adjustScale = self.frame.size.width/_beganScrollSize.width;
                    }
                    _XRatio = _XRatio*(adjustScale * _beganScrollSize.width/_scrollView.contentSize.width);
                    _scrollView.contentSize = CGSizeMake(adjustScale * _beganScrollSize.width, _scrollView.contentSize.height);
                }
                    break;
                case YHPageViewZoomDirectionY: {
                    if (pinGesture.scale < 1 && _beganScrollSize.height < self.frame.size.height) break;
                    if (pinGesture.scale*_beganScrollSize.height < self.frame.size.height) {
                        adjustScale = self.frame.size.height/_beganScrollSize.height;
                    }
                    _YRatio = _YRatio*(adjustScale*_beganScrollSize.height/_scrollView.contentSize.height);
                    _scrollView.contentSize = CGSizeMake(_scrollView.contentSize.width, adjustScale*_beganScrollSize.height);
                }
                    break;
                case YHPageViewZoomDirectionXAndY: {
                    if (pinGesture.scale < 1 && (_beganScrollSize.width < self.frame.size.width || _beganScrollSize.height < self.frame.size.height)) break;
                    if (pinGesture.scale*_beganScrollSize.width < self.frame.size.width || pinGesture.scale*_beganScrollSize.height < self.frame.size.height) {
                        adjustScale = MAX(self.frame.size.height/_beganScrollSize.height,self.frame.size.width/_beganScrollSize.width);
                    }
                    _XRatio = _XRatio*(adjustScale*_beganScrollSize.width/_scrollView.contentSize.width);
                    _YRatio = _XRatio;
                    _scrollView.contentSize = CGSizeMake(adjustScale*_beganScrollSize.width, adjustScale*_beganScrollSize.height);
                }
                    break;
                case YHPageViewZoomDirectionXOrY: {
                    if (_changeDirection == 1) {
                        if (pinGesture.scale < 1 && _beganScrollSize.width < self.frame.size.width) break;
                        if (pinGesture.scale*_beganScrollSize.width < self.frame.size.width) {
                            adjustScale = self.frame.size.width/_beganScrollSize.width;
                        }
                        _XRatio = _XRatio*(adjustScale*_beganScrollSize.width/_scrollView.contentSize.width);
                        _scrollView.contentSize = CGSizeMake(adjustScale*_beganScrollSize.width, _scrollView.contentSize.height);
                    } else {
                        if (pinGesture.scale < 1 && _beganScrollSize.height < self.frame.size.height) break;
                        if (pinGesture.scale*_beganScrollSize.height < self.frame.size.height) {
                            adjustScale = self.frame.size.height/_beganScrollSize.height;
                        }
                        _YRatio = _YRatio*(adjustScale*_beganScrollSize.height/_scrollView.contentSize.height);
                        _scrollView.contentSize = CGSizeMake(_scrollView.contentSize.width, adjustScale*_beganScrollSize.height);
                    }
                }
                    break;
                    
                default:
                    break;
            }
            
            
            [self adjustvisibleArea];
            
            NSLog(@"ratio=%ld",_changeDirection);
            NSLog(@"_XRatio=%f,_YRatio=%f",_XRatio,_YRatio);
        }
            break;
        case UIGestureRecognizerStateEnded: {
            
        }
            break;
            
        default:
            break;
    }
}
- (void)adjustvisibleArea {
    CGPoint adjustP = [self adjustContentOffset];
    [self updatePageViewItemsFromOffset:adjustP];
    [self reloadVisibleItems];
    [self.scrollView setContentOffset:adjustP animated:NO];
    if (self.delegate && [self.delegate respondsToSelector:@selector(pageView:didZoomingXRatio:YRatio:)]) {
        [self.delegate pageView:self didZoomingXRatio:_XRatio YRatio:_YRatio];
    }
}
- (void)updatePageViewItemsFromOffset:(CGPoint)offset {
    if (offset.x < 0 || offset.y < 0) {
        return ;
    }
    
    NSUInteger firstNeededPageIndex = 0;
    NSUInteger lastNeededPageIndex = 0;
    
    //第一项的index
    firstNeededPageIndex = 0;
    CGFloat referValue = self.pageViewOrientation == KIPageViewVertical ? offset.y : offset.x;
    firstNeededPageIndex = [self halfSearchFirst:firstNeededPageIndex rightIndex:[self numberWithInfinitCells]-1 referValue:referValue];
    //最后一项的index
    CGRect lastRect = [self scaledRect:[self.rectForItems objectAtIndex:firstNeededPageIndex]];
    CGFloat leftValue = self.pageViewOrientation == KIPageViewVertical ? lastRect.origin.y : lastRect.origin.x;
    CGFloat rightValue = self.pageViewOrientation == KIPageViewVertical ? self.bounds.size.height : self.bounds.size.width;
    lastNeededPageIndex = [self halfSearchLast:lastNeededPageIndex rightIndex:[self numberWithInfinitCells] leftReferValue:leftValue referValue:rightValue];
    
    firstNeededPageIndex = MAX(firstNeededPageIndex, 0);
    lastNeededPageIndex  = MIN(lastNeededPageIndex, [self numberWithInfinitCells]-1);
    
    [self setPageIndexForCellInVisibileList:firstNeededPageIndex];
    
    [self recycleItemsWithoutIndex:firstNeededPageIndex toIndex:lastNeededPageIndex];
    [self reloadItemAtIndex:firstNeededPageIndex toIndex:lastNeededPageIndex];
}

- (NSInteger)halfSearchFirst:(NSInteger)leftIndex rightIndex:(NSInteger)rightIndex referValue:(CGFloat)referValue {
    if (leftIndex == rightIndex) return leftIndex;
    NSInteger midIndex = (leftIndex + rightIndex)/2;
    CGRect rect = [self scaledRect:[self.rectForItems objectAtIndex:midIndex]];
    CGFloat min = 0, max = 0;
    if (self.pageViewOrientation == KIPageViewVertical) {
        min = rect.origin.y - _cellMargin/2;
        max = min + rect.size.height + _cellMargin/2;
    } else {
        min = rect.origin.x - _cellMargin/2;
        max = min + rect.size.width + _cellMargin/2;
    }
    if (min <= referValue && max > referValue) {
        return midIndex;
    } else if (min < referValue) {
        if (midIndex == rightIndex) return rightIndex;
        return [self halfSearchFirst:midIndex+1 rightIndex:rightIndex referValue:referValue];
    } else {
        if (midIndex == 0) return 0;
        return [self halfSearchFirst:leftIndex rightIndex:midIndex-1 referValue:referValue];
    }
}
- (NSInteger)halfSearchLast:(NSInteger)leftIndex rightIndex:(NSInteger)rightIndex leftReferValue:(CGFloat)leftValue referValue:(CGFloat)referValue {
    if (leftIndex == rightIndex) return leftIndex;
    NSInteger midIndex = (leftIndex + rightIndex)/2;
    CGRect rect = [self scaledRect:[self.rectForItems objectAtIndex:midIndex]];
    CGFloat min = 0, max = 0;
    if (self.pageViewOrientation == KIPageViewVertical) {
        min = rect.origin.y - _cellMargin/2;
        max = min + rect.size.height + _cellMargin/2;
    } else {
        min = rect.origin.x - _cellMargin/2;
        max = min + rect.size.width + _cellMargin/2;
    }
    if (min-leftValue <= referValue && max-leftValue > referValue) {
        return midIndex+1;
    } else if (min-leftValue < referValue) {
        return [self halfSearchLast:midIndex+1 rightIndex:rightIndex leftReferValue:leftValue referValue:referValue];
    } else {
        if (midIndex == 0) return 0;
        return [self halfSearchLast:leftIndex rightIndex:midIndex-1 leftReferValue:leftValue referValue:referValue];
    }
}
- (CGPoint)adjustContentOffset {
    NSLog(@"self.scrollView.contentSize=%@",NSStringFromCGSize(self.scrollView.contentSize));
    CGFloat offsetX = self.scrollView.contentSize.width * _beganPointXPercent;
    CGFloat offsetY = self.scrollView.contentSize.height * _beganPointYPercent;
    
    CGFloat adjustX = offsetX - _convertPoint.x;
    if (adjustX < 0 || self.scrollView.contentSize.width <= self.bounds.size.width) {
        adjustX = 0;
    } else if (self.scrollView.contentSize.width > self.bounds.size.width && adjustX > (self.scrollView.contentSize.width-self.bounds.size.width)) {
        adjustX = self.scrollView.contentSize.width - self.bounds.size.width;
    }
    
    CGFloat adjustY = offsetY-_convertPoint.y;
    if (adjustY < 0 || self.scrollView.contentSize.height <= self.bounds.size.height) {
        adjustY = 0;
    } else if (self.scrollView.contentSize.height > self.bounds.size.height && adjustY > (self.scrollView.contentSize.height-self.bounds.size.height)) {
        adjustY = self.scrollView.contentSize.height - self.bounds.size.height;
    }
    return CGPointMake(adjustX, adjustY);
}
- (CGRect)scaledRect:(NSString *)rectStringValue {
    CGRect rect = CGRectFromString(rectStringValue);
    return CGRectMake(rect.origin.x*_XRatio, rect.origin.y*_YRatio, rect.size.width*_XRatio, rect.size.height*_YRatio);
}
- (NSMutableSet *)visibleItems {
    if (_visibleItems == nil) {
        _visibleItems = [[NSMutableSet alloc] init];
    }
    return _visibleItems;
}

- (NSMutableSet *)recycledItems {
    if (_recycledItems == nil) {
        _recycledItems = [[NSMutableSet alloc] init];
    }
    return _recycledItems;
}

- (NSMutableDictionary *)reusableItems {
    if (_reusableItems == nil) {
        _reusableItems = [[NSMutableDictionary alloc] init];
    }
    return _reusableItems;
}

- (NSMutableArray *)rectForItems {
    if (_rectForItems == nil) {
        _rectForItems = [[NSMutableArray alloc] init];
    }
    return _rectForItems;
}

- (void)setDelegate:(id<KIPageViewDelegate>)delegate {
    if (_delegate == delegate) {
        return;
    }
    
    _delegate = delegate;
}

- (void)setScrollEnabled:(BOOL)scrollEnabled {
    if (self.scrollView.scrollEnabled == scrollEnabled) {
        return ;
    }
    
    [self.scrollView setScrollEnabled:scrollEnabled];
}

- (BOOL)scrollEnabled {
    return self.scrollView.scrollEnabled;
}

- (BOOL)bounces {
    return self.scrollView.bounces;
}

- (void)setBounces:(BOOL)bounces {
    [self.scrollView setBounces:bounces];
}

- (BOOL)scrollsToTop {
    return self.scrollView.scrollsToTop;
}

- (void)setScrollsToTop:(BOOL)scrollsToTop {
    [self.scrollView setScrollsToTop:scrollsToTop];
}

@end
