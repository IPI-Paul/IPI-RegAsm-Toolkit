using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;

public class WatermarkAdorner : Adorner
{
    private string _watermark;

    public string Watermark {
        get { return _watermark; }
        set {
            _watermark = value;

            // Forces OnRender to run again
            InvalidateVisual();
        }
    }

    public WatermarkAdorner(UIElement adornedElement, string watermark) : base(adornedElement)
    {
        IsHitTestVisible = false;
        _watermark = watermark;
    }

    protected override void OnRender(DrawingContext drawingContext)
    {
    var tb = AdornedElement as TextBox;
    if (tb != null && string.IsNullOrEmpty(tb.Text))
        {
            var dpi = VisualTreeHelper.GetDpi(this);

            var formattedText = new FormattedText (
                _watermark,
                System.Globalization.CultureInfo.CurrentCulture,
                FlowDirection.LeftToRight,
                new Typeface(tb.FontFamily, tb.FontStyle, tb.FontWeight, tb.FontStretch),
                tb.FontSize,
                Brushes.Gray,
                dpi.PixelsPerDip
            );

            drawingContext.DrawText(formattedText, new Point(5, 2));
        }
    }
}

public static class WatermarkService 
{
    public static readonly DependencyProperty WatermarkProperty = 
        DependencyProperty.RegisterAttached(
            "Watermark",
            typeof(string),
            typeof(WatermarkService),
            new PropertyMetadata("", OnWatermarkChanged));

    public static void SetWatermark(Control element, string value)
    {
        AdornerLayer layer = AdornerLayer.GetAdornerLayer(element);
        if (layer == null) return;

        // Try to find an existing WatermarkAdorner
        Adorner[] adorners = layer.GetAdorners(element);
        WatermarkAdorner existing = null;

        if (adorners != null) {
            foreach (var adorner in adorners) {
                if (adorner is WatermarkAdorner) {
                    existing = (WatermarkAdorner)adorner;
                    break;
                }
            }
        }

        if (existing != null) {
            // Update existing instead of adding a new one
            existing.Watermark = value;
        } else {
            // element.SetValue(WatermarkProperty, value);
            WatermarkAdorner newAdorner = new WatermarkAdorner(element, value);
            layer.Add(newAdorner);
            layer.Update();

            ((TextBox)element).TextChanged += delegate { newAdorner.InvalidateVisual(); };
        }
    }

    public static string GetWatermark(DependencyObject element)
    {
        return (string)element.GetValue(WatermarkProperty);
    }

    private static void OnWatermarkChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        TextBox tb = d as TextBox;
        if (tb != null)
        {
            tb.Loaded += (s, ev) =>
            {
                var layer = AdornerLayer.GetAdornerLayer(tb);
                if (layer != null)
                {
                    layer.Add(new WatermarkAdorner(tb, GetWatermark(tb)));
                }
            };

            tb.TextChanged += (s, ev) =>
            {
                var layer = AdornerLayer.GetAdornerLayer(tb);
                if (layer != null)
                {
                    layer.Update(tb);
                }
            };
        }
    }
}