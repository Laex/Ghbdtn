unit Ghbdtn.CaretHint;

interface

uses
  Winapi.Windows,
  System.Types,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Ghbdtn.Layout;

procedure ShowCaretHint(ALang: TLangKind; const ANote: string = '');
{ Shows a short message at the caret without a layout tag. Safe to call
  from any thread. }
procedure ShowCaretNote(const ANote: string);

implementation

uses
  Winapi.Messages,
  Winapi.ActiveX,
  System.SysUtils,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  Winapi.UIAutomation,
  Ghbdtn.Colors,
  Ghbdtn.Settings;

const
  HintWidth = 42;
  HintHeight = 22;
  HintVisibleMs = 1100;
  HintFlashMs = 380;
  // A bare message without a layout is dark gray; the layouts use the colors
  // of the tray badge.
  HintNoteColor = $00464646;

type
  TCaretHintForm = class(TForm)
  private
    FHideAt: UInt64;
    FAnchorWindow: HWND;
    FShown: Boolean;
    FDragging: Boolean;
    FDragOrigin: TPoint;
    FDragAnchor: TPoint;
    FOffsetOrigin: TPoint;
    FAppearedAt: UInt64;
    FNote: string;
    FLang: TLangKind;
    FNoteUntil: UInt64;
    FTimer: TTimer;
    procedure HideHint;
    procedure PlaceAtCaret;
    function HintBaseColor: TColor;
    function HintInkColor: TColor;
    function HintFillColor: TColor;
    function HintScale: Double;
    function FlashActive: Boolean;
    procedure TimerTick(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ShowLanguage(ALang: TLangKind; const ANote: string);
  end;

var
  HintForm: TCaretHintForm;
  HintOwner: HWND;

function HintOwnerWindow: HWND;
begin
  if HintOwner = 0 then
    HintOwner := CreateWindowEx(WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE, 'Static',
      nil, WS_POPUP, 0, 0, 0, 0, 0, 0, HInstance, nil);
  Result := HintOwner;
end;

procedure ApplyNoTaskbarStyle(AWindow: HWND);
var
  ExStyle: NativeInt;
begin
  if AWindow = 0 then
    Exit;
  ExStyle := GetWindowLong(AWindow, GWL_EXSTYLE);
  ExStyle := (ExStyle or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE or WS_EX_TOPMOST)
    and not WS_EX_APPWINDOW;
  SetWindowLong(AWindow, GWL_EXSTYLE, ExStyle);
end;

function TryGetWin32Caret(out APoint: TPoint): Boolean;
var
  Foreground: HWND;
  Info: TGUIThreadInfo;
  ThreadId: DWORD;
begin
  Result := False;
  APoint := Point(0, 0);
  Foreground := GetForegroundWindow;
  if Foreground = 0 then
    Exit;
  ThreadId := GetWindowThreadProcessId(Foreground, nil);
  ZeroMemory(@Info, SizeOf(Info));
  Info.cbSize := SizeOf(Info);
  if not GetGUIThreadInfo(ThreadId, Info) then
    Exit;
  if Info.hwndCaret = 0 then
    Exit;
  APoint := Info.rcCaret.TopLeft;
  if not ClientToScreen(Info.hwndCaret, APoint) then
    Exit;
  Result := True;
end;

function AutomationClient: IUIAutomation;
const
  CLSCTX_INPROC_SERVER = 1;
begin
  Result := nil;
  if Failed(CoCreateInstance(CLSID_CUIAutomation, nil, CLSCTX_INPROC_SERVER,
    IUIAutomation, Result)) then
    Result := nil;
end;

function RectFromBoundingArray(Rects: PSafeArray; out APoint: TPoint): Boolean;
var
  Lower, Upper, Coord, Index: Integer;
  Value: Double;
  Values: array[0..3] of Double;
begin
  Result := False;
  APoint := Point(0, 0);
  if Rects = nil then
    Exit;
  if Failed(SafeArrayGetLBound(Rects, 1, Lower)) or
     Failed(SafeArrayGetUBound(Rects, 1, Upper)) then
    Exit;
  if Upper - Lower + 1 < 4 then
    Exit;
  for Index := 0 to 3 do
  begin
    Coord := Lower + Index;
    Value := 0;
    if Failed(SafeArrayGetElement(Rects, Coord, Value)) then
      Exit;
    Values[Index] := Value;
  end;
  if (Values[2] <= 0) and (Values[3] <= 0) then
    Exit;
  APoint := Point(Round(Values[0]), Round(Values[1]));
  Result := True;
end;

function TryGetAutomationCaret(out APoint: TPoint): Boolean;
type
  TGetBoundingRectangles = function(This: Pointer; out Rects: PSafeArray): HRESULT; stdcall;
var
  Client: IUIAutomation;
  Element: IUIAutomationElement;
  Pattern: IUIAutomationTextPattern2;
  Range: IUIAutomationTextRange;
  PatternPtr: Pointer;
  PatternId: TGUID;
  Active: BOOL;
  Rects: PSafeArray;
  VTable: PPointer;
  ReadRects: TGetBoundingRectangles;
begin
  Result := False;
  APoint := Point(0, 0);
  Client := AutomationClient;
  if Client = nil then
    Exit;
  Element := nil;
  if Failed(Client.GetFocusedElement(Element)) or (Element = nil) then
    Exit;
  PatternId := IUIAutomationTextPattern2;
  PatternPtr := nil;
  if Failed(Element.GetCurrentPatternAs(UIA_TextPattern2Id, @PatternId, PatternPtr)) or
     (PatternPtr = nil) then
    Exit;
  Pointer(Pattern) := PatternPtr;
  Range := nil;
  if Failed(Pattern.GetCaretRange(Active, Range)) or (Range = nil) then
    Exit;
  // The imported signature passes SAFEARRAY by value. The real method returns
  // a SAFEARRAY pointer, so call that slot directly.
  VTable := PPointer(Pointer(Range)^);
  Inc(VTable, 10);
  ReadRects := TGetBoundingRectangles(VTable^);
  Rects := nil;
  try
    if Failed(ReadRects(Pointer(Range), Rects)) then
      Exit;
    Result := RectFromBoundingArray(Rects, APoint);
  finally
    if Rects <> nil then
      SafeArrayDestroy(Rects);
  end;
end;

function TryGetCaretScreenPoint(out APoint: TPoint): Boolean;
begin
  Result := TryGetWin32Caret(APoint);
  if not Result then
  begin
    try
      Result := TryGetAutomationCaret(APoint);
    except
      Result := False;
    end;
  end;
  if not Result then
    Result := GetCursorPos(APoint);
end;

constructor TCaretHintForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  BorderStyle := bsNone;
  FormStyle := fsStayOnTop;
  FLang := lkEN;
  Color := BadgeColorFor(lkEN);
  Caption := 'EN';
  ClientWidth := HintWidth;
  ClientHeight := HintHeight;
  Position := poDesigned;
  Visible := False;
  OnMouseDown := FormMouseDown;
  OnMouseMove := FormMouseMove;
  OnMouseUp := FormMouseUp;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 80;
  FTimer.OnTimer := TimerTick;
  FTimer.Enabled := True;
  HandleNeeded;
end;

procedure TCaretHintForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := WS_POPUP;
  Params.ExStyle := (Params.ExStyle or WS_EX_TOPMOST or WS_EX_TOOLWINDOW or
    WS_EX_NOACTIVATE) and not WS_EX_APPWINDOW;
  Params.WndParent := HintOwnerWindow;
end;

procedure TCaretHintForm.CreateWnd;
begin
  inherited CreateWnd;
  ApplyNoTaskbarStyle(Handle);
end;

procedure TCaretHintForm.Paint;
var
  R: TRect;
begin
  Canvas.Brush.Color := HintFillColor;
  Canvas.FillRect(ClientRect);
  Canvas.Pen.Color := DarkerShade(HintBaseColor);
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, ClientWidth, ClientHeight);
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := HintInkColor;
  Canvas.Font.Height := -Round(14 * HintScale);
  R := ClientRect;
  DrawText(Canvas.Handle, PChar(Caption), Length(Caption), R,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE);
end;

function TCaretHintForm.FlashActive: Boolean;
begin
  Result := AppSettings.CaretHintFlash and (FAppearedAt <> 0) and
    (GetTickCount64 - FAppearedAt < HintFlashMs);
end;

function TCaretHintForm.HintScale: Double;
var
  Elapsed: UInt64;
begin
  Result := 1;
  if not AppSettings.CaretHintAnimate or (FAppearedAt = 0) then
    Exit;
  Elapsed := GetTickCount64 - FAppearedAt;
  if Elapsed >= HintFlashMs then
    Exit;
  Result := 1 + 0.28 * (1 - Elapsed / HintFlashMs);
end;

function TCaretHintForm.HintBaseColor: TColor;
begin
  if FLang in [lkRU, lkEN] then
    Result := BadgeColorFor(FLang)
  else
    Result := HintNoteColor;
end;

function TCaretHintForm.HintInkColor: TColor;
begin
  Result := BadgeInkFor(FLang);
end;

function TCaretHintForm.HintFillColor: TColor;
var
  Elapsed: UInt64;
  Amount: Double;
  NormalR, NormalG, NormalB: Integer;
  FlashR, FlashG, FlashB: Integer;
begin
  Result := HintBaseColor;
  if not FlashActive then
    Exit;
  Elapsed := GetTickCount64 - FAppearedAt;
  Amount := Elapsed / HintFlashMs;
  NormalR := GetRValue(HintBaseColor);
  NormalG := GetGValue(HintBaseColor);
  NormalB := GetBValue(HintBaseColor);
  case FLang of
    lkEN:
      begin
        FlashR := 190;
        FlashG := 215;
        FlashB := 255;
      end;
    lkRU:
      begin
        FlashR := 255;
        FlashG := 244;
        FlashB := 180;
      end;
  else
    FlashR := 200;
    FlashG := 200;
    FlashB := 200;
  end;
  Result := RGB(
    Round(FlashR + (NormalR - FlashR) * Amount),
    Round(FlashG + (NormalG - FlashG) * Amount),
    Round(FlashB + (NormalB - FlashB) * Amount));
end;

procedure TCaretHintForm.HideHint;
begin
  if HandleAllocated then
    ShowWindow(Handle, SW_HIDE);
  FShown := False;
  FHideAt := 0;
  FAnchorWindow := 0;
end;

procedure TCaretHintForm.PlaceAtCaret;
var
  Caret: TPoint;
  Scale: Double;
  Width, Height, ExtraX, ExtraY: Integer;
begin
  if FDragging then
    Caret := FDragAnchor
  else if not TryGetCaretScreenPoint(Caret) then
    Exit;
  Scale := HintScale;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Height := -14;
  ExtraX := Canvas.TextWidth(Caption) + 16;
  if ExtraX < HintWidth then
    ExtraX := HintWidth;
  Width := Round(ExtraX * Scale);
  Height := Round(HintHeight * Scale);
  ExtraX := (Width - ExtraX) div 2;
  ExtraY := (Height - HintHeight) div 2;
  ApplyNoTaskbarStyle(Handle);
  SetWindowPos(Handle, HWND_TOPMOST,
    Caret.X + AppSettings.CaretHintOffsetX - ExtraX,
    Caret.Y + AppSettings.CaretHintOffsetY - ExtraY,
    Width, Height,
    SWP_NOACTIVATE or SWP_SHOWWINDOW);
  FShown := True;
end;

procedure TCaretHintForm.ShowLanguage(ALang: TLangKind; const ANote: string);
var
  Note: string;
begin
  if AppSettings.CaretHintMode = chOff then
  begin
    HideHint;
    Exit;
  end;
  FLang := ALang;
  Note := ANote;
  if Note <> '' then
  begin
    FNote := Note;
    FNoteUntil := GetTickCount64 + 1600;
  end
  else if (FNote <> '') and (GetTickCount64 <= FNoteUntil) then
    Note := FNote
  else
    FNote := '';
  if ALang = lkRU then
    Caption := 'RU'
  else if ALang = lkEN then
    Caption := 'EN'
  else if Note = '' then
    Exit
  else
    Caption := '';
  if Note <> '' then
  begin
    if Caption <> '' then
      Caption := Caption + '  ';
    Caption := Caption + Note;
  end;
  FAnchorWindow := GetForegroundWindow;
  if AppSettings.CaretHintFlash or AppSettings.CaretHintAnimate then
    FAppearedAt := GetTickCount64
  else
    FAppearedAt := 0;
  if AppSettings.CaretHintMode = chTimed then
    FHideAt := GetTickCount64 + HintVisibleMs
  else
    FHideAt := 0;
  PlaceAtCaret;
  Invalidate;
end;

procedure TCaretHintForm.TimerTick(Sender: TObject);
begin
  if not FShown then
    Exit;
  if FDragging or ((GetAsyncKeyState(VK_SHIFT) and $8000) <> 0) then
  begin
    if FDragging then
      PlaceAtCaret;
    if FlashActive then
    begin
      PlaceAtCaret;
      Invalidate;
    end;
    Exit;
  end;
  if (AppSettings.CaretHintFlash or AppSettings.CaretHintAnimate) and
     (FAppearedAt <> 0) and
     (GetTickCount64 - FAppearedAt < HintFlashMs + 100) then
  begin
    PlaceAtCaret;
    Invalidate;
  end;
  if AppSettings.CaretHintMode = chOff then
  begin
    HideHint;
    Exit;
  end;
  if AppSettings.CaretHintMode = chFollow then
  begin
    if (FAnchorWindow = 0) or (GetForegroundWindow <> FAnchorWindow) then
      HideHint
    else
      PlaceAtCaret;
    Exit;
  end;
  if (FHideAt <> 0) and (GetTickCount64 >= FHideAt) then
    HideHint;
end;

procedure TCaretHintForm.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if (Button <> mbLeft) or not (ssShift in Shift) then
    Exit;
  FDragging := True;
  GetCursorPos(FDragOrigin);
  if not TryGetCaretScreenPoint(FDragAnchor) then
    FDragAnchor := FDragOrigin;
  FOffsetOrigin := Point(AppSettings.CaretHintOffsetX, AppSettings.CaretHintOffsetY);
  SetCapture(Handle);
end;

procedure TCaretHintForm.FormMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  CursorPos: TPoint;
begin
  if not FDragging then
    Exit;
  GetCursorPos(CursorPos);
  AppSettings.CaretHintOffsetX := FOffsetOrigin.X + CursorPos.X - FDragOrigin.X;
  AppSettings.CaretHintOffsetY := FOffsetOrigin.Y + CursorPos.Y - FDragOrigin.Y;
  PlaceAtCaret;
end;

procedure TCaretHintForm.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if not FDragging then
    Exit;
  FDragging := False;
  ReleaseCapture;
  AppSettings.SaveToFile;
  FHideAt := GetTickCount64 + HintVisibleMs;
end;

procedure ShowCaretHint(ALang: TLangKind; const ANote: string);
begin
  if HintForm = nil then
    HintForm := TCaretHintForm.Create(nil);
  HintForm.ShowLanguage(ALang, ANote);
end;

procedure ShowCaretNote(const ANote: string);
begin
  if GetCurrentThreadId = MainThreadID then
    ShowCaretHint(lkUnknown, ANote)
  else
    TThread.Queue(nil,
      procedure
      begin
        ShowCaretHint(lkUnknown, ANote);
      end);
end;

initialization
  HintForm := nil;
  HintOwner := 0;

finalization
  FreeAndNil(HintForm);
  if HintOwner <> 0 then
    DestroyWindow(HintOwner);

end.
