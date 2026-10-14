unit Ghbdtn.Colors;

interface

uses
  System.UITypes,
  Ghbdtn.Layout;

{ Badge colors shared by the tray icon and the hint at the caret: Russian is
  orange with black letters, English is blue with white letters, anything
  else is gray. }
function BadgeColorFor(ALang: TLangKind): TColor;
function BadgeInkFor(ALang: TLangKind): TColor;

{ A darker shade of the same hue. The badge border uses it, so the edge reads
  on both light and dark taskbars without depending on the Windows theme. }
function DarkerShade(AColor: TColor): TColor;

implementation

uses
  Winapi.Windows;

const
  BorderBrightness = 0.6;

function BadgeColorFor(ALang: TLangKind): TColor;
begin
  case ALang of
    lkRU: Result := TColor(RGB(247, 152, 27));
    lkEN: Result := TColor(RGB(36, 104, 214));
  else
    Result := TColor(RGB(128, 128, 128));
  end;
end;

function BadgeInkFor(ALang: TLangKind): TColor;
begin
  if ALang = lkRU then
    Result := TColor(RGB(0, 0, 0))
  else
    Result := TColor(RGB(255, 255, 255));
end;

function DarkerShade(AColor: TColor): TColor;
var
  Channels: Integer;
begin
  Channels := Integer(AColor) and $FFFFFF;
  Result := TColor(RGB(
    Round(GetRValue(Channels) * BorderBrightness),
    Round(GetGValue(Channels) * BorderBrightness),
    Round(GetBValue(Channels) * BorderBrightness)));
end;

end.
