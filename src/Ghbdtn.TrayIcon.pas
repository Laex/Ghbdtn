unit Ghbdtn.TrayIcon;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Ghbdtn.Colors,
  Ghbdtn.Layout;

{ APaused adds a contrasting dot in the lower right corner of the badge. }
procedure UpdateTrayIconLang(ATrayIcon: TTrayIcon; ALang: TLangKind;
  APaused: Boolean = False);

implementation

const
  // Squared channel distance from the badge fill. ClearType fringes stay
  // under it; the letter stroke does not.
  cBadgeInkDistance = 2500;

procedure SelectBadgeFont(ACanvas: TCanvas; AIconH, AExtra: Integer;
  AInk: TColor; AScale: Double);
begin
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Height := -Round(AIconH * AScale);
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Color := AInk;
  SetBkMode(ACanvas.Handle, Winapi.Windows.TRANSPARENT);
  SetTextCharacterExtra(ACanvas.Handle, AExtra);
end;

function RightInkColumn(const AText: string; AIconW, AIconH, AExtra: Integer;
  ABadge: TColor; AScale: Double): Integer;
var
  Bmp: TBitmap;
  X, Y, BR, BG, BB, DR, DG, DB: Integer;
  Row: PByte;
  R: TRect;
  Ref: TColor;
begin
  Result := -1;
  if (AText = '') or (AIconW <= 0) or (AIconH <= 0) then
    Exit;

  Ref := ColorToRGB(ABadge);
  BR := Ref and $FF;
  BG := (Ref shr 8) and $FF;
  BB := (Ref shr 16) and $FF;

  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(AIconW, AIconH);
    Bmp.PixelFormat := pf24bit;
    Bmp.Canvas.Brush.Color := ABadge;
    Bmp.Canvas.Brush.Style := bsSolid;
    Bmp.Canvas.FillRect(Rect(0, 0, AIconW, AIconH));
    SelectBadgeFont(Bmp.Canvas, AIconH, AExtra, clBlack, AScale);
    R := Rect(0, 0, AIconW, AIconH);
    DrawText(Bmp.Canvas.Handle, PChar(AText), Length(AText), R,
      DT_CENTER or DT_VCENTER or DT_SINGLELINE);
    for Y := 0 to AIconH - 1 do
    begin
      Row := Bmp.ScanLine[Y];
      for X := 0 to AIconW - 1 do
      begin
        DB := Integer(Row[X * 3]) - BB;
        DG := Integer(Row[X * 3 + 1]) - BG;
        DR := Integer(Row[X * 3 + 2]) - BR;
        if (DR * DR + DG * DG + DB * DB >= cBadgeInkDistance) and (X > Result) then
          Result := X;
      end;
    end;
  finally
    Bmp.Free;
  end;
end;

procedure UpdateTrayIconLang(ATrayIcon: TTrayIcon; ALang: TLangKind;
  APaused: Boolean);
var
  ColorBmp, MaskBmp: TBitmap;
  IconInfo: TIconInfo;
  HResIcon: HICON;
  TempIcon: TIcon;
  TextStr: string;
  R: TRect;
  IconW, IconH, CornerRadius, Extra, DotSize: Integer;
  BadgeColor, InkColor, BorderColor: TColor;
  FontScale: Double;
begin
  if (ATrayIcon = nil) then Exit;

  TextStr := LangKindToString(ALang);

  // System small icon size.
  IconW := GetSystemMetrics(SM_CXSMICON);
  IconH := GetSystemMetrics(SM_CYSMICON);
  if IconW < 16 then IconW := 16;
  if IconH < 16 then IconH := 16;

  CornerRadius := Round(IconW * 0.25);
  // Each layout has its own badge color, so a glance at the tray is enough.
  BadgeColor := BadgeColorFor(ALang);
  InkColor := BadgeInkFor(ALang);
  BorderColor := DarkerShade(BadgeColor);
  // The English letters are drawn larger than the Russian ones.
  if ALang = lkEN then
    FontScale := 0.75
  else
    FontScale := 0.65;

  ColorBmp := TBitmap.Create;
  MaskBmp := TBitmap.Create;
  try
    // Color bitmap of the badge.
    ColorBmp.SetSize(IconW, IconH);
    ColorBmp.PixelFormat := pf24bit;

    ColorBmp.Canvas.Brush.Color := clBlack;
    ColorBmp.Canvas.Brush.Style := bsSolid;
    ColorBmp.Canvas.FillRect(Rect(0, 0, IconW, IconH));

    ColorBmp.Canvas.Brush.Color := BadgeColor;
    ColorBmp.Canvas.Brush.Style := bsSolid;
    ColorBmp.Canvas.Pen.Color := BorderColor;
    ColorBmp.Canvas.Pen.Width := 1;
    ColorBmp.Canvas.RoundRect(0, 0, IconW, IconH, CornerRadius, CornerRadius);

    // The frame owns the last column. DrawText centers the advance width,
    // so a wider label keeps its extra pixel on the right and the stroke
    // meets the frame. Negative character extra closes that gap and leaves
    // an orange column before the frame.
    Extra := 0;
    while (Extra > -2) and
      (RightInkColumn(TextStr, IconW, IconH, Extra, BadgeColor, FontScale) >= IconW - 2) do
      Dec(Extra);

    SelectBadgeFont(ColorBmp.Canvas, IconH, Extra, InkColor, FontScale);
    R := Rect(0, 0, IconW, IconH);
    DrawText(ColorBmp.Canvas.Handle, PChar(TextStr), Length(TextStr), R,
      DT_CENTER or DT_VCENTER or DT_SINGLELINE);

    if APaused then
    begin
      // Red with a white ring: visible on the orange badge and on both
      // light and dark taskbars.
      DotSize := Round(IconW * 0.45);
      ColorBmp.Canvas.Brush.Color := RGB(214, 20, 20);
      ColorBmp.Canvas.Brush.Style := bsSolid;
      ColorBmp.Canvas.Pen.Color := clWhite;
      ColorBmp.Canvas.Pen.Width := 1;
      ColorBmp.Canvas.Ellipse(IconW - DotSize - 1, IconH - DotSize - 1,
        IconW - 1, IconH - 1);
    end;

    // Monochrome mask: white is transparent, black is opaque.
    MaskBmp.SetSize(IconW, IconH);
    MaskBmp.PixelFormat := pf1bit;

    MaskBmp.Canvas.Brush.Color := clWhite;
    MaskBmp.Canvas.Brush.Style := bsSolid;
    MaskBmp.Canvas.FillRect(Rect(0, 0, IconW, IconH));

    MaskBmp.Canvas.Brush.Color := clBlack;
    MaskBmp.Canvas.Brush.Style := bsSolid;
    MaskBmp.Canvas.Pen.Color := clBlack;
    MaskBmp.Canvas.Pen.Width := 1;
    MaskBmp.Canvas.RoundRect(0, 0, IconW, IconH, CornerRadius, CornerRadius);

    // Build the HICON.
    FillChar(IconInfo, SizeOf(IconInfo), 0);
    IconInfo.fIcon := TRUE;
    IconInfo.xHotspot := 0;
    IconInfo.yHotspot := 0;
    IconInfo.hbmMask := MaskBmp.Handle;
    IconInfo.hbmColor := ColorBmp.Handle;

    HResIcon := CreateIconIndirect(IconInfo);
    if HResIcon <> 0 then
    begin
      TempIcon := TIcon.Create;
      try
        TempIcon.Handle := HResIcon;
        ATrayIcon.Icon := TempIcon;
      finally
        TempIcon.Free;
      end;
    end;

    ATrayIcon.Hint := 'Ghbdtn [' + TextStr + ']';
    if not ATrayIcon.Visible then
      ATrayIcon.Visible := True;
  finally
    MaskBmp.Free;
    ColorBmp.Free;
  end;
end;

end.
