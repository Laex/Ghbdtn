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
  Ghbdtn.Fixer,
  Ghbdtn.Layout,
  Ghbdtn.Learning,
  Ghbdtn.Password,
  Ghbdtn.Hook,
  Ghbdtn.Sound,
  Ghbdtn.Diagnostics,
  Ghbdtn.Settings;

const
  ClipboardRetryCount = 8;
  ClipboardRetryDelayMs = 15;
  CopyPollMs = 8;
  CopyWaitMs = 45;
  PasteSettleDelayMs = 16;
  SelectionCopyAttempts = 3;
  MaxSelectionChars = 4096;
  MaxSavedClipboardChars = 1 shl 20;

function OpenClipboardWithRetry: Boolean;
var
  Attempt: Integer;
begin
  for Attempt := 1 to ClipboardRetryCount do
  begin
    if OpenClipboard(0) then
      Exit(True);
    Sleep(ClipboardRetryDelayMs);
  end;
  Result := False;
end;

function ClipboardHandleToString(Data: THandle; AMaxChars: NativeUInt;
  out ATruncated: Boolean): string;
var
  Ptr: PWideChar;
  Available: NativeUInt;
  Len: NativeUInt;
begin
  Result := '';
  ATruncated := False;
  Ptr := GlobalLock(Data);
  if Ptr = nil then
    Exit;
  try
    Available := GlobalSize(Data) div SizeOf(WideChar);
    if Available = 0 then
      Exit;
    if Available > AMaxChars + 1 then
      Available := AMaxChars + 1;
    Len := 0;
    while (Len < Available) and (Ptr[Len] <> #0) do
      Inc(Len);
    if Len > AMaxChars then
    begin
      Len := AMaxChars;
      ATruncated := True;
    end;
    SetString(Result, Ptr, Len);
  finally
    GlobalUnlock(Data);
  end;
end;

{ ATruncated is set when the clipboard text is longer than AMaxChars. A
  truncated selection must not be pasted back: the paste would replace the
  whole selection with only its head. }
function TryReadClipboardText(out AText: string; AMaxChars: NativeUInt;
  out ATruncated: Boolean): Boolean;
var
  Attempt: Integer;
  Data: THandle;
begin
  AText := '';
  ATruncated := False;
  for Attempt := 1 to ClipboardRetryCount do
  begin
    if OpenClipboardWithRetry then
    try
      Data := GetClipboardData(CF_UNICODETEXT);
      if Data <> 0 then
      begin
        AText := ClipboardHandleToString(Data, AMaxChars, ATruncated);
        if AText <> '' then
          Exit(True);
      end;
    finally
      CloseClipboard;
    end;
    Sleep(ClipboardRetryDelayMs);
  end;
  LogDiagnostic(dlError, deClipboardReadFailed);
  Result := False;
end;

function TryWriteClipboardText(const AText: string): Boolean;
var
  Attempt: Integer;
  Data: THandle;
  Ptr: Pointer;
  ByteCount: NativeUInt;
  Text: string;
begin
  Text := AText;
  for Attempt := 1 to ClipboardRetryCount do
  begin
    ByteCount := (Length(Text) + 1) * SizeOf(WideChar);
    Data := GlobalAlloc(GMEM_MOVEABLE, ByteCount);
    if Data = 0 then
      Continue;
    Ptr := GlobalLock(Data);
    if Ptr = nil then
    begin
      GlobalFree(Data);
      Continue;
    end;
    try
      if Text <> '' then
        Move(PWideChar(Text)^, Ptr^, ByteCount)
      else
        PWideChar(Ptr)^ := #0;
    finally
      GlobalUnlock(Data);
    end;

    if OpenClipboardWithRetry then
    try
      EmptyClipboard;
      if SetClipboardData(CF_UNICODETEXT, Data) <> 0 then
      begin
        Data := 0;
        Exit(True);
      end;
    finally
      CloseClipboard;
      if Data <> 0 then
        GlobalFree(Data);
    end
    else
      GlobalFree(Data);

    Sleep(ClipboardRetryDelayMs);
  end;
  LogDiagnostic(dlError, deClipboardWriteFailed);
  Result := False;
end;

function TryClearClipboard: Boolean;
begin
  Result := False;
  if not OpenClipboardWithRetry then
    Exit;
  try
    EmptyClipboard;
    Result := True;
  finally
    CloseClipboard;
  end;
end;

constructor TInputWorker.Create(AQueue: TInputQueue);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FQueue := AQueue;
end;

procedure TInputWorker.ExecuteWordReplacement(const AItem: TInputWorkItem);
begin
  if not IsTargetWindowValid(AItem.TargetWindow) then
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
    if TryReadClipboardText(AText, MaxSelectionChars, ATruncated) then
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

procedure TInputWorker.ExecuteSelectionReplacement(const AItem: TInputWorkItem);
var
  SavedClipboard: string;
  SelectedText: string;
  ConvertedText: string;
  Attempt: Integer;
  Copied, Truncated, SavedTruncated, Prepared: Boolean;
  TargetLang: TLangKind;
  Caret: TCaretRead;
begin
  if not IsTargetWindowValid(AItem.TargetWindow) then
    Exit;

  EnsureModifiersReleased;
  Prepared := False;
  SelectedText := '';
  if AItem.FromCaret and TryReadCaretText(AItem.TargetWindow, Caret) then
  begin
    if AItem.CaseCycle then
      ConvertedText := InvertLetterCase(Caret.Text)
    else
      ConvertedText := ConvertForProcess(AItem.LearningProcess, Caret.Text);
    if (ConvertedText = '') or (ConvertedText = Caret.Text) or
       not IsTargetWindowValid(AItem.TargetWindow) then
      Exit;
    if SelectCaretRead(Caret) then
    begin
      SelectedText := Caret.Text;
      Prepared := True;
    end;
  end;

  SavedClipboard := '';
  TryReadClipboardText(SavedClipboard, MaxSavedClipboardChars, SavedTruncated);
  // The clipboard is cleared below, so text that cannot be restored in full
  // must not be touched.
  if SavedTruncated then
    Exit;

  try
    if not TryClearClipboard then
    begin
      LogDiagnostic(dlError, deClipboardWriteFailed);
      Exit;
    end;

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
          Break;
      end;

      if not Copied then
      begin
        LogDiagnostic(dlError, deClipboardReadFailed);
        Exit;
      end;
      if Truncated then
        Exit;

      if AItem.CaseCycle then
        ConvertedText := InvertLetterCase(SelectedText)
      else
        ConvertedText := ConvertForProcess(AItem.LearningProcess, SelectedText);
      if (ConvertedText = '') or (ConvertedText = SelectedText) or
         not IsTargetWindowValid(AItem.TargetWindow) then
        Exit;
    end;

    if not TryWriteClipboardText(ConvertedText) then
      Exit;
    if not TryPasteClipboard(AItem.TargetWindow) then
      Exit;
    Sleep(PasteSettleDelayMs);
    if AItem.CaseCycle then
    begin
      if HookManager <> nil then
        HookManager.RememberCaseText(ConvertedText);
    end
    else
    begin
      if Prepared and (Caret.Source <> csSelected) then
        RememberManualWord(AItem.LearningProcess, SelectedText);
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
    if SavedClipboard <> '' then
      TryWriteClipboardText(SavedClipboard)
    else
      TryClearClipboard;
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
