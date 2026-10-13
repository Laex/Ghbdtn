unit Ghbdtn.Hook;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  Ghbdtn.Layout,
  Ghbdtn.Buffer,
  Ghbdtn.KeyState,
  Ghbdtn.InputQueue,
  Ghbdtn.InputWorker,
  Ghbdtn.Learning,
  Ghbdtn.Phrase,
  Ghbdtn.Settings,
  System.SyncObjs;

type
  TLangChangeEvent = procedure(ALang: TLangKind) of object;

  PKBDLLHOOKSTRUCT = ^TKBDLLHOOKSTRUCT;
  TKBDLLHOOKSTRUCT = record
    vkCode: DWORD;
    scanCode: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;

  TKbdHookManager = class
  private
    FHookHandle: HHOOK;
    FMouseHookHandle: HHOOK;
    FInputBuffer: TInputBuffer;
    FQueue: TInputQueue;
    FWorker: TInputWorker;
    FLastLShiftTime: UInt64;
    FLeftShiftDown: Boolean;
    FPendingDoubleShift: Boolean;
    FRightShiftDown: Boolean;
    FLastRShiftTime: UInt64;
    FPendingDoubleRightShift: Boolean;
    FRightUsedAsModifier: Boolean;
    FRightTapCount: Integer;
    FRightTapTick: UInt64;
    FLastCaseText: string;
    FLastSelectionOriginal: string;
    FLastSelectionConverted: string;
    FCaseLock: TCriticalSection;
    FSelectionArmed: Boolean;
    FSelectionArmedTick: UInt64;
    FShiftTapCount: Integer;
    FShiftTapTick: UInt64;
    FShiftUsedAsModifier: Boolean;
    FOnLangChange: TLangChangeEvent;
    FLastLang: TLangKind;
    FLastHKL: HKL;
    FSuppressLayoutSoundUntil: UInt64;
    FFocusLayoutQuietUntil: UInt64;
    FLastWindow: HWND;
    FCurrentProcess: string;
    FLastExternalWindow: HWND;
    FLastExternalProcess: string;
    FWindowContextReady: Boolean;
    FTemporarilyDisabledProcess: string;
    FLastConvertedText: string;
    FLastConvertedLen: Integer;
    FLastConversionTick: UInt64;
    FLastTypedWord: string;
    FConversionLesson: Integer;
    FPhrase: TPhraseContext;
    FPendingPhraseLang: TLangKind;
    FBackspaceRun: Integer;
    FQuestionFixPending: Boolean;
    FAwaitQuestionSpace: Boolean;
    FConsumedDelimiterVK: Word;
    FGloballyPaused: Boolean;
    FPauseKeyDown: Boolean;
    FMouseDown: Boolean;
    FMouseDragged: Boolean;
    FMouseDownPoint: TPoint;
    procedure ClearLastConversion;
    procedure ResetContext;
    function IsSelectionStillArmed: Boolean;
    procedure ArmSelectionGesture;
    procedure ResetShiftGestureState;
    procedure MarkShiftUsedAsModifier;
    procedure ClearShiftPressFlags;
    function ReadLeftShiftTransition(AIsKeyDown, AIsKeyUp: Boolean): TLeftShiftTransition;
    procedure NoteSelectionShiftTap;
    function IsLayoutHotkeyChord: Boolean;
    procedure HandleSelectionLeftShift(ATransition: TLeftShiftTransition);
    procedure HandleSoloLeftShift(ATransition: TLeftShiftTransition);
    procedure IgnoreLeftShiftWhileDisabled(AIsKeyDown, AIsKeyUp: Boolean);
    procedure TrackCapturedInput(const AInput: TQueuedInput);
    procedure HandleExplicitUndo;
    procedure HandleLeftShiftEvent(AIsKeyDown, AIsKeyUp: Boolean);
    procedure HandleRightShiftEvent(AIsKeyDown, AIsKeyUp: Boolean);
    procedure HandleDoubleRightShift;
    procedure ClearLastCase;
    function TakeSelectionUndo(out AOriginal, AConverted: string): Boolean;
    function ReadCaseText: string;
    procedure HandleBackspace;
    function HandleWordDelimiter(ALang: TLangKind; VKCode: DWORD;
      APunctuation: Char): Boolean;
    procedure HandlePrintableKey(VKCode: DWORD; ALang: TLangKind);
    function CurrentApplicationEnabled: Boolean;
    function GetProcessNameForWindow(AWindow: HWND): string;
    procedure EnqueueWork(const AItem: TInputWorkItem);
    procedure QueueLearningSave(const AWord: string; AAction: TLearningAction);
    function LearningProcessName: string;
    procedure RememberConversionLesson(AAction: TLearningAction);
    procedure NoteConversionKept;
    procedure SettlePendingPhrase(AKept: Boolean);
    procedure RevertPhraseToTypedLayout;
    procedure RememberCommittedWord(ALang: TLangKind; const AText: string);
    function CurrentProfile: TApplicationProfile;
  public
    constructor Create;
    destructor Destroy; override;
    procedure StartHook;
    procedure StopHook;
    procedure CheckLangChange;
    function OnHookKeyboard(Code: Integer; WParam: WPARAM; LParam: LPARAM): Boolean;
    procedure HandleDoubleLeftShift;
    procedure NotifyMouse(AMessage: WPARAM; const APoint: TPoint);
    procedure ToggleCurrentApplicationDisabled;
    function IsCurrentApplicationDisabled: Boolean;
    procedure ToggleCurrentApplicationRule;
    function IsCurrentApplicationAutoSwitchEnabled: Boolean;
    procedure AddCurrentApplicationToExclusions;
    function IsGloballyPaused: Boolean;
    procedure ToggleGlobalPause;
    function CurrentLearningProcess: string;
    procedure RememberCaseText(const AText: string);
    procedure RememberSelectionConversion(const AOriginal, AConverted: string);
    property OnLangChange: TLangChangeEvent read FOnLangChange write FOnLangChange;
  end;

var
  HookManager: TKbdHookManager = nil;

implementation

uses
  Winapi.Messages,
  System.Classes,
  Ghbdtn.Analyzer,
  Ghbdtn.CaretHint,
  Ghbdtn.Fixer,
  Ghbdtn.Sound,
  Ghbdtn.Diagnostics,
  Ghbdtn.Password;

const
  LeftShiftMinInterval = 0;
  LeftShiftMaxInterval = 650;
  SelectionArmWindowMs = 4000;
  MouseDragSlop = 4;
  LowLevelHookExtended = $01;
  LowLevelHookUp = $80;
  LearningUndoWindowMs = 3000;
  MaxSelectionUndoChars = 512;
  LessonNone = 0;
  LessonWeakReject = 1;
  LessonStrongReject = 2;
  ProcessQueryLimitedInformation = $1000;

function QueryFullProcessImageNameW(AProcess: THandle; AFlags: DWORD;
  AExeName: PWideChar; var ASize: DWORD): BOOL; stdcall;
  external kernel32 name 'QueryFullProcessImageNameW';

function IsNavigationOrEditKey(AVirtualKey: DWORD): Boolean; forward;

function LowLevelKeyboardProc(Code: Integer; WParam: WPARAM;
  LParam: LPARAM): LRESULT; stdcall;
begin
  if (Code = HC_ACTION) and (HookManager <> nil) and
     HookManager.OnHookKeyboard(Code, WParam, LParam) then
    Exit(1);
  Result := CallNextHookEx(0, Code, WParam, LParam);
end;

type
  PLowLevelMouse = ^TLowLevelMouse;
  TLowLevelMouse = record
    pt: TPoint;
    mouseData: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;

function LowLevelMouseProc(Code: Integer; WParam: WPARAM;
  LParam: LPARAM): LRESULT; stdcall;
var
  Info: PLowLevelMouse;
begin
  if (Code = HC_ACTION) and (HookManager <> nil) and (LParam <> 0) and
     ((WParam = WM_MOUSEMOVE) or (WParam = WM_LBUTTONDOWN) or
      (WParam = WM_LBUTTONUP) or (WParam = WM_LBUTTONDBLCLK) or
      (WParam = WM_RBUTTONDOWN) or (WParam = WM_MBUTTONDOWN) or
      (WParam = WM_XBUTTONDOWN)) then
  begin
    Info := PLowLevelMouse(LParam);
    HookManager.NotifyMouse(WParam, Info^.pt);
  end;
  Result := CallNextHookEx(0, Code, WParam, LParam);
end;

constructor TKbdHookManager.Create;
begin
  inherited Create;
  FInputBuffer := TInputBuffer.Create;
  FCaseLock := TCriticalSection.Create;
  FQueue := TInputQueue.Create;
  FWorker := TInputWorker.Create(FQueue);
  FWorker.Start;
  FLastLang := lkUnknown;
  FLastHKL := 0;
end;

destructor TKbdHookManager.Destroy;
begin
  StopHook;
  FQueue.Stop;
  FWorker.WaitFor;
  FWorker.Free;
  FQueue.Free;
  FInputBuffer.Free;
  FCaseLock.Free;
  inherited Destroy;
end;

procedure TKbdHookManager.StartHook;
begin
  if FHookHandle = 0 then
  begin
    FHookHandle := SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc,
      HInstance, 0);
    if FHookHandle = 0 then
    begin
      LogDiagnostic(dlError, deHookInstallFailed, GetLastError);
      raise EOSError.CreateFmt('Keyboard hook installation failed (%d)',
        [GetLastError]);
    end;
  end;
  if FMouseHookHandle = 0 then
  begin
    FMouseHookHandle := SetWindowsHookEx(WH_MOUSE_LL, LowLevelMouseProc,
      HInstance, 0);
    if FMouseHookHandle = 0 then
    begin
      UnhookWindowsHookEx(FHookHandle);
      FHookHandle := 0;
      LogDiagnostic(dlError, deHookInstallFailed, GetLastError);
      raise EOSError.CreateFmt('Mouse hook installation failed (%d)',
        [GetLastError]);
    end;
  end;
end;

procedure TKbdHookManager.StopHook;
begin
  if FMouseHookHandle <> 0 then
  begin
    if not UnhookWindowsHookEx(FMouseHookHandle) then
      LogDiagnostic(dlError, deHookUninstallFailed, GetLastError);
    FMouseHookHandle := 0;
  end;
  if FHookHandle <> 0 then
  begin
    if not UnhookWindowsHookEx(FHookHandle) then
      LogDiagnostic(dlError, deHookUninstallFailed, GetLastError);
    FHookHandle := 0;
  end;
end;

function TKbdHookManager.GetProcessNameForWindow(AWindow: HWND): string;
var
  ProcessId: DWORD;
  ProcessHandle: THandle;
  Buffer: array[0..MAX_PATH] of Char;
  Size: DWORD;
begin
  Result := '';
  GetWindowThreadProcessId(AWindow, ProcessId);
  // The limited right is enough for QueryFullProcessImageName and, unlike
  // PROCESS_VM_READ, is granted for elevated processes too.
  ProcessHandle := OpenProcess(ProcessQueryLimitedInformation, False,
    ProcessId);
  if ProcessHandle = 0 then
    Exit;
  try
    Size := Length(Buffer);
    if QueryFullProcessImageNameW(ProcessHandle, 0, Buffer, Size) then
      SetString(Result, Buffer, Size);
  finally
    CloseHandle(ProcessHandle);
  end;
end;

procedure TKbdHookManager.ClearLastConversion;
begin
  FLastConvertedText := '';
  FLastConvertedLen := 0;
  FLastConversionTick := 0;
  FLastTypedWord := '';
  FConversionLesson := LessonNone;
  FBackspaceRun := 0;
  FPendingPhraseLang := lkUnknown;
end;

procedure TKbdHookManager.ResetContext;
begin
  FInputBuffer.Clear;
  ClearLastConversion;
  FBackspaceRun := 0;
  FPendingDoubleShift := False;
  FSelectionArmed := False;
  FSelectionArmedTick := 0;
  FShiftTapCount := 0;
  FShiftTapTick := 0;
  FShiftUsedAsModifier := False;
  FQuestionFixPending := False;
  FAwaitQuestionSpace := False;
  FConsumedDelimiterVK := 0;
  FPendingPhraseLang := lkUnknown;
  FPendingDoubleRightShift := False;
  FRightUsedAsModifier := False;
  FRightTapCount := 0;
  FRightTapTick := 0;
  ClearLastCase;
end;

procedure TKbdHookManager.ClearLastCase;
begin
  FCaseLock.Enter;
  try
    FLastCaseText := '';
    FLastSelectionOriginal := '';
    FLastSelectionConverted := '';
  finally
    FCaseLock.Leave;
  end;
end;

function TKbdHookManager.ReadCaseText: string;
begin
  FCaseLock.Enter;
  try
    Result := FLastCaseText;
  finally
    FCaseLock.Leave;
  end;
end;

procedure TKbdHookManager.RememberCaseText(const AText: string);
begin
  FCaseLock.Enter;
  try
    FLastCaseText := AText;
    FLastSelectionOriginal := '';
    FLastSelectionConverted := '';
  finally
    FCaseLock.Leave;
  end;
end;

procedure TKbdHookManager.RememberSelectionConversion(const AOriginal,
  AConverted: string);
begin
  // Only single-line text is erased and retyped to undo the conversion;
  // line breaks do not map one-to-one to Backspace presses.
  if (AOriginal = '') or (AConverted = '') or
     (Length(AConverted) > MaxSelectionUndoChars) or
     (Pos(#10, AConverted) > 0) or (Pos(#13, AConverted) > 0) then
  begin
    ClearLastCase;
    Exit;
  end;
  FCaseLock.Enter;
  try
    FLastSelectionOriginal := AOriginal;
    FLastSelectionConverted := AConverted;
  finally
    FCaseLock.Leave;
  end;
end;

function TKbdHookManager.IsSelectionStillArmed: Boolean;
begin
  Result := FSelectionArmed and
    (GetTickCount64 - FSelectionArmedTick <= SelectionArmWindowMs);
  if FSelectionArmed and not Result then
  begin
    FSelectionArmed := False;
    FSelectionArmedTick := 0;
    FShiftTapCount := 0;
    FShiftTapTick := 0;
    FRightTapCount := 0;
    FRightTapTick := 0;
  end;
end;

procedure TKbdHookManager.ArmSelectionGesture;
begin
  FSelectionArmed := True;
  FSelectionArmedTick := GetTickCount64;
  FLastLShiftTime := 0;
  FPendingDoubleShift := False;
  FLastRShiftTime := 0;
  FPendingDoubleRightShift := False;
  FRightTapCount := 0;
  FRightTapTick := 0;
  FShiftTapCount := 0;
  FShiftTapTick := 0;
end;

procedure TKbdHookManager.ResetShiftGestureState;
begin
  FPendingDoubleShift := False;
  FLastLShiftTime := 0;
  FShiftTapCount := 0;
  FShiftTapTick := 0;
  FLeftShiftDown := False;
  FShiftUsedAsModifier := False;
  FPendingDoubleRightShift := False;
  FLastRShiftTime := 0;
  FRightTapCount := 0;
  FRightTapTick := 0;
  FRightShiftDown := False;
  FRightUsedAsModifier := False;
end;

procedure TKbdHookManager.MarkShiftUsedAsModifier;
begin
  // Shift is held together with another key - ignore this press as a gesture.
  FShiftUsedAsModifier := True;
  FLastLShiftTime := 0;
  FPendingDoubleShift := False;
  FShiftTapCount := 0;
  FShiftTapTick := 0;
end;

procedure TKbdHookManager.ClearShiftPressFlags;
begin
  FShiftUsedAsModifier := False;
  FPendingDoubleShift := False;
  FLastLShiftTime := 0;
  FShiftTapCount := 0;
  FShiftTapTick := 0;
end;

procedure TKbdHookManager.NotifyMouse(AMessage: WPARAM; const APoint: TPoint);
var
  Dragged: Boolean;
begin
  case AMessage of
    WM_MOUSEMOVE:
      if FMouseDown and not FMouseDragged and
         ((Abs(APoint.X - FMouseDownPoint.X) > MouseDragSlop) or
          (Abs(APoint.Y - FMouseDownPoint.Y) > MouseDragSlop)) then
        FMouseDragged := True;
    WM_LBUTTONDOWN:
      begin
        // The corrected word is already on screen. A click does not cancel it.
        SettlePendingPhrase(True);
        ResetContext;
        FMouseDown := True;
        FMouseDragged := False;
        FMouseDownPoint := APoint;
      end;
    WM_LBUTTONUP:
      begin
        Dragged := FMouseDown and (FMouseDragged or
          ((GetAsyncKeyState(VK_SHIFT) and $8000) <> 0));
        FMouseDown := False;
        FMouseDragged := False;
        if Dragged then
          ArmSelectionGesture;
      end;
    WM_LBUTTONDBLCLK:
      begin
        SettlePendingPhrase(True);
        ResetContext;
        FMouseDown := False;
        FMouseDragged := False;
        ArmSelectionGesture;
      end;
    WM_RBUTTONDOWN, WM_MBUTTONDOWN, WM_XBUTTONDOWN:
      begin
        SettlePendingPhrase(True);
        ResetContext;
        FMouseDown := False;
        FMouseDragged := False;
      end;
  end;
end;

function TKbdHookManager.IsGloballyPaused: Boolean;
begin
  Result := FGloballyPaused;
end;

procedure TKbdHookManager.ToggleGlobalPause;
begin
  FGloballyPaused := not FGloballyPaused;
  FPhrase := EmptyPhrase;
  ResetContext;
end;

function TKbdHookManager.CurrentLearningProcess: string;
begin
  Result := LearningProcessName;
end;

procedure TKbdHookManager.CheckLangChange;
var
  CurrentLang: TLangKind;
  CurrentHKL: HKL;
  CurrentWindow: HWND;
  ProcessId: DWORD;
  WindowClass: array[0..255] of Char;
  PreviousLang: TLangKind;
  Profile: TApplicationProfile;
  WindowChanged: Boolean;
begin
  CurrentWindow := GetForegroundWindow;
  WindowChanged := CurrentWindow <> FLastWindow;
  if WindowChanged then
  begin
    FLastWindow := CurrentWindow;
    ResetContext;
    FPhrase := EmptyPhrase;
    FWindowContextReady := False;
    // Focus changes report the layout twice (leaving window, then the new one).
    FFocusLayoutQuietUntil := GetTickCount64 + 600;
  end;
  if not FWindowContextReady then
  begin
    FCurrentProcess := GetProcessNameForWindow(CurrentWindow);
    FWindowContextReady := True;
    ProcessId := 0;
    GetWindowThreadProcessId(CurrentWindow, ProcessId);
    WindowClass[0] := #0;
    GetClassName(CurrentWindow, WindowClass, Length(WindowClass));
    if IsUsableExternalTarget(ProcessId, GetCurrentProcessId,
      WindowClass) then
    begin
      FLastExternalWindow := CurrentWindow;
      FLastExternalProcess := FCurrentProcess;
    end;
  end;

  if FQueue.IsReplacementPending then
    Exit;
  CurrentHKL := GetForegroundKeyboardLayout;
  CurrentLang := HKLToLangKind(CurrentHKL);
  if CurrentLang = FLastLang then
  begin
    FLastHKL := CurrentHKL;
    Exit;
  end;

  PreviousLang := FLastLang;
  FLastHKL := CurrentHKL;
  FLastLang := CurrentLang;
  if Assigned(FOnLangChange) then
    FOnLangChange(CurrentLang);

  // Sound for manual Alt+Shift / Win+Space. Skip when we just switched ourselves
  // (worker already plays its own switch beep).
  if (not WindowChanged) and
     (GetTickCount64 >= FFocusLayoutQuietUntil) and
     (PreviousLang <> lkUnknown) and (CurrentLang <> lkUnknown) and
     (PreviousLang <> CurrentLang) and
     (GetTickCount64 >= FSuppressLayoutSoundUntil) then
  begin
    Profile := CurrentProfile;
    if Profile.SoundOnSwitch then
      PlaySwitchBeep(CurrentLang);
  end;
end;

function TKbdHookManager.CurrentApplicationEnabled: Boolean;
begin
  Result := FWindowContextReady and
    not AppSettings.IsProcessExcluded(FCurrentProcess) and
    not SameText(FCurrentProcess, FTemporarilyDisabledProcess);
end;

function TKbdHookManager.CurrentProfile: TApplicationProfile;
begin
  Result := AppSettings.ResolveProfile(FCurrentProcess);
end;

procedure TKbdHookManager.ToggleCurrentApplicationDisabled;
begin
  if (FLastExternalProcess = '') or not IsWindow(FLastExternalWindow) then
    Exit;
  if SameText(FLastExternalProcess, FTemporarilyDisabledProcess) then
    FTemporarilyDisabledProcess := ''
  else
    FTemporarilyDisabledProcess := FLastExternalProcess;
  ResetContext;
end;

function TKbdHookManager.IsCurrentApplicationDisabled: Boolean;
begin
  Result := (FLastExternalProcess <> '') and
    IsWindow(FLastExternalWindow) and
    SameText(FLastExternalProcess, FTemporarilyDisabledProcess);
end;

procedure TKbdHookManager.ToggleCurrentApplicationRule;
begin
  if (FLastExternalProcess = '') or not IsWindow(FLastExternalWindow) then
    Exit;
  AppSettings.SetApplicationRule(FLastExternalProcess,
    not AppSettings.IsAutoSwitchEnabledFor(FLastExternalProcess));
  AppSettings.SaveToFile;
  ResetContext;
end;

function TKbdHookManager.IsCurrentApplicationAutoSwitchEnabled: Boolean;
begin
  Result := (FLastExternalProcess <> '') and
    IsWindow(FLastExternalWindow) and
    AppSettings.IsAutoSwitchEnabledFor(FLastExternalProcess);
end;

procedure TKbdHookManager.AddCurrentApplicationToExclusions;
var
  ProcessName: string;
begin
  if not IsWindow(FLastExternalWindow) then
    Exit;
  ProcessName := LowerCase(ExtractFileName(FLastExternalProcess));
  if (ProcessName = '') or AppSettings.IsProcessExcluded(ProcessName) then
    Exit;
  AppSettings.AddExclusion(ProcessName);
  AppSettings.SaveToFile;
  ResetContext;
end;

procedure TKbdHookManager.EnqueueWork(const AItem: TInputWorkItem);
begin
  if AItem.Kind in [iwReplaceWord, iwReplaceSelection, iwSwitchLayout] then
    FSuppressLayoutSoundUntil := GetTickCount64 + 500;
  FQueue.EnqueueWork(AItem);
end;

procedure TKbdHookManager.QueueLearningSave(const AWord: string;
  AAction: TLearningAction);
var
  Item: TInputWorkItem;
begin
  FillChar(Item, SizeOf(Item), 0);
  Item.Kind := iwPersistSettings;
  Item.LearningWord := AWord;
  Item.LearningAction := AAction;
  Item.LearningProcess := LearningProcessName;
  EnqueueWork(Item);
end;

function TKbdHookManager.LearningProcessName: string;
begin
  Result := LowerCase(ExtractFileName(FCurrentProcess));
  if Result = '' then
    Result := LowerCase(ExtractFileName(FLastExternalProcess));
end;

procedure TKbdHookManager.RememberConversionLesson(AAction: TLearningAction);
var
  Word: string;
begin
  if not IsWithinLearningWindow(FLastConversionTick, GetTickCount64,
    LearningUndoWindowMs) then
    Exit;
  if AAction = laRejectStrong then
  begin
    if FConversionLesson = LessonStrongReject then
      Exit;
    FConversionLesson := LessonStrongReject;
  end
  else if AAction = laRejectWeak then
  begin
    if FConversionLesson <> LessonNone then
      Exit;
    FConversionLesson := LessonWeakReject;
  end
  else
    Exit;
  if FLastTypedWord <> '' then
    Word := FLastTypedWord
  else
    Word := ConvertStringSwap(FLastConvertedText);
  if Word <> '' then
    QueueLearningSave(Word, AAction);
end;

procedure TKbdHookManager.SettlePendingPhrase(AKept: Boolean);
var
  Lang: TLangKind;
begin
  if FPendingPhraseLang = lkUnknown then
    Exit;
  if AKept then
    Lang := FPendingPhraseLang
  else if FPendingPhraseLang = lkRU then
    Lang := lkEN
  else
    Lang := lkRU;
  FPendingPhraseLang := lkUnknown;
  RememberPhraseLanguage(FPhrase, Lang);
end;

procedure TKbdHookManager.RevertPhraseToTypedLayout;
begin
  if FPendingPhraseLang <> lkUnknown then
  begin
    SettlePendingPhrase(False);
    Exit;
  end;
  if FPhrase.Count = 0 then
    Exit;
  if FPhrase.Languages[FPhrase.Count - 1] = lkRU then
    FPhrase.Languages[FPhrase.Count - 1] := lkEN
  else if FPhrase.Languages[FPhrase.Count - 1] = lkEN then
    FPhrase.Languages[FPhrase.Count - 1] := lkRU;
end;

procedure TKbdHookManager.RememberCommittedWord(ALang: TLangKind;
  const AText: string);
begin
  if (ALang <> lkUnknown) and ContainsPhraseLetter(AText) then
    RememberPhraseLanguage(FPhrase, ALang);
end;

procedure TKbdHookManager.NoteConversionKept;
begin
  // The next word started and the fix is still there, so an earlier
  // rejection of this typed word was probably a mistake.
  SettlePendingPhrase(True);
  if (FLastTypedWord <> '') and (FConversionLesson = LessonNone) and
     (FBackspaceRun = 0) and
     (AppSettings.LearningCount(FLastTypedWord, LearningProcessName) > 0) then
    QueueLearningSave(FLastTypedWord, laAccept);
  ClearLastConversion;
end;

function TKbdHookManager.TakeSelectionUndo(out AOriginal,
  AConverted: string): Boolean;
begin
  FCaseLock.Enter;
  try
    AOriginal := FLastSelectionOriginal;
    AConverted := FLastSelectionConverted;
  finally
    FCaseLock.Leave;
  end;
  Result := (AOriginal <> '') and (AConverted <> '');
end;

procedure TKbdHookManager.HandleDoubleLeftShift;
var
  Item: TInputWorkItem;
  CurrentLang: TLangKind;
  Profile: TApplicationProfile;
  ManualWord, UndoOriginal, UndoConverted: string;
  PreferSelection: Boolean;
begin
  FillChar(Item, SizeOf(Item), 0);
  ManualWord := '';
  PreferSelection := IsSelectionStillArmed and FInputBuffer.IsEmpty;
  CurrentLang := GetForegroundLangKind;
  if CurrentLang = lkRU then
    Item.TargetLang := lkEN
  else
    Item.TargetLang := lkRU;
  Item.TargetWindow := GetForegroundWindow;
  Profile := CurrentProfile;
  Item.PlaySwitchSound := Profile.SoundOnSwitch;
  Item.LearningProcess := LearningProcessName;
  if PreferSelection then
  begin
    // Shift+arrows or a mouse selection: convert that selection.
    Item.Kind := iwReplaceSelection;
    FInputBuffer.Clear;
  end
  else if not FInputBuffer.IsEmpty then
  begin
    Item.Kind := iwReplaceWord;
    Item.OldWordLength := FInputBuffer.BufferLength;
    Item.NewText := ConvertStringSwap(FInputBuffer.BufferText);
    if Item.NewText <> FInputBuffer.BufferText then
    begin
      ManualWord := FInputBuffer.BufferText;
      FLastTypedWord := ManualWord;
      FLastConvertedText := Item.NewText;
      FLastConvertedLen := Length(Item.NewText);
      FLastConversionTick := GetTickCount64;
      FConversionLesson := LessonNone;
      FBackspaceRun := 0;
      SettlePendingPhrase(True);
      RememberPhraseLanguage(FPhrase, Item.TargetLang);
    end;
    FInputBuffer.Clear;
  end
  else if FLastConvertedText <> '' then
  begin
    Item.Kind := iwReplaceWord;
    Item.OldWordLength := FLastConvertedLen;
    Item.NewText := ConvertStringSwap(FLastConvertedText);
    RevertPhraseToTypedLayout;
    RememberConversionLesson(laRejectStrong);
    ClearLastConversion;
  end
  else if TakeSelectionUndo(UndoOriginal, UndoConverted) then
  begin
    // Undo of the previous selection or caret-word conversion; a further
    // double Left Shift converts the text again.
    Item.Kind := iwReplaceWord;
    Item.OldWordLength := Length(UndoConverted);
    Item.NewText := UndoOriginal;
    Item.TargetLang := CurrentLang;
    Item.PlaySwitchSound := False;
    ClearLastConversion;
    RememberSelectionConversion(UndoConverted, UndoOriginal);
  end
  else
  begin
    Item.Kind := iwReplaceSelection;
    Item.FromCaret := True;
  end;
  FSelectionArmed := False;
  FSelectionArmedTick := 0;
  ResetShiftGestureState;
  EnqueueWork(Item);
  if ManualWord <> '' then
    QueueLearningSave(ManualWord, laManualSwitch);
end;

function TKbdHookManager.ReadLeftShiftTransition(AIsKeyDown,
  AIsKeyUp: Boolean): TLeftShiftTransition;
var
  PhysicallyDown: Boolean;
begin
  PhysicallyDown := (GetAsyncKeyState(VK_LSHIFT) and $8000) <> 0;
  // A missed KEYUP would leave the flag set, and the next press would
  // look like a repeat instead of a gesture.
  if AIsKeyDown and FLeftShiftDown and not PhysicallyDown then
    FLeftShiftDown := False;
  if AIsKeyUp then
    FLeftShiftDown := False;

  Result := TrackLeftShiftState(FLeftShiftDown, AIsKeyDown, AIsKeyUp);
  if AIsKeyUp then
    FLeftShiftDown := False;
end;

procedure TKbdHookManager.NoteSelectionShiftTap;
var
  NowTick: UInt64;
begin
  NowTick := GetTickCount64;
  if (FShiftTapCount > 0) and
     (NowTick - FShiftTapTick > LeftShiftMaxInterval) then
    FShiftTapCount := 0;
  Inc(FShiftTapCount);
  FShiftTapTick := NowTick;
end;

function TKbdHookManager.IsLayoutHotkeyChord: Boolean;
begin
  // Ctrl+Shift and Alt+Shift switch the layout in Windows; that Shift press
  // is part of the chord, not a tap of the double-Shift gesture.
  Result := ((GetAsyncKeyState(VK_CONTROL) and $8000) <> 0) or
    ((GetAsyncKeyState(VK_MENU) and $8000) <> 0);
end;

// Left Shift events are never swallowed. A swallowed press leaves Windows
// without Shift, so the following key is typed unshifted.
// The gesture is recognised on the release of the second tap.
procedure TKbdHookManager.HandleSelectionLeftShift(
  ATransition: TLeftShiftTransition);
begin
  // Shift+Home/arrows armed a selection. Convert it only on a full double tap.
  case ATransition of
    lstPressed:
      begin
        FShiftUsedAsModifier := IsLayoutHotkeyChord;
        if FShiftUsedAsModifier then
          FShiftTapCount := 0
        else
          NoteSelectionShiftTap;
      end;
    lstReleased:
      if FShiftTapCount >= 2 then
      begin
        ClearShiftPressFlags;
        HandleDoubleLeftShift;
      end
      else if FShiftTapCount = 0 then
        ClearShiftPressFlags;
  end;
end;

procedure TKbdHookManager.HandleSoloLeftShift(
  ATransition: TLeftShiftTransition);
begin
  if ATransition = lstReleased then
  begin
    if FPendingDoubleShift then
    begin
      ClearShiftPressFlags;
      HandleDoubleLeftShift;
    end;
    Exit;
  end;
  if ATransition <> lstPressed then
    Exit;

  // A fresh press does not inherit a modifier flag left by an earlier chord.
  FShiftUsedAsModifier := False;
  FShiftTapCount := 0;
  FShiftTapTick := 0;
  if not AppSettings.DoubleLeftShiftEnabled then
    Exit;
  if IsLayoutHotkeyChord then
  begin
    MarkShiftUsedAsModifier;
    Exit;
  end;
  if IsDoubleLeftShift(FLastLShiftTime, GetTickCount64, LeftShiftMinInterval,
    LeftShiftMaxInterval) then
    FPendingDoubleShift := True;
end;

procedure TKbdHookManager.HandleLeftShiftEvent(AIsKeyDown,
  AIsKeyUp: Boolean);
var
  Transition: TLeftShiftTransition;
begin
  Transition := ReadLeftShiftTransition(AIsKeyDown, AIsKeyUp);
  if (Transition = lstReleased) and FShiftUsedAsModifier then
  begin
    // KEYUP after Shift+Home / Shift+letter is not a convert gesture.
    ClearShiftPressFlags;
    Exit;
  end;
  if IsSelectionStillArmed then
    HandleSelectionLeftShift(Transition)
  else
    HandleSoloLeftShift(Transition);
end;

procedure TKbdHookManager.IgnoreLeftShiftWhileDisabled(AIsKeyDown,
  AIsKeyUp: Boolean);
begin
  TrackLeftShiftState(FLeftShiftDown, AIsKeyDown, AIsKeyUp);
  FPendingDoubleShift := False;
  FShiftUsedAsModifier := False;
  FShiftTapCount := 0;
  FLastLShiftTime := 0;
end;

procedure TKbdHookManager.HandleDoubleRightShift;
var
  Item: TInputWorkItem;
  CaseText, NextText: string;
  PreferSelection: Boolean;
begin
  FPendingDoubleRightShift := False;
  FRightTapCount := 0;
  FRightTapTick := 0;
  FRightUsedAsModifier := False;
  FLastRShiftTime := 0;
  FillChar(Item, SizeOf(Item), 0);
  Item.TargetWindow := GetForegroundWindow;
  Item.CaseCycle := True;
  Item.LearningProcess := LearningProcessName;
  PreferSelection := IsSelectionStillArmed and FInputBuffer.IsEmpty;
  if PreferSelection then
  begin
    Item.Kind := iwReplaceSelection;
    FInputBuffer.Clear;
  end
  else if not FInputBuffer.IsEmpty then
  begin
    CaseText := FInputBuffer.BufferText;
    NextText := InvertLetterCase(CaseText);
    if NextText = CaseText then
      Exit;
    Item.Kind := iwReplaceWord;
    Item.OldWordLength := FInputBuffer.BufferLength;
    Item.NewText := NextText;
    FInputBuffer.Clear;
  end
  else
  begin
    CaseText := ReadCaseText;
    if CaseText <> '' then
    begin
      NextText := InvertLetterCase(CaseText);
      if NextText = CaseText then
        Exit;
      Item.Kind := iwReplaceWord;
      Item.OldWordLength := Length(CaseText);
      Item.NewText := NextText;
    end
    else
    begin
      Item.Kind := iwReplaceSelection;
      Item.FromCaret := True;
    end;
  end;
  ClearLastConversion;
  FSelectionArmed := False;
  FSelectionArmedTick := 0;
  EnqueueWork(Item);
end;

procedure TKbdHookManager.HandleRightShiftEvent(AIsKeyDown, AIsKeyUp: Boolean);
var
  Transition: TLeftShiftTransition;
  PhysicallyDown: Boolean;
begin
  // VK_RSHIFT is not a reliable GetAsyncKeyState argument. VK_SHIFT is.
  PhysicallyDown := (GetAsyncKeyState(VK_SHIFT) and $8000) <> 0;
  if AIsKeyDown and FRightShiftDown and not PhysicallyDown then
    FRightShiftDown := False;
  if AIsKeyUp then
    FRightShiftDown := False;
  Transition := TrackLeftShiftState(FRightShiftDown, AIsKeyDown, AIsKeyUp);
  if AIsKeyUp then
    FRightShiftDown := False;

  if not CurrentApplicationEnabled then
  begin
    FPendingDoubleRightShift := False;
    FRightUsedAsModifier := False;
    FRightTapCount := 0;
    FLastRShiftTime := 0;
    Exit;
  end;

  if (Transition = lstReleased) and FRightUsedAsModifier then
  begin
    FRightUsedAsModifier := False;
    FPendingDoubleRightShift := False;
    FLastRShiftTime := 0;
    FRightTapCount := 0;
    Exit;
  end;

  if IsSelectionStillArmed then
  begin
    if Transition = lstPressed then
    begin
      FRightUsedAsModifier := IsLayoutHotkeyChord;
      if FRightUsedAsModifier then
        FRightTapCount := 0
      else if (FRightTapCount = 0) or
              (GetTickCount64 - FRightTapTick > LeftShiftMaxInterval) then
      begin
        FRightTapCount := 1;
        FRightTapTick := GetTickCount64;
      end
      else
        Inc(FRightTapCount);
    end
    else if (Transition = lstReleased) and (FRightTapCount >= 2) then
    begin
      FRightTapCount := 0;
      HandleDoubleRightShift;
    end;
    Exit;
  end;

  if Transition = lstReleased then
  begin
    if FPendingDoubleRightShift then
      HandleDoubleRightShift;
    Exit;
  end;
  if Transition <> lstPressed then
    Exit;
  FRightUsedAsModifier := False;
  FRightTapCount := 0;
  if IsLayoutHotkeyChord then
  begin
    FRightUsedAsModifier := True;
    FLastRShiftTime := 0;
    FPendingDoubleRightShift := False;
    Exit;
  end;
  if IsDoubleLeftShift(FLastRShiftTime, GetTickCount64, LeftShiftMinInterval,
    LeftShiftMaxInterval) then
    FPendingDoubleRightShift := True;
end;

procedure TKbdHookManager.HandleBackspace;
var
  Action: TLearningAction;
  TrackingConversion: Boolean;
begin
  ClearLastCase;
  FInputBuffer.RemoveLastChar;
  Inc(FBackspaceRun);
  FQuestionFixPending := False;
  FAwaitQuestionSpace := False;
  TrackingConversion := (FLastTypedWord <> '') or (FLastConvertedText <> '');
  if TrackingConversion then
  begin
    if not IsWithinLearningWindow(FLastConversionTick, GetTickCount64,
      LearningUndoWindowMs) then
    begin
      ClearLastConversion;
      Exit;
    end;
    if BackspaceLearningAction(FBackspaceRun, FLastConvertedLen, Action) then
      RememberConversionLesson(Action);
    if (FLastConvertedLen > 0) and (FBackspaceRun >= FLastConvertedLen) then
      ClearLastConversion;
    Exit;
  end;
  if FBackspaceRun >= 3 then
    ResetContext;
end;

function IsPunctuationKey(AVirtualKey: DWORD): Boolean;
begin
  // ; ' [ ] are Russian letters, so they stay inside the word:
  // nfr;t -> также, ' -> э, [ -> х, ] -> ъ.
  // Minus and plus are included: "-" and "+" end a word, "_" and "=" do not.
  Result := AVirtualKey in [VK_OEM_PLUS, VK_OEM_COMMA, VK_OEM_MINUS,
    VK_OEM_PERIOD, VK_OEM_2, VK_OEM_3, VK_OEM_5];
end;

function ShiftedDigitPunctuation(AVirtualKey: DWORD; ALang: TLangKind): Char;
const
  EnShiftDigits = ')!@#$%^&*(';
  RuShiftDigits = ')!"№;%:?*(';
begin
  Result := #0;
  if (AVirtualKey < Ord('0')) or (AVirtualKey > Ord('9')) then
    Exit;
  if ALang = lkRU then
    Result := RuShiftDigits[AVirtualKey - Ord('0') + 1]
  else
    Result := EnShiftDigits[AVirtualKey - Ord('0') + 1];
end;

function KeyedWordSeparator(AVirtualKey: DWORD; AShifted: Boolean;
  ALang: TLangKind): Char;
var
  Ch: Char;
begin
  // Numpad plus and minus are the same separators as the main keys.
  if AVirtualKey = VK_ADD then
    Exit('+');
  if AVirtualKey = VK_SUBTRACT then
    Exit('-');

  Result := #0;
  if IsPunctuationKey(AVirtualKey) then
  begin
    Ch := MapVirtualKeyToChar(AVirtualKey, AShifted, ALang);
    if (ALang = lkRU) and IsRussianLetterOnPunctuationKey(Ch) then
      Exit;
    // user_name and a=b stay one word. "-" and "+" end it.
    if (Ch = '_') or (Ch = '=') then
      Exit;
    Exit(Ch);
  end;
  if AShifted then
    Result := ShiftedDigitPunctuation(AVirtualKey, ALang);
  if Result <> #0 then
    Exit;
  // Colon on the English layout is Shift+;, the Russian letter "ж" unshifted.
  if MapVirtualKeyToChar(AVirtualKey, AShifted, ALang) = ':' then
    Result := ':';
end;

function DecisionNote(AMark: TDecisionMark): string;
begin
  case AMark of
    dmLearning: Result := 'обучение';
    dmDictionary: Result := 'словарь';
    dmLeave: Result := 'не трогать';
  else
    Result := '';
  end;
end;

function TKbdHookManager.HandleWordDelimiter(ALang: TLangKind;
  VKCode: DWORD; APunctuation: Char): Boolean;
var
  Analysis: TAnalysisResult;
  Item: TInputWorkItem;
    NeverSwitch: TNeverSwitchCallback;
  PreferSwitch: TPreferSwitchCallback;
  Profile: TApplicationProfile;
  ProcessName: string;
  QuestionArmed: Boolean;
  MarkerText: string;
begin
  Result := False;
  if FInputBuffer.IsEmpty then
  begin
    if (APunctuation = #0) and FAwaitQuestionSpace then
    begin
      FQuestionFixPending := True;
      FAwaitQuestionSpace := False;
    end;
    Exit;
  end;
  // A kept "," or "." ended the word that was already analyzed. Nothing is
  // typed after it, so there is no new word to check.
  if CharInSet(FInputBuffer.BufferText[Length(FInputBuffer.BufferText)],
    [',', '.']) then
  begin
    FInputBuffer.Clear;
    FBackspaceRun := 0;
    Exit;
  end;
  if ColonEndsASingleLetter(FInputBuffer.BufferText, APunctuation) then
  begin
    FInputBuffer.Clear;
    FBackspaceRun := 0;
    Exit;
  end;

  QuestionArmed := FQuestionFixPending;
  FQuestionFixPending := False;
  FAwaitQuestionSpace := False;
  Profile := CurrentProfile;
  if Profile.AutoSwitchEnabled then
  begin
    ProcessName := LearningProcessName;
    NeverSwitch :=
      function(const AWord: string): Boolean
      begin
        Result := AppSettings.IsNeverSwitchWord(AWord, ProcessName);
      end;
    PreferSwitch :=
      function(const AWord: string): Boolean
      begin
        Result := AppSettings.IsPreferSwitchWord(AWord, ProcessName);
      end;
    MarkerText := FInputBuffer.BufferText;
    Analysis := AnalyzeWord(MarkerText, ALang,
      Profile.HeuristicMode, NeverSwitch, PreferSwitch, FPhrase);
    if Analysis.Mark <> dmNone then
    begin
      if Analysis.NeedsSwitch then
        ShowCaretHint(Analysis.TargetLang, DecisionNote(Analysis.Mark))
      else
        ShowCaretHint(ALang, DecisionNote(Analysis.Mark));
    end;
    if Analysis.NeedsSwitch then
    begin
      FillChar(Item, SizeOf(Item), 0);
      Item.Kind := iwReplaceWord;
      Item.TargetWindow := GetForegroundWindow;
      Item.OldWordLength := FInputBuffer.BufferLength;
      Item.NewText := Analysis.ConvertedText;
      // "hello? xbnftncz" -> "hello, читается" (? on EN layout is ,)
      if QuestionArmed then
      begin
        Item.OldWordLength := Item.OldWordLength + 2;
        Item.NewText := ', ' + Analysis.ConvertedText;
      end;
      if APunctuation <> #0 then
      begin
        // In the English layout "," and "." are the Russian letters "б" and "ю".
        // When the word is converted to Russian they belong to the word.
        if (Analysis.TargetLang = lkRU) and
           CharInSet(APunctuation, [',', '.']) then
          Item.NewText := Item.NewText + ConvertCharSwap(APunctuation)
        else
          Item.NewText := Item.NewText + APunctuation;
        FConsumedDelimiterVK := Word(VKCode);
      end
      else
        Item.TrailingKey := Word(VKCode);
      Item.TargetLang := Analysis.TargetLang;
      Item.PlaySwitchSound := Profile.SoundOnSwitch;
      if (Analysis.TargetLang = lkRU) and CharInSet(APunctuation, [',', '.']) then
      begin
        FLastConvertedText := Item.NewText;
        FLastConvertedLen := Length(Item.NewText);
      end
      else
      begin
        FLastConvertedText := Analysis.ConvertedText;
        FLastConvertedLen := Length(Analysis.ConvertedText);
      end;
      FLastConversionTick := GetTickCount64;
      FLastTypedWord := MarkerText;
      FConversionLesson := LessonNone;
      SettlePendingPhrase(True);
      FPendingPhraseLang := Analysis.TargetLang;
      EnqueueWork(Item);
      Result := True;
    end
    else
    begin
      SettlePendingPhrase(True);
      RememberCommittedWord(ALang, MarkerText);
      if (APunctuation = '?') and IsEnglishQuestionMarker(MarkerText + '?') then
        FAwaitQuestionSpace := True;
    end;
  end
  else
  begin
    SettlePendingPhrase(True);
    RememberCommittedWord(ALang, FInputBuffer.BufferText);
  end;
  // In the English layout "," and "." are the Russian letters "b" and "yu".
  // A kept word stays in the buffer with the mark, so letters typed right after
  // it (Hf,jxbq) are analyzed together as one word.
  if (not Result) and (ALang = lkEN) and (APunctuation <> #0) and
     CharInSet(APunctuation, [',', '.']) then
  begin
    FInputBuffer.AddChar(APunctuation, ALang);
    FBackspaceRun := 0;
    Exit;
  end;
  FInputBuffer.Clear;
  FBackspaceRun := 0;
end;

procedure TKbdHookManager.HandlePrintableKey(VKCode: DWORD; ALang: TLangKind);
var
  Shifted: Boolean;
  Ch: Char;
  Profile: TApplicationProfile;
begin
  ClearLastCase;
  Profile := CurrentProfile;
  if (ALang = lkRU) and Profile.SoundOnRussianInput then
    PlayKeyClickRU;
  if FInputBuffer.IsEmpty and (FLastConvertedText <> '') then
    NoteConversionKept;
  Shifted := ((GetKeyState(VK_SHIFT) and $8000) <> 0) xor
    ((GetKeyState(VK_CAPITAL) and 1) <> 0);
  FAwaitQuestionSpace := False;
  Ch := MapVirtualKeyToChar(VKCode, Shifted, ALang);
  if Ch <> #0 then
    FInputBuffer.AddChar(Ch, ALang);
  FBackspaceRun := 0;
end;

procedure TKbdHookManager.HandleExplicitUndo;
begin
  RevertPhraseToTypedLayout;
  RememberConversionLesson(laRejectStrong);
  ResetContext;
end;

procedure TKbdHookManager.TrackCapturedInput(const AInput: TQueuedInput);
var
  Shifted: Boolean;
  Ch: Char;
  CurrentLang: TLangKind;
begin
  if AInput.VirtualKey = VK_LSHIFT then
  begin
    FLeftShiftDown := (AInput.Flags and KEYEVENTF_KEYUP) = 0;
    Exit;
  end;
  if (AInput.Flags and KEYEVENTF_KEYUP) <> 0 then
    Exit;
  if (AInput.VirtualKey = Ord('Z')) and
     ((GetAsyncKeyState(VK_CONTROL) and $8000) <> 0) then
  begin
    HandleExplicitUndo;
    Exit;
  end;
  if AInput.VirtualKey in [VK_CONTROL, VK_LCONTROL, VK_RCONTROL,
    VK_MENU, VK_LMENU, VK_RMENU, VK_LWIN, VK_RWIN] then
    Exit;
  if ((GetAsyncKeyState(VK_CONTROL) and $8000) <> 0) or
     ((GetAsyncKeyState(VK_MENU) and $8000) <> 0) or
     ((GetAsyncKeyState(VK_LWIN) and $8000) <> 0) or
     ((GetAsyncKeyState(VK_RWIN) and $8000) <> 0) or
     IsNavigationOrEditKey(AInput.VirtualKey) then
  begin
    ResetContext;
    Exit;
  end;
  if AInput.VirtualKey = VK_BACK then
  begin
    HandleBackspace;
    Exit;
  end;
  if AInput.VirtualKey in [VK_SPACE, VK_RETURN, VK_TAB] then
  begin
    FInputBuffer.Clear;
    FBackspaceRun := 0;
    Exit;
  end;
  if ((AInput.VirtualKey >= $30) and (AInput.VirtualKey <= $5A)) or
     ((AInput.VirtualKey >= VK_OEM_1) and
      (AInput.VirtualKey <= VK_OEM_7)) or
     (AInput.VirtualKey = VK_ADD) or
     (AInput.VirtualKey = VK_SUBTRACT) then
  begin
    CurrentLang := GetForegroundLangKind;
    Shifted := ((GetAsyncKeyState(VK_SHIFT) and $8000) <> 0) xor
      ((GetKeyState(VK_CAPITAL) and 1) <> 0);
    if KeyedWordSeparator(AInput.VirtualKey, Shifted, CurrentLang) <> #0 then
    begin
      FInputBuffer.Clear;
      FBackspaceRun := 0;
      Exit;
    end;
    if FInputBuffer.IsEmpty and (FLastConvertedText <> '') then
      NoteConversionKept;
    Ch := MapVirtualKeyToChar(AInput.VirtualKey, Shifted, CurrentLang);
    if Ch <> #0 then
      FInputBuffer.AddChar(Ch, CurrentLang);
    FBackspaceRun := 0;
  end;
end;

function IsNavigationOrEditKey(AVirtualKey: DWORD): Boolean;
begin
  Result := AVirtualKey in [VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN, VK_HOME,
    VK_END, VK_PRIOR, VK_NEXT, VK_DELETE, VK_INSERT, VK_ESCAPE];
end;

function TKbdHookManager.OnHookKeyboard(Code: Integer; WParam: WPARAM;
  LParam: LPARAM): Boolean;
var
  Kbd: PKBDLLHOOKSTRUCT;
  Captured: TQueuedInput;
  IsKeyDown: Boolean;
  IsKeyUp: Boolean;
  Shifted: Boolean;
  Punctuation: Char;
  CurrentWindow: HWND;
  CurrentLang: TLangKind;
begin
  Result := False;
  try
  Kbd := PKBDLLHOOKSTRUCT(LParam);
  // Unicode injection must pass through untouched. Swallowing its key-up
  // leaves Y held down and the rest of the text is typed as "yyyy...".
  if IsInjectingInput or IsOwnInput(Kbd^.dwExtraInfo) or
     (Kbd^.vkCode = VK_PACKET) then
    Exit;

  Captured.VirtualKey := Word(Kbd^.vkCode);
  Captured.ScanCode := Word(Kbd^.scanCode);
  Captured.Flags := 0;
  if (Kbd^.flags and LowLevelHookExtended) <> 0 then
    Captured.Flags := Captured.Flags or KEYEVENTF_EXTENDEDKEY;
  if (Kbd^.flags and LowLevelHookUp) <> 0 then
    Captured.Flags := Captured.Flags or KEYEVENTF_KEYUP;
  if FQueue.TryCaptureReplay(Captured) then
  begin
    TrackCapturedInput(Captured);
    Exit(True);
  end;

  CurrentWindow := GetForegroundWindow;
  if CurrentWindow <> FLastWindow then
  begin
    FLastWindow := CurrentWindow;
    FCurrentProcess := '';
    FWindowContextReady := False;
    ResetContext;
    FPhrase := EmptyPhrase;
  end;

  IsKeyDown := (WParam = WM_KEYDOWN) or (WParam = WM_SYSKEYDOWN);
  IsKeyUp := (WParam = WM_KEYUP) or (WParam = WM_SYSKEYUP);

  if (FConsumedDelimiterVK <> 0) and (Kbd^.vkCode = FConsumedDelimiterVK) then
  begin
    if IsKeyUp then
      FConsumedDelimiterVK := 0;
    Exit(True);
  end;

  if Kbd^.vkCode = VK_PAUSE then
  begin
    if IsKeyDown and not FPauseKeyDown then
    begin
      FPauseKeyDown := True;
      ToggleGlobalPause;
    end
    else if IsKeyUp then
      FPauseKeyDown := False;
    Exit(True);
  end;
  if FGloballyPaused then
    Exit;

  if IsFocusedPasswordField then
  begin
    ResetContext;
    Exit;
  end;

  if Kbd^.vkCode in [VK_MENU, VK_LMENU, VK_RMENU] then
    Exit;

  if Kbd^.vkCode = VK_LSHIFT then
  begin
    if CurrentApplicationEnabled then
      HandleLeftShiftEvent(IsKeyDown, IsKeyUp)
    else
      IgnoreLeftShiftWhileDisabled(IsKeyDown, IsKeyUp);
    Exit;
  end;

  if IsRightShiftKey(Kbd^.vkCode, Kbd^.scanCode) then
  begin
    HandleRightShiftEvent(IsKeyDown, IsKeyUp);
    Exit;
  end;

  if not IsKeyDown then
    Exit;

  // Any other key while our tracked Shift is down = modifier chord.
  // Do not use GetAsyncKeyState here: after swallowed Shift events it can lie
  // and leave the modifier flag stuck for later double-Shift gestures.
  if FLeftShiftDown then
    MarkShiftUsedAsModifier;
  if FRightShiftDown then
    FRightUsedAsModifier := True;

  if not CurrentApplicationEnabled then
  begin
    ResetContext;
    Exit;
  end;
  if (Kbd^.vkCode = Ord('Z')) and
     ((GetAsyncKeyState(VK_CONTROL) and $8000) <> 0) then
  begin
    HandleExplicitUndo;
    Exit;
  end;
  if Kbd^.vkCode in [VK_CONTROL, VK_LCONTROL, VK_RCONTROL,
    VK_MENU, VK_LMENU, VK_RMENU, VK_LWIN, VK_RWIN] then
    Exit;
  if ((GetAsyncKeyState(VK_CONTROL) and $8000) <> 0) or
     ((GetAsyncKeyState(VK_MENU) and $8000) <> 0) or
     ((GetAsyncKeyState(VK_LWIN) and $8000) <> 0) or
     ((GetAsyncKeyState(VK_RWIN) and $8000) <> 0) then
  begin
    ResetContext;
    Exit;
  end;
  if IsNavigationOrEditKey(Kbd^.vkCode) then
  begin
    if FLeftShiftDown or ((GetAsyncKeyState(VK_SHIFT) and $8000) <> 0) or
       ((GetAsyncKeyState(VK_LSHIFT) and $8000) <> 0) then
    begin
      FInputBuffer.Clear;
      ClearLastConversion;
      FBackspaceRun := 0;
      ArmSelectionGesture;
    end
    else
      ResetContext;
    Exit;
  end;

  FSelectionArmed := False;
  FSelectionArmedTick := 0;
  CurrentLang := GetForegroundLangKind;
  if Kbd^.vkCode = VK_BACK then
  begin
    HandleBackspace;
    Exit;
  end;
  Shifted := ((GetAsyncKeyState(VK_SHIFT) and $8000) <> 0) xor
    ((GetKeyState(VK_CAPITAL) and 1) <> 0);
  Punctuation := KeyedWordSeparator(Kbd^.vkCode, Shifted, CurrentLang);
  if (Kbd^.vkCode in [VK_SPACE, VK_RETURN, VK_TAB]) or (Punctuation <> #0) then
  begin
    if HandleWordDelimiter(CurrentLang, Kbd^.vkCode, Punctuation) then
      Exit(True);
    Exit;
  end;
  if ((Kbd^.vkCode >= $30) and (Kbd^.vkCode <= $5A)) or
     ((Kbd^.vkCode >= VK_OEM_1) and (Kbd^.vkCode <= VK_OEM_7)) then
    HandlePrintableKey(Kbd^.vkCode, CurrentLang);
  except
    on E: Exception do
    begin
      LogDiagnostic(dlError, deHookFailure, E.HelpContext,
        E.ClassName + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

procedure PauseKeyboardHookOnMainThread;
begin
  if GetCurrentThreadId = MainThreadID then
  begin
    if HookManager <> nil then
      HookManager.StopHook;
  end
  else
    TThread.Synchronize(nil,
      procedure
      begin
        if HookManager <> nil then
          HookManager.StopHook;
      end);
end;

procedure ResumeKeyboardHookOnMainThread;
begin
  if GetCurrentThreadId = MainThreadID then
  begin
    if HookManager <> nil then
      HookManager.StartHook;
  end
  else
    TThread.Synchronize(nil,
      procedure
      begin
        if HookManager <> nil then
          HookManager.StartHook;
      end);
end;

initialization
  PauseKeyboardHook := PauseKeyboardHookOnMainThread;
  ResumeKeyboardHook := ResumeKeyboardHookOnMainThread;

end.
