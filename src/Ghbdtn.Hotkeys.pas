unit Ghbdtn.Hotkeys;

{ Keys the user assigns to the program's commands: their text form, which
  combinations may be assigned and which command a pressed key belongs to. }

interface

type
  TAppAction = (aaConvert, aaConvertLine, aaCaseInvert, aaCaseUpper,
    aaCaseLower, aaCaseCapitalize, aaTranslitToLatin, aaTranslitToCyrillic,
    aaPause);

  THotkeyModifier = (hmCtrl, hmAlt, hmShift, hmWin);
  THotkeyModifiers = set of THotkeyModifier;

  { Key = 0 means that nothing is assigned. }
  THotkey = record
    Key: Word;
    Modifiers: THotkeyModifiers;
  end;

  THotkeyMap = array[TAppAction] of THotkey;

const
  { Names of the commands in config.json. }
  AppActionIds: array[TAppAction] of string = ('Convert', 'ConvertLine',
    'CaseInvert', 'CaseUpper', 'CaseLower', 'CaseCapitalize',
    'TranslitToLatin', 'TranslitToCyrillic', 'Pause');

function NoHotkey: THotkey;
function MakeHotkey(AVirtualKey: Word; AModifiers: THotkeyModifiers): THotkey;
function SameHotkey(const ALeft, ARight: THotkey): Boolean;
function IsModifierKey(AVirtualKey: Word): Boolean;
{ A key that types or moves the caret is taken only together with Ctrl, Alt
  or Win, otherwise it could not be typed any more. }
function IsAssignableHotkey(const AHotkey: THotkey): Boolean;
{ "Ctrl+Alt+U", or an empty string when nothing is assigned. }
function HotkeyToText(const AHotkey: THotkey): string;
{ An empty text is a valid "nothing assigned". False for a text that names no
  assignable key. }
function TryTextToHotkey(const AText: string; out AHotkey: THotkey): Boolean;
function DefaultHotkeys: THotkeyMap;
{ A key belongs to one command: assigning it takes it from the others. }
procedure AssignHotkey(var AMap: THotkeyMap; AAction: TAppAction;
  const AHotkey: THotkey);
function TryFindHotkeyAction(const AMap: THotkeyMap; const AHotkey: THotkey;
  out AAction: TAppAction): Boolean;

implementation

uses
  Winapi.Windows,
  System.SysUtils;

type
  TKeyName = record
    Key: Word;
    Name: string;
  end;

const
  ModifierNames: array[THotkeyModifier] of string = ('Ctrl', 'Alt', 'Shift',
    'Win');
  NamedKeys: array[0..30] of TKeyName = (
    (Key: VK_PAUSE; Name: 'Pause'), (Key: VK_SCROLL; Name: 'ScrollLock'),
    (Key: VK_INSERT; Name: 'Insert'), (Key: VK_DELETE; Name: 'Delete'),
    (Key: VK_HOME; Name: 'Home'), (Key: VK_END; Name: 'End'),
    (Key: VK_PRIOR; Name: 'PageUp'), (Key: VK_NEXT; Name: 'PageDown'),
    (Key: VK_LEFT; Name: 'Left'), (Key: VK_RIGHT; Name: 'Right'),
    (Key: VK_UP; Name: 'Up'), (Key: VK_DOWN; Name: 'Down'),
    (Key: VK_SPACE; Name: 'Space'), (Key: VK_RETURN; Name: 'Enter'),
    (Key: VK_TAB; Name: 'Tab'), (Key: VK_ESCAPE; Name: 'Esc'),
    (Key: VK_BACK; Name: 'Backspace'), (Key: VK_SNAPSHOT; Name: 'PrintScreen'),
    (Key: VK_APPS; Name: 'Menu'), (Key: VK_OEM_1; Name: ';'),
    (Key: VK_OEM_PLUS; Name: '='), (Key: VK_OEM_COMMA; Name: ','),
    (Key: VK_OEM_MINUS; Name: '-'), (Key: VK_OEM_PERIOD; Name: '.'),
    (Key: VK_OEM_2; Name: '/'), (Key: VK_OEM_3; Name: '`'),
    (Key: VK_OEM_4; Name: '['), (Key: VK_OEM_5; Name: '\'),
    (Key: VK_OEM_6; Name: ']'), (Key: VK_OEM_7; Name: ''''),
    (Key: VK_CAPITAL; Name: 'CapsLock'));
  NumpadPrefix = 'Num';
  OtherKeyPrefix = 'Key';

function NoHotkey: THotkey;
begin
  Result.Key := 0;
  Result.Modifiers := [];
end;

function MakeHotkey(AVirtualKey: Word; AModifiers: THotkeyModifiers): THotkey;
begin
  Result.Key := AVirtualKey;
  Result.Modifiers := AModifiers;
  // The Pause key pressed with Ctrl is reported as Break.
  if AVirtualKey = VK_CANCEL then
  begin
    Result.Key := VK_PAUSE;
    Include(Result.Modifiers, hmCtrl);
  end;
end;

function SameHotkey(const ALeft, ARight: THotkey): Boolean;
begin
  Result := (ALeft.Key = ARight.Key) and (ALeft.Modifiers = ARight.Modifiers);
end;

function IsModifierKey(AVirtualKey: Word): Boolean;
begin
  case AVirtualKey of
    VK_SHIFT, VK_CONTROL, VK_MENU, VK_LSHIFT, VK_RSHIFT, VK_LCONTROL,
    VK_RCONTROL, VK_LMENU, VK_RMENU, VK_LWIN, VK_RWIN:
      Result := True;
  else
    Result := False;
  end;
end;

function IsAssignableHotkey(const AHotkey: THotkey): Boolean;
begin
  if (AHotkey.Key = 0) or (AHotkey.Key > $FE) or IsModifierKey(AHotkey.Key) then
    Exit(False);
  case AHotkey.Key of
    VK_PAUSE, VK_SCROLL, VK_INSERT, VK_F1..VK_F24:
      Result := True;
  else
    Result := AHotkey.Modifiers * [hmCtrl, hmAlt, hmWin] <> [];
  end;
end;

function KeyToName(AKey: Word): string;
var
  Item: TKeyName;
begin
  for Item in NamedKeys do
    if Item.Key = AKey then
      Exit(Item.Name);
  case AKey of
    Ord('0')..Ord('9'), Ord('A')..Ord('Z'):
      Result := Char(AKey);
    VK_F1..VK_F24:
      Result := 'F' + IntToStr(AKey - VK_F1 + 1);
    VK_NUMPAD0..VK_NUMPAD9:
      Result := NumpadPrefix + IntToStr(AKey - VK_NUMPAD0);
  else
    Result := OtherKeyPrefix + IntToHex(AKey, 2);
  end;
end;

function TryNameToKey(const AName: string; out AKey: Word): Boolean;
var
  Item: TKeyName;
  Code: Integer;
begin
  for Item in NamedKeys do
    if SameText(Item.Name, AName) then
    begin
      AKey := Item.Key;
      Exit(True);
    end;
  // Every other name is one that KeyToName produces for some key code.
  for Code := 1 to $FE do
    if SameText(KeyToName(Code), AName) then
    begin
      AKey := Code;
      Exit(True);
    end;
  AKey := 0;
  Result := False;
end;

function HotkeyToText(const AHotkey: THotkey): string;
var
  Modifier: THotkeyModifier;
begin
  if AHotkey.Key = 0 then
    Exit('');
  Result := '';
  for Modifier := Low(THotkeyModifier) to High(THotkeyModifier) do
    if Modifier in AHotkey.Modifiers then
      Result := Result + ModifierNames[Modifier] + '+';
  Result := Result + KeyToName(AHotkey.Key);
end;

function TryTextToHotkey(const AText: string; out AHotkey: THotkey): Boolean;
var
  Parts: TArray<string>;
  Modifier: THotkeyModifier;
  I: Integer;
  Found: Boolean;
  Key: Word;
begin
  AHotkey := NoHotkey;
  if Trim(AText) = '' then
    Exit(True);
  Parts := Trim(AText).Split(['+']);
  for I := 0 to High(Parts) - 1 do
  begin
    Found := False;
    for Modifier := Low(THotkeyModifier) to High(THotkeyModifier) do
      if SameText(Trim(Parts[I]), ModifierNames[Modifier]) then
      begin
        Include(AHotkey.Modifiers, Modifier);
        Found := True;
      end;
    if not Found then
    begin
      AHotkey := NoHotkey;
      Exit(False);
    end;
  end;
  if (Length(Parts) > 0) and TryNameToKey(Trim(Parts[High(Parts)]), Key) then
    AHotkey.Key := Key;
  Result := IsAssignableHotkey(AHotkey);
  if not Result then
    AHotkey := NoHotkey;
end;

function DefaultHotkeys: THotkeyMap;
var
  Action: TAppAction;
begin
  for Action := Low(TAppAction) to High(TAppAction) do
    Result[Action] := NoHotkey;
  Result[aaPause] := MakeHotkey(VK_PAUSE, []);
end;

procedure AssignHotkey(var AMap: THotkeyMap; AAction: TAppAction;
  const AHotkey: THotkey);
var
  Other: TAppAction;
begin
  if AHotkey.Key <> 0 then
    for Other := Low(TAppAction) to High(TAppAction) do
      if SameHotkey(AMap[Other], AHotkey) then
        AMap[Other] := NoHotkey;
  AMap[AAction] := AHotkey;
end;

function TryFindHotkeyAction(const AMap: THotkeyMap; const AHotkey: THotkey;
  out AAction: TAppAction): Boolean;
var
  Action: TAppAction;
begin
  AAction := Low(TAppAction);
  if AHotkey.Key = 0 then
    Exit(False);
  for Action := Low(TAppAction) to High(TAppAction) do
    if SameHotkey(AMap[Action], AHotkey) then
    begin
      AAction := Action;
      Exit(True);
    end;
  Result := False;
end;

end.
