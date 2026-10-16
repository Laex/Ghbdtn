unit Ghbdtn.Analyzer;

interface

uses
  System.SysUtils,
  System.Character,
  Ghbdtn.Layout,
  Ghbdtn.Phrase;

type
  THeuristicMode = (hmCautious, hmBalanced, hmAggressive);
  TCaseMode = (cmInvert, cmUpper, cmLower, cmCapitalize);
  TDecisionMark = (dmNone, dmLearning, dmDictionary, dmLeave);
  TNeverSwitchCallback = reference to function(const AWord: string): Boolean;
  TPreferSwitchCallback = reference to function(const AWord: string): Boolean;

  TAnalysisResult = record
    NeedsSwitch: Boolean;
    TargetLang: TLangKind;
    ConvertedText: string;
    Mark: TDecisionMark;
  end;

const
  // How many typed letters of a word the early switch waits for.
  EarlyLettersMin = 3;
  EarlyLettersMax = 8;
  EarlyLettersDefault = 4;

function AnalyzeWord(const AWord: string; ACurrentLang: TLangKind): TAnalysisResult; overload;
function AnalyzeWord(const AWord: string; ACurrentLang: TLangKind;
  AMode: THeuristicMode; const ANeverSwitch: TNeverSwitchCallback): TAnalysisResult; overload;
function AnalyzeWord(const AWord: string; ACurrentLang: TLangKind;
  AMode: THeuristicMode; const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback): TAnalysisResult; overload;
function AnalyzeWord(const AWord: string; ACurrentLang: TLangKind;
  AMode: THeuristicMode; const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback;
  const APhrase: TPhraseContext): TAnalysisResult; overload;
{ Whether the beginning of a word that is still being typed is already clearly
  text of the other layout. Only a prefix that starts no word of the typed
  language and does start a word of the other one is switched. }
function AnalyzeWordPrefix(const APrefix: string; ACurrentLang: TLangKind;
  AMinLetters: Integer; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback): TAnalysisResult;
{ ALine ends with a word of AWordLength characters that is being switched to
  Russian. When one space before it stands a one- or two-letter word typed on
  the English layout whose Russian text is a function word ("D yfxfkt": "D"
  is "В"), the word is returned: a short word at the start of a phrase is
  left alone by itself, but it belongs to the words after it. }
function TryPrecedingShortWord(const ALine: string; AWordLength: Integer;
  out AWord: string): Boolean;
{ Three or more of the key that types "ё" on the Russian layout: a code fence
  typed on the wrong layout. No Russian word looks like that. }
function IsCodeFenceKeys(const AText: string): Boolean;
function IsEnglishQuestionMarker(const AText: string): Boolean;
function AnalyzeSelection(const AText: string; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback): TAnalysisResult;
function ConvertSelectionSmart(const AText: string; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback): string; overload;
function ConvertSelectionSmart(const AText: string; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback): string; overload;
function ConvertManualSelection(const AText: string; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback): string;
function TryWordAtCaret(const AText: string; ACaret: Integer;
  out AStart, AEnd: Integer): Boolean;
function InvertLetterCase(const AText: string): string;
{ cmCapitalize puts the first letter of each sentence in capitals and the
  rest in lower case. }
function ApplyCaseMode(const AText: string; AMode: TCaseMode): string;
{ Line breaks as a single LF, for comparing text read back from an editor. }
function NormalizeLineBreaks(const AText: string): string;
{ How many times Left moves the caret across AText: a line break (CRLF, CR
  or LF) and a surrogate pair each count once. }
function CaretStepCount(const AText: string): Integer;
function TryFixInitialCapitals(const AWord: string; out AFixed: string): Boolean;
function TryFixCapsLockWord(const AWord: string; out AFixed: string): Boolean;
function NormalizeAnalyzedWord(const AWord: string): string;

implementation

uses
  System.Math,
  Ghbdtn.Diagnostics,
  Ghbdtn.Heuristics,
  Ghbdtn.LetterModel,
  Ghbdtn.Reading,
  Ghbdtn.WordFreq;

const
  // Quarter-bits (4 points = 1 bit) the other layout's reading must be ahead
  // by before the word is switched.
  SwitchEvidenceMargin = 28;
  CautiousExtraMargin = 12;
  AggressiveLessMargin = 8;
  UnknownLayoutMargin = 36;
  // The costliest letter of a text that still reads as a word of its
  // language, with the word end counted as a letter.
  PlausibleRussianLetterCost = 24;
  PlausibleEnglishLetterCost = 26;
  // What a capital Russian letter inside a word costs: the English layout
  // types it with Shift on the same keys as "<" or "{", so code such as a<b
  // would otherwise read as a Russian word.
  InnerCapitalKeyCost = 48;
  // The beginning of a word is judged only while it has at most this many
  // letters.
  EarlySwitchMaxLetters = 12;
  // The manual gesture switches a word unless what was typed is clearly the
  // better reading: the other reading may trail by this much (a negative
  // margin), so words the automatic rule refuses are still converted.
  ManualSwitchMargin = -16;

function LayoutToken(ALang: TLangKind): string;
begin
  case ALang of
    lkRU: Result := 'RU';
    lkEN: Result := 'EN';
  else
    Result := 'unknown';
  end;
end;

function ModeToken(AMode: THeuristicMode): string;
begin
  case AMode of
    hmCautious: Result := 'cautious';
    hmBalanced: Result := 'balanced';
    hmAggressive: Result := 'aggressive';
  else
    Result := 'balanced';
  end;
end;

function QuoteTrace(const AValue: string): string;
begin
  Result := '"' + AValue.Replace('"', '''').Replace(#13, ' ').Replace(#10, ' ') + '"';
end;

function ReadingTrace(const APrefix: string; const AReading: TReading): string;
begin
  Result :=
    ' ' + APrefix + '_cost=' + IntToStr(AReading.Cost) +
    ' ' + APrefix + '_listed=' + IntToStr(Ord(AReading.Listed));
end;

procedure TraceHeuristic(const ADetail: string);
begin
  if EffectiveDiagnosticsLevel >= dlVerbose then
    LogDiagnostic(dlVerbose, deHeuristicDecision, 0, ADetail);
end;

function SwitchMargin(AMode: THeuristicMode; ALayoutKnown: Boolean): Integer;
begin
  // An unknown layout has no mode adjustment: the bar stays fixed.
  if not ALayoutKnown then
    Exit(UnknownLayoutMargin);
  Result := SwitchEvidenceMargin;
  case AMode of
    hmCautious:
      Inc(Result, CautiousExtraMargin);
    hmAggressive:
      Dec(Result, AggressiveLessMargin);
  end;
end;

function IsDottedExtension(const ALower: string): Boolean;
begin
  Result := (Length(ALower) >= 3) and (ALower[1] = '.') and
    IsFileExtension(Copy(ALower, 2, MaxInt));
end;

function TypedLayout(const AText: string; ACurrentLang: TLangKind): TLangKind;
var
  I: Integer;
begin
  if ACurrentLang <> lkUnknown then
    Exit(ACurrentLang);
  // The first letter says which alphabet the word is written in; keys such as
  // "," that type Russian letters on the English layout say nothing.
  for I := 1 to Length(AText) do
    if CharInSet(AText[I], ['a'..'z', 'A'..'Z']) then
      Exit(lkEN)
    else if Ord(AText[I]) > 127 then
      Exit(lkRU);
  Result := lkEN;
end;

{ The text of a word the layout reading is measured on: punctuation around it
  is dropped, except the keys of the English layout that type Russian letters,
  which may be part of the word. }
function InnerCapitalKeyCount(const AText: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 2 to Length(AText) do
    if CharInSet(AText[I], ['<', '>', '"', '{', '}', '~']) then
      Inc(Result);
end;

function TrimToReading(const AWord: string; ALayout: TLangKind): string;
var
  StartIdx, EndIdx: Integer;

  function Belongs(C: Char): Boolean;
  begin
    Result := CharInSet(C, ['a'..'z', 'A'..'Z', '0'..'9']) or (Ord(C) > 127) or
      ((ALayout <> lkRU) and IsRussianLetterKey(C));
  end;

begin
  StartIdx := 1;
  EndIdx := Length(AWord);
  while (StartIdx <= EndIdx) and not Belongs(AWord[StartIdx]) do
    Inc(StartIdx);
  while (EndIdx >= StartIdx) and not Belongs(AWord[EndIdx]) do
    Dec(EndIdx);
  Result := Copy(AWord, StartIdx, EndIdx - StartIdx + 1);
end;

function CleanWordString(const S: string): string;
var
  StartIdx, EndIdx: Integer;
begin
  StartIdx := 1;
  EndIdx := Length(S);
  while (StartIdx <= EndIdx) and not (CharInSet(S[StartIdx], ['a'..'z', 'A'..'Z', '0'..'9']) or (Ord(S[StartIdx]) > 127)) do
    Inc(StartIdx);
  while (EndIdx >= StartIdx) and not (CharInSet(S[EndIdx], ['a'..'z', 'A'..'Z', '0'..'9']) or (Ord(S[EndIdx]) > 127)) do
    Dec(EndIdx);

  if StartIdx <= EndIdx then
    Result := Copy(S, StartIdx, EndIdx - StartIdx + 1)
  else
    Result := S;
end;

function NormalizeAnalyzedWord(const AWord: string): string;
begin
  Result := CleanWordString(AWord).ToLower;
  if Result = '' then
    Result := AWord.ToLower;
end;

function IsCodeFenceKeys(const AText: string): Boolean;
var
  I: Integer;
begin
  Result := Length(AText) >= 3;
  for I := 1 to Length(AText) do
    if (AText[I] <> 'ё') and (AText[I] <> 'Ё') then
      Exit(False);
end;

function IsProtectedToken(const S: string): Boolean;
var
  I, LetterCount: Integer;
  HasLatin, HasCyrillic, AllUpper: Boolean;
  C: Char;
begin
  if (Pos('://', S) > 0) or (Pos('@', S) > 0) or
     (Pos('\', S) > 0) or (Pos('/', S) > 0) or
     (Pos('_', S) > 0) or (Pos('=', S) > 0) or
     (Pos(':', S) > 0) then
    Exit(True);

  HasLatin := False;
  HasCyrillic := False;
  AllUpper := True;
  LetterCount := 0;
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if CharInSet(C, ['0'..'9']) then
      Exit(True);

    if CharInSet(C, ['a'..'z', 'A'..'Z']) then
      HasLatin := True
    else if ((C >= 'А') and (C <= 'я')) or (C = 'Ё') or (C = 'ё') then
      HasCyrillic := True;

    if C.IsLetter then
    begin
      Inc(LetterCount);
      if not C.IsUpper then
        AllUpper := False;
    end;
  end;

  Result :=
    (HasLatin and HasCyrillic) or
    (AllUpper and (LetterCount >= 2) and (LetterCount <= 4));
end;

function AnalyzeWord(const AWord: string; ACurrentLang: TLangKind;
  AMode: THeuristicMode; const ANeverSwitch: TNeverSwitchCallback): TAnalysisResult;
begin
  Result := AnalyzeWord(AWord, ACurrentLang, AMode, ANeverSwitch, nil);
end;

function AnalyzeWord(const AWord: string; ACurrentLang: TLangKind;
  AMode: THeuristicMode; const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback): TAnalysisResult;
begin
  Result := AnalyzeWord(AWord, ACurrentLang, AMode, ANeverSwitch, APreferSwitch,
    UntrackedPhrase);
end;

function AnalyzeWordCore(const AWord: string; ACurrentLang: TLangKind;
  AMode: THeuristicMode; const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback;
  const APhrase: TPhraseContext; AManual: Boolean): TAnalysisResult;
var
  CleanW: string;
  LowerWord: string;
  ReadText: string;
  ReadCased: string;
  OtherText: string;
  Converted: string;
  SourceLayout: TLangKind;
  OtherLayout: TLangKind;
  Typed: TReading;
  Other: TReading;
  Margin: Integer;
  Bias: Integer;
  Delta: Integer;
  Plausible: Integer;
  KeptStart, KeptStop, Offset: Integer;
  ShortWord: string;
  Head: string;
begin
  Result.NeedsSwitch := False;
  Result.TargetLang := lkUnknown;
  Result.ConvertedText := '';
  Result.Mark := dmNone;
  KeptStart := 1;
  KeptStop := MaxInt;

  CleanW := CleanWordString(AWord);
  if CleanW = '' then
    CleanW := AWord;
  LowerWord := CleanW.ToLower;
  Head := 'word=' + QuoteTrace(LowerWord) + ' layout=' + LayoutToken(ACurrentLang) +
    ' mode=' + ModeToken(AMode);
  if Assigned(ANeverSwitch) and ANeverSwitch(LowerWord) then
  begin
    Result.Mark := dmLearning;
    TraceHeuristic(Head + ' reason=never_switch switch=0');
    Exit;
  end;
  if (ACurrentLang <> lkEN) and IsCodeFenceKeys(AWord) then
  begin
    Result.NeedsSwitch := True;
    Result.TargetLang := lkEN;
    Result.ConvertedText := ConvertStringSwap(AWord);
    TraceHeuristic(Head + ' reason=code_fence switch=1 target=EN');
    Exit;
  end;
  if IsProtectedToken(CleanW) then
  begin
    Result.Mark := dmLeave;
    TraceHeuristic(Head + ' reason=protected switch=0');
    Exit;
  end;
  SourceLayout := TypedLayout(AWord, ACurrentLang);
  if Assigned(APreferSwitch) and APreferSwitch(LowerWord) then
  begin
    Result.Mark := dmLearning;
    Result.NeedsSwitch := True;
    Result.ConvertedText := ConvertStringSwap(AWord);
    if SourceLayout = lkEN then
      Result.TargetLang := lkRU
    else
      Result.TargetLang := lkEN;
    TraceHeuristic(Head + ' reason=learned_prefer switch=1 target=' +
      LayoutToken(Result.TargetLang) + ' converted=' +
      QuoteTrace(Result.ConvertedText.ToLower));
    Exit;
  end;
  // A one- or two-letter Russian function word ("и", "не", "на") is too short
  // to score. Typed after Russian words it is taken as Russian; at the start
  // of a phrase it stays put, since "vs" or "c" is just as likely English.
  // Keys of Russian letters on the edge count as letters here: "'nj" is the
  // three-letter "это", not the short "то" in quotes.
  ShortWord := TrimToReading(AWord, lkEN);
  if ShortWord = '' then
    ShortWord := CleanW;
  if (Length(ShortWord) <= 2) and (ACurrentLang <> lkRU) and
     IsRussianFunctionWord(ConvertStringSwap(ShortWord).ToLower) then
  begin
    if AManual or APhrase.Untracked or PhraseEndsWith(APhrase, lkRU) then
    begin
      Result.Mark := dmDictionary;
      Result.NeedsSwitch := True;
      Result.TargetLang := lkRU;
      Result.ConvertedText := ConvertStringSwap(AWord);
      TraceHeuristic(Head + ' reason=short_layout switch=1 target=RU converted=' +
        QuoteTrace(Result.ConvertedText.ToLower));
    end
    else
      TraceHeuristic(Head + ' reason=short_needs_context switch=0');
    Exit;
  end;
  ReadCased := TrimToReading(AWord, SourceLayout);
  ReadText := ReadCased.ToLower;
  if Length(ReadText) < 2 then
  begin
    TraceHeuristic(Head + ' reason=too_short switch=0');
    Exit;
  end;
  // "юзва" is ".pdf" typed on the Russian layout. A file extension has no
  // vowels or letter sequences to score, so it is recognized from the list.
  if (ACurrentLang <> lkEN) and IsDottedExtension(ConvertStringSwap(CleanW).ToLower) then
  begin
    Result.Mark := dmDictionary;
    Result.NeedsSwitch := True;
    Result.TargetLang := lkEN;
    Result.ConvertedText := ConvertStringSwap(AWord);
    TraceHeuristic(Head + ' reason=file_extension switch=1 target=EN converted=' +
      QuoteTrace(Result.ConvertedText.ToLower));
    Exit;
  end;

  Converted := ConvertStringSwap(AWord);
  OtherText := ConvertStringSwap(ReadText).ToLower;
  if SourceLayout = lkEN then
  begin
    OtherLayout := lkRU;
    Typed := ReadAsEnglish(ReadText);
    Other := ReadAsRussianKeepingEdges(ReadText, KeptStart, KeptStop);
    Inc(Other.Cost, InnerCapitalKeyCost * InnerCapitalKeyCount(ReadCased));
  end
  else
  begin
    OtherLayout := lkEN;
    Typed := ReadAsRussian(ReadText);
    Other := ReadAsEnglish(OtherText);
  end;
  if not (Typed.Valid and Other.Valid) then
  begin
    TraceHeuristic(Head + ' reason=no_reading switch=0');
    Exit;
  end;
  // A word of the other layout needs a vowel; without one the converted text
  // is an abbreviation typed as it is (pdf, ltd), not a word typed wrongly.
  // A Russian abbreviation of the word list (млн, снг) is the exception.
  if (Length(Other.Core) >= 3) and not HasVowel(Other.Core, OtherLayout) and
     not ((OtherLayout = lkRU) and Other.Listed) then
  begin
    TraceHeuristic(Head + ' reason=no_vowel switch=0');
    Exit;
  end;
  // The text switched to must read as a word of its language by itself, not
  // only be less improbable than what was typed: single letters joined by
  // commas or periods ("a,b,c") read as nothing in either language.
  if not Other.Listed then
  begin
    if OtherLayout = lkRU then
      Plausible := PlausibleRussianLetterCost
    else
      Plausible := PlausibleEnglishLetterCost;
    if Other.PlainCost > Plausible * (Length(Other.Core) + 1) then
    begin
      TraceHeuristic(Head + ' reason=implausible switch=0');
      Exit;
    end;
  end;
  Bias := PhraseScoreBias(APhrase, OtherLayout) -
    PhraseScoreBias(APhrase, SourceLayout);
  Delta := Typed.Cost - Other.Cost + Bias;
  if AManual then
    Margin := ManualSwitchMargin
  else
    Margin := SwitchMargin(AMode, ACurrentLang <> lkUnknown);
  if Delta >= Margin then
  begin
    Result.NeedsSwitch := True;
    Result.TargetLang := OtherLayout;
    Result.ConvertedText := Converted;
    if (SourceLayout = lkEN) and
       ((KeptStart > 1) or (KeptStop < Length(ReadText))) then
    begin
      // The edge keys read as punctuation stay as typed.
      Offset := Pos(ReadCased, AWord) - 1;
      Result.ConvertedText :=
        ConvertStringSwap(Copy(AWord, 1, Offset)) +
        Copy(AWord, Offset + 1, KeptStart - 1) +
        ConvertStringSwap(Copy(AWord, Offset + KeptStart,
          KeptStop - KeptStart + 1)) +
        Copy(AWord, Offset + KeptStop + 1, Length(ReadText) - KeptStop) +
        ConvertStringSwap(Copy(AWord, Offset + Length(ReadText) + 1,
          MaxInt));
    end;
    if Other.Listed then
      Result.Mark := dmDictionary;
  end;
  TraceHeuristic(Head + ' reason=score typed=' + LayoutToken(SourceLayout) +
    ' other=' + QuoteTrace(OtherText) +
    ' phrase=' + IntToStr(Bias) +
    ' margin=' + IntToStr(Margin) +
    ' delta=' + IntToStr(Delta) +
    ' switch=' + IntToStr(Ord(Result.NeedsSwitch)) +
    ' target=' + LayoutToken(Result.TargetLang) +
    ReadingTrace(LayoutToken(SourceLayout), Typed) +
    ReadingTrace(LayoutToken(OtherLayout), Other));
end;

function AnalyzeWord(const AWord: string; ACurrentLang: TLangKind;
  AMode: THeuristicMode; const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback;
  const APhrase: TPhraseContext): TAnalysisResult;
begin
  Result := AnalyzeWordCore(AWord, ACurrentLang, AMode, ANeverSwitch,
    APreferSwitch, APhrase, False);
end;

function AnalyzeWord(const AWord: string;
  ACurrentLang: TLangKind): TAnalysisResult;
begin
  Result := AnalyzeWord(AWord, ACurrentLang, hmBalanced, nil);
end;

function IsPlainLayoutLetters(const AText: string; ALayout: TLangKind): Boolean;
var
  I: Integer;
  C: Char;
begin
  Result := AText <> '';
  for I := 1 to Length(AText) do
  begin
    C := AText[I];
    if ALayout = lkEN then
    begin
      if not CharInSet(C, ['a'..'z', 'A'..'Z']) then
        Exit(False);
    end
    else if not (((C >= 'а') and (C <= 'я')) or
      ((C >= 'А') and (C <= 'Я'))) then
      Exit(False);
  end;
end;

function TryPrecedingShortWord(const ALine: string; AWordLength: Integer;
  out AWord: string): Boolean;
var
  Head: string;
  WordEnd, I: Integer;
begin
  Result := False;
  AWord := '';
  if (AWordLength <= 0) or (AWordLength >= Length(ALine)) then
    Exit;
  Head := Copy(ALine, 1, Length(ALine) - AWordLength);
  WordEnd := Length(Head) - 1;
  if (WordEnd < 1) or (Head[Length(Head)] <> ' ') then
    Exit;
  I := WordEnd;
  while (I >= 1) and CharInSet(Head[I], ['a'..'z', 'A'..'Z']) do
    Dec(I);
  if (WordEnd - I < 1) or (WordEnd - I > 2) then
    Exit;
  if (I >= 1) and not CharInSet(Head[I], [' ', #9, #10, #13, ',', ';', ':',
    '!', '?', '(', '"']) then
    Exit;
  AWord := Copy(Head, I + 1, WordEnd - I);
  Result := IsRussianFunctionWord(ConvertStringSwap(AWord).ToLower);
  if not Result then
    AWord := '';
end;

function AnalyzeWordPrefix(const APrefix: string; ACurrentLang: TLangKind;
  AMinLetters: Integer; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback): TAnalysisResult;
var
  Lower, OtherText, Head: string;
  OtherLayout: TLangKind;
  Margin, Delta: Integer;
begin
  Result.NeedsSwitch := False;
  Result.TargetLang := lkUnknown;
  Result.ConvertedText := '';
  Result.Mark := dmNone;
  if not (ACurrentLang in [lkEN, lkRU]) or
     (Length(APrefix) < Max(AMinLetters, EarlyLettersMin)) or
     (Length(APrefix) > EarlySwitchMaxLetters) or
     not IsPlainLayoutLetters(APrefix, ACurrentLang) or
     IsProtectedToken(APrefix) then
    Exit;
  if ACurrentLang = lkEN then
    OtherLayout := lkRU
  else
    OtherLayout := lkEN;
  Lower := APrefix.ToLower;
  if Assigned(ANeverSwitch) and ANeverSwitch(Lower) then
    Exit;
  OtherText := ConvertStringSwap(Lower);
  if not IsPlainLayoutLetters(OtherText, OtherLayout) or
     not HasVowel(OtherText, OtherLayout) or
     HasWordWithPrefix(Lower, ACurrentLang) or
     not HasWordWithPrefix(OtherText, OtherLayout) then
    Exit;
  Margin := SwitchMargin(AMode, True);
  Delta := LetterModelPrefixCost(Lower, ACurrentLang) -
    LetterModelPrefixCost(OtherText, OtherLayout);
  if Delta >= Margin then
  begin
    Result.NeedsSwitch := True;
    Result.TargetLang := OtherLayout;
    Result.ConvertedText := ConvertStringSwap(APrefix);
  end;
  Head := 'prefix=' + QuoteTrace(Lower) + ' layout=' + LayoutToken(ACurrentLang) +
    ' mode=' + ModeToken(AMode);
  TraceHeuristic(Head + ' reason=early margin=' + IntToStr(Margin) +
    ' delta=' + IntToStr(Delta) + ' switch=' + IntToStr(Ord(Result.NeedsSwitch)));
end;

function IsEnglishQuestionMarker(const AText: string): Boolean;
var
  I: Integer;
  Letters: Integer;
begin
  // "hello?" or "a?" or "ok?": Latin letters, then '?' with no space.
  Result := False;
  if Length(AText) < 2 then
    Exit;
  if AText[Length(AText)] <> '?' then
    Exit;
  Letters := 0;
  for I := 1 to Length(AText) - 1 do
  begin
    if not CharInSet(AText[I], ['a'..'z', 'A'..'Z']) then
      Exit;
    Inc(Letters);
  end;
  Result := Letters >= 1;
end;

function AnalyzeSelection(const AText: string; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback): TAnalysisResult;
var
  I: Integer;
  StartIdx: Integer;
  Token: string;
  TokenResult: TAnalysisResult;
  Lang: TLangKind;
  AnyNeeds: Boolean;
  Target: TLangKind;
begin
  Result.NeedsSwitch := False;
  Result.TargetLang := lkUnknown;
  Result.ConvertedText := '';
  Result.Mark := dmNone;
  if Trim(AText) = '' then
    Exit;

  AnyNeeds := False;
  Target := lkUnknown;
  I := 1;
  while I <= Length(AText) do
  begin
    while (I <= Length(AText)) and CharInSet(AText[I], [' ', #9, #10, #13]) do
      Inc(I);
    if I > Length(AText) then
      Break;
    StartIdx := I;
    while (I <= Length(AText)) and
          not CharInSet(AText[I], [' ', #9, #10, #13]) do
      Inc(I);
    Token := Copy(AText, StartIdx, I - StartIdx);
    if Length(Token) < 2 then
      Continue;
    Lang := TypedLayout(Token, lkUnknown);
    TokenResult := AnalyzeWord(Token, Lang, AMode, ANeverSwitch);
    if TokenResult.NeedsSwitch then
    begin
      AnyNeeds := True;
      if Target = lkUnknown then
        Target := TokenResult.TargetLang;
    end;
  end;

  if not AnyNeeds then
  begin
    // Whole selection as one token (phrases without spaces still handled).
    Lang := TypedLayout(AText, lkUnknown);
    Result := AnalyzeWord(AText, Lang, AMode, ANeverSwitch);
    if Result.NeedsSwitch then
      Result.ConvertedText := ConvertStringSwap(AText);
    Exit;
  end;

  Result.NeedsSwitch := True;
  Result.TargetLang := Target;
  Result.ConvertedText := ConvertStringSwap(AText);
end;

function ConvertSelectionSmart(const AText: string; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback): string;
begin
  Result := ConvertSelectionSmart(AText, AMode, ANeverSwitch, nil);
end;

function ConvertTokens(const AText: string; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback; AManual: Boolean): string;
var
  I, StartIdx: Integer;
  Token: string;
  Lang: TLangKind;
  Analysis: TAnalysisResult;
begin
  Result := '';
  if AText = '' then
    Exit;
  I := 1;
  while I <= Length(AText) do
  begin
    if CharInSet(AText[I], [' ', #9, #10, #13]) then
    begin
      Result := Result + AText[I];
      Inc(I);
      Continue;
    end;
    StartIdx := I;
    while (I <= Length(AText)) and
          not CharInSet(AText[I], [' ', #9, #10, #13]) do
      Inc(I);
    Token := Copy(AText, StartIdx, I - StartIdx);
    if Token = '' then
      Continue;
    Lang := TypedLayout(Token, lkUnknown);
    Analysis := AnalyzeWordCore(Token, Lang, AMode, ANeverSwitch,
      APreferSwitch, UntrackedPhrase, AManual);
    if Analysis.NeedsSwitch and (Analysis.ConvertedText <> '') then
      Result := Result + Analysis.ConvertedText
    else
      Result := Result + Token;
  end;
end;

function ConvertSelectionSmart(const AText: string; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback): string;
begin
  Result := ConvertTokens(AText, AMode, ANeverSwitch, APreferSwitch, False);
end;

function TextHasBothScripts(const AText: string): Boolean;
var
  I: Integer;
  C: Char;
  Latin, Cyrillic: Boolean;
begin
  Latin := False;
  Cyrillic := False;
  for I := 1 to Length(AText) do
  begin
    C := AText[I];
    if CharInSet(C, ['a'..'z', 'A'..'Z']) then
      Latin := True
    else if ((C >= 'А') and (C <= 'я')) or (C = 'Ё') or (C = 'ё') then
      Cyrillic := True;
    if Latin and Cyrillic then
      Exit(True);
  end;
  Result := False;
end;

function CountTokens(const AText: string): Integer;
var
  I: Integer;
  InToken: Boolean;
begin
  Result := 0;
  InToken := False;
  for I := 1 to Length(AText) do
    if CharInSet(AText[I], [' ', #9, #10, #13]) then
      InToken := False
    else if not InToken then
    begin
      InToken := True;
      Inc(Result);
    end;
end;

function ConvertManualSelection(const AText: string; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback): string;
begin
  // A single word is the one the gesture points at, so it is flipped whatever
  // it reads like. In longer text each word is flipped unless what was typed
  // is clearly the better reading, so words that already belong to their
  // layout stay and the ones the automatic rule left alone are converted.
  if (CountTokens(AText) <= 1) and not TextHasBothScripts(AText) then
    Result := ConvertStringSwap(AText)
  else
    Result := ConvertTokens(AText, AMode, ANeverSwitch, APreferSwitch, True);
end;

function IsLayoutLetter(C: Char): Boolean;
begin
  Result := CharInSet(C, ['a'..'z', 'A'..'Z']) or
    ((C >= 'А') and (C <= 'я')) or (C = 'Ё') or (C = 'ё');
end;

function TryWordAtCaret(const AText: string; ACaret: Integer;
  out AStart, AEnd: Integer): Boolean;
var
  Pos: Integer;
begin
  // ACaret is a 0-based insertion point, the same kind EM_GETSEL returns.
  Result := False;
  AStart := 0;
  AEnd := 0;
  if (AText = '') or (ACaret < 0) or (ACaret > Length(AText)) then
    Exit;
  if (ACaret < Length(AText)) and IsLayoutLetter(AText[ACaret + 1]) then
    Pos := ACaret + 1
  else if (ACaret > 0) and IsLayoutLetter(AText[ACaret]) then
    Pos := ACaret
  else
    Exit;
  while (Pos > 1) and IsLayoutLetter(AText[Pos - 1]) do
    Dec(Pos);
  AStart := Pos - 1;
  while (Pos <= Length(AText)) and IsLayoutLetter(AText[Pos]) do
    Inc(Pos);
  AEnd := Pos - 1;
  Result := AEnd > AStart;
end;

function NormalizeLineBreaks(const AText: string): string;
begin
  Result := AText.Replace(#13#10, #10).Replace(#13, #10);
end;

function CaretStepCount(const AText: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  I := 1;
  while I <= Length(AText) do
  begin
    if (AText[I] = #13) and (I < Length(AText)) and (AText[I + 1] = #10) then
      Inc(I)
    else if AText[I].IsHighSurrogate and (I < Length(AText)) and
            AText[I + 1].IsLowSurrogate then
      Inc(I);
    Inc(Result);
    Inc(I);
  end;
end;

function TryFixInitialCapitals(const AWord: string; out AFixed: string): Boolean;
var
  I: Integer;
  C: Char;
  Latin, Cyrillic: Boolean;
begin
  AFixed := AWord;
  Result := False;
  // "ТОлько": two capitals followed only by lowercase letters. A longer run
  // of capitals or a later capital is an acronym or a CamelCase name.
  if Length(AWord) < 4 then
    Exit;
  Latin := False;
  Cyrillic := False;
  for I := 1 to Length(AWord) do
  begin
    C := AWord[I];
    if CharInSet(C, ['a'..'z', 'A'..'Z']) then
      Latin := True
    else if ((C >= 'А') and (C <= 'я')) or (C = 'Ё') or (C = 'ё') then
      Cyrillic := True
    else
      Exit;
    if (I <= 2) and not C.IsUpper then
      Exit;
    if (I > 2) and not C.IsLower then
      Exit;
  end;
  if Latin = Cyrillic then
    Exit;
  AFixed := AWord[1] + AWord.Substring(1).ToLower;
  // Latin identifiers such as TForm or IUnknown have the same shape, so
  // Latin words are corrected only when they are common English words.
  if Latin and not IsCommonEnglishWord(AFixed.ToLower) then
  begin
    AFixed := AWord;
    Exit;
  end;
  Result := True;
end;

function TryFixCapsLockWord(const AWord: string; out AFixed: string): Boolean;
var
  I: Integer;
  C: Char;
  Latin, Cyrillic: Boolean;
begin
  AFixed := AWord;
  Result := False;
  // "пРИВЕТ": a lowercase first letter followed only by capitals is what a
  // word typed with Caps Lock on looks like when the first letter was shifted.
  if Length(AWord) < 4 then
    Exit;
  Latin := False;
  Cyrillic := False;
  for I := 1 to Length(AWord) do
  begin
    C := AWord[I];
    if CharInSet(C, ['a'..'z', 'A'..'Z']) then
      Latin := True
    else if ((C >= 'А') and (C <= 'я')) or (C = 'Ё') or (C = 'ё') then
      Cyrillic := True
    else
      Exit;
    if (I = 1) and not C.IsLower then
      Exit;
    if (I > 1) and not C.IsUpper then
      Exit;
  end;
  if Latin = Cyrillic then
    Exit;
  AFixed := AWord[1].ToUpper + AWord.Substring(1).ToLower;
  Result := True;
end;

function ApplyCaseMode(const AText: string; AMode: TCaseMode): string;
var
  I: Integer;
  C: Char;
  SentenceStart: Boolean;
begin
  case AMode of
    cmUpper:
      Exit(AText.ToUpper);
    cmLower:
      Exit(AText.ToLower);
    cmInvert:
      Exit(InvertLetterCase(AText));
  end;
  Result := AText;
  SentenceStart := True;
  for I := 1 to Length(Result) do
  begin
    C := Result[I];
    if C.IsLetter then
    begin
      if SentenceStart then
        Result[I] := C.ToUpper
      else
        Result[I] := C.ToLower;
      SentenceStart := False;
    end
    else if CharInSet(C, ['.', '!', '?', #10, #13]) then
      SentenceStart := True;
  end;
end;

function InvertLetterCase(const AText: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := AText;
  for I := 1 to Length(Result) do
  begin
    C := Result[I];
    if not C.IsLetter then
      Continue;
    if C.IsUpper then
      Result[I] := C.ToLower
    else
      Result[I] := C.ToUpper;
  end;
end;

end.
