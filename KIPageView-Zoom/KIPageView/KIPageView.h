//
//  KIPageView.h
//  KIPageView
//
//  Created by SmartWalle on 15/8/14.
//  Copyright (c) 2015年 SmartWalle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KIPageViewCell.h"

@class KIPageView;

#pragma mark - Typedef - KIPageViewOrientation
typedef NS_OPTIONS(NSUInteger, KIPageViewOrientation) {
    KIPageViewHorizontal = 1,
    KIPageViewVertical   = 2,
};

#pragma mark - Protocol - KIPageViewDelegate
@protocol KIPageViewDelegate <NSObject>

@required
- (NSInteger)numberOfCellsInPageView:(KIPageView *)pageView;
- (KIPageViewCell *)pageView:(KIPageView *)pageView cellAtIndex:(NSInteger)index;

@optional
- (void)pageView:(KIPageView *)pageView willDisplayCell:(KIPageViewCell *)pageViewCell atIndex:(NSInteger)index;
- (void)pageView:(KIPageView *)pageView didEndDisplayingCell:(KIPageViewCell *)pageViewCell atIndex:(NSInteger)index;

- (CGFloat)pageView:(KIPageView *)pageView widthForCellAtIndex:(NSInteger)index;
- (CGFloat)pageView:(KIPageView *)pageView heightForCellAtIndex:(NSInteger)index;

- (void)pageView:(KIPageView *)pageView didSelectedCellAtIndex:(NSInteger)index;
- (void)pageView:(KIPageView *)pageView didDeselectedCellAtIndex:(NSInteger)index;

@end


#pragma mark - Interface - KIPageView
@interface KIPageView : UIView

@property (nonatomic, assign) id<KIPageViewDelegate>    delegate;

@property (nonatomic, assign) BOOL                      scrollEnabled;
@property (nonatomic, assign) BOOL                      bounces;
@property (nonatomic, assign) BOOL                      scrollsToTop;

- (instancetype)initWithOrientation:(KIPageViewOrientation)orientation;

- (KIPageViewOrientation)pageViewOrientation;

- (NSInteger)numberOfPages;

- (CGRect)rectForPageViewCellAtIndex:(NSInteger)index;

- (NSInteger)indexOfPageViewCell:(KIPageViewCell *)item;

- (KIPageViewCell *)pageViewCellAtIndex:(NSInteger)index;

- (KIPageViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier;

- (void)scrollToPageViewCellAtIndex:(NSInteger)index;
- (void)scrollToPageViewCellAtIndex:(NSInteger)index animated:(BOOL)animated;

- (void)selectCellAtIndex:(NSInteger)index animated:(BOOL)animated;
- (void)deselectCellAtIndex:(NSInteger)index animated:(BOOL)animated;

- (void)reloadData;

@end
