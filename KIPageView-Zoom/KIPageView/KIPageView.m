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
@property (nonatomic, assign) NSInteger     lastDisplayPageIndex; //标记最后一次显示的cell，并且只在pagingEnable时有用

@property (nonatomic, assign) NSInteger     selectedIndex; //当前选中cell的index

@property (nonatomic, strong) UIScrollView  *scrollView;

@property (nonatomic, assign) NSUInteger    timeInterval;
@property (nonatomic, strong) NSTimer       *timer;

@property (nonatomic,assign) CGFloat XRatio;
@property (nonatomic,assign) CGFloat YRatio;
@property (nonatomic,assign) CGPoint beganPoint;
@property (nonatomic,assign) CGPoint changedPoint;
@property (nonatomic,assign) CGFloat beganPointXPercent;
@property (nonatomic,assign) CGFloat beganPointYPercent;
@property (nonatomic,assign) CGPoint convertPoint;
@property (nonatomic,assign) NSUInteger changeDirection; //0：方向未确定、1：X轴方向改变、2：Y轴方向改变
@property (nonatomic,assign) CGSize beganScrollSize;
@end

@implementation KIPageView

#pragma mark - Lifecycle
- (void)dealloc {
    [self invalidTimer];
}

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

- (void)removeFromSuperview {
    [self invalidTimer];
    [super removeFromSuperview];
}

- (void)layoutSubviews {
    CGRect rect = self.bounds;
    if (self.pagingEnabled) {
        if (self.pageViewOrientation == KIPageViewVertical) {
            rect.size.height += self.cellMargin;
        } else {
            rect.size.width += self.cellMargin;
        }
    }
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

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    //开始拖曳的时候，暂时将timer设置无效
    [self invalidTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    //结束拖曳的时候，重新启动timer
    [self flipOverWithTime:self.timeInterval];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self updateDidDisplayPageIndex:scrollView];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self updateDidDisplayPageIndex:scrollView];
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
    [self setLastDisplayPageIndex:-1];
    [self setInfinite:YES];
    [self setBackgroundColor:[UIColor whiteColor]];
    [self setClipsToBounds:YES];
    self.XRatio = 1.0;
    self.YRatio = 1.0;
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
        return [self.delegate pageView:self cellAtIndex:[self indexWithInfiniteIndex:index]];
    }
    return nil;
}

- (void)willDisplayCell:(KIPageViewCell *)cell atIndex:(NSInteger)index {
    if (self.pagingEnabled) {
        return ;
    }
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:willDisplayCell:atIndex:)]) {
        [self.delegate pageView:self willDisplayCell:cell atIndex:[self indexWithInfiniteIndex:index]];
    }
}

- (void)didEndDisplayingCell:(KIPageViewCell *)cell atIndex:(NSInteger)index {
    if (self.pagingEnabled) {
        return ;
    }
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:didEndDisplayingCell:atIndex:)]) {
        [self.delegate pageView:self didEndDisplayingCell:cell atIndex:[self indexWithInfiniteIndex:index]];
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

- (void)didDisplayPage:(NSInteger)index {
    if (!self.pagingEnabled) {
        return ;
    }
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:didDisplayPage:)]) {
        [self.delegate pageView:self didDisplayPage:[self indexWithInfiniteIndex:index]];
    }
}

- (void)didEndDisplayingPage:(NSInteger)index {
    if (!self.pagingEnabled) {
        return ;
    }
    if (index == 0 || index == [self numberWithInfinitCells]-1) {
        return ;
    }
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:didEndDisplayingPage:)]) {
        [self.delegate pageView:self didEndDisplayingPage:[self indexWithInfiniteIndex:index]];
    }
}

- (void)didSelectedCellAtIndex:(NSInteger)index {
    if (self.selectedIndex >= 0) {
        [self deselectCellAtIndex:self.selectedIndex animated:NO];
    }
    
    [self setSelectedIndex:index];
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:didSelectedCellAtIndex:)]) {
        [self.delegate pageView:self didSelectedCellAtIndex:[self indexWithInfiniteIndex:index]];
    }
}

- (void)didDeselectedCellAtIndex:(NSInteger)index {
    if (self.selectedIndex != index) {
        return ;
    }
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(pageView:didDeselectedCellAtIndex:)]) {
        [self.delegate pageView:self didDeselectedCellAtIndex:[self indexWithInfiniteIndex:index]];
    }
}

- (void)updateRectForCells {
    [self.rectForItems removeAllObjects];
    
    CGFloat x = 0, y = 0;
    CGFloat width = [self width], height = [self height];
    
    for (int i=0; i<[self numberWithInfinitCells]; i++) {
        CGRect rect;
        if (self.pageViewOrientation == KIPageViewVertical) {
            if ([self infinitable] || self.pagingEnabled) {
                y = ([self height] + self.cellMargin) * i;
                rect = CGRectMake(x, y, width, height);
            } else {
                height = [self heightForCellAtIndex:i];
                rect = CGRectMake(x, y, width, height);
                y += height;
            }
        } else {
            if ([self infinitable] || self.pagingEnabled) {
                x = ([self width] + self.cellMargin) * i;
                rect = CGRectMake(x, y, width, height);
            } else {
                width = [self widthForCellAtIndex:i];
                rect = CGRectMake(x, y, width, height);
                x += width;
            }
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
    
    if ([self infinitable] || self.pagingEnabled) {
        width = [self width];
        height = [self height];
        
        if (self.pageViewOrientation == KIPageViewVertical) {
            height += [self cellMargin];
            height *= [self numberWithInfinitCells];
        } else {
            width += [self cellMargin];
            width *= [self numberWithInfinitCells];
        }
    } else {
        for (int i=0; i<[self numberWithInfinitCells]; i++) {
            if (self.pageViewOrientation == KIPageViewVertical) {
                height += [self scaledRect:[self.rectForItems objectAtIndex:i]].size.height;
            } else {
                width += [self scaledRect:[self.rectForItems objectAtIndex:i]].size.width;
            }
        }
    }
    [self.scrollView setContentSize:CGSizeMake(width, height)];
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
    
    return [self indexWithInfiniteIndex:[cell _pageViewCellIndex]];
}

/*
 获取指定index的KIPageViewCell
 */
- (KIPageViewCell *)pageViewCellAtIndex:(NSInteger)index {
    if ([self indexOutOfBounds:index]) {
        return nil;
    }
    
    KIPageViewCell *cell = nil;
    if ([self infinitable]) {
        if (index == [self numberWithInfinitCells] - 2) {
            index = 0;
            cell = [self pageViewCellInReusableListWithIndex:index];
        } else if (index == 1) {
            index = [self numberWithInfinitCells] - 1;
            cell = [self pageViewCellInReusableListWithIndex:index];
        }
        if (cell != nil) {
            return cell;
        }
    }
    
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
    if ([self infinitable] && count > 1) {
        return count + 2;
    }
    return count;
}

- (BOOL)infinitable{
    if (self.scrollView.pagingEnabled && self.infinite) {
        return YES;
    }
    return NO;
}

#pragma mark **************************************************
#pragma mark 【将无限循环的index修正为常规的index】
#pragma mark **************************************************
- (NSInteger)indexWithInfiniteIndex:(NSInteger)index {
    if ([self infinitable] && [self numberWithInfinitCells] > 1) {
        if (index == [self numberWithInfinitCells] - 1) {
            index = 1;
        } else if (index == [self numberWithInfinitCells] - 2) {
            index = 0;
        }
    }
    return index;
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
        [self updateDidDisplayPageIndex:self.scrollView];
    } else {
        CGRect rect = [self rectForPageViewCellAtIndex:index];
        
        if ([self infinitable]) {
            //优化选中的滑动动画
            if ((index == 0 || index == 1) && self.pageIndexForCellInVisibileList > [self numberOfPages] / 2) {
                index = [self numberWithInfinitCells] - (2 - index);
                rect = [self rectForPageViewCellAtIndex:index];
            }
        }
        
        CGPoint offset = rect.origin;
        if ([self infinitable]) {
            [self.scrollView setContentOffset:offset animated:animated];
        } else {
            [self.scrollView scrollRectToVisible:rect animated:animated];
        }
    }
}

- (void)scrollToPageAtIndex:(NSInteger)pageIndex {
    [self scrollToPageViewCellAtIndex:pageIndex animated:YES];
}

- (void)scrollToNextPage {
    if ([self infinitable]) {
        NSInteger index = self.pageIndexForCellInVisibileList;
        if (index == 0) {
            index = [self numberWithInfinitCells] - 2;
        }
        [self scrollToPageViewCellAtIndex:++index animated:YES];
    }
}

- (void)scrollToPreviousPage {
    if ([self infinitable]) {
        NSInteger index = self.pageIndexForCellInVisibileList;
        if (index == 0) {
            index = [self numberWithInfinitCells] - 2;
        }
        [self scrollToPageViewCellAtIndex:--index animated:YES];
    }
}

- (void)selectCellAtIndex:(NSInteger)index animated:(BOOL)animated {
    if ([self indexOutOfBounds:index]) {
        return ;
    }
    
    NSInteger scrollToIndex = index;
    if ([self infinitable]) {
        
    }
    
    [self scrollToPageViewCellAtIndex:[self indexWithInfiniteIndex:scrollToIndex] animated:animated];
    
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
#pragma mark 【自动翻页】
#pragma mark **************************************************
- (void)flipOverWithTime:(NSUInteger)time {
    [self setTimeInterval:time];
    
    [self invalidTimer];
    
    if (self.timeInterval == 0) {
        return ;
    }
    
    if (![self infinitable]) {
        return ;
    }
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.timeInterval
                                                  target:self
                                                selector:@selector(scrollToNextPage)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)invalidTimer {
    if (self.timer != nil) {
        [self.timer invalidate];
    }
    self.timer = nil;
}

#pragma mark **************************************************
#pragma mark 【重新加载数据】
#pragma mark **************************************************
- (void)reloadData {
    [self setSelectedIndex:-1];
    [self setTotalPages:0];
    [self setPageIndexForCellInVisibileList:-1];
    [self setLastDisplayPageIndex:-1];
    
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
            
            if (self.pagingEnabled) {
                [self didEndDisplayingPage:index];
            } else {
                [self didEndDisplayingCell:item atIndex:index];
            }
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
                
                if ([self infinitable]) {
                    if (index == 0 && self.selectedIndex >=0 && self.selectedIndex == [self numberWithInfinitCells] - 2) {
                        [pageViewItem setSelected:YES animated:NO];
                    } else if (index == [self numberWithInfinitCells] - 1 && self.selectedIndex >=0 && self.selectedIndex == 1) {
                        [pageViewItem setSelected:YES animated:NO];
                    } else if (index == self.selectedIndex) {
                        [pageViewItem setSelected:YES animated:NO];
                    } else {
                        [pageViewItem setSelected:NO animated:NO];
                    }
                } else {
                    if (index == self.selectedIndex) {
                        [pageViewItem setSelected:YES animated:NO];
                    } else {
                        [pageViewItem setSelected:NO animated:NO];
                    }
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

- (void)updateDidDisplayPageIndex:(UIScrollView *)scrollView {
    if (!self.pagingEnabled) {
        return ;
    }
    
    NSInteger index = 0;
    if (self.pageViewOrientation == KIPageViewVertical) {
        index = scrollView.contentOffset.y / CGRectGetHeight(scrollView.frame);
    } else {
        index = scrollView.contentOffset.x / CGRectGetWidth(scrollView.frame);
    }
    
    if ([self infinitable]) {
        if (index == 0) {
            index = [self numberWithInfinitCells] - 2;
        } else if (index == [self numberWithInfinitCells] - 1) {
            index = 1;
        }
        [self.scrollView setContentOffset:[self rectForPageViewCellAtIndex:index].origin animated:NO];
    }
    
    if (index >= 0 && self.lastDisplayPageIndex != index) {
        [self setLastDisplayPageIndex:index];
        [self didDisplayPage:index];
    }
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
            if (_changeDirection == 0) {
                if (fabs(_changedPoint.y-_beganPoint.y) == fabs(_changedPoint.x-_beganPoint.x)) break;
                _changeDirection = fabs(_changedPoint.y-_beganPoint.y) > fabs(_changedPoint.x-_beganPoint.x) ? 1 : 2;
            }
            
            switch (_changeDirection) {
                case 1: {
                    _YRatio = _YRatio*(pinGesture.scale*_beganScrollSize.height/_scrollView.contentSize.height);
                    _scrollView.contentSize = CGSizeMake(_scrollView.contentSize.width, pinGesture.scale*_beganScrollSize.height);
                }
                    break;
                case 2: {
                    _XRatio = _XRatio*(pinGesture.scale*_beganScrollSize.width/_scrollView.contentSize.width);
                    _scrollView.contentSize = CGSizeMake(pinGesture.scale*_beganScrollSize.width, _scrollView.contentSize.height);
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
            CGPoint endPoint = [pinGesture locationInView:_scrollView];
            NSLog(@"Ended:%f,%f",endPoint.x,endPoint.y);
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
}
- (void)updatePageViewItemsFromOffset:(CGPoint)offset {
    if (offset.x < 0 || offset.y < 0) {
        return ;
    }
    
    NSUInteger firstNeededPageIndex = 0;
    NSUInteger lastNeededPageIndex = 0;
    if (self.scrollView.pagingEnabled) {
        CGRect visibleBounds = self.scrollView.bounds;
        if (CGRectIsEmpty(visibleBounds)) {
            return ;
        }
        
        if (self.pageViewOrientation == KIPageViewVertical) {
            firstNeededPageIndex = floorf(CGRectGetMinY(visibleBounds) / CGRectGetHeight(visibleBounds));
            lastNeededPageIndex  = floorf((CGRectGetMaxY(visibleBounds)-1) / CGRectGetHeight(visibleBounds));
        } else {
            firstNeededPageIndex = floorf(CGRectGetMinX(visibleBounds) / CGRectGetWidth(visibleBounds));
            lastNeededPageIndex  = floorf((CGRectGetMaxX(visibleBounds)-1) / CGRectGetWidth(visibleBounds));
        }
        
        firstNeededPageIndex = MAX(firstNeededPageIndex, 0);
        lastNeededPageIndex  = MIN(lastNeededPageIndex, [self numberWithInfinitCells] - 1);
    } else {
        //第一项的index
        firstNeededPageIndex = 0;
        CGFloat referValue = self.pageViewOrientation == KIPageViewVertical ? offset.y : offset.x;
        firstNeededPageIndex = [self halfSearchFirst:firstNeededPageIndex rightIndex:[self numberWithInfinitCells] referValue:referValue];
        //最后一项的index
        CGRect lastRect = [self scaledRect:[self.rectForItems objectAtIndex:firstNeededPageIndex]];
        CGFloat leftValue = self.pageViewOrientation == KIPageViewVertical ? lastRect.origin.y : lastRect.origin.x;
        CGFloat rightValue = self.pageViewOrientation == KIPageViewVertical ? self.bounds.size.height : self.bounds.size.width;
        lastNeededPageIndex = [self halfSearchLast:lastNeededPageIndex rightIndex:[self numberWithInfinitCells] leftReferValue:leftValue referValue:rightValue];
        
        firstNeededPageIndex = MAX(firstNeededPageIndex, 0);
        lastNeededPageIndex  = MIN(lastNeededPageIndex, [self numberWithInfinitCells]-1);
    }
    
    [self setPageIndexForCellInVisibileList:firstNeededPageIndex];
    
    [self recycleItemsWithoutIndex:firstNeededPageIndex toIndex:lastNeededPageIndex];
    [self reloadItemAtIndex:firstNeededPageIndex toIndex:lastNeededPageIndex];
}

- (NSInteger)halfSearchFirst:(NSInteger)leftIndex rightIndex:(NSInteger)rightIndex referValue:(CGFloat)referValue {
    NSInteger midIndex = (leftIndex + rightIndex)/2;
    CGRect rect = [self scaledRect:[self.rectForItems objectAtIndex:midIndex]];
    CGFloat min = 0, max = 0;
    if (self.pageViewOrientation == KIPageViewVertical) {
        min = rect.origin.y;
        max = min + rect.size.height;
    } else {
        min = rect.origin.x;
        max = min + rect.size.width;
    }
    if (min <= referValue && max > referValue) {
        return midIndex;
    } else if (min < referValue) {
        return [self halfSearchFirst:midIndex+1 rightIndex:rightIndex referValue:referValue];
    } else {
        return [self halfSearchFirst:leftIndex rightIndex:midIndex-1 referValue:referValue];
    }
}
- (NSInteger)halfSearchLast:(NSInteger)leftIndex rightIndex:(NSInteger)rightIndex leftReferValue:(CGFloat)leftValue referValue:(CGFloat)referValue {
    NSInteger midIndex = (leftIndex + rightIndex)/2;
    CGRect rect = [self scaledRect:[self.rectForItems objectAtIndex:midIndex]];
    CGFloat min = 0, max = 0;
    if (self.pageViewOrientation == KIPageViewVertical) {
        min = rect.origin.y;
        max = min + rect.size.height;
    } else {
        min = rect.origin.x;
        max = min + rect.size.width;
    }
    if (min-leftValue <= referValue && max-leftValue > referValue) {
        return midIndex+1;
    } else if (min-leftValue < referValue) {
        return [self halfSearchLast:midIndex+1 rightIndex:rightIndex leftReferValue:leftValue referValue:referValue];
    } else {
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
    [self invalidTimer];
}

- (void)setInfinite:(BOOL)infinite {
    if (_infinite == infinite) {
        return ;
    }
    
    _infinite = infinite;
    if (_infinite) {
        [self.scrollView setPagingEnabled:YES];
    }
    
    [self setNeedsLayout];
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

- (void)setPagingEnabled:(BOOL)pagingEnabled {
    if (self.scrollView.pagingEnabled == pagingEnabled) {
        return ;
    }
    
    [self.scrollView setPagingEnabled:pagingEnabled];
    
    [self setNeedsLayout];
}

- (BOOL)pagingEnabled {
    return self.scrollView.pagingEnabled;
}

- (void)setCellMargin:(NSInteger)itemMargin {
    if (_cellMargin == itemMargin) {
        return ;
    }
    
    _cellMargin = itemMargin;
    
    [self setNeedsLayout];
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
