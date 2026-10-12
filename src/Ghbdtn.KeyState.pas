unit Ghbdtn.KeyState;

interface

uses
  Winapi.Windows;

type
  TLeftShiftTransition = (lstOther, lstReleased, lstPressed, lstRepeated);

function TrackLeftShiftState(
  var AIsDown: Boolean;
  AIsKeyDown: Boolean;
  AIsKeyUp: Boolean
): TLeftShiftTransition;
function IsDoubleLeftShift(
  var ALastPressTime: UInt64;
  AEventTime: UInt64;
  AMinInterval: UInt64;
  AMaxInterval: UInt64
): Boolean;
function IsRightShiftKey(AVirtualKey, AScanCode: DWORD): Boolean;
function IsWithinLearningWindow(AConversionTick, ACurrentTick,
  AWindowMs: UInt64): Boolean;
function IsRussianLetterOnPunctuationKey(AChar: Char): Boolean;
function ColonEndsASingleLetter(const AWord: string; APunctuation: Char): Boolean;
function IsUsableExternalTarget(AWindowProcessId, AOwnProcessId: DWORD;
  const AWindowClass: string): Boolean;

implementation

uses
  System.SysUtils;

function TrackLeftShiftState(
  var AIsDown: Boolean;
  AIsKeyDown: Boolean;
  AIsKeyUp: Boolean
): TLeftShiftTransition;
begin
  Result := lstOther;

  if AIsKeyUp then
  begin
    AIsDown := False;
    Exit(lstReleased);
  end;

  if not AIsKeyDown then
    Exit;

  if AIsDown then
    Exit(lstRepeated);

  AIsDown := True;
  Result := lstPressed;
end;

function IsDoubleLeftShift(
  var ALastPressTime: UInt64;
  AEventTime: UInt64;
  AMinInterval: UInt64;
  AMaxInterval: UInt64
): Boolean;
var
  TimeDiff: UInt64;
begin
  Result := False;
  if ALastPressTime = 0 then
  begin
    ALastPressTime := AEventTime;
    Exit;
  end;

  TimeDiff := AEventTime - ALastPressTime;
  // Inclusive bounds: GetTickCount64 is ~15 ms, so very fast taps often share
  // a tick (TimeDiff = 0) and must still count as a double press.
  if (TimeDiff >= AMinInterval) and (TimeDiff <= AMaxInterval) then
  begin
    ALastPressTime := 0;
    Exit(True);
  end;

  ALastPressTime := AEventTime;
end;

function IsRightShiftKey(AVirtualKey, AScanCode: DWORD): Boolean;
begin
  // A low-level hook often reports this key as VK_SHIFT. The scan code is
  // still the right-shift code, 0x36.
  Result := (AVirtualKey = VK_RSHIFT) or
    ((AVirtualKey = VK_SHIFT) and ((AScanCode and $FF) = $36));
end;

function IsWithinLearningWindow(AConversionTick, ACurrentTick,
  AWindowMs: UInt64): Boolean;
begin
  Result := (AConversionTick <> 0) and
    (ACurrentTick >= AConversionTick) and
    (ACurrentTick - AConversionTick <= AWindowMs);
end;

function IsRussianLetterOnPunctuationKey(AChar: Char): Boolean;
begin
  // On the Russian layout the keys of , . and ` type the letters b, yu and yo.
  // They are part of a word there, not delimiters.
  Result := (AChar = 'б') or (AChar = 'ю') or (AChar = 'ё') or
    (AChar = 'Б') or (AChar = 'Ю') or (AChar = 'Ё');
end;

function ColonEndsASingleLetter(const AWord: string; APunctuation: Char): Boolean;
begin
  // "C:" is a drive letter. A one-letter word must not switch on colon.
  Result := (APunctuation = ':') and (Length(AWord) = 1);
end;

function IsUsableExternalTarget(AWindowProcessId, AOwnProcessId: DWORD;
  const AWindowClass: string): Boolean;
begin
  Result := (AWindowProcessId <> 0) and
    (AWindowProcessId <> AOwnProcessId) and
    not SameText(AWindowClass, 'Shell_TrayWnd') and
    not SameText(AWindowClass, 'Shell_SecondaryTrayWnd') and
    not SameText(AWindowClass, 'NotifyIconOverflowWindow') and
    not SameText(AWindowClass, 'Progman') and
    not SameText(AWindowClass, 'WorkerW');
end;

end.
