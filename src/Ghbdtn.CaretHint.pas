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
  Ghbdtn.MarkerAnimation,
  Ghbdtn.Settings;

const
  MarkerAlpha = 210;
  // Polled often so the label keeps up with the mouse.
  MouseMarkerPollMs = 40;
  // While the label is catching up with the pointer it is moved every frame.
  MouseMarkerFrameMs = 16;
  // Time constant of the label's approach to the pointer: after this long it has
  // covered about 63 percent of the gap.
  MouseDotLagMs = 55;
  MouseDotMaxStepMs = 100;
  MouseDotSize = 9;
  // The dot is drawn on a canvas larger than itself so the pulse can grow it
  // without resizing the window.
  MouseDotPad = 6;
  MouseDotCanvas = MouseDotSize + 2 * MouseDotPad;
  // Width of the ring that spreads out in the wave animation.
  MouseDotWaveWidth = 1.6;
  // Ring thickness while Caps Lock is on.
  MouseDotRingWidth = 2.5;
  MouseTextWidth = 26;
  MouseTextHeight = 16;
  // Room around the label for the animations that enlarge it.
  MouseTextPad = 8;
  MouseMarkerOffsetX = 14;
  MouseMarkerOffsetY = 16;
  MarkerFullscreenCheckMs = 500;
  HintWidth = 42;
  HintHeight = 22;
  HintVisibleMs = 1100;
  HintFlashMs = 380;
  // While the appear flash or size animation runs the timer ticks once per
  // frame; otherwise it only polls.
  HintFrameMs = 16;
  HintPollMs = 80;
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
    FDirty: Boolean;
    FPulseAt: UInt64;
    FPulseFrom: TLangKind;
    FPulseStyle: TMarkerAnimation;
    FBits: TBitmap;
    // The label at rest in the previous and in the current layout; the window
    // bitmap is composed from them.
    FLabelFrom: TBitmap;
    FLabelTo: TBitmap;
    procedure HideMarker;
    procedure ApplyMode(AMode: TMouseMarkerMode);
    function PulseState(out AFrame: TDotFrame): Boolean;
    procedure DrawDot(const AFrame: TDotFrame);
    procedure DrawText(ATarget: TBitmap; ALang: TLangKind);
    procedure DrawLetters(ATarget: TBitmap; ALang: TLangKind);
    procedure DrawLabel(AMode: TMouseMarkerMode; ATarget: TBitmap;
      ALang: TLangKind);
    procedure ComposeLabel(AMode: TMouseMarkerMode; const AFrame: TDotFrame);
    procedure Render(const APlace: TPoint; AMode: TMouseMarkerMode;
      const AFrame: TDotFrame);
    function BlockedByFullscreen: Boolean;
    function RefreshState(out AMode: TMouseMarkerMode): Boolean;
    procedure SetTimerRate(AFast: Boolean);
    procedure TimerTick(Sender: TObject);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
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

{ Reads the first rectangle of a bounding-rectangles array (left, top, width,
  height as doubles). ARightEdge returns its right edge instead of the left. }
function RectFromBoundingArray(Rects: PSafeArray; ARightEdge: Boolean;
  out APoint: TPoint): Boolean;
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
  if ARightEdge then
    APoint := Point(Round(Values[0] + Values[2]), Round(Values[1]))
  else
    APoint := Point(Round(Values[0]), Round(Values[1]));
  Result := True;
end;

function RangePoint(const ARange: IUIAutomationTextRange; ARightEdge: Boolean;
  out APoint: TPoint): Boolean;
type
  TGetBoundingRectangles = function(This: Pointer; out Rects: PSafeArray): HRESULT; stdcall;
var
  Rects: PSafeArray;
  VTable: PPointer;
  ReadRects: TGetBoundingRectangles;
begin
  Result := False;
  APoint := Point(0, 0);
  if ARange = nil then
    Exit;
  // The imported signature passes SAFEARRAY by value. The real method returns
  // a SAFEARRAY pointer, so call that slot directly.
  VTable := PPointer(Pointer(ARange)^);
  Inc(VTable, 10);
  ReadRects := TGetBoundingRectangles(VTable^);
  Rects := nil;
  try
    if Failed(ReadRects(Pointer(ARange), Rects)) then
      Exit;
    Result := RectFromBoundingArray(Rects, ARightEdge, APoint);
  finally
    if Rects <> nil then
      SafeArrayDestroy(Rects);
  end;
end;

{ TextPattern2 gives the caret range directly. }
function TryCaretRangePoint(const AElement: IUIAutomationElement;
  out APoint: TPoint): Boolean;
var
  Pattern: IUIAutomationTextPattern2;
  Range: IUIAutomationTextRange;
  PatternPtr: Pointer;
  PatternId: TGUID;
  Active: BOOL;
begin
  Result := False;
  APoint := Point(0, 0);
  PatternId := IUIAutomationTextPattern2;
  PatternPtr := nil;
  if Failed(AElement.GetCurrentPatternAs(UIA_TextPattern2Id, @PatternId, PatternPtr)) or
     (PatternPtr = nil) then
    Exit;
  Pointer(Pattern) := PatternPtr;
  Range := nil;
  if Failed(Pattern.GetCaretRange(Active, Range)) or (Range = nil) then
    Exit;
  Result := RangePoint(Range, False, APoint);
end;

{ Elements with TextPattern only (Chromium and Electron fields, terminals):
  the selection is a collapsed range at the caret and has no rectangle of its
  own. The character after it gives the caret's left edge; at the end of the
  text the character before it gives the right edge. }
function TrySelectionPoint(const AElement: IUIAutomationElement;
  out APoint: TPoint): Boolean;
var
  Pattern: IUIAutomationTextPattern;
  Ranges: IUIAutomationTextRangeArray;
  Selection, Probe: IUIAutomationTextRange;
  PatternPtr: Pointer;
  PatternId: TGUID;
  Count, Moved: Integer;
begin
  Result := False;
  APoint := Point(0, 0);
  PatternId := IUIAutomationTextPattern;
  PatternPtr := nil;
  if Failed(AElement.GetCurrentPatternAs(UIA_TextPatternId, @PatternId, PatternPtr)) or
     (PatternPtr = nil) then
    Exit;
  Pointer(Pattern) := PatternPtr;
  Ranges := nil;
  if Failed(Pattern.GetSelection(Ranges)) or (Ranges = nil) then
    Exit;
  if Failed(Ranges.get_Length(Count)) or (Count < 1) then
    Exit;
  Selection := nil;
  if Failed(Ranges.GetElement(0, Selection)) or (Selection = nil) then
    Exit;
  Probe := nil;
  if Succeeded(Selection.Clone(Probe)) and (Probe <> nil) and
     Succeeded(Probe.ExpandToEnclosingUnit(TextUnit_Character)) and
     RangePoint(Probe, False, APoint) then
    Exit(True);
  Probe := nil;
  if Failed(Selection.Clone(Probe)) or (Probe = nil) then
    Exit;
  Moved := 0;
  if Failed(Probe.MoveEndpointByUnit(TextPatternRangeEndpoint_Start,
    TextUnit_Character, -1, Moved)) or (Moved = 0) then
    Exit;
  Result := RangePoint(Probe, True, APoint);
end;

function TryGetAutomationCaret(out APoint: TPoint): Boolean;
var
  Client: IUIAutomation;
  Element: IUIAutomationElement;
begin
  Result := False;
  APoint := Point(0, 0);
  Client := AutomationClient;
  if Client = nil then
    Exit;
  Element := nil;
  if Failed(Client.GetFocusedElement(Element)) or (Element = nil) then
    Exit;
  Result := TryCaretRangePoint(Element, APoint) or
    TrySelectionPoint(Element, APoint);
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
  FTimer.Interval := HintPollMs;
  FTimer.OnTimer := TimerTick;
  FTimer.Enabled := True;
  // The badge is repainted on every animation frame; drawing it off screen
  // avoids the flicker of fill, border and text appearing one after another.
  DoubleBuffered := True;
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

{ Size of the badge relative to its normal size: it starts 28 percent larger
  and settles with an ease-out curve. }
function TCaretHintForm.HintScale: Double;
var
  Elapsed: UInt64;
  Left: Double;
begin
  Result := 1;
  if not AppSettings.CaretHintAnimate or (FAppearedAt = 0) then
    Exit;
  Elapsed := GetTickCount64 - FAppearedAt;
  if Elapsed >= HintFlashMs then
    Exit;
  Left := 1 - Elapsed / HintFlashMs;
  Result := 1 + 0.28 * Left * Left;
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
  BaseWidth, Width, Height, ExtraX, ExtraY: Integer;
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
  BaseWidth := Canvas.TextWidth(Caption) + 16;
  if BaseWidth < HintWidth then
    BaseWidth := HintWidth;
  Width := Round(BaseWidth * Scale);
  Height := Round(HintHeight * Scale);
  // The badge grows around its normal center; rounding the half difference
  // keeps the center from stepping by a pixel at alternate sizes.
  ExtraX := Round((Width - BaseWidth) / 2);
  ExtraY := Round((Height - HintHeight) / 2);
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
    // Start the frame rate now instead of at the next slow poll.
    if FAppearedAt <> 0 then
      FTimer.Interval := HintFrameMs;
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
var
  Animating: Boolean;
  Rate: Cardinal;
begin
  Animating := (AppSettings.CaretHintFlash or AppSettings.CaretHintAnimate) and
    (FAppearedAt <> 0) and
    (GetTickCount64 - FAppearedAt < UInt64(HintFlashMs + HintFrameMs));
  if Animating then
    Rate := HintFrameMs
  else
    Rate := HintPollMs;
  if FTimer.Interval <> Rate then
    FTimer.Interval := Rate;
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
  if Animating then
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
  Visible := False;
  FBits := TBitmap.Create;
  FBits.PixelFormat := pf32bit;
  FLabelFrom := TBitmap.Create;
  FLabelFrom.PixelFormat := pf32bit;
  FLabelFrom.SetSize(MouseTextWidth, MouseTextHeight);
  FLabelTo := TBitmap.Create;
  FLabelTo.PixelFormat := pf32bit;
  FLabelTo.SetSize(MouseTextWidth, MouseTextHeight);
  FTimer := TTimer.Create(Self);
  FTimer.Interval := MouseMarkerPollMs;
  FTimer.OnTimer := TimerTick;
  FTimer.Enabled := True;
  HandleNeeded;
end;

destructor TMouseMarkerForm.Destroy;
begin
  FLabelTo.Free;
  FLabelFrom.Free;
  FBits.Free;
  inherited;
end;

procedure TMouseMarkerForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := WS_POPUP;
  Params.ExStyle := (Params.ExStyle or WS_EX_TOPMOST or WS_EX_TOOLWINDOW or
    WS_EX_NOACTIVATE or WS_EX_TRANSPARENT or WS_EX_LAYERED) and
    not WS_EX_APPWINDOW;
  Params.WndParent := HintOwnerWindow;
end;

procedure TMouseMarkerForm.CreateWnd;
begin
  inherited CreateWnd;
  ApplyNoTaskbarStyle(Handle);
end;

type
  PQuadRow = ^TQuadRow;
  TQuadRow = array[0..4095] of TRGBQuad;

function Clamp01(AValue: Double): Double;
begin
  if AValue < 0 then
    Result := 0
  else if AValue > 1 then
    Result := 1
  else
    Result := AValue;
end;

function MixChannel(AFrom, ATo: Integer; AMix: Double): Integer;
begin
  Result := Round(AFrom + (ATo - AFrom) * AMix);
end;

{ Anti-aliased dot, or a ring while Caps Lock is on: the edge pixels get
  partial coverage, which the layered window blends with what is behind it.
  The shape is a rounded square of half-width R whose corner radius shrinks
  from R (a circle) to nothing, drawn through a rotation and a per-axis scale;
  distances are measured before the scale and brought back with its mean.
  Colors are premultiplied. }
procedure TMouseMarkerForm.DrawDot(const AFrame: TDotFrame);
var
  X, Y: Integer;
  Row: PQuadRow;
  FromRgb, ToRgb: Integer;
  Red, Green, Blue: Integer;
  Half, Corner, Inner, Center, Px, Py, Qx, Qy, Dx, Dy, Dist, Wave,
    Cover, Hole, Factor, SinA, CosA, RingR: Double;
  Alpha: Integer;
begin
  FromRgb := ColorToRGB(BadgeColorFor(FPulseFrom));
  ToRgb := ColorToRGB(BadgeColorFor(FLang));
  Red := MixChannel(GetRValue(FromRgb), GetRValue(ToRgb), AFrame.Mix);
  Green := MixChannel(GetGValue(FromRgb), GetGValue(ToRgb), AFrame.Mix);
  Blue := MixChannel(GetBValue(FromRgb), GetBValue(ToRgb), AFrame.Mix);
  Half := MouseDotSize / 2;
  Corner := Half * (1 - AFrame.Roundness);
  Inner := Half - Corner;
  Center := MouseDotCanvas / 2;
  Factor := (AFrame.ScaleX + AFrame.ScaleY) / 2;
  SinA := Sin(AFrame.Angle);
  CosA := Cos(AFrame.Angle);
  RingR := Half + (Center - 0.5 - MouseDotWaveWidth - Half) *
    Clamp01(AFrame.Wave);
  for Y := 0 to MouseDotCanvas - 1 do
  begin
    Row := FBits.ScanLine[Y];
    for X := 0 to MouseDotCanvas - 1 do
    begin
      Px := X + 0.5 - Center;
      Py := Y + 0.5 - Center;
      Qx := (Px * CosA + Py * SinA) / AFrame.ScaleX;
      Qy := (Py * CosA - Px * SinA) / AFrame.ScaleY;
      Dx := Abs(Qx) - Inner;
      Dy := Abs(Qy) - Inner;
      Dist := (Sqrt(Sqr(Max(Dx, 0.0)) + Sqr(Max(Dy, 0.0))) +
        Min(Max(Dx, Dy), 0.0) - Corner) * Factor;
      Cover := Clamp01(0.5 - Dist);
      if FCaps then
      begin
        // Caps Lock turns the dot into a ring: the middle is cut out.
        Hole := Clamp01(-Dist - MouseDotRingWidth + 0.5);
        Cover := Cover * (1 - Hole);
      end;
      if AFrame.Wave >= 0 then
      begin
        Wave := Clamp01(0.5 - (Abs(Sqrt(Sqr(Px) + Sqr(Py)) - RingR) -
          MouseDotWaveWidth / 2)) * (1 - AFrame.Wave);
        if Wave > Cover then
          Cover := Wave;
      end;
      Alpha := Round(Cover * MarkerAlpha);
      Row^[X].rgbReserved := Alpha;
      Row^[X].rgbRed := Red * Alpha div 255;
      Row^[X].rgbGreen := Green * Alpha div 255;
      Row^[X].rgbBlue := Blue * Alpha div 255;
    end;
  end;
end;

{ Letters straight on the desktop: the glyph coverage is drawn as white on
  black, then the fill color over a one-pixel darker shadow is composed from
  it so the letters read on light and dark backgrounds alike. A full outline
  would close the gaps between the small glyphs. }
procedure TMouseMarkerForm.DrawLetters(ATarget: TBitmap; ALang: TLangKind);
var
  R: TRect;
  Text: string;
  X, Y: Integer;
  Row: PQuadRow;
  Mask: array[0..MouseTextHeight - 1, 0..MouseTextWidth - 1] of Byte;
  Cover, Edge, Alpha: Integer;
  Ink, Rim: Integer;
begin
  with ATarget.Canvas do
  begin
    Brush.Style := bsSolid;
    Brush.Color := clBlack;
    FillRect(Rect(0, 0, MouseTextWidth, MouseTextHeight));
    Brush.Style := bsClear;
    Font.Name := 'Segoe UI';
    Font.Style := [fsBold];
    Font.Height := -14;
    Font.Quality := fqAntialiased;
    Font.Color := clWhite;
    Text := LangLabel(ALang, FCaps);
    R := Rect(0, 0, MouseTextWidth, MouseTextHeight);
    Winapi.Windows.DrawText(Handle, PChar(Text), Length(Text), R,
      DT_CENTER or DT_VCENTER or DT_SINGLELINE);
  end;
  for Y := 0 to MouseTextHeight - 1 do
  begin
    Row := ATarget.ScanLine[Y];
    for X := 0 to MouseTextWidth - 1 do
      Mask[Y, X] := Row^[X].rgbGreen;
  end;
  Ink := ColorToRGB(BadgeColorFor(ALang));
  Rim := ColorToRGB(DarkerShade(BadgeColorFor(ALang)));
  for Y := 0 to MouseTextHeight - 1 do
  begin
    Row := ATarget.ScanLine[Y];
    for X := 0 to MouseTextWidth - 1 do
    begin
      Cover := Mask[Y, X];
      Edge := 0;
      if (Y > 0) and (X > 0) then
        Edge := Mask[Y - 1, X - 1];
      // Fill over shadow, premultiplied.
      Alpha := Cover + Edge * (255 - Cover) div 255;
      Row^[X].rgbRed := (GetRValue(Ink) * Cover +
        GetRValue(Rim) * (Alpha - Cover)) div 255 * MarkerAlpha div 255;
      Row^[X].rgbGreen := (GetGValue(Ink) * Cover +
        GetGValue(Rim) * (Alpha - Cover)) div 255 * MarkerAlpha div 255;
      Row^[X].rgbBlue := (GetBValue(Ink) * Cover +
        GetBValue(Rim) * (Alpha - Cover)) div 255 * MarkerAlpha div 255;
      Row^[X].rgbReserved := Alpha * MarkerAlpha div 255;
    end;
  end;
end;

procedure TMouseMarkerForm.DrawText(ATarget: TBitmap; ALang: TLangKind);
var
  R: TRect;
  Text: string;
  X, Y: Integer;
  Row: PQuadRow;
begin
  with ATarget.Canvas do
  begin
    Brush.Style := bsSolid;
    Brush.Color := BadgeColorFor(ALang);
    FillRect(Rect(0, 0, MouseTextWidth, MouseTextHeight));
    Pen.Color := DarkerShade(BadgeColorFor(ALang));
    Brush.Style := bsClear;
    Rectangle(0, 0, MouseTextWidth, MouseTextHeight);
    Font.Name := 'Segoe UI';
    Font.Style := [fsBold];
    Font.Height := -11;
    Font.Color := BadgeInkFor(ALang);
    Text := LangLabel(ALang, FCaps);
    R := Rect(0, 0, MouseTextWidth, MouseTextHeight);
    Winapi.Windows.DrawText(Handle, PChar(Text), Length(Text), R,
      DT_CENTER or DT_VCENTER or DT_SINGLELINE);
  end;
  // GDI leaves the alpha byte empty; the label is uniformly translucent.
  for Y := 0 to MouseTextHeight - 1 do
  begin
    Row := ATarget.ScanLine[Y];
    for X := 0 to MouseTextWidth - 1 do
    begin
      Row^[X].rgbRed := Row^[X].rgbRed * MarkerAlpha div 255;
      Row^[X].rgbGreen := Row^[X].rgbGreen * MarkerAlpha div 255;
      Row^[X].rgbBlue := Row^[X].rgbBlue * MarkerAlpha div 255;
      Row^[X].rgbReserved := MarkerAlpha;
    end;
  end;
end;

procedure TMouseMarkerForm.DrawLabel(AMode: TMouseMarkerMode;
  ATarget: TBitmap; ALang: TLangKind);
begin
  if AMode = mmText then
    DrawText(ATarget, ALang)
  else
    DrawLetters(ATarget, ALang);
end;

{ Composes the label of the current frame in the window bitmap, which is
  larger than the label so that it can grow. The label at rest is drawn in the
  colors of the previous and the current layout, blended by the frame's Mix,
  and resampled with the frame's scale around the center; at scale 1 every
  pixel lands exactly on one source pixel, so the label stays sharp. }
procedure TMouseMarkerForm.ComposeLabel(AMode: TMouseMarkerMode;
  const AFrame: TDotFrame);
var
  X, Y, X0, Y0, K, N: Integer;
  RowFrom, RowTo, Dest: PQuadRow;
  Pa, Pb: PRGBQuad;
  U, V, Fx, Fy: Double;
  Acc: array[0..3] of Double;
  Src: array[0..3] of PRGBQuad;
  Weights: array[0..3] of Double;
  DestWidth, DestHeight: Integer;

  function Pixel(AX, AY: Integer): PRGBQuad;
  begin
    if (AX < 0) or (AY < 0) or (AX >= MouseTextWidth) or
       (AY >= MouseTextHeight) then
      Exit(nil);
    Result := @PQuadRow(FLabelTo.ScanLine[AY])^[AX];
  end;

begin
  DrawLabel(AMode, FLabelTo, FLang);
  if AFrame.Mix < 1 then
  begin
    DrawLabel(AMode, FLabelFrom, FPulseFrom);
    for Y := 0 to MouseTextHeight - 1 do
    begin
      RowFrom := FLabelFrom.ScanLine[Y];
      RowTo := FLabelTo.ScanLine[Y];
      for X := 0 to MouseTextWidth - 1 do
      begin
        Pa := @RowFrom^[X];
        Pb := @RowTo^[X];
        Pb^.rgbRed := MixChannel(Pa^.rgbRed, Pb^.rgbRed, AFrame.Mix);
        Pb^.rgbGreen := MixChannel(Pa^.rgbGreen, Pb^.rgbGreen, AFrame.Mix);
        Pb^.rgbBlue := MixChannel(Pa^.rgbBlue, Pb^.rgbBlue, AFrame.Mix);
        Pb^.rgbReserved := MixChannel(Pa^.rgbReserved, Pb^.rgbReserved,
          AFrame.Mix);
      end;
    end;
  end;
  DestWidth := MouseTextWidth + 2 * MouseTextPad;
  DestHeight := MouseTextHeight + 2 * MouseTextPad;
  for Y := 0 to DestHeight - 1 do
  begin
    Dest := FBits.ScanLine[Y];
    V := (Y + 0.5 - DestHeight / 2) / AFrame.ScaleY + MouseTextHeight / 2 - 0.5;
    Y0 := Floor(V);
    Fy := V - Y0;
    for X := 0 to DestWidth - 1 do
    begin
      U := (X + 0.5 - DestWidth / 2) / AFrame.ScaleX + MouseTextWidth / 2 - 0.5;
      X0 := Floor(U);
      Fx := U - X0;
      Src[0] := Pixel(X0, Y0);
      Src[1] := Pixel(X0 + 1, Y0);
      Src[2] := Pixel(X0, Y0 + 1);
      Src[3] := Pixel(X0 + 1, Y0 + 1);
      Weights[0] := (1 - Fx) * (1 - Fy);
      Weights[1] := Fx * (1 - Fy);
      Weights[2] := (1 - Fx) * Fy;
      Weights[3] := Fx * Fy;
      for K := 0 to 3 do
        Acc[K] := 0;
      // Pixels outside the label are transparent; the colors are
      // premultiplied, so a weighted sum is a correct blend.
      for N := 0 to 3 do
        if Src[N] <> nil then
        begin
          Acc[0] := Acc[0] + Src[N]^.rgbBlue * Weights[N];
          Acc[1] := Acc[1] + Src[N]^.rgbGreen * Weights[N];
          Acc[2] := Acc[2] + Src[N]^.rgbRed * Weights[N];
          Acc[3] := Acc[3] + Src[N]^.rgbReserved * Weights[N];
        end;
      Dest^[X].rgbBlue := Round(Acc[0]);
      Dest^[X].rgbGreen := Round(Acc[1]);
      Dest^[X].rgbRed := Round(Acc[2]);
      Dest^[X].rgbReserved := Round(Acc[3]);
    end;
  end;
end;

{ Draws the label into the bitmap and hands it to the window with per-pixel
  alpha; the same call moves and sizes the window. }
procedure TMouseMarkerForm.Render(const APlace: TPoint; AMode: TMouseMarkerMode;
  const AFrame: TDotFrame);
var
  Width, Height: Integer;
  Dest, Src: TPoint;
  Size: TSize;
  Blend: TBlendFunction;
  ExStyle: NativeInt;
begin
  if AMode in [mmText, mmLetters] then
  begin
    Width := MouseTextWidth + 2 * MouseTextPad;
    Height := MouseTextHeight + 2 * MouseTextPad;
    Dest := Point(APlace.X - MouseTextPad, APlace.Y - MouseTextPad);
  end
  else
  begin
    Width := MouseDotCanvas;
    Height := MouseDotCanvas;
    Dest := Point(APlace.X - MouseDotPad, APlace.Y - MouseDotPad);
  end;
  if (FBits.Width <> Width) or (FBits.Height <> Height) then
    FBits.SetSize(Width, Height);
  if AMode in [mmText, mmLetters] then
    ComposeLabel(AMode, AFrame)
  else
    DrawDot(AFrame);
  Src := Point(0, 0);
  Size.cx := Width;
  Size.cy := Height;
  Blend.BlendOp := AC_SRC_OVER;
  Blend.BlendFlags := 0;
  Blend.SourceConstantAlpha := 255;
  Blend.AlphaFormat := AC_SRC_ALPHA;
  // The form drops the layered style when AlphaBlend is off, so it is set
  // here, where the window is about to receive a bitmap.
  ExStyle := GetWindowLong(Handle, GWL_EXSTYLE);
  if ExStyle and WS_EX_LAYERED = 0 then
    SetWindowLong(Handle, GWL_EXSTYLE, ExStyle or WS_EX_LAYERED);
  UpdateLayeredWindow(Handle, 0, @Dest, @Size, FBits.Canvas.Handle, @Src, 0,
    @Blend, ULW_ALPHA);
  SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_SHOWWINDOW);
end;

{ The frame of the running layout-change animation, or the resting dot when
  none runs. The style is fixed when the animation starts. }
function TMouseMarkerForm.PulseState(out AFrame: TDotFrame): Boolean;
var
  Phase: Double;
begin
  AFrame := RestingDotFrame;
  Result := False;
  if FPulseAt = 0 then
    Exit;
  Phase := (GetTickCount64 - FPulseAt) / MarkerAnimationMs(FPulseStyle);
  if Phase >= 1 then
  begin
    FPulseAt := 0;
    FDirty := True;
    Exit;
  end;
  AFrame := ComputeDotFrame(FPulseStyle, Phase);
  Result := True;
end;

procedure TMouseMarkerForm.HideMarker;
begin
  if FShown and HandleAllocated then
    ShowWindow(Handle, SW_HIDE);
  FShown := False;
  FDirty := True;
  FPulseAt := 0;
end;

procedure TMouseMarkerForm.ApplyMode(AMode: TMouseMarkerMode);
begin
  if FModeApplied and (AMode = FMode) then
    Exit;
  FMode := AMode;
  FModeApplied := True;
  FPulseAt := 0;
  FDirty := True;
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
    if AppSettings.MouseMarkerAnimate and FShown and
       (Lang <> FLang) and (FLang <> lkUnknown) then
    begin
      FPulseFrom := FLang;
      FPulseStyle := AppSettings.MouseMarkerAnimation;
      // The square and the wave are shapes of the dot; a label swells instead.
      if (AMode <> mmDot) and (FPulseStyle in [maSquare, maWave]) then
        FPulseStyle := maSwell;
      FPulseAt := GetTickCount64;
    end;
    FLang := Lang;
    FCaps := Caps;
    FDirty := True;
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

{ True when every pixel of the cursor bitmap is fully transparent: AND mask
  all ones and XOR/color data all zero. Players hide the pointer this way by
  installing a blank cursor. Any failure counts as not blank. }
function CursorIsBlank(AIcon: HICON): Boolean;
var
  Info: TIconInfo;
  Bmp: tagBITMAP;
  DC: HDC;
  Bits: TBytes;
  Hdr: TBitmapInfo;
  W, H, Rows, I, Stride: Integer;

  function Fetch(ABitmap: HBITMAP; ARows: Integer): Boolean;
  begin
    FillChar(Hdr, SizeOf(Hdr), 0);
    Hdr.bmiHeader.biSize := SizeOf(Hdr.bmiHeader);
    Hdr.bmiHeader.biWidth := W;
    Hdr.bmiHeader.biHeight := -ARows;
    Hdr.bmiHeader.biPlanes := 1;
    Hdr.bmiHeader.biBitCount := 32;
    Hdr.bmiHeader.biCompression := BI_RGB;
    Stride := W * 4;
    SetLength(Bits, Stride * ARows);
    Result := GetDIBits(DC, ABitmap, 0, ARows, Bits, Hdr, DIB_RGB_COLORS) = ARows;
  end;

begin
  Result := False;
  if not GetIconInfo(AIcon, Info) then
    Exit;
  DC := GetDC(0);
  try
    if GetObject(Info.hbmMask, SizeOf(Bmp), @Bmp) = 0 then
      Exit;
    W := Bmp.bmWidth;
    H := Bmp.bmHeight;
    if (W <= 0) or (H <= 0) or (W > 256) or (H > 512) then
      Exit;
    if Info.hbmColor <> 0 then
    begin
      { Color cursor: mask is W x H (AND only). }
      Rows := H;
      if not Fetch(Info.hbmMask, Rows) then
        Exit;
      for I := 0 to W * Rows - 1 do
        if Bits[I * 4] <> $FF then
          Exit;
      if not Fetch(Info.hbmColor, Rows) then
        Exit;
      for I := 0 to W * Rows - 1 do
        if PCardinal(@Bits[I * 4])^ <> 0 then
          Exit;
      Result := True;
    end
    else
    begin
      { Monochrome cursor: AND mask on top, XOR mask below. }
      if not Fetch(Info.hbmMask, H) then
        Exit;
      Rows := H div 2;
      for I := 0 to W * Rows - 1 do
        if Bits[I * 4] <> $FF then
          Exit;
      for I := W * Rows to W * Rows * 2 - 1 do
        if Bits[I * 4] <> 0 then
          Exit;
      Result := True;
    end;
  finally
    ReleaseDC(0, DC);
    if Info.hbmMask <> 0 then
      DeleteObject(Info.hbmMask);
    if Info.hbmColor <> 0 then
      DeleteObject(Info.hbmColor);
  end;
end;

{ False while the system pointer is hidden: the show counter is lowered, the
  cursor is null, or it is a fully transparent cursor. If the query fails the
  pointer is assumed visible. }
function PointerVisible: Boolean;
var
  Info: TCursorInfo;
begin
  Info.cbSize := SizeOf(Info);
  if not GetCursorInfo(Info) then
    Exit(True);
  Result := (Info.flags and CURSOR_SHOWING <> 0) and (Info.hCursor <> 0) and
    not CursorIsBlank(Info.hCursor);
end;

{ The state checks run at the slow poll rate. The position is read on every
  tick; the label eases toward the pointer instead of jumping, and the timer
  runs at frame rate only while it is still moving. }
procedure TMouseMarkerForm.TimerTick(Sender: TObject);
var
  Mode: TMouseMarkerMode;
  Spot: TPoint;
  Tick: UInt64;
  Stamp: Int64;
  StepMs, Gain, TargetX, TargetY: Double;
  Place: TPoint;
  Frame: TDotFrame;
  Pulsing: Boolean;
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
    if not FWantShow or not PointerVisible or not GetCursorPos(Spot) then
    begin
      HideMarker;
      FSmooth := False;
      SetTimerRate(False);
      Exit;
    end;
    TargetX := Spot.X + MouseMarkerOffsetX;
    TargetY := Spot.Y + MouseMarkerOffsetY;
    Stamp := TStopwatch.GetTimeStamp;
    if not FSmooth or not FShown then
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
    FSmooth := True;
    Pulsing := PulseState(Frame);
    SetTimerRate(Pulsing or
      (FSmooth and ((FPosX <> TargetX) or (FPosY <> TargetY))));
    Place := Point(Round(FPosX), Round(FPosY));
    if FShown and (Place = FPlaced) and not FDirty and not Pulsing then
      Exit;
    Render(Place, Mode, Frame);
    FPlaced := Place;
    FShown := True;
    FDirty := False;
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
