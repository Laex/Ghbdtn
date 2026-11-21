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
{ Starts the label beside the mouse pointer: a dot in the color of the current
  layout or the letters en/EN. It follows AppSettings.MouseMarker, so the
  setting takes effect without a restart. Call from the main thread. }
procedure StartMouseMarker;

implementation

uses
  Winapi.Messages,
  Winapi.ActiveX,
  System.SysUtils,
  System.SyncObjs,
  System.Diagnostics,
  System.Math,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  Winapi.UIAutomation,
  Ghbdtn.Colors,
  Ghbdtn.Fullscreen,
  Ghbdtn.Settings;

const
  MarkerAlpha = 210;
  // Polled often so the label keeps up with the mouse.
  MouseMarkerPollMs = 40;
  // While the dot is catching up with the pointer it is moved every frame.
  MouseMarkerFrameMs = 16;
  // Time constant of the dot's approach to the pointer: after this long it has
  // covered about 63 percent of the gap.
  MouseDotLagMs = 55;
  MouseDotMaxStepMs = 100;
  MouseDotSize = 9;
  MouseTextWidth = 26;
  MouseTextHeight = 16;
  MouseMarkerOffsetX = 14;
  MouseMarkerOffsetY = 16;
  MarkerFullscreenCheckMs = 500;
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
    FShownAt: UInt64;
    FNote: string;
    FLang: TLangKind;
    FNoteUntil: UInt64;
    FTimer: TTimer;
    procedure HideHint;
    procedure PlaceAtCaret;
    procedure FollowTick;
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
    { AQuiet refreshes the text without the appear flash and animation. }
    procedure ShowLanguage(ALang: TLangKind; const ANote: string;
      AQuiet: Boolean = False);
  end;

  { Click-through label beside the mouse pointer in the color of the layout.
    Unlike the hint it is not tied to a layout change: it is drawn for as long
    as the foreground layout is known. }
  TMouseMarkerForm = class(TForm)
  private
    FLang: TLangKind;
    FCaps: Boolean;
    FMode: TMouseMarkerMode;
    FModeApplied: Boolean;
    FShown: Boolean;
    FFullscreen: Boolean;
    FFullscreenTick: UInt64;
    FTimer: TTimer;
    FStateTick: UInt64;
    FWantShow: Boolean;
    FSmooth: Boolean;
    FPosX, FPosY: Double;
    FStamp: Int64;
    FPlaced: TPoint;
    FFast: Boolean;
    procedure HideMarker;
    procedure ApplyMode(AMode: TMouseMarkerMode);
    function BlockedByFullscreen: Boolean;
    function RefreshState(out AMode: TMouseMarkerMode): Boolean;
    procedure SetTimerRate(AFast: Boolean);
    procedure TimerTick(Sender: TObject);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  HintForm: TCaretHintForm;
  MouseMarkerForm: TMouseMarkerForm;
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

var
  AutomationCaretTick: UInt64;
  AutomationCaretPoint: TPoint;
  AutomationCaretFound: Boolean;

const
  AutomationCaretCacheMs = 300;
  // An answer older than this is dropped: it belongs to a caret that has
  // probably moved or to a window that is no longer in front.
  AutomationCaretMaxAgeMs = 1500;

type
  { Runs the UI Automation caret query off the main thread. The query is a
    cross-process call that blocks for as long as the target application does
    not answer; on the main thread that would also stall the keyboard and
    mouse hooks. A stuck query leaves only this thread waiting, and callers
    keep getting the last answer until it expires. }
  TAutomationCaretWorker = class(TThread)
  private
    FWake: TEvent;
    FLock: TCriticalSection;
    FBusy: Boolean;
    FPoint: TPoint;
    FFound: Boolean;
    FAnswerTick: UInt64;
    FAnswerWindow: HWND;
  protected
    procedure Execute; override;
    procedure TerminatedSet; override;
  public
    constructor Create;
    destructor Destroy; override;
    function Poll(out APoint: TPoint): Boolean;
  end;

constructor TAutomationCaretWorker.Create;
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FWake := TEvent.Create(nil, False, False, '');
  FLock := TCriticalSection.Create;
end;

destructor TAutomationCaretWorker.Destroy;
begin
  FLock.Free;
  FWake.Free;
  inherited;
end;

procedure TAutomationCaretWorker.TerminatedSet;
begin
  inherited;
  FWake.SetEvent;
end;

procedure TAutomationCaretWorker.Execute;
var
  Init: HRESULT;
  Window: HWND;
  Point: TPoint;
  Found: Boolean;
begin
  Init := CoInitializeEx(nil, COINIT_MULTITHREADED);
  try
    while not Terminated do
    begin
      FWake.WaitFor(INFINITE);
      if Terminated then
        Break;
      Window := GetForegroundWindow;
      try
        Found := TryGetAutomationCaret(Point);
      except
        Found := False;
      end;
      FLock.Acquire;
      try
        FPoint := Point;
        FFound := Found;
        FAnswerWindow := Window;
        FAnswerTick := GetTickCount64;
        FBusy := False;
      finally
        FLock.Release;
      end;
    end;
  finally
    if (Init = S_OK) or (Init = S_FALSE) then
      CoUninitialize;
  end;
end;

{ Returns the last answer when it is recent and for the window now in front,
  and asks for a fresh one when the answer is stale and no query is running. }
function TAutomationCaretWorker.Poll(out APoint: TPoint): Boolean;
var
  Tick: UInt64;
  Window: HWND;
  Fresh, SameWindow, Wake: Boolean;
begin
  Tick := GetTickCount64;
  Window := GetForegroundWindow;
  FLock.Acquire;
  try
    SameWindow := FAnswerWindow = Window;
    Fresh := (FAnswerTick <> 0) and (Tick - FAnswerTick <= AutomationCaretMaxAgeMs);
    Wake := not FBusy and
      ((FAnswerTick = 0) or not SameWindow or
       (Tick - FAnswerTick > AutomationCaretCacheMs));
    if Wake then
      FBusy := True;
    Result := Fresh and SameWindow and FFound;
    if Result then
      APoint := FPoint
    else
      APoint := Point(0, 0);
  finally
    FLock.Release;
  end;
  if Wake then
    FWake.SetEvent;
end;

var
  AutomationWorker: TAutomationCaretWorker;

{ The follow timer reuses a recent answer instead of repeating the query every
  tick. With CaretAutomationBackground off the query runs on the main thread. }
function TryGetCachedAutomationCaret(out APoint: TPoint): Boolean;
var
  Tick: UInt64;
begin
  if AppSettings.CaretAutomationBackground then
  begin
    if AutomationWorker = nil then
    begin
      AutomationWorker := TAutomationCaretWorker.Create;
      AutomationWorker.Start;
    end;
    Exit(AutomationWorker.Poll(APoint));
  end;
  Tick := GetTickCount64;
  if (AutomationCaretTick = 0) or
     (Tick - AutomationCaretTick > AutomationCaretCacheMs) then
  begin
    try
      AutomationCaretFound := TryGetAutomationCaret(AutomationCaretPoint);
    except
      AutomationCaretFound := False;
    end;
    AutomationCaretTick := Tick;
  end;
  APoint := AutomationCaretPoint;
  Result := AutomationCaretFound;
end;

{ The text caret only; the mouse pointer is not a fallback. }
function TryGetTextCaret(out APoint: TPoint): Boolean;
begin
  Result := TryGetWin32Caret(APoint);
  if not Result then
    Result := TryGetCachedAutomationCaret(APoint);
end;

function TryGetCaretScreenPoint(out APoint: TPoint): Boolean;
begin
  Result := TryGetTextCaret(APoint);
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
  else if (AppSettings.MouseMarker <> mmOff) and (FLang <> lkUnknown) then
  begin
    // The mouse label already shows the layout at the pointer, so a layout
    // hint appears only where a text caret exists. A bare message keeps the
    // pointer fallback.
    if not TryGetTextCaret(Caret) then
    begin
      if FShown then
        HideHint;
      Exit;
    end;
  end
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

procedure TCaretHintForm.ShowLanguage(ALang: TLangKind; const ANote: string;
  AQuiet: Boolean);
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
  if ALang <> lkUnknown then
    Caption := LangLabel(ALang, IsCapsLockOn)
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
  if not AQuiet then
  begin
    FShownAt := GetTickCount64;
    if AppSettings.CaretHintFlash or AppSettings.CaretHintAnimate then
      FAppearedAt := FShownAt
    else
      FAppearedAt := 0;
  end;
  if AppSettings.CaretHintMode = chTimed then
    FHideAt := GetTickCount64 + HintVisibleMs
  else
    FHideAt := 0;
  PlaceAtCaret;
  Invalidate;
end;

{ Continuous mode: the badge stays at the text caret of the foreground window
  for as long as one is found, and follows layout and Caps Lock changes. Right
  after a layout change in a window without a text caret the badge stays for
  the usual time at the mouse pointer, where the hint is placed then; with the
  mouse label on there is no such fallback. }
procedure TCaretHintForm.FollowTick;
var
  Lang: TLangKind;
  Spot: TPoint;
  Tick: UInt64;
begin
  Lang := GetForegroundLangKind;
  if (Lang = lkUnknown) or not TryGetTextCaret(Spot) then
  begin
    if FShown and ((AppSettings.MouseMarker <> mmOff) or
       (GetTickCount64 - FShownAt > HintVisibleMs)) then
      HideHint;
    Exit;
  end;
  Tick := GetTickCount64;
  if (FNote <> '') and (Tick <= FNoteUntil) then
    PlaceAtCaret
  else if not FShown or (GetForegroundWindow <> FAnchorWindow) then
    ShowLanguage(Lang, '')
  else if Caption <> LangLabel(Lang, IsCapsLockOn) then
    ShowLanguage(Lang, '', True)
  else
    PlaceAtCaret;
end;

procedure TCaretHintForm.TimerTick(Sender: TObject);
begin
  if AppSettings.CaretHintMode = chOff then
  begin
    if FShown then
      HideHint;
    Exit;
  end;
  if (AppSettings.CaretHintMode = chTimed) and not FShown then
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
  if AppSettings.CaretHintMode = chFollow then
  begin
    FollowTick;
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

constructor TMouseMarkerForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  BorderStyle := bsNone;
  FormStyle := fsStayOnTop;
  FLang := lkUnknown;
  FMode := mmOff;
  ClientWidth := MouseDotSize;
  ClientHeight := MouseDotSize;
  Position := poDesigned;
  AlphaBlend := True;
  AlphaBlendValue := MarkerAlpha;
  Visible := False;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := MouseMarkerPollMs;
  FTimer.OnTimer := TimerTick;
  FTimer.Enabled := True;
  HandleNeeded;
end;

procedure TMouseMarkerForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := WS_POPUP;
  Params.ExStyle := (Params.ExStyle or WS_EX_TOPMOST or WS_EX_TOOLWINDOW or
    WS_EX_NOACTIVATE or WS_EX_TRANSPARENT) and not WS_EX_APPWINDOW;
  Params.WndParent := HintOwnerWindow;
end;

procedure TMouseMarkerForm.CreateWnd;
begin
  inherited CreateWnd;
  ApplyNoTaskbarStyle(Handle);
end;

procedure TMouseMarkerForm.Paint;
var
  R: TRect;
  Text: string;
begin
  Canvas.Brush.Color := BadgeColorFor(FLang);
  Canvas.FillRect(ClientRect);
  if FMode <> mmText then
    Exit;
  Canvas.Pen.Color := DarkerShade(BadgeColorFor(FLang));
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, ClientWidth, ClientHeight);
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Height := -11;
  Canvas.Font.Color := BadgeInkFor(FLang);
  Text := LangLabel(FLang, FCaps);
  R := ClientRect;
  DrawText(Canvas.Handle, PChar(Text), Length(Text), R,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE);
end;

procedure TMouseMarkerForm.HideMarker;
begin
  if FShown and HandleAllocated then
    ShowWindow(Handle, SW_HIDE);
  FShown := False;
end;

{ The dot is clipped to a circle; the letters use the whole rectangle. }
procedure TMouseMarkerForm.ApplyMode(AMode: TMouseMarkerMode);
begin
  if FModeApplied and (AMode = FMode) then
    Exit;
  FMode := AMode;
  FModeApplied := True;
  if AMode = mmText then
    SetWindowRgn(Handle, 0, True)
  else
    SetWindowRgn(Handle, CreateEllipticRgn(0, 0, MouseDotSize + 1,
      MouseDotSize + 1), True);
  Invalidate;
end;

function TMouseMarkerForm.BlockedByFullscreen: Boolean;
var
  Tick: UInt64;
begin
  if not AppSettings.PauseInFullscreen then
    Exit(False);
  Tick := GetTickCount64;
  if (FFullscreenTick = 0) or
     (Tick - FFullscreenTick > MarkerFullscreenCheckMs) then
  begin
    FFullscreen := IsForegroundFullscreen;
    FFullscreenTick := Tick;
  end;
  Result := FFullscreen;
end;

{ Decides whether the marker is shown and brings its mode, layout and Caps Lock
  state up to date. Returns False when it has to be hidden. }
function TMouseMarkerForm.RefreshState(out AMode: TMouseMarkerMode): Boolean;
var
  Lang: TLangKind;
  Caps: Boolean;
begin
  AMode := AppSettings.MouseMarker;
  Result := False;
  if AMode = mmOff then
    Exit;
  Lang := GetForegroundLangKind;
  if (Lang = lkUnknown) or BlockedByFullscreen then
    Exit;
  ApplyMode(AMode);
  Caps := IsCapsLockOn;
  if (Lang <> FLang) or (Caps <> FCaps) then
  begin
    FLang := Lang;
    FCaps := Caps;
    Invalidate;
  end;
  Result := True;
end;

procedure TMouseMarkerForm.SetTimerRate(AFast: Boolean);
begin
  if AFast = FFast then
    Exit;
  FFast := AFast;
  if AFast then
    FTimer.Interval := MouseMarkerFrameMs
  else
    FTimer.Interval := MouseMarkerPollMs;
end;

{ The state checks run at the slow poll rate. The position is read on every
  tick; in dot mode the dot eases toward the pointer instead of jumping, and
  the timer runs at frame rate only while it is still moving. }
procedure TMouseMarkerForm.TimerTick(Sender: TObject);
var
  Mode: TMouseMarkerMode;
  Spot: TPoint;
  Tick: UInt64;
  Stamp: Int64;
  StepMs, Gain, TargetX, TargetY: Double;
  Width, Height: Integer;
  Place: TPoint;
begin
  try
    Tick := GetTickCount64;
    Mode := AppSettings.MouseMarker;
    if (FStateTick = 0) or (Tick - FStateTick >= MouseMarkerPollMs) or
       (Mode <> FMode) then
    begin
      FWantShow := RefreshState(Mode);
      FStateTick := Tick;
    end;
    if not FWantShow or not GetCursorPos(Spot) then
    begin
      HideMarker;
      FSmooth := False;
      SetTimerRate(False);
      Exit;
    end;
    TargetX := Spot.X + MouseMarkerOffsetX;
    TargetY := Spot.Y + MouseMarkerOffsetY;
    Stamp := TStopwatch.GetTimeStamp;
    if (Mode <> mmDot) or not FSmooth or not FShown then
    begin
      FPosX := TargetX;
      FPosY := TargetY;
    end
    else
    begin
      StepMs := (Stamp - FStamp) * 1000.0 / TStopwatch.Frequency;
      if StepMs > MouseDotMaxStepMs then
        StepMs := MouseDotMaxStepMs;
      Gain := 1 - Exp(-StepMs / MouseDotLagMs);
      FPosX := FPosX + (TargetX - FPosX) * Gain;
      FPosY := FPosY + (TargetY - FPosY) * Gain;
      if (Abs(TargetX - FPosX) < 0.5) and (Abs(TargetY - FPosY) < 0.5) then
      begin
        FPosX := TargetX;
        FPosY := TargetY;
      end;
    end;
    FStamp := Stamp;
    FSmooth := Mode = mmDot;
    SetTimerRate(FSmooth and ((FPosX <> TargetX) or (FPosY <> TargetY)));
    if Mode = mmText then
    begin
      Width := MouseTextWidth;
      Height := MouseTextHeight;
    end
    else
    begin
      Width := MouseDotSize;
      Height := MouseDotSize;
    end;
    Place := Point(Round(FPosX), Round(FPosY));
    if FShown and (Place = FPlaced) and (ClientWidth = Width) and
       (ClientHeight = Height) then
      Exit;
    SetWindowPos(Handle, HWND_TOPMOST, Place.X, Place.Y, Width, Height,
      SWP_NOACTIVATE or SWP_SHOWWINDOW);
    FPlaced := Place;
    FShown := True;
  except
    HideMarker;
  end;
end;

procedure StartMouseMarker;
begin
  if MouseMarkerForm = nil then
    MouseMarkerForm := TMouseMarkerForm.Create(nil);
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
  MouseMarkerForm := nil;
  HintOwner := 0;

finalization
  // Not waited for: a worker stuck in a query must not block shutdown.
  if AutomationWorker <> nil then
    AutomationWorker.Terminate;
  FreeAndNil(HintForm);
  FreeAndNil(MouseMarkerForm);
  if HintOwner <> 0 then
    DestroyWindow(HintOwner);

end.
