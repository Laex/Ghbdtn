unit Ghbdtn.Analyzer;

interface

uses
  System.SysUtils,
  System.Character,
  Ghbdtn.Layout,
  Ghbdtn.Phrase;

type
  THeuristicMode = (hmCautious, hmBalanced, hmAggressive);
  TDecisionMark = (dmNone, dmLearning, dmDictionary, dmLeave);
  TNeverSwitchCallback = reference to function(const AWord: string): Boolean;
  TPreferSwitchCallback = reference to function(const AWord: string): Boolean;

  TAnalysisResult = record
    NeedsSwitch: Boolean;
    TargetLang: TLangKind;
    ConvertedText: string;
    Mark: TDecisionMark;
  end;

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
function NormalizeAnalyzedWord(const AWord: string): string;

implementation

uses
  Ghbdtn.Diagnostics,
  Ghbdtn.Heuristics;

const
  KnownLayoutWordScore = 8;
  SwitchScoreMargin = 4;
  UnknownLayoutMargin = 6;

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

function PartsTrace(const APrefix: string; const AParts: TScoreParts): string;
begin
  Result :=
    ' ' + APrefix + '_ngram=' + IntToStr(AParts.NGrams) +
    ' ' + APrefix + '_dict=' + IntToStr(AParts.Dictionary) +
    ' ' + APrefix + '_vowel=' + IntToStr(AParts.Vowel) +
    ' ' + APrefix + '_shape=' + IntToStr(AParts.Shape) +
    ' ' + APrefix + '_pairs=' + IntToStr(AParts.Pairs) +
    ' ' + APrefix + '_run=' + IntToStr(AParts.ConsonantRun) +
    ' ' + APrefix + '_total=' + IntToStr(AParts.Total);
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
  Result := SwitchScoreMargin;
  case AMode of
    hmCautious:
      Inc(Result, 3);
    hmAggressive:
      Dec(Result, 2);
  end;
end;

function TypedLayout(const ALower: string; ACurrentLang: TLangKind): TLangKind;
begin
  if ACurrentLang <> lkUnknown then
    Exit(ACurrentLang);
  if (ALower <> '') and CharInSet(ALower[1], ['a'..'z']) then
    Result := lkEN
  else
    Result := lkRU;
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
    EmptyPhrase);
end;

function AnalyzeWord(const AWord: string; ACurrentLang: TLangKind;
  AMode: THeuristicMode; const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback;
  const APhrase: TPhraseContext): TAnalysisResult;
var
  CleanW: string;
  LowerWord: string;
  Converted: string;
  LowerConverted: string;
  OriginalScore: Integer;
  ConvertedScore: Integer;
  Margin: Integer;
  SourceLayout: TLangKind;
  TypedParts: TScoreParts;
  OtherParts: TScoreParts;
  KnownKey: Integer;
  OtherLayout: TLangKind;
  Head: string;
begin
  Result.NeedsSwitch := False;
  Result.TargetLang := lkUnknown;
  Result.ConvertedText := '';
  Result.Mark := dmNone;

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
  if IsProtectedToken(CleanW) then
  begin
    Result.Mark := dmLeave;
    TraceHeuristic(Head + ' reason=protected switch=0');
    Exit;
  end;
  if Assigned(APreferSwitch) and APreferSwitch(LowerWord) then
  begin
    Result.Mark := dmLearning;
    SourceLayout := TypedLayout(LowerWord, ACurrentLang);
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
  if IsShortLayoutWord(LowerWord) and (ACurrentLang <> lkRU) then
  begin
    Result.Mark := dmDictionary;
    Result.NeedsSwitch := True;
    Result.TargetLang := lkRU;
    Result.ConvertedText := ConvertStringSwap(AWord);
    TraceHeuristic(Head + ' reason=short_layout switch=1 target=RU converted=' +
      QuoteTrace(Result.ConvertedText.ToLower));
    Exit;
  end;
  if Length(CleanW) < 2 then
  begin
    TraceHeuristic(Head + ' reason=too_short switch=0');
    Exit;
  end;

  Converted := ConvertStringSwap(AWord);
  LowerConverted := ConvertStringSwap(CleanW).ToLower;
  SourceLayout := TypedLayout(LowerWord, ACurrentLang);
  KnownKey := 0;
  if SourceLayout = lkEN then
  begin
    TypedParts := ExplainEnglish(LowerWord);
    OtherParts := ExplainRussian(LowerConverted);
    if IsKnownEnToRuKey(LowerWord) then
      KnownKey := KnownLayoutWordScore;
  end
  else
  begin
    TypedParts := ExplainRussian(LowerWord);
    OtherParts := ExplainEnglish(LowerConverted);
  end;
  if SourceLayout = lkEN then
    OtherLayout := lkRU
  else
    OtherLayout := lkEN;
  OriginalScore := TypedParts.Total + PhraseScoreBias(APhrase, SourceLayout);
  ConvertedScore := OtherParts.Total + KnownKey +
    PhraseScoreBias(APhrase, OtherLayout);
  Margin := SwitchMargin(AMode, ACurrentLang <> lkUnknown);
  if SourceLayout = lkEN then
  begin
    if ConvertedScore - OriginalScore >= Margin then
      Result.TargetLang := lkRU;
  end
  else if ConvertedScore - OriginalScore >= Margin then
    Result.TargetLang := lkEN;

  if Result.TargetLang <> lkUnknown then
  begin
    Result.NeedsSwitch := True;
    Result.ConvertedText := Converted;
    if (KnownKey > 0) or (OtherParts.Dictionary > 0) then
      Result.Mark := dmDictionary;
  end;
  TraceHeuristic(Head + ' reason=score typed=' + LayoutToken(SourceLayout) +
    ' other=' + QuoteTrace(LowerConverted) +
    ' known_key=' + IntToStr(KnownKey) +
    ' phrase=' + IntToStr(PhraseScoreBias(APhrase, OtherLayout) -
      PhraseScoreBias(APhrase, SourceLayout)) +
    ' margin=' + IntToStr(Margin) +
    ' delta=' + IntToStr(ConvertedScore - OriginalScore) +
    ' switch=' + IntToStr(Ord(Result.NeedsSwitch)) +
    ' target=' + LayoutToken(Result.TargetLang) +
    PartsTrace(LayoutToken(SourceLayout), TypedParts) +
    PartsTrace(LayoutToken(OtherLayout), OtherParts));
end;

function AnalyzeWord(const AWord: string;
  ACurrentLang: TLangKind): TAnalysisResult;
begin
  Result := AnalyzeWord(AWord, ACurrentLang, hmBalanced, nil);
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
    if CharInSet(Token[1], ['a'..'z', 'A'..'Z']) then
      Lang := lkEN
    else
      Lang := lkRU;
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
    if CharInSet(AText[1], ['a'..'z', 'A'..'Z']) then
      Lang := lkEN
    else
      Lang := lkRU;
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

function ConvertSelectionSmart(const AText: string; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback): string;
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
    if CharInSet(Token[1], ['a'..'z', 'A'..'Z']) then
      Lang := lkEN
    else
      Lang := lkRU;
    Analysis := AnalyzeWord(Token, Lang, AMode, ANeverSwitch, APreferSwitch);
    if Analysis.NeedsSwitch and (Analysis.ConvertedText <> '') then
      Result := Result + Analysis.ConvertedText
    else
      Result := Result + Token;
  end;
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

function ConvertManualSelection(const AText: string; AMode: THeuristicMode;
  const ANeverSwitch: TNeverSwitchCallback;
  const APreferSwitch: TPreferSwitchCallback): string;
begin
  // A uniform block is what the gesture asked to flip. A mix keeps the
  // words that already belong to their layout.
  if TextHasBothScripts(AText) then
    Result := ConvertSelectionSmart(AText, AMode, ANeverSwitch, APreferSwitch)
  else
    Result := ConvertStringSwap(AText);
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
