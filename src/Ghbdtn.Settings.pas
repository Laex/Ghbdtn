unit Ghbdtn.Settings;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  Ghbdtn.Analyzer,
  Ghbdtn.Diagnostics,
  Ghbdtn.Learning;

type
  TCaretHintMode = (chTimed, chFollow, chOff);

const
  AllApplicationsLearning = '*';

type
  TApplicationProfile = record
    AutoSwitchEnabled: Boolean;
    SoundOnRussianInput: Boolean;
    SoundOnSwitch: Boolean;
    HeuristicMode: THeuristicMode;
  end;

  TLearningView = record
    Process: string;
    Word: string;
    Reject: Integer;
    Prefer: Integer;
    Blocks: Boolean;
    Forces: Boolean;
  end;

  TApplicationRuleView = record
    Pattern: string;
    HasAutoSwitch: Boolean;
    AutoSwitchEnabled: Boolean;
    HasSoundOnRussianInput: Boolean;
    SoundOnRussianInput: Boolean;
    HasSoundOnSwitch: Boolean;
    SoundOnSwitch: Boolean;
    HasHeuristicMode: Boolean;
    HeuristicMode: THeuristicMode;
  end;

  TApplicationRule = class
  public
    Pattern: string;
    HasAutoSwitch: Boolean;
    AutoSwitchEnabled: Boolean;
    HasSoundOnRussianInput: Boolean;
    SoundOnRussianInput: Boolean;
    HasSoundOnSwitch: Boolean;
    SoundOnSwitch: Boolean;
    HasHeuristicMode: Boolean;
    HeuristicMode: THeuristicMode;
  end;

  TSettings = class
  private
    FConfigPathOverride: string;
    FLock: TCriticalSection;
    FFileLock: TCriticalSection;
    FExclusions: TStringList;
    FCaseFixKept: TStringList;
    FFixInitialCaps: Boolean;
    FFixCapsLock: Boolean;
    FPauseInFullscreen: Boolean;
    FEnglishInSecureFields: Boolean;
    FDoubleCtrlEnabled: Boolean;
    FEarlySwitchEnabled: Boolean;
    FEarlySwitchLetters: Integer;
    FApplicationRules: TObjectList<TApplicationRule>;
    FLearning: TDictionary<string, TLearningEntry>;
    FAppLearning: TObjectDictionary<string, TDictionary<string, TLearningEntry>>;
    FLearningStamp: Integer;
    FSoundOnRussianInput: Boolean;
    FSoundOnSwitch: Boolean;
    FDoubleLeftShiftEnabled: Boolean;
    FSwitchLayoutAfterSelection: Boolean;
    FAutoSwitchEnabled: Boolean;
    FAutoStart: Boolean;
    FHeuristicMode: THeuristicMode;
    FDiagnosticsLevel: TDiagnosticsLevel;
    FCaretHintOffsetX: Integer;
    FCaretHintOffsetY: Integer;
    FCaretHintMode: TCaretHintMode;
    FCaretHintFlash: Boolean;
    FCaretHintAnimate: Boolean;
    function GetConfigFilePath: string;
    function GetSoundOnRussianInput: Boolean;
    procedure SetSoundOnRussianInput(AValue: Boolean);
    function GetSoundOnSwitch: Boolean;
    procedure SetSoundOnSwitch(AValue: Boolean);
    function GetDoubleLeftShiftEnabled: Boolean;
    procedure SetDoubleLeftShiftEnabled(AValue: Boolean);
    function GetSwitchLayoutAfterSelection: Boolean;
    procedure SetSwitchLayoutAfterSelection(AValue: Boolean);
    function GetAutoSwitchEnabled: Boolean;
    procedure SetAutoSwitchEnabled(AValue: Boolean);
    function GetAutoStart: Boolean;
    procedure SetAutoStart(AValue: Boolean);
    function GetHeuristicMode: THeuristicMode;
    procedure SetHeuristicMode(AValue: THeuristicMode);
    function GetDiagnosticsLevel: TDiagnosticsLevel;
    procedure SetDiagnosticsLevel(AValue: TDiagnosticsLevel);
    function GetCaretHintOffsetX: Integer;
    procedure SetCaretHintOffsetX(AValue: Integer);
    function GetCaretHintOffsetY: Integer;
    procedure SetCaretHintOffsetY(AValue: Integer);
    function GetCaretHintMode: TCaretHintMode;
    procedure SetCaretHintMode(AValue: TCaretHintMode);
    function GetCaretHintFlash: Boolean;
    procedure SetCaretHintFlash(AValue: Boolean);
    function GetCaretHintAnimate: Boolean;
    procedure SetCaretHintAnimate(AValue: Boolean);
    function GetFixInitialCaps: Boolean;
    procedure SetFixInitialCaps(AValue: Boolean);
    function GetFixCapsLock: Boolean;
    procedure SetFixCapsLock(AValue: Boolean);
    function GetPauseInFullscreen: Boolean;
    procedure SetPauseInFullscreen(AValue: Boolean);
    function GetEnglishInSecureFields: Boolean;
    procedure SetEnglishInSecureFields(AValue: Boolean);
    function GetDoubleCtrlEnabled: Boolean;
    procedure SetDoubleCtrlEnabled(AValue: Boolean);
    function GetEarlySwitchEnabled: Boolean;
    procedure SetEarlySwitchEnabled(AValue: Boolean);
    function GetEarlySwitchLetters: Integer;
    procedure SetEarlySwitchLetters(AValue: Integer);
    procedure SetDefaults;
    procedure SetDefaultsUnlocked;
    function LoadJsonFile(const APath: string): Boolean;
    procedure BoundDictionary(ADict: TDictionary<string, TLearningEntry>);
    procedure BoundLearning;
    function AppDictionary(const AProcess: string;
      ACreate: Boolean): TDictionary<string, TLearningEntry>;
    function FindPromoted(ADict: TDictionary<string, TLearningEntry>;
      const AWord: string; out AEntry: TLearningEntry): Boolean;
    function LookupLearning(const AWord, AProcess: string;
      out AEntry: TLearningEntry): Boolean;
    procedure StoreLearningUnlocked(const AWord: string;
      AReject, APrefer: Integer; const AProcess: string = '');
    function FindOrAddRuleUnlocked(const APattern: string): TApplicationRule;
  public
    constructor Create(const AConfigPath: string = '');
    destructor Destroy; override;
    procedure LoadFromFile;
    procedure SaveToFile;
    function IsProcessExcluded(const AProcessName: string): Boolean;
    procedure AddExclusion(const APattern: string);
    procedure ClearExclusions;
    function ResolveProfile(const AProcessName: string): TApplicationProfile;
    function IsAutoSwitchEnabledFor(const AProcessName: string): Boolean;
    procedure SetApplicationRule(const AProcessName: string; AEnabled: Boolean);
    procedure SetApplicationRuleOverrides(const APattern: string;
      AOverrideAutoSwitch, AAutoSwitch: Boolean;
      AOverrideInputSound, AInputSound: Boolean;
      AOverrideSwitchSound, ASwitchSound: Boolean;
      AOverrideMode: Boolean; AMode: THeuristicMode);
    procedure RemoveApplicationRule(const AProcessName: string);
    function IsCaseFixKept(const AWord: string): Boolean;
    procedure KeepCaseFixWord(const AWord: string);
    function ListExclusions: TArray<string>;
    procedure RemoveExclusion(const APattern: string);
    function ListApplicationRules: TArray<TApplicationRuleView>;
    procedure PinLearning(const AWord, AProcess: string; APreferSwitch: Boolean);
    function IsNeverSwitchWord(const AWord: string;
      const AProcess: string = ''): Boolean;
    function IsPreferSwitchWord(const AWord: string;
      const AProcess: string = ''): Boolean;
    function LearningCount(const AWord: string;
      const AProcess: string = ''): Integer;
    function LearningEntryCount: Integer;
    function ObserveLearning(const AWord: string; AAction: TLearningAction;
      const AProcess: string = ''): Boolean;
    function ListLearning: TArray<TLearningView>;
    procedure ForgetLearning(const AProcess, AWord: string);
    procedure RecordLearning(const AWord: string; AStrongSignal: Boolean);
    procedure LearnNeverSwitch(const AWord: string);
    procedure ResetLearning;
    property ConfigFilePath: string read GetConfigFilePath;
    property SoundOnRussianInput: Boolean read GetSoundOnRussianInput write SetSoundOnRussianInput;
    property SoundOnSwitch: Boolean read GetSoundOnSwitch write SetSoundOnSwitch;
    property DoubleLeftShiftEnabled: Boolean read GetDoubleLeftShiftEnabled write SetDoubleLeftShiftEnabled;
    property SwitchLayoutAfterSelection: Boolean read GetSwitchLayoutAfterSelection write SetSwitchLayoutAfterSelection;
    property AutoSwitchEnabled: Boolean read GetAutoSwitchEnabled write SetAutoSwitchEnabled;
    property AutoStart: Boolean read GetAutoStart write SetAutoStart;
    property HeuristicMode: THeuristicMode read GetHeuristicMode write SetHeuristicMode;
    property DiagnosticsLevel: TDiagnosticsLevel read GetDiagnosticsLevel write SetDiagnosticsLevel;
    property CaretHintOffsetX: Integer read GetCaretHintOffsetX write SetCaretHintOffsetX;
    property CaretHintOffsetY: Integer read GetCaretHintOffsetY write SetCaretHintOffsetY;
    property CaretHintMode: TCaretHintMode read GetCaretHintMode write SetCaretHintMode;
    property CaretHintFlash: Boolean read GetCaretHintFlash write SetCaretHintFlash;
    property CaretHintAnimate: Boolean read GetCaretHintAnimate write SetCaretHintAnimate;
    property FixInitialCaps: Boolean read GetFixInitialCaps write SetFixInitialCaps;
    property FixCapsLock: Boolean read GetFixCapsLock write SetFixCapsLock;
    property PauseInFullscreen: Boolean read GetPauseInFullscreen write SetPauseInFullscreen;
    property EnglishInSecureFields: Boolean read GetEnglishInSecureFields write SetEnglishInSecureFields;
    property DoubleCtrlEnabled: Boolean read GetDoubleCtrlEnabled write SetDoubleCtrlEnabled;
    property EarlySwitchEnabled: Boolean read GetEarlySwitchEnabled write SetEarlySwitchEnabled;
    property EarlySwitchLetters: Integer read GetEarlySwitchLetters write SetEarlySwitchLetters;
  end;

var
  AppSettings: TSettings;

implementation

uses
  Winapi.Windows,
  System.DateUtils,
  System.IOUtils,
  System.JSON,
  System.Math;

const
  SettingsSchemaVersion = 4;
  MaxCaseFixKept = 500;
  // Password managers are always excluded and cannot be removed from the list.
  AlwaysExcludedProcesses: array[0..9] of string = (
    'keepass.exe', 'keepassxc.exe', '1password.exe', 'bitwarden.exe',
    'dashlane.exe', 'enpass.exe', 'roboform.exe', 'nordpass.exe',
    'lastpass.exe', 'protonpass.exe');

function WildcardMatch(const APattern, AValue: string): Boolean;
var
  P, V, Star, Retry: Integer;
  Pattern, Value: string;
begin
  Pattern := LowerCase(APattern);
  Value := LowerCase(AValue);
  P := 1;
  V := 1;
  Star := 0;
  Retry := 0;
  while V <= Length(Value) do
  begin
    if (P <= Length(Pattern)) and
       ((Pattern[P] = '?') or (Pattern[P] = Value[V])) then
    begin
      Inc(P);
      Inc(V);
    end
    else if (P <= Length(Pattern)) and (Pattern[P] = '*') then
    begin
      Star := P;
      Inc(P);
      Retry := V;
    end
    else if Star <> 0 then
    begin
      P := Star + 1;
      Inc(Retry);
      V := Retry;
    end
    else
      Exit(False);
  end;
  while (P <= Length(Pattern)) and (Pattern[P] = '*') do
    Inc(P);
  Result := P > Length(Pattern);
end;

function ModeToString(AMode: THeuristicMode): string;
begin
  case AMode of
    hmCautious: Result := 'cautious';
    hmAggressive: Result := 'aggressive';
  else
    Result := 'balanced';
  end;
end;

function StringToMode(const AValue: string): THeuristicMode;
begin
  if SameText(AValue, 'cautious') then
    Result := hmCautious
  else if SameText(AValue, 'aggressive') then
    Result := hmAggressive
  else
    Result := hmBalanced;
end;

function DiagnosticsToString(ALevel: TDiagnosticsLevel): string;
begin
  case ALevel of
    dlError: Result := 'error';
    dlInfo: Result := 'info';
    dlVerbose: Result := 'verbose';
  else
    Result := 'off';
  end;
end;

function StringToDiagnostics(const AValue: string): TDiagnosticsLevel;
begin
  if SameText(AValue, 'error') then
    Result := dlError
  else if SameText(AValue, 'info') then
    Result := dlInfo
  else if SameText(AValue, 'verbose') then
    Result := dlVerbose
  else
    Result := dlOff;
end;

function CaretHintModeToString(AMode: TCaretHintMode): string;
begin
  case AMode of
    chFollow: Result := 'follow';
    chOff: Result := 'off';
  else
    Result := 'timed';
  end;
end;

function StringToCaretHintMode(const AValue: string): TCaretHintMode;
begin
  if SameText(AValue, 'follow') then
    Result := chFollow
  else if SameText(AValue, 'off') then
    Result := chOff
  else
    Result := chTimed;
end;

constructor TSettings.Create(const AConfigPath: string);
begin
  inherited Create;
  FConfigPathOverride := AConfigPath;
  FLock := TCriticalSection.Create;
  FFileLock := TCriticalSection.Create;
  FExclusions := TStringList.Create;
  FExclusions.CaseSensitive := False;
  FCaseFixKept := TStringList.Create;
  FCaseFixKept.CaseSensitive := False;
  FApplicationRules := TObjectList<TApplicationRule>.Create(True);
  FLearning := TDictionary<string, TLearningEntry>.Create;
  FAppLearning := TObjectDictionary<string, TDictionary<string, TLearningEntry>>.Create([doOwnsValues]);
  SetDefaults;
end;

destructor TSettings.Destroy;
begin
  FFileLock.Acquire;
  try
    FLock.Acquire;
    try
      FAppLearning.Free;
      FLearning.Free;
      FApplicationRules.Free;
      FExclusions.Free;
      FCaseFixKept.Free;
    finally
      FLock.Release;
    end;
  finally
    FFileLock.Release;
  end;
  FFileLock.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TSettings.SetDefaults;
begin
  FLock.Acquire;
  try
    SetDefaultsUnlocked;
  finally
    FLock.Release;
  end;
end;

procedure TSettings.SetDefaultsUnlocked;
begin
  FSoundOnRussianInput := True;
  FSoundOnSwitch := True;
  FDoubleLeftShiftEnabled := True;
  FSwitchLayoutAfterSelection := False;
  FAutoSwitchEnabled := True;
  FAutoStart := False;
  FHeuristicMode := hmBalanced;
  FDiagnosticsLevel := dlOff;
  FCaretHintOffsetX := 14;
  FCaretHintOffsetY := 18;
  FCaretHintMode := chTimed;
  FCaretHintFlash := True;
  FCaretHintAnimate := True;
  FFixInitialCaps := True;
  FFixCapsLock := True;
  FPauseInFullscreen := True;
  FEnglishInSecureFields := True;
  FDoubleCtrlEnabled := True;
  FEarlySwitchEnabled := False;
  FEarlySwitchLetters := EarlyLettersDefault;
  FCaseFixKept.Clear;
  FExclusions.Clear;
  FExclusions.Add('cmd.exe');
  FExclusions.Add('powershell.exe');
  FExclusions.Add('wt.exe');
  FExclusions.Add('putty.exe');
  FApplicationRules.Clear;
  FLearning.Clear;
  FAppLearning.Clear;
  FLearningStamp := 0;
end;

function TSettings.GetConfigFilePath: string;
begin
  if FConfigPathOverride <> '' then
    Exit(FConfigPathOverride);
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'config.json');
end;

function TSettings.GetSoundOnRussianInput: Boolean;
begin
  FLock.Acquire;
  try Result := FSoundOnRussianInput; finally FLock.Release; end;
end;

procedure TSettings.SetSoundOnRussianInput(AValue: Boolean);
begin
  FLock.Acquire;
  try FSoundOnRussianInput := AValue; finally FLock.Release; end;
end;

function TSettings.GetSoundOnSwitch: Boolean;
begin
  FLock.Acquire;
  try Result := FSoundOnSwitch; finally FLock.Release; end;
end;

procedure TSettings.SetSoundOnSwitch(AValue: Boolean);
begin
  FLock.Acquire;
  try FSoundOnSwitch := AValue; finally FLock.Release; end;
end;

function TSettings.GetDoubleLeftShiftEnabled: Boolean;
begin
  FLock.Acquire;
  try Result := FDoubleLeftShiftEnabled; finally FLock.Release; end;
end;

procedure TSettings.SetDoubleLeftShiftEnabled(AValue: Boolean);
begin
  FLock.Acquire;
  try FDoubleLeftShiftEnabled := AValue; finally FLock.Release; end;
end;

function TSettings.GetSwitchLayoutAfterSelection: Boolean;
begin
  FLock.Acquire;
  try Result := FSwitchLayoutAfterSelection; finally FLock.Release; end;
end;

procedure TSettings.SetSwitchLayoutAfterSelection(AValue: Boolean);
begin
  FLock.Acquire;
  try FSwitchLayoutAfterSelection := AValue; finally FLock.Release; end;
end;

function TSettings.GetAutoSwitchEnabled: Boolean;
begin
  FLock.Acquire;
  try Result := FAutoSwitchEnabled; finally FLock.Release; end;
end;

procedure TSettings.SetAutoSwitchEnabled(AValue: Boolean);
begin
  FLock.Acquire;
  try FAutoSwitchEnabled := AValue; finally FLock.Release; end;
end;

function TSettings.GetAutoStart: Boolean;
begin
  FLock.Acquire;
  try Result := FAutoStart; finally FLock.Release; end;
end;

procedure TSettings.SetAutoStart(AValue: Boolean);
begin
  FLock.Acquire;
  try FAutoStart := AValue; finally FLock.Release; end;
end;

function TSettings.GetHeuristicMode: THeuristicMode;
begin
  FLock.Acquire;
  try Result := FHeuristicMode; finally FLock.Release; end;
end;

procedure TSettings.SetHeuristicMode(AValue: THeuristicMode);
begin
  FLock.Acquire;
  try FHeuristicMode := AValue; finally FLock.Release; end;
end;

function TSettings.GetDiagnosticsLevel: TDiagnosticsLevel;
begin
  FLock.Acquire;
  try Result := FDiagnosticsLevel; finally FLock.Release; end;
end;

procedure TSettings.SetDiagnosticsLevel(AValue: TDiagnosticsLevel);
begin
  FLock.Acquire;
  try FDiagnosticsLevel := AValue; finally FLock.Release; end;
end;

function TSettings.GetCaretHintOffsetX: Integer;
begin
  FLock.Acquire;
  try Result := FCaretHintOffsetX; finally FLock.Release; end;
end;

procedure TSettings.SetCaretHintOffsetX(AValue: Integer);
begin
  FLock.Acquire;
  try FCaretHintOffsetX := AValue; finally FLock.Release; end;
end;

function TSettings.GetCaretHintOffsetY: Integer;
begin
  FLock.Acquire;
  try Result := FCaretHintOffsetY; finally FLock.Release; end;
end;

procedure TSettings.SetCaretHintOffsetY(AValue: Integer);
begin
  FLock.Acquire;
  try FCaretHintOffsetY := AValue; finally FLock.Release; end;
end;

function TSettings.GetCaretHintMode: TCaretHintMode;
begin
  FLock.Acquire;
  try Result := FCaretHintMode; finally FLock.Release; end;
end;

procedure TSettings.SetCaretHintMode(AValue: TCaretHintMode);
begin
  FLock.Acquire;
  try FCaretHintMode := AValue; finally FLock.Release; end;
end;

function TSettings.GetCaretHintFlash: Boolean;
begin
  FLock.Acquire;
  try Result := FCaretHintFlash; finally FLock.Release; end;
end;

procedure TSettings.SetCaretHintFlash(AValue: Boolean);
begin
  FLock.Acquire;
  try FCaretHintFlash := AValue; finally FLock.Release; end;
end;

function TSettings.GetFixInitialCaps: Boolean;
begin
  FLock.Acquire;
  try Result := FFixInitialCaps; finally FLock.Release; end;
end;

procedure TSettings.SetFixInitialCaps(AValue: Boolean);
begin
  FLock.Acquire;
  try FFixInitialCaps := AValue; finally FLock.Release; end;
end;

function TSettings.GetFixCapsLock: Boolean;
begin
  FLock.Acquire;
  try Result := FFixCapsLock; finally FLock.Release; end;
end;

procedure TSettings.SetFixCapsLock(AValue: Boolean);
begin
  FLock.Acquire;
  try FFixCapsLock := AValue; finally FLock.Release; end;
end;

function TSettings.GetPauseInFullscreen: Boolean;
begin
  FLock.Acquire;
  try Result := FPauseInFullscreen; finally FLock.Release; end;
end;

procedure TSettings.SetPauseInFullscreen(AValue: Boolean);
begin
  FLock.Acquire;
  try FPauseInFullscreen := AValue; finally FLock.Release; end;
end;

function TSettings.GetEnglishInSecureFields: Boolean;
begin
  FLock.Acquire;
  try Result := FEnglishInSecureFields; finally FLock.Release; end;
end;

procedure TSettings.SetEnglishInSecureFields(AValue: Boolean);
begin
  FLock.Acquire;
  try FEnglishInSecureFields := AValue; finally FLock.Release; end;
end;

function TSettings.GetDoubleCtrlEnabled: Boolean;
begin
  FLock.Acquire;
  try Result := FDoubleCtrlEnabled; finally FLock.Release; end;
end;

procedure TSettings.SetDoubleCtrlEnabled(AValue: Boolean);
begin
  FLock.Acquire;
  try FDoubleCtrlEnabled := AValue; finally FLock.Release; end;
end;

function TSettings.GetEarlySwitchEnabled: Boolean;
begin
  FLock.Acquire;
  try Result := FEarlySwitchEnabled; finally FLock.Release; end;
end;

procedure TSettings.SetEarlySwitchEnabled(AValue: Boolean);
begin
  FLock.Acquire;
  try FEarlySwitchEnabled := AValue; finally FLock.Release; end;
end;

function TSettings.GetEarlySwitchLetters: Integer;
begin
  FLock.Acquire;
  try Result := FEarlySwitchLetters; finally FLock.Release; end;
end;

procedure TSettings.SetEarlySwitchLetters(AValue: Integer);
begin
  FLock.Acquire;
  try
    FEarlySwitchLetters := Min(Max(AValue, EarlyLettersMin), EarlyLettersMax);
  finally
    FLock.Release;
  end;
end;

function TSettings.IsCaseFixKept(const AWord: string): Boolean;
begin
  FLock.Acquire;
  try Result := FCaseFixKept.IndexOf(LowerCase(AWord)) >= 0; finally FLock.Release; end;
end;

procedure TSettings.KeepCaseFixWord(const AWord: string);
begin
  if AWord = '' then
    Exit;
  FLock.Acquire;
  try
    if (FCaseFixKept.IndexOf(LowerCase(AWord)) < 0) and
       (FCaseFixKept.Count < MaxCaseFixKept) then
      FCaseFixKept.Add(LowerCase(AWord));
  finally
    FLock.Release;
  end;
end;

function TSettings.GetCaretHintAnimate: Boolean;
begin
  FLock.Acquire;
  try Result := FCaretHintAnimate; finally FLock.Release; end;
end;

procedure TSettings.SetCaretHintAnimate(AValue: Boolean);
begin
  FLock.Acquire;
  try FCaretHintAnimate := AValue; finally FLock.Release; end;
end;

procedure TSettings.BoundDictionary(ADict: TDictionary<string, TLearningEntry>);
var
  Pair: TPair<string, TLearningEntry>;
  VictimKey: string;
  VictimWeight: Integer;
  VictimStamp: Integer;
  Weight: Integer;
begin
  if ADict = nil then
    Exit;
  while ADict.Count > MaxLearningEntries do
  begin
    VictimKey := '';
    VictimWeight := MaxInt;
    VictimStamp := MaxInt;
    for Pair in ADict do
    begin
      Weight := LearningEntryWeight(Pair.Value);
      if (Weight < VictimWeight) or
         ((Weight = VictimWeight) and (Pair.Value.Stamp < VictimStamp)) then
      begin
        VictimKey := Pair.Key;
        VictimWeight := Weight;
        VictimStamp := Pair.Value.Stamp;
      end;
    end;
    if VictimKey = '' then
      Break;
    ADict.Remove(VictimKey);
  end;
end;

procedure TSettings.BoundLearning;
begin
  BoundDictionary(FLearning);
end;

function TSettings.AppDictionary(const AProcess: string;
  ACreate: Boolean): TDictionary<string, TLearningEntry>;
var
  Key: string;
begin
  Key := LowerCase(ExtractFileName(AProcess));
  if Key = '' then
    Exit(FLearning);
  if not FAppLearning.TryGetValue(Key, Result) then
  begin
    Result := nil;
    if not ACreate then
      Exit;
    Result := TDictionary<string, TLearningEntry>.Create;
    FAppLearning.Add(Key, Result);
  end;
end;

function TSettings.FindPromoted(ADict: TDictionary<string, TLearningEntry>;
  const AWord: string; out AEntry: TLearningEntry): Boolean;
var
  Pair: TPair<string, TLearningEntry>;
  BestWeight, Weight: Integer;
  Have: Boolean;
begin
  Result := False;
  if (ADict = nil) or (AWord = '') then
    Exit;
  if ADict.TryGetValue(AWord, AEntry) and
     (LearningBlocksSwitch(AEntry) or LearningForcesSwitch(AEntry)) then
    Exit(True);
  Have := False;
  BestWeight := -1;
  for Pair in ADict do
  begin
    if not LearnedFormsMatch(Pair.Key, AWord) then
      Continue;
    if not (LearningBlocksSwitch(Pair.Value) or LearningForcesSwitch(Pair.Value)) then
      Continue;
    Weight := LearningEntryWeight(Pair.Value);
    if (not Have) or (Weight > BestWeight) or
       ((Weight = BestWeight) and (Pair.Value.Stamp > AEntry.Stamp)) then
    begin
      AEntry := Pair.Value;
      BestWeight := Weight;
      Have := True;
    end;
  end;
  Result := Have;
end;

procedure TSettings.StoreLearningUnlocked(const AWord: string;
  AReject, APrefer: Integer; const AProcess: string);
var
  Key: string;
  Entry: TLearningEntry;
  Dict: TDictionary<string, TLearningEntry>;
begin
  Key := NormalizeAnalyzedWord(AWord);
  if Key = '' then
    Exit;
  if AReject < 0 then
    AReject := 0;
  if APrefer < 0 then
    APrefer := 0;
  if AReject > LearningScoreCap then
    AReject := LearningScoreCap;
  if APrefer > LearningScoreCap then
    APrefer := LearningScoreCap;
  if (AReject = 0) and (APrefer = 0) then
    Exit;
  Dict := AppDictionary(AProcess, True);
  if not Dict.TryGetValue(Key, Entry) then
    Entry := Default(TLearningEntry);
  if AReject > Entry.Reject then
    Entry.Reject := AReject;
  if APrefer > Entry.Prefer then
    Entry.Prefer := APrefer;
  Inc(FLearningStamp);
  Entry.Stamp := FLearningStamp;
  Dict.AddOrSetValue(Key, Entry);
  BoundDictionary(Dict);
end;

function TSettings.LoadJsonFile(const APath: string): Boolean;
var
  Parsed: TJSONValue;
  Root, RulesObject, RuleObject, LearningObject: TJSONObject;
  ArrayValue: TJSONArray;
  Pair: TJSONPair;
  Rule: TApplicationRule;
  I, Count: Integer;
  TextValue: string;
begin
  Result := False;
  Parsed := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(APath, TEncoding.UTF8));
  if Parsed = nil then
    Exit;
  if not (Parsed is TJSONObject) then
  begin
    Parsed.Free;
    Exit;
  end;
  Root := TJSONObject(Parsed);
  try
    FLock.Acquire;
    try
    SetDefaultsUnlocked;
    Root.TryGetValue<Boolean>('SoundOnRussianInput', FSoundOnRussianInput);
    Root.TryGetValue<Boolean>('SoundOnSwitch', FSoundOnSwitch);
    Root.TryGetValue<Boolean>('DoubleLeftShiftEnabled', FDoubleLeftShiftEnabled);
    Root.TryGetValue<Boolean>('SwitchLayoutAfterSelection', FSwitchLayoutAfterSelection);
    Root.TryGetValue<Boolean>('AutoSwitchEnabled', FAutoSwitchEnabled);
    Root.TryGetValue<Boolean>('AutoStart', FAutoStart);
    if Root.TryGetValue<string>('HeuristicMode', TextValue) then
      FHeuristicMode := StringToMode(TextValue);
    if Root.TryGetValue<string>('DiagnosticsLevel', TextValue) then
      FDiagnosticsLevel := StringToDiagnostics(TextValue);
    Root.TryGetValue<Integer>('CaretHintOffsetX', FCaretHintOffsetX);
    Root.TryGetValue<Integer>('CaretHintOffsetY', FCaretHintOffsetY);
    if Root.TryGetValue<string>('CaretHintMode', TextValue) then
      FCaretHintMode := StringToCaretHintMode(TextValue);
    Root.TryGetValue<Boolean>('CaretHintFlash', FCaretHintFlash);
    Root.TryGetValue<Boolean>('CaretHintAnimate', FCaretHintAnimate);
    Root.TryGetValue<Boolean>('FixInitialCaps', FFixInitialCaps);
    Root.TryGetValue<Boolean>('FixCapsLock', FFixCapsLock);
    Root.TryGetValue<Boolean>('PauseInFullscreen', FPauseInFullscreen);
    Root.TryGetValue<Boolean>('EnglishInSecureFields', FEnglishInSecureFields);
    Root.TryGetValue<Boolean>('DoubleCtrlEnabled', FDoubleCtrlEnabled);
    Root.TryGetValue<Boolean>('EarlySwitchEnabled', FEarlySwitchEnabled);
    Root.TryGetValue<Integer>('EarlySwitchLetters', FEarlySwitchLetters);
    FEarlySwitchLetters := Min(Max(FEarlySwitchLetters, EarlyLettersMin),
      EarlyLettersMax);

    ArrayValue := Root.Values['CaseFixKept'] as TJSONArray;
    if ArrayValue <> nil then
      for I := 0 to ArrayValue.Count - 1 do
        if (FCaseFixKept.Count < MaxCaseFixKept) and
           (FCaseFixKept.IndexOf(LowerCase(ArrayValue.Items[I].Value)) < 0) then
          FCaseFixKept.Add(LowerCase(ArrayValue.Items[I].Value));

    ArrayValue := Root.Values['Exclusions'] as TJSONArray;
    if ArrayValue <> nil then
    begin
      FExclusions.Clear;
      for I := 0 to ArrayValue.Count - 1 do
        FExclusions.Add(LowerCase(ArrayValue.Items[I].Value));
    end;

    RulesObject := Root.Values['ApplicationRules'] as TJSONObject;
    if RulesObject <> nil then
    begin
      FApplicationRules.Clear;
      for Pair in RulesObject do
      begin
        Rule := TApplicationRule.Create;
        Rule.Pattern := LowerCase(Pair.JsonString.Value);
        if Pair.JsonValue is TJSONBool then
        begin
          Rule.HasAutoSwitch := True;
          Rule.AutoSwitchEnabled := SameText(Pair.JsonValue.Value, 'true');
        end
        else if Pair.JsonValue is TJSONObject then
        begin
          RuleObject := TJSONObject(Pair.JsonValue);
          Rule.HasAutoSwitch := RuleObject.TryGetValue<Boolean>(
            'AutoSwitchEnabled', Rule.AutoSwitchEnabled);
          Rule.HasSoundOnRussianInput := RuleObject.TryGetValue<Boolean>(
            'SoundOnRussianInput', Rule.SoundOnRussianInput);
          Rule.HasSoundOnSwitch := RuleObject.TryGetValue<Boolean>(
            'SoundOnSwitch', Rule.SoundOnSwitch);
          if RuleObject.TryGetValue<string>('HeuristicMode', TextValue) then
          begin
            Rule.HasHeuristicMode := True;
            Rule.HeuristicMode := StringToMode(TextValue);
          end;
        end;
        FApplicationRules.Add(Rule);
      end;
    end;

    LearningObject := Root.Values['NeverSwitchLearning'] as TJSONObject;
    if LearningObject <> nil then
    begin
      for Pair in LearningObject do
      begin
        Count := StrToIntDef(Pair.JsonValue.Value, 0);
        if Count > 0 then
          StoreLearningUnlocked(Pair.JsonString.Value, Count, 0);
      end;
    end
    else
    begin
      ArrayValue := Root.Values['NeverSwitchWords'] as TJSONArray;
      if ArrayValue <> nil then
        for I := 0 to ArrayValue.Count - 1 do
          StoreLearningUnlocked(ArrayValue.Items[I].Value,
            LearningPromotionCount, 0);
    end;

    LearningObject := Root.Values['PreferSwitchLearning'] as TJSONObject;
    if LearningObject <> nil then
      for Pair in LearningObject do
      begin
        Count := StrToIntDef(Pair.JsonValue.Value, 0);
        if Count > 0 then
          StoreLearningUnlocked(Pair.JsonString.Value, 0, Count);
      end;

    RulesObject := Root.Values['ApplicationLearning'] as TJSONObject;
    if RulesObject <> nil then
      for Pair in RulesObject do
      begin
        if not (Pair.JsonValue is TJSONObject) then
          Continue;
        RuleObject := TJSONObject(Pair.JsonValue);
        LearningObject := RuleObject.Values['Never'] as TJSONObject;
        if LearningObject <> nil then
          for I := 0 to LearningObject.Count - 1 do
          begin
            Count := StrToIntDef(LearningObject.Pairs[I].JsonValue.Value, 0);
            if Count > 0 then
              StoreLearningUnlocked(LearningObject.Pairs[I].JsonString.Value,
                Count, 0, Pair.JsonString.Value);
          end;
        LearningObject := RuleObject.Values['Prefer'] as TJSONObject;
        if LearningObject <> nil then
          for I := 0 to LearningObject.Count - 1 do
          begin
            Count := StrToIntDef(LearningObject.Pairs[I].JsonValue.Value, 0);
            if Count > 0 then
              StoreLearningUnlocked(LearningObject.Pairs[I].JsonString.Value,
                0, Count, Pair.JsonString.Value);
          end;
      end;
    BoundLearning;
    Result := True;
    finally
      FLock.Release;
    end;
  finally
    Root.Free;
  end;
end;

procedure TSettings.LoadFromFile;
var
  Path, BackupPath, CorruptPath: string;
begin
  FFileLock.Acquire;
  try
  Path := GetConfigFilePath;
  BackupPath := Path + '.bak';
  if not FileExists(Path) then
  begin
    try
      if FileExists(BackupPath) and LoadJsonFile(BackupPath) then
      begin
        LogDiagnostic(dlInfo, deSettingsRecovered);
        SaveToFile;
        Exit;
      end;
    except
      on E: Exception do
        LogDiagnostic(dlError, deSettingsLoadFailed, E.HelpContext);
    end;
    SetDefaults;
    SaveToFile;
    Exit;
  end;
  try
    if LoadJsonFile(Path) then
      Exit;
  except
    on E: Exception do
      LogDiagnostic(dlError, deSettingsLoadFailed, E.HelpContext);
  end;

  CorruptPath := ChangeFileExt(Path, '') + '.corrupt-' +
    FormatDateTime('yyyymmdd-hhnnss', Now) + '.json';
  try
    TFile.Move(Path, CorruptPath);
  except
    on E: Exception do
      LogDiagnostic(dlError, deSettingsLoadFailed, E.HelpContext);
  end;
  try
    if FileExists(BackupPath) and LoadJsonFile(BackupPath) then
    begin
      LogDiagnostic(dlInfo, deSettingsRecovered);
      SaveToFile;
      Exit;
    end;
  except
    on E: Exception do
      LogDiagnostic(dlError, deSettingsLoadFailed, E.HelpContext);
  end;
  SetDefaults;
  SaveToFile;
  finally
    FFileLock.Release;
  end;
end;

procedure TSettings.SaveToFile;
var
  Root, RulesObject, RuleObject, LearningObject, PreferObject, AppRoot,
    AppObject: TJSONObject;
  ExclusionsArray, KeptArray: TJSONArray;
  Rule: TApplicationRule;
  Pair: TPair<string, TLearningEntry>;
  AppPair: TPair<string, TDictionary<string, TLearningEntry>>;
  I: Integer;
  Path, TempPath, BackupPath: string;
begin
  FFileLock.Acquire;
  try
  Path := GetConfigFilePath;
  TempPath := Path + '.tmp';
  BackupPath := Path + '.bak';
  Root := TJSONObject.Create;
  try
    FLock.Acquire;
    try
    Root.AddPair('SchemaVersion', TJSONNumber.Create(SettingsSchemaVersion));
    Root.AddPair('SoundOnRussianInput', TJSONBool.Create(FSoundOnRussianInput));
    Root.AddPair('SoundOnSwitch', TJSONBool.Create(FSoundOnSwitch));
    Root.AddPair('DoubleLeftShiftEnabled',
      TJSONBool.Create(FDoubleLeftShiftEnabled));
    Root.AddPair('SwitchLayoutAfterSelection',
      TJSONBool.Create(FSwitchLayoutAfterSelection));
    Root.AddPair('AutoSwitchEnabled', TJSONBool.Create(FAutoSwitchEnabled));
    Root.AddPair('AutoStart', TJSONBool.Create(FAutoStart));
    Root.AddPair('HeuristicMode', ModeToString(FHeuristicMode));
    Root.AddPair('DiagnosticsLevel', DiagnosticsToString(FDiagnosticsLevel));
    Root.AddPair('CaretHintOffsetX', TJSONNumber.Create(FCaretHintOffsetX));
    Root.AddPair('CaretHintOffsetY', TJSONNumber.Create(FCaretHintOffsetY));
    Root.AddPair('CaretHintMode', CaretHintModeToString(FCaretHintMode));
    Root.AddPair('CaretHintFlash', TJSONBool.Create(FCaretHintFlash));
    Root.AddPair('CaretHintAnimate', TJSONBool.Create(FCaretHintAnimate));
    ExclusionsArray := TJSONArray.Create;
    for I := 0 to FExclusions.Count - 1 do
      ExclusionsArray.Add(FExclusions[I]);
    Root.AddPair('Exclusions', ExclusionsArray);
    Root.AddPair('FixInitialCaps', TJSONBool.Create(FFixInitialCaps));
    Root.AddPair('FixCapsLock', TJSONBool.Create(FFixCapsLock));
    Root.AddPair('PauseInFullscreen', TJSONBool.Create(FPauseInFullscreen));
    Root.AddPair('EnglishInSecureFields', TJSONBool.Create(FEnglishInSecureFields));
    Root.AddPair('DoubleCtrlEnabled', TJSONBool.Create(FDoubleCtrlEnabled));
    Root.AddPair('EarlySwitchEnabled', TJSONBool.Create(FEarlySwitchEnabled));
    Root.AddPair('EarlySwitchLetters', TJSONNumber.Create(FEarlySwitchLetters));
    KeptArray := TJSONArray.Create;
    for I := 0 to FCaseFixKept.Count - 1 do
      KeptArray.Add(FCaseFixKept[I]);
    Root.AddPair('CaseFixKept', KeptArray);

    RulesObject := TJSONObject.Create;
    for Rule in FApplicationRules do
    begin
      RuleObject := TJSONObject.Create;
      if Rule.HasAutoSwitch then
        RuleObject.AddPair('AutoSwitchEnabled',
          TJSONBool.Create(Rule.AutoSwitchEnabled));
      if Rule.HasSoundOnRussianInput then
        RuleObject.AddPair('SoundOnRussianInput',
          TJSONBool.Create(Rule.SoundOnRussianInput));
      if Rule.HasSoundOnSwitch then
        RuleObject.AddPair('SoundOnSwitch',
          TJSONBool.Create(Rule.SoundOnSwitch));
      if Rule.HasHeuristicMode then
        RuleObject.AddPair('HeuristicMode', ModeToString(Rule.HeuristicMode));
      RulesObject.AddPair(Rule.Pattern, RuleObject);
    end;
    Root.AddPair('ApplicationRules', RulesObject);

    LearningObject := TJSONObject.Create;
    PreferObject := TJSONObject.Create;
    for Pair in FLearning do
    begin
      if Pair.Value.Reject > 0 then
        LearningObject.AddPair(Pair.Key, TJSONNumber.Create(Pair.Value.Reject));
      if Pair.Value.Prefer > 0 then
        PreferObject.AddPair(Pair.Key, TJSONNumber.Create(Pair.Value.Prefer));
    end;
    Root.AddPair('NeverSwitchLearning', LearningObject);
    Root.AddPair('PreferSwitchLearning', PreferObject);

    AppRoot := TJSONObject.Create;
    for AppPair in FAppLearning do
    begin
      if AppPair.Value.Count = 0 then
        Continue;
      AppObject := TJSONObject.Create;
      LearningObject := TJSONObject.Create;
      PreferObject := TJSONObject.Create;
      for Pair in AppPair.Value do
      begin
        if Pair.Value.Reject > 0 then
          LearningObject.AddPair(Pair.Key, TJSONNumber.Create(Pair.Value.Reject));
        if Pair.Value.Prefer > 0 then
          PreferObject.AddPair(Pair.Key, TJSONNumber.Create(Pair.Value.Prefer));
      end;
      AppObject.AddPair('Never', LearningObject);
      AppObject.AddPair('Prefer', PreferObject);
      AppRoot.AddPair(AppPair.Key, AppObject);
    end;
    Root.AddPair('ApplicationLearning', AppRoot);
    finally
      FLock.Release;
    end;

    try
      TFile.WriteAllText(TempPath, Root.Format(2), TEncoding.UTF8);
      if FileExists(Path) then
      begin
        if not ReplaceFile(PChar(Path), PChar(TempPath), PChar(BackupPath),
          REPLACEFILE_WRITE_THROUGH, nil, nil) then
          RaiseLastOSError;
      end
      else if not MoveFileEx(PChar(TempPath), PChar(Path),
        MOVEFILE_WRITE_THROUGH) then
        RaiseLastOSError;
    except
      on E: Exception do
      begin
        LogDiagnostic(dlError, deSettingsSaveFailed, E.HelpContext);
        raise;
      end;
    end;
  finally
    Root.Free;
    if FileExists(TempPath) then
      try
        TFile.Delete(TempPath);
      except
        on E: Exception do
          LogDiagnostic(dlError, deSettingsSaveFailed, E.HelpContext);
      end;
  end;
  finally
    FFileLock.Release;
  end;
end;

function TSettings.IsProcessExcluded(const AProcessName: string): Boolean;
var
  I: Integer;
  Name: string;
begin
  Name := LowerCase(ExtractFileName(AProcessName));
  for I := Low(AlwaysExcludedProcesses) to High(AlwaysExcludedProcesses) do
    if Name = AlwaysExcludedProcesses[I] then
      Exit(True);
  FLock.Acquire;
  try
    for I := 0 to FExclusions.Count - 1 do
      if WildcardMatch(FExclusions[I], Name) or
         WildcardMatch(FExclusions[I], LowerCase(AProcessName)) then
        Exit(True);
    Result := False;
  finally
    FLock.Release;
  end;
end;

procedure TSettings.AddExclusion(const APattern: string);
begin
  if APattern = '' then
    Exit;
  FLock.Acquire;
  try
    if FExclusions.IndexOf(LowerCase(APattern)) < 0 then
      FExclusions.Add(LowerCase(APattern));
  finally
    FLock.Release;
  end;
end;

procedure TSettings.ClearExclusions;
begin
  FLock.Acquire;
  try
    FExclusions.Clear;
  finally
    FLock.Release;
  end;
end;

function TSettings.ResolveProfile(
  const AProcessName: string): TApplicationProfile;
var
  Rule: TApplicationRule;
  Name, FullName: string;
begin
  Name := LowerCase(ExtractFileName(AProcessName));
  FullName := LowerCase(AProcessName);
  FLock.Acquire;
  try
    Result.AutoSwitchEnabled := FAutoSwitchEnabled;
    Result.SoundOnRussianInput := FSoundOnRussianInput;
    Result.SoundOnSwitch := FSoundOnSwitch;
    Result.HeuristicMode := FHeuristicMode;
    for Rule in FApplicationRules do
      if WildcardMatch(Rule.Pattern, Name) or
         WildcardMatch(Rule.Pattern, FullName) then
      begin
        if Rule.HasAutoSwitch then
          Result.AutoSwitchEnabled := Rule.AutoSwitchEnabled;
        if Rule.HasSoundOnRussianInput then
          Result.SoundOnRussianInput := Rule.SoundOnRussianInput;
        if Rule.HasSoundOnSwitch then
          Result.SoundOnSwitch := Rule.SoundOnSwitch;
        if Rule.HasHeuristicMode then
          Result.HeuristicMode := Rule.HeuristicMode;
      end;
  finally
    FLock.Release;
  end;
end;

function TSettings.IsAutoSwitchEnabledFor(const AProcessName: string): Boolean;
begin
  Result := ResolveProfile(AProcessName).AutoSwitchEnabled;
end;

function TSettings.FindOrAddRuleUnlocked(
  const APattern: string): TApplicationRule;
begin
  for Result in FApplicationRules do
    if SameText(Result.Pattern, APattern) then
      Exit;
  Result := TApplicationRule.Create;
  Result.Pattern := APattern;
  FApplicationRules.Add(Result);
end;

procedure TSettings.SetApplicationRule(const AProcessName: string;
  AEnabled: Boolean);
var
  Rule: TApplicationRule;
  Pattern: string;
begin
  Pattern := LowerCase(ExtractFileName(AProcessName));
  FLock.Acquire;
  try
    Rule := FindOrAddRuleUnlocked(Pattern);
    Rule.HasAutoSwitch := True;
    Rule.AutoSwitchEnabled := AEnabled;
  finally
    FLock.Release;
  end;
end;

procedure TSettings.SetApplicationRuleOverrides(const APattern: string;
  AOverrideAutoSwitch, AAutoSwitch, AOverrideInputSound, AInputSound,
  AOverrideSwitchSound, ASwitchSound, AOverrideMode: Boolean;
  AMode: THeuristicMode);
var
  Rule: TApplicationRule;
begin
  FLock.Acquire;
  try
    Rule := FindOrAddRuleUnlocked(LowerCase(APattern));
    Rule.HasAutoSwitch := AOverrideAutoSwitch;
    Rule.AutoSwitchEnabled := AAutoSwitch;
    Rule.HasSoundOnRussianInput := AOverrideInputSound;
    Rule.SoundOnRussianInput := AInputSound;
    Rule.HasSoundOnSwitch := AOverrideSwitchSound;
    Rule.SoundOnSwitch := ASwitchSound;
    Rule.HasHeuristicMode := AOverrideMode;
    Rule.HeuristicMode := AMode;
  finally
    FLock.Release;
  end;
end;

function TSettings.ListExclusions: TArray<string>;
var
  I: Integer;
begin
  FLock.Acquire;
  try
    SetLength(Result, FExclusions.Count);
    for I := 0 to FExclusions.Count - 1 do
      Result[I] := FExclusions[I];
  finally
    FLock.Release;
  end;
end;

procedure TSettings.RemoveExclusion(const APattern: string);
var
  I: Integer;
begin
  if APattern = '' then
    Exit;
  FLock.Acquire;
  try
    for I := FExclusions.Count - 1 downto 0 do
      if SameText(FExclusions[I], APattern) then
        FExclusions.Delete(I);
  finally
    FLock.Release;
  end;
end;

function TSettings.ListApplicationRules: TArray<TApplicationRuleView>;
var
  I: Integer;
  Rule: TApplicationRule;
begin
  FLock.Acquire;
  try
    SetLength(Result, FApplicationRules.Count);
    I := 0;
    for Rule in FApplicationRules do
    begin
      Result[I].Pattern := Rule.Pattern;
      Result[I].HasAutoSwitch := Rule.HasAutoSwitch;
      Result[I].AutoSwitchEnabled := Rule.AutoSwitchEnabled;
      Result[I].HasSoundOnRussianInput := Rule.HasSoundOnRussianInput;
      Result[I].SoundOnRussianInput := Rule.SoundOnRussianInput;
      Result[I].HasSoundOnSwitch := Rule.HasSoundOnSwitch;
      Result[I].SoundOnSwitch := Rule.SoundOnSwitch;
      Result[I].HasHeuristicMode := Rule.HasHeuristicMode;
      Result[I].HeuristicMode := Rule.HeuristicMode;
      Inc(I);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TSettings.PinLearning(const AWord, AProcess: string;
  APreferSwitch: Boolean);
var
  Process: string;
  Action: TLearningAction;
begin
  if APreferSwitch then
    Action := laManualSwitch
  else
    Action := laRejectStrong;
  Process := Trim(AProcess);
  if (Process = '') or SameText(Process, AllApplicationsLearning) then
    Process := AllApplicationsLearning
  else
    Process := ExtractFileName(Process);
  ObserveLearning(AWord, Action, Process);
end;

procedure TSettings.RemoveApplicationRule(const AProcessName: string);
var
  I: Integer;
  Pattern: string;
begin
  Pattern := LowerCase(ExtractFileName(AProcessName));
  FLock.Acquire;
  try
    for I := FApplicationRules.Count - 1 downto 0 do
      if SameText(FApplicationRules[I].Pattern, Pattern) then
        FApplicationRules.Delete(I);
  finally
    FLock.Release;
  end;
end;

function TSettings.LearningCount(const AWord, AProcess: string): Integer;
var
  Key, ProcessKey: string;
  Entry: TLearningEntry;
  Dict: TDictionary<string, TLearningEntry>;
begin
  FLock.Acquire;
  try
    Result := 0;
    Key := NormalizeAnalyzedWord(AWord);
    if Key = '' then
      Exit;
    ProcessKey := LowerCase(ExtractFileName(AProcess));
    if (ProcessKey <> '') and FAppLearning.TryGetValue(ProcessKey, Dict) and
       Dict.TryGetValue(Key, Entry) then
      Exit(Entry.Reject);
    if FLearning.TryGetValue(Key, Entry) then
      Result := Entry.Reject;
  finally
    FLock.Release;
  end;
end;

function TSettings.LearningEntryCount: Integer;
begin
  FLock.Acquire;
  try
    Result := FLearning.Count;
  finally
    FLock.Release;
  end;
end;

function TSettings.LookupLearning(const AWord, AProcess: string;
  out AEntry: TLearningEntry): Boolean;
var
  Key, ProcessKey: string;
  AppDict: TDictionary<string, TLearningEntry>;
begin
  Result := False;
  Key := NormalizeAnalyzedWord(AWord);
  if Key = '' then
    Exit;
  ProcessKey := LowerCase(ExtractFileName(AProcess));
  if ProcessKey <> '' then
  begin
    // The application entry wins. "*" is an explicit choice for every
    // application that has no entry of its own. The legacy table is not
    // consulted while a process name is known.
    if FAppLearning.TryGetValue(ProcessKey, AppDict) then
      Result := FindPromoted(AppDict, Key, AEntry);
    if Result then
      Exit;
    if (ProcessKey <> AllApplicationsLearning) and
       FAppLearning.TryGetValue(AllApplicationsLearning, AppDict) then
      Result := FindPromoted(AppDict, Key, AEntry);
    Exit;
  end;
  Result := FindPromoted(FLearning, Key, AEntry);
end;

function TSettings.IsNeverSwitchWord(const AWord, AProcess: string): Boolean;
var
  Entry: TLearningEntry;
begin
  FLock.Acquire;
  try
    Result := LookupLearning(AWord, AProcess, Entry) and LearningBlocksSwitch(Entry);
  finally
    FLock.Release;
  end;
end;

function TSettings.IsPreferSwitchWord(const AWord, AProcess: string): Boolean;
var
  Entry: TLearningEntry;
begin
  FLock.Acquire;
  try
    Result := LookupLearning(AWord, AProcess, Entry) and LearningForcesSwitch(Entry);
  finally
    FLock.Release;
  end;
end;

function TSettings.ObserveLearning(const AWord: string;
  AAction: TLearningAction; const AProcess: string): Boolean;
var
  Key, ProcessKey: string;
  Entry, Updated: TLearningEntry;
  Dict: TDictionary<string, TLearningEntry>;
  Exists: Boolean;
begin
  Result := False;
  Key := NormalizeAnalyzedWord(AWord);
  if Key = '' then
    Exit;
  FLock.Acquire;
  try
    ProcessKey := LowerCase(ExtractFileName(AProcess));
    if ProcessKey = '' then
      Dict := FLearning
    else if not FAppLearning.TryGetValue(ProcessKey, Dict) then
      Dict := nil;
    Exists := (Dict <> nil) and Dict.TryGetValue(Key, Entry);
    if not Exists then
      Entry := Default(TLearningEntry);
    Updated := ApplyLearningAction(Entry, AAction);
    if (Updated.Reject = Entry.Reject) and (Updated.Prefer = Entry.Prefer) then
    begin
      // The score is already at the cap. Keep the entry recent in memory
      // without rewriting the file: the stamp is not stored.
      if Exists and (AAction <> laAccept) then
      begin
        Inc(FLearningStamp);
        Entry.Stamp := FLearningStamp;
        Dict.AddOrSetValue(Key, Entry);
      end;
      Exit;
    end;
    if (Updated.Reject = 0) and (Updated.Prefer = 0) then
    begin
      if Exists then
      begin
        Dict.Remove(Key);
        if (ProcessKey <> '') and (Dict.Count = 0) then
          FAppLearning.Remove(ProcessKey);
        Result := True;
      end;
      Exit;
    end;
    if Dict = nil then
      Dict := AppDictionary(AProcess, True);
    Inc(FLearningStamp);
    Updated.Stamp := FLearningStamp;
    Dict.AddOrSetValue(Key, Updated);
    BoundDictionary(Dict);
    Result := True;
  finally
    FLock.Release;
  end;
end;

function TSettings.ListLearning: TArray<TLearningView>;
var
  Items: TList<TLearningView>;
  Pair: TPair<string, TLearningEntry>;
  AppPair: TPair<string, TDictionary<string, TLearningEntry>>;

  procedure AddPair(const AProcess: string;
    const APair: TPair<string, TLearningEntry>);
  var
    View: TLearningView;
  begin
    if (APair.Value.Reject <= 0) and (APair.Value.Prefer <= 0) then
      Exit;
    View.Process := AProcess;
    View.Word := APair.Key;
    View.Reject := APair.Value.Reject;
    View.Prefer := APair.Value.Prefer;
    View.Blocks := LearningBlocksSwitch(APair.Value);
    View.Forces := LearningForcesSwitch(APair.Value);
    Items.Add(View);
  end;

begin
  Items := TList<TLearningView>.Create;
  FLock.Acquire;
  try
    for Pair in FLearning do
      AddPair('', Pair);
    for AppPair in FAppLearning do
      for Pair in AppPair.Value do
        AddPair(AppPair.Key, Pair);
    Result := Items.ToArray;
  finally
    FLock.Release;
    Items.Free;
  end;
end;

procedure TSettings.ForgetLearning(const AProcess, AWord: string);
var
  Key, ProcessKey: string;
  Dict: TDictionary<string, TLearningEntry>;
begin
  Key := NormalizeAnalyzedWord(AWord);
  if Key = '' then
    Exit;
  FLock.Acquire;
  try
    ProcessKey := LowerCase(ExtractFileName(AProcess));
    if ProcessKey = '' then
      FLearning.Remove(Key)
    else if FAppLearning.TryGetValue(ProcessKey, Dict) then
    begin
      Dict.Remove(Key);
      if Dict.Count = 0 then
        FAppLearning.Remove(ProcessKey);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TSettings.RecordLearning(const AWord: string;
  AStrongSignal: Boolean);
begin
  if AStrongSignal then
    ObserveLearning(AWord, laRejectStrong)
  else
    ObserveLearning(AWord, laRejectWeak);
end;

procedure TSettings.LearnNeverSwitch(const AWord: string);
begin
  RecordLearning(AWord, True);
end;

procedure TSettings.ResetLearning;
begin
  FLock.Acquire;
  try
    FLearning.Clear;
    FAppLearning.Clear;
  finally
    FLock.Release;
  end;
end;

initialization
  AppSettings := TSettings.Create;

finalization
  AppSettings.Free;

end.
