#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// Иконки с яркостью краёв выше порога считаются «светлыми» и инвертируются
static const CGFloat kLightThreshold = 0.62;
// Затемнение для остальных иконок (0.0 - без изменений)
static const CGFloat kDimAlpha = 0.20;
static const NSInteger kOverlayTag = 0xDA12;

typedef struct {
    float m11, m12, m13, m14, m15;
    float m21, m22, m23, m24, m25;
    float m31, m32, m33, m34, m35;
    float m41, m42, m43, m44, m45;
} CAColorMatrix;

@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end

@interface SBIconImageView : UIView
@end

// Инверсия + поворот оттенка на 180°: светлый фон становится тёмным,
// цветной значок остаётся примерно того же оттенка
static NSArray *invertHueFilters(void) {
    static NSArray *filters = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class cls = NSClassFromString(@"CAFilter");
        if (!cls) return;
        id filter = [cls filterWithType:@"colorMatrix"];
        CAColorMatrix m = {
             0.574f, -1.430f, -0.144f, 0.0f, 1.0f,
            -0.426f, -0.430f, -0.144f, 0.0f, 1.0f,
            -0.426f, -1.430f,  0.856f, 0.0f, 1.0f,
             0.0f,    0.0f,    0.0f,   1.0f, 0.0f
        };
        [filter setValue:[NSValue valueWithBytes:&m objCType:"{CAColorMatrix=ffffffffffffffffffff}"]
                  forKey:@"inputColorMatrix"];
        filters = @[filter];
    });
    return filters;
}

// Средняя яркость по краю иконки (0..1), прозрачные углы пропускаются
static CGFloat edgeLuminance(CALayer *layer, CGSize size) {
    const int N = 16;
    uint8_t buf[N * N * 4];
    memset(buf, 0, sizeof(buf));

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(buf, N, N, 8, N * 4, cs,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    if (!ctx) return 0;

    CGContextScaleCTM(ctx, N / size.width, N / size.height);
    [layer renderInContext:ctx];
    CGContextRelease(ctx);

    double sum = 0;
    int count = 0;
    for (int y = 0; y < N; y++) {
        for (int x = 0; x < N; x++) {
            if (!(x < 2 || x >= N - 2 || y < 2 || y >= N - 2)) continue;
            int i = (y * N + x) * 4;
            double a = buf[i + 3];
            if (a < 128) continue;
            double r = buf[i] * 255.0 / a;
            double g = buf[i + 1] * 255.0 / a;
            double b = buf[i + 2] * 255.0 / a;
            sum += (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
            count++;
        }
    }
    return count ? (CGFloat)(sum / count) : 0;
}

%hook SBIconImageView

- (void)layoutSubviews {
    %orig;

    CGSize size = self.bounds.size;
    if (size.width < 10 || size.height < 10) return;

    UIView *overlay = [self viewWithTag:kOverlayTag];
    if (!overlay) {
        overlay = [[UIView alloc] initWithFrame:CGRectZero];
        overlay.tag = kOverlayTag;
        overlay.userInteractionEnabled = NO;
        overlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kDimAlpha];
        overlay.layer.cornerCurve = kCACornerCurveContinuous;
        overlay.layer.masksToBounds = YES;
        [self addSubview:overlay];
    }
    overlay.frame = self.bounds;
    overlay.layer.cornerRadius = size.width * 0.2237;
    [self bringSubviewToFront:overlay];

    // Снимаем эффекты перед замером яркости
    self.layer.filters = nil;
    overlay.hidden = YES;
    CGFloat lum = edgeLuminance(self.layer, size);

    if (lum > kLightThreshold) {
        self.layer.filters = invertHueFilters();
        overlay.hidden = YES;
    } else {
        overlay.hidden = NO;
    }
}

%end
