unit Ghbdtn.InputWorker;

interface

uses
  Winapi.Windows,
  System.Classes,
  Ghbdtn.InputQueue;

type
  TInputWorker = class(TThread)
  private
    FQueue: TInputQueue;
    procedure ExecuteWork(const AItem: TInputWorkItem);
    procedure RunWork(const AItem: TInputWorkItem);
    procedure ExecuteWordReplacement(const AItem: TInputWorkItem);
    procedure ExecuteSelectionReplacement(const AItem: TInputWorkItem);
    procedure ExecuteReplaceBeforeCaret(const AItem: TInputWorkItem);
  protected
    procedure Execute; override;
  public
    constructor Create(AQueue: TInputQueue);
  end;

implementation

uses
  Winapi.Messages,
  Winapi.ActiveX,
  System.SysUtils,
  Winapi.UIAutomation,
  Ghbdtn.Analyzer,
  Ghbdtn.CaretHint,
  Ghbdtn.Clipboard,
  Ghbdtn.Fixer,
  Ghbdtn.Layout,
  Ghbdtn.Learning,
  Ghbdtn.Password,
  Ghbdtn.Hook,
  Ghbdtn.Sound,
  Ghbdtn.Translit,
  Ghbdtn.Diagnostics,
  Ghbdtn.Settings;

const
  CopyPollMs = 8;
  CopyWaitMs = 45;
  PasteSettleDelayMs = 80;
  PasteProbeTimeoutMs = 250;
  PasteHungDelayMs = 400;
  ActivateWaitMs = 500;
  ActivateSettleMs = 40;
  SelectionCopyAttempts = 3;
  MaxSelectionChars = 4096;

constructor TInputWorker.Create(AQueue: TInputQueue);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FQueue := AQueue;
end;

function IsItemCurrent(const AItem: TInputWorkItem): Boolean;
begin
  if not IsTargetWindowValid(AItem.TargetWindow) then
    Exit(False);
  Result := IsWorkItemCurrent(AItem.TargetFocus, ForegroundFocusWindow,
    AItem.EnqueuedTick, GetTickCount64);
  if not Result then
    LogDiagnostic(dlInfo, deStaleWorkDropped);
end;

procedure TInputWorker.ExecuteWordReplacement(const AItem: TInputWorkItem);
begin
  if not IsItemCurrent(AItem) then
    Exit;
  if not SendMarkedWordReplacement(AItem.OldWordLength, AItem.NewText,
    AItem.TrailingKey) then
    Exit;
  if not IsTargetWindowValid(AItem.TargetWindow) then
    Exit;
  if AItem.CaseCycle then
  begin
    if HookManager <> nil then
      HookManager.RememberCaseText(AItem.NewText);
    Exit;
  end;
  if AItem.ToggleCapsLock and ((GetKeyState(VK_CAPITAL) and 1) <> 0) then
    SendMarkedKeyPress(VK_CAPITAL);
  if AItem.KeepLayout then
    Exit;
  SwitchForegroundKeyboardLayout(AItem.TargetLang);
  if AItem.PlaySwitchSound then
    PlaySwitchBeep(AItem.TargetLang);
end;

function LayoutForConvertedText(const AText: string): TLangKind;
var
  I, Latin, Cyrillic: Integer;
  C: Char;
begin
  Latin := 0;
  Cyrillic := 0;
  for I := 1 to Length(AText) do
  begin
    C := AText[I];
    if CharInSet(C, ['a'..'z', 'A'..'Z']) then
      Inc(Latin)
    else if ((C >= 'А') and (C <= 'я')) or (C = 'Ё') or (C = 'ё') then
      Inc(Cyrillic);
  end;
  if (Latin = 0) and (Cyrillic = 0) then
    Result := lkUnknown
  else if Cyrillic >= Latin then
    Result := lkRU
  else
    Result := lkEN;
end;

function WaitForClipboardText(out AText: string; out ATruncated: Boolean): Boolean;
var
  Deadline: UInt64;
begin
  Deadline := GetTickCount64 + CopyWaitMs;
  repeat
    if TryPeekClipboardText(AText, MaxSelectionChars, ATruncated) then
      Exit(True);
    Sleep(CopyPollMs);
  until GetTickCount64 >= Deadline;
  Result := False;
end;

type
  TCaretSource = (csNone, csSelected, csUiaWord, csEditWord);

  TCaretRead = record
    Source: TCaretSource;
    Text: string;
    Range: IUIAutomationTextRange;
    EditWindow: HWND;
    EditStart: Integer;
    EditEnd: Integer;
  end;

function RangeText(const ARange: IUIAutomationTextRange): string;
type
  TRangeGetText = function(This: Pointer; MaxLength: Integer;
    out Text: WideString): HRESULT; stdcall;
var
  VTable: PPointer;
  ReadText: TRangeGetText;
  Raw: WideString;
begin
  // The imported GetText returns PChar. The method returns a BSTR, so call
  // that slot directly.
  Result := '';
  if ARange = nil then
    Exit;
  VTable := PPointer(Pointer(ARange)^);
  Inc(VTable, 12);
  ReadText := TRangeGetText(VTable^);
  Raw := '';
  if Failed(ReadText(Pointer(ARange), -1, Raw)) then
    Exit;
  Result := string(Raw);
end;

procedure TrimRangeEdges(const ARange: IUIAutomationTextRange);
var
  Text: string;
  Moved: Integer;
begin
  if ARange = nil then
    Exit;
  Text := RangeText(ARange);
  while (Text <> '') and (Text[Length(Text)] <= ' ') do
  begin
    if Failed(ARange.MoveEndpointByUnit(TextPatternRangeEndpoint_End,
      TextUnit_Character, -1, Moved)) or (Moved = 0) then
      Break;
    Text := RangeText(ARange);
  end;
  while (Text <> '') and (Text[1] <= ' ') do
  begin
    if Failed(ARange.MoveEndpointByUnit(TextPatternRangeEndpoint_Start,
      TextUnit_Character, 1, Moved)) or (Moved = 0) then
      Break;
    Text := RangeText(ARange);
  end;
end;

function TryUiaCaretRead(out ARead: TCaretRead): Boolean;
const
  CLSCTX_INPROC_SERVER = 1;
var
  Client: IUIAutomation;
  Element: IUIAutomationElement;
  Pattern: IUIAutomationTextPattern2;
  PatternPtr: Pointer;
  PatternId: TGUID;
  Ranges: IUIAutomationTextRangeArray;
  Range: IUIAutomationTextRange;
  Count, Index: Integer;
  Active: BOOL;
  Text: string;
begin
  Result := False;
  ARead := Default(TCaretRead);
  Client := nil;
  if Failed(CoCreateInstance(CLSID_CUIAutomation, nil, CLSCTX_INPROC_SERVER,
    IUIAutomation, Client)) or (Client = nil) then
    Exit;
  Element := nil;
  if Failed(Client.GetFocusedElement(Element)) or (Element = nil) then
    Exit;
  PatternId := IUIAutomationTextPattern2;
  PatternPtr := nil;
  if Failed(Element.GetCurrentPatternAs(UIA_TextPattern2Id, @PatternId,
    PatternPtr)) or (PatternPtr = nil) then
    Exit;
  Pointer(Pattern) := PatternPtr;
  Ranges := nil;
  if Succeeded(Pattern.GetSelection(Ranges)) and (Ranges <> nil) and
     Succeeded(Ranges.get_Length(Count)) then
    for Index := 0 to Count - 1 do
    begin
      Range := nil;
      if Failed(Ranges.GetElement(Index, Range)) or (Range = nil) then
        Continue;
      Text := RangeText(Range);
      if (Text = '') or (Length(Text) > MaxSelectionChars) then
        Continue;
      ARead.Source := csSelected;
      ARead.Text := Text;
      ARead.Range := nil;
      Exit(True);
    end;

  Range := nil;
  if Failed(Pattern.GetCaretRange(Active, Range)) or (Range = nil) then
    Exit;
  if Failed(Range.ExpandToEnclosingUnit(TextUnit_Word)) then
    Exit;
  TrimRangeEdges(Range);
  Text := RangeText(Range);
  if (Text = '') or (Length(Text) > 128) or (Pos(' ', Text) > 0) or
     (Pos(#10, Text) > 0) or (Pos(#13, Text) > 0) then
    Exit;
  ARead.Source := csUiaWord;
  ARead.Text := Text;
  ARead.Range := Range;
  Result := True;
end;

function TryEditCaretRead(AWindow: HWND; out ARead: TCaretRead): Boolean;
const
  EditQueryTimeoutMs = 40;
var
  ClassName: array[0..63] of Char;
  Len, Got, Sel: DWORD_PTR;
  Buffer: TArray<Char>;
  Text: string;
  SelStart, SelEnd, WordStart, WordEnd: Integer;
begin
  Result := False;
  ARead := Default(TCaretRead);
  if (AWindow = 0) or (GetClassName(AWindow, ClassName, Length(ClassName)) = 0) or
     not SameText(ClassName, 'Edit') then
    Exit;
  Len := 0;
  if SendMessageTimeout(AWindow, WM_GETTEXTLENGTH, 0, 0,
    SMTO_ABORTIFHUNG or SMTO_NORMAL, EditQueryTimeoutMs, @Len) = 0 then
    Exit;
  if (Len = 0) or (Len > 65535) then
    Exit;
  SetLength(Buffer, Len + 1);
  Got := 0;
  if SendMessageTimeout(AWindow, WM_GETTEXT, WPARAM(Len + 1), LPARAM(@Buffer[0]),
    SMTO_ABORTIFHUNG or SMTO_NORMAL, EditQueryTimeoutMs, @Got) = 0 then
    Exit;
  Text := PChar(Buffer);
  Sel := 0;
  if SendMessageTimeout(AWindow, EM_GETSEL, 0, 0,
    SMTO_ABORTIFHUNG or SMTO_NORMAL, EditQueryTimeoutMs, @Sel) = 0 then
    Exit;
  SelStart := Integer(Sel and $FFFF);
  SelEnd := Integer((Sel shr 16) and $FFFF);
  if SelEnd < SelStart then
    Exit;
  if SelStart <> SelEnd then
  begin
    if (SelEnd > Length(Text)) or (SelEnd - SelStart > MaxSelectionChars) then
      Exit;
    ARead.Source := csSelected;
    ARead.Text := Copy(Text, SelStart + 1, SelEnd - SelStart);
    Result := ARead.Text <> '';
    Exit;
  end;
  if not TryWordAtCaret(Text, SelStart, WordStart, WordEnd) then
    Exit;
  ARead.Source := csEditWord;
  ARead.Text := Copy(Text, WordStart + 1, WordEnd - WordStart);
  ARead.EditWindow := AWindow;
  ARead.EditStart := WordStart;
  ARead.EditEnd := WordEnd;
  Result := ARead.Text <> '';
end;

function TryReadCaretText(AWindow: HWND; out ARead: TCaretRead): Boolean;
begin
  ARead := Default(TCaretRead);
  try
    Result := TryUiaCaretRead(ARead);
  except
    Result := False;
    ARead := Default(TCaretRead);
  end;
  if Result then
    Exit;
  try
    Result := TryEditCaretRead(AWindow, ARead);
  except
    Result := False;
    ARead := Default(TCaretRead);
  end;
end;

function SelectCaretRead(const ARead: TCaretRead): Boolean;
var
  Sent: DWORD_PTR;
begin
  case ARead.Source of
    csSelected:
      Result := True;
    csUiaWord:
      Result := (ARead.Range <> nil) and Succeeded(ARead.Range.Select);
    csEditWord:
      begin
        Sent := 0;
        Result := SendMessageTimeout(ARead.EditWindow, EM_SETSEL,
          WPARAM(ARead.EditStart), LPARAM(ARead.EditEnd),
          SMTO_ABORTIFHUNG or SMTO_NORMAL, 40, @Sent) <> 0;
      end;
  else
    Result := False;
  end;
end;

function ConvertForProcess(const AProcess, AText: string): string;
var
  Profile: TApplicationProfile;
  Process: string;
begin
  Process := AProcess;
  Profile := AppSettings.ResolveProfile(Process);
  Result := ConvertManualSelection(AText, Profile.HeuristicMode,
    function(const AWord: string): Boolean
    begin
      Result := AppSettings.IsNeverSwitchWord(AWord, Process);
    end,
    function(const AWord: string): Boolean
    begin
      Result := AppSettings.IsPreferSwitchWord(AWord, Process);
    end);
end;

procedure RememberManualWord(const AProcess, AWord: string);
begin
  if (AWord = '') or (Pos(' ', AWord) > 0) or (Pos(#10, AWord) > 0) or
     (Pos(#13, AWord) > 0) then
    Exit;
  if AppSettings.ObserveLearning(AWord, laManualSwitch, AProcess) then
    AppSettings.SaveToFile;
end;

{ The target application reads the clipboard some time after Ctrl+V is
  delivered. A short settle delay plus a probe of its message loop keeps the
  original content from being put back before the paste has been consumed. }
procedure WaitForPasteConsumed(ATargetWindow: HWND);
var
  Reply: DWORD_PTR;
begin
  Sleep(PasteSettleDelayMs);
  Reply := 0;
  if SendMessageTimeout(ATargetWindow, WM_NULL, 0, 0,
    SMTO_ABORTIFHUNG or SMTO_NORMAL, PasteProbeTimeoutMs, @Reply) = 0 then
    Sleep(PasteHungDelayMs);
end;

{ The saved content is put back only while the clipboard still holds what this
  program put there: its own sequence number, or the selection text that a
  slow target copied after the wait ended. Anything else was placed by the
  user or another program and is left alone. }
procedure RestoreClipboardIfOwned(const ASnapshot: TClipboardSnapshot;
  AOwnedSequence: DWORD; const ASelectedText, AConvertedText: string);
begin
  if (ClipboardSequence = AOwnedSequence) or
     ((ASelectedText <> '') and ClipboardHoldsText(ASelectedText)) or
     ((AConvertedText <> '') and ClipboardHoldsText(AConvertedText)) then
    TryRestoreClipboard(ASnapshot);
end;

{ A command chosen from the tray menu starts with the menu's own window in
  front; the text lives in the window that was active before. }
procedure ActivateTargetWindow(ATarget: HWND);
var
  Deadline: UInt64;
begin
  if (ATarget = 0) or not IsWindow(ATarget) or
     (GetForegroundWindow = ATarget) then
    Exit;
  SetForegroundWindow(ATarget);
  Deadline := GetTickCount64 + ActivateWaitMs;
  while (GetForegroundWindow <> ATarget) and (GetTickCount64 < Deadline) do
    Sleep(10);
  Sleep(ActivateSettleMs);
end;

{ The text a tray command produces: a transliteration or a case change. }
function TransformCommandText(const AText: string;
  const AItem: TInputWorkItem): string;
begin
  if AItem.Translit <> tdNone then
    Result := ApplyTranslit(AText, AItem.Translit)
  else
    Result := ApplyCaseMode(AText, AItem.CaseMode);
end;

procedure NoteNothingToConvert(ATargetWindow: HWND);
begin
  if IsTargetWindowValid(ATargetWindow) then
    ShowCaretNote('Нечего конвертировать');
end;

procedure NoteClipboardRefused(AResult: TClipboardCaptureResult);
begin
  case AResult of
    ccTooLarge:
      ShowCaretNote('Буфер обмена слишком большой');
    ccUnsupported:
      ShowCaretNote('Буфер обмена нельзя сохранить');
  else
    ShowCaretNote('Буфер обмена занят');
  end;
end;

procedure TInputWorker.ExecuteSelectionReplacement(const AItem: TInputWorkItem);
var
  Snapshot: TClipboardSnapshot;
  CaptureResult: TClipboardCaptureResult;
  OwnedSequence: DWORD;
  ClipboardTouched: Boolean;
  SelectedText: string;
  ConvertedText: string;
  Attempt: Integer;
  Copied, Truncated, Prepared: Boolean;
  TargetLang: TLangKind;
  Caret: TCaretRead;
begin
  if AItem.ActivateTarget then
    ActivateTargetWindow(AItem.TargetWindow);
  if not IsItemCurrent(AItem) then
    Exit;

  EnsureModifiersReleased;
  Prepared := False;
  SelectedText := '';
  if AItem.FromCaret and TryReadCaretText(AItem.TargetWindow, Caret) then
  begin
    if AItem.CaseCycle then
      ConvertedText := TransformCommandText(Caret.Text, AItem)
    else
      ConvertedText := ConvertForProcess(AItem.LearningProcess, Caret.Text);
    if (ConvertedText = '') or (ConvertedText = Caret.Text) then
    begin
      NoteNothingToConvert(AItem.TargetWindow);
      Exit;
    end;
    if not IsTargetWindowValid(AItem.TargetWindow) then
      Exit;
    if SelectCaretRead(Caret) then
    begin
      SelectedText := Caret.Text;
      Prepared := True;
    end;
  end;

  // The clipboard is replaced below, so content that cannot be put back in
  // full must not be touched.
  if not TryCaptureClipboard(Snapshot, CaptureResult) then
  begin
    NoteClipboardRefused(CaptureResult);
    Exit;
  end;

  ClipboardTouched := False;
  OwnedSequence := 0;
  try
    ClipboardTouched := True;
    if not TryClearClipboard then
    begin
      LogDiagnostic(dlError, deClipboardWriteFailed);
      NoteClipboardRefused(ccUnavailable);
      Exit;
    end;
    OwnedSequence := ClipboardSequence;

    if not Prepared then
    begin
      Copied := False;
      Truncated := False;
      SelectedText := '';
      for Attempt := 1 to SelectionCopyAttempts do
      begin
        if not TryCopySelection(AItem.TargetWindow) then
          Continue;
        Copied := WaitForClipboardText(SelectedText, Truncated);
        if Copied then
        begin
          OwnedSequence := ClipboardSequence;
          Break;
        end;
      end;

      if not Copied then
      begin
        LogDiagnostic(dlError, deClipboardReadFailed);
        if IsTargetWindowValid(AItem.TargetWindow) then
          ShowCaretNote('Нет текста для конвертации');
        Exit;
      end;
      if Truncated then
      begin
        if IsTargetWindowValid(AItem.TargetWindow) then
          ShowCaretNote('Выделение больше ' + IntToStr(MaxSelectionChars) +
            ' символов');
        Exit;
      end;

      if AItem.CaseCycle then
        ConvertedText := TransformCommandText(SelectedText, AItem)
      else
        ConvertedText := ConvertForProcess(AItem.LearningProcess, SelectedText);
      if (ConvertedText = '') or (ConvertedText = SelectedText) then
      begin
        NoteNothingToConvert(AItem.TargetWindow);
        Exit;
      end;
      if not IsTargetWindowValid(AItem.TargetWindow) then
        Exit;
    end;

    if not TryWriteClipboardText(ConvertedText) then
      Exit;
    OwnedSequence := ClipboardSequence;
    if not TryPasteClipboard(AItem.TargetWindow) then
      Exit;
    WaitForPasteConsumed(AItem.TargetWindow);
    if AItem.CaseCycle then
    begin
      if HookManager <> nil then
      begin
        // A case change is repeated by double Right Shift; a transliteration
        // is taken back by double Left Shift.
        if AItem.Translit = tdNone then
          HookManager.RememberCaseText(ConvertedText)
        else
          HookManager.RememberSelectionConversion(SelectedText, ConvertedText);
      end;
    end
    else
    begin
      if Prepared and (Caret.Source <> csSelected) then
        RememberManualWord(AItem.LearningProcess, SelectedText);
      if HookManager <> nil then
        HookManager.RememberSelectionConversion(SelectedText, ConvertedText);
    end;
    if not AItem.CaseCycle and AppSettings.SwitchLayoutAfterSelection then
    begin
      TargetLang := LayoutForConvertedText(ConvertedText);
      if (TargetLang <> lkUnknown) and IsTargetWindowValid(AItem.TargetWindow) then
      begin
        SwitchForegroundKeyboardLayout(TargetLang);
        if AItem.PlaySwitchSound then
          PlaySwitchBeep(TargetLang);
      end;
    end;
  finally
    if ClipboardTouched then
      RestoreClipboardIfOwned(Snapshot, OwnedSequence, SelectedText,
        ConvertedText);
  end;
end;

{ Puts the text of the previous conversion back. The converted text is selected
  backwards from the caret and read before it is replaced, so an edit made in
  the meantime leaves the document untouched. }
procedure TInputWorker.ExecuteReplaceBeforeCaret(const AItem: TInputWorkItem);
var
  Snapshot: TClipboardSnapshot;
  CaptureResult: TClipboardCaptureResult;
  OwnedSequence: DWORD;
  ClipboardTouched, Copied, Truncated: Boolean;
  Selected: string;
  Attempt: Integer;
  TargetLang: TLangKind;
begin
  if not IsItemCurrent(AItem) then
    Exit;
  EnsureModifiersReleased;
  if not TryCaptureClipboard(Snapshot, CaptureResult) then
  begin
    NoteClipboardRefused(CaptureResult);
    Exit;
  end;

  ClipboardTouched := False;
  OwnedSequence := 0;
  Selected := '';
  try
    ClipboardTouched := True;
    if not TryClearClipboard then
    begin
      LogDiagnostic(dlError, deClipboardWriteFailed);
      NoteClipboardRefused(ccUnavailable);
      Exit;
    end;
    OwnedSequence := ClipboardSequence;
    if not SendMarkedArrow(VK_LEFT, AItem.OldWordLength, True) then
      Exit;
    Copied := False;
    Truncated := False;
    for Attempt := 1 to SelectionCopyAttempts do
    begin
      if not TryCopySelection(AItem.TargetWindow) then
        Continue;
      Copied := WaitForClipboardText(Selected, Truncated);
      if Copied then
      begin
        OwnedSequence := ClipboardSequence;
        Break;
      end;
    end;
    if not Copied or Truncated or
       (NormalizeLineBreaks(Selected) <> NormalizeLineBreaks(AItem.ExpectedText)) then
    begin
      // Collapse the selection back to the caret and leave the text alone.
      SendMarkedArrow(VK_RIGHT, 1, False);
      if IsTargetWindowValid(AItem.TargetWindow) then
        if AItem.SwitchLayoutAfter then
          ShowCaretNote('Набранный текст не найден перед кареткой')
        else
          ShowCaretNote('Текст изменился, отмена невозможна');
      Exit;
    end;
    if not TryWriteClipboardText(AItem.NewText) then
      Exit;
    OwnedSequence := ClipboardSequence;
    if not TryPasteClipboard(AItem.TargetWindow) then
      Exit;
    WaitForPasteConsumed(AItem.TargetWindow);
    if HookManager <> nil then
      HookManager.RememberSelectionConversion(AItem.ExpectedText, AItem.NewText);
    if AItem.SwitchLayoutAfter and AppSettings.SwitchLayoutAfterSelection then
    begin
      TargetLang := LayoutForConvertedText(AItem.NewText);
      if (TargetLang <> lkUnknown) and IsTargetWindowValid(AItem.TargetWindow) then
      begin
        SwitchForegroundKeyboardLayout(TargetLang);
        if AItem.PlaySwitchSound then
          PlaySwitchBeep(TargetLang);
      end;
    end;
  finally
    if ClipboardTouched then
      RestoreClipboardIfOwned(Snapshot, OwnedSequence, Selected, AItem.NewText);
  end;
end;

procedure TInputWorker.RunWork(const AItem: TInputWorkItem);
begin
  try
    ExecuteWork(AItem);
  except
    on E: Exception do
      LogDiagnostic(dlError, deWorkerFailure, E.HelpContext,
        E.ClassName + ': ' + E.Message);
  end;
end;

procedure TInputWorker.ExecuteWork(const AItem: TInputWorkItem);
begin
  case AItem.Kind of
    iwReplaceWord:
      ExecuteWordReplacement(AItem);
    iwReplaceSelection:
      ExecuteSelectionReplacement(AItem);
    iwReplaceBeforeCaret:
      ExecuteReplaceBeforeCaret(AItem);
    iwSwitchLayout:
      if IsTargetWindowValid(AItem.TargetWindow) then
      begin
        SwitchForegroundKeyboardLayout(AItem.TargetLang);
        if AItem.PlaySwitchSound then
          PlaySwitchBeep(AItem.TargetLang);
      end;
    iwPersistSettings:
      begin
        if AItem.LearningWord = '' then
          AppSettings.SaveToFile
        else if AppSettings.ObserveLearning(AItem.LearningWord,
          AItem.LearningAction, AItem.LearningProcess) then
          AppSettings.SaveToFile;
      end;
  end;
end;

procedure TInputWorker.Execute;
var
  Work: TInputWorkItem;
  Captured: TQueuedInput;
  Init: HRESULT;
begin
  Init := CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
  try
  while not Terminated do
  begin
    if FQueue.TryDequeueWork(Work) then
    begin
      RunWork(Work);
      Continue;
    end;
    if FQueue.TryDequeueReplay(Captured) then
    begin
      SendMarkedReplay(Captured.VirtualKey, Captured.ScanCode,
        Captured.Flags);
      Continue;
    end;
    if FQueue.TryCompleteIfIdle then
    begin
      if FQueue.TryDequeueBackground(Work) then
      begin
        RunWork(Work);
        Continue;
      end;
      if FQueue.IsStopping then
        Break;
      FQueue.WaitForWork(250);
    end;
  end;
  finally
    if Init = S_OK then
      CoUninitialize;
  end;
end;

end.
