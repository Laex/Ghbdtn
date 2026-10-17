unit Ghbdtn.Reading;

{ How plausible a typed word is as text of one language. A reading has a cost
  in quarter-bits (4 points = 1 bit), the negated log of how likely the text
  is: the letter model gives every string a cost, and a word of the frequency
  list is never costlier than its share of running text makes it.

  Several keys of the English layout type Russian letters: , . ; ' [ ] and
  the shifted forms of those. Read as English they are punctuation at the edge
  of a word, read as Russian they are letters. The English reading may give
  up any of them at a price; the Russian reading keeps them. }

interface

uses
  Ghbdtn.Layout;

type
  TReading = record
    // False when nothing but punctuation keys is left to read.
    Valid: Boolean;
    // The cost of the text with the edge keys given up included.
    Cost: Integer;
    // The cost of the text alone.
    PlainCost: Integer;
    // The text is a word of the frequency list.
    Listed: Boolean;
    // The text the cost was measured on, without the edge keys given up.
    Core: string;
  end;

{ ALower is a lowercase text as typed on the English layout, or converted to
  it from the Russian layout. }
function ReadAsEnglish(const ALower: string): TReading;

{ ALower is a lowercase text as typed on the Russian layout, or converted to
  it from the English layout. }
function ReadAsRussian(const ALower: string): TReading;

{ ATypedLower is a lowercase text typed on the English layout. Its Russian
  reading may leave any of the edge keys that type Russian letters as the
  punctuation they are on the English layout ("[ghbdtn]" is "[привет]", not
  "хприветъ"), at a price. AStart and AStop are the first and the last
  character of ATypedLower that are read as Russian; Core is that part
  converted. }
function ReadAsRussianKeepingEdges(const ATypedLower: string;
  out AStart, AStop: Integer): TReading;

{ AWord is a Russian word as typed, whose last letter is on the key of a
  punctuation mark of the English layout. When the word reads better as a
  shorter word followed by that mark, APunct is the mark: a word switched to
  Russian before its end leaves the mark's key on the Russian layout, where
  it is a letter. A final "х" is left alone: many Russian words end with it. }
function TryRussianTrailingPunctuation(const AWord: string;
  out APunct: Char): Boolean;

implementation

uses
  System.SysUtils,
  Ghbdtn.LetterModel,
  Ghbdtn.WordFreq;

const
  // What it costs the English reading to treat an edge key as punctuation.
  // A comma or a period after a word is common. The other keys are rare: the
  // price has to clear the switch margin even when the letters left behind
  // are a very frequent English word ("to`" is "ещё", and "to" costs 24).
  CommaPunctuationCost = 16;
  KeyPunctuationCost = 48;

function ReadWord(const AWord: string; ALang: TLangKind): TReading;
var
  Listed: Integer;
begin
  Result.Valid := AWord <> '';
  Result.Core := AWord;
  Result.Listed := False;
  Result.Cost := LetterModelCost(AWord, ALang);
  Listed := WordCost(AWord, ALang);
  if Listed >= 0 then
  begin
    Result.Listed := True;
    if Listed < Result.Cost then
      Result.Cost := Listed;
  end;
  Result.PlainCost := Result.Cost;
end;

function PunctuationCost(AChar: Char): Integer;
begin
  if (AChar = ',') or (AChar = '.') then
    Result := CommaPunctuationCost
  else
    Result := KeyPunctuationCost;
end;

function ReadAsRussian(const ALower: string): TReading;
begin
  Result := ReadWord(ALower, lkRU);
end;

function ReadAsRussianKeepingEdges(const ATypedLower: string;
  out AStart, AStop: Integer): TReading;
var
  First, Last, Start, Stop, I, Trimmed: Integer;
  Candidate: TReading;
begin
  AStart := 1;
  AStop := Length(ATypedLower);
  Result := ReadAsRussian(ConvertStringSwap(ATypedLower).ToLower);
  First := 1;
  Last := Length(ATypedLower);
  while (First <= Last) and IsRussianLetterKey(ATypedLower[First]) do
    Inc(First);
  while (Last >= First) and IsRussianLetterKey(ATypedLower[Last]) do
    Dec(Last);
  if First > Last then
    Exit;
  for Start := 1 to First do
    for Stop := Last to Length(ATypedLower) do
    begin
      if (Start = 1) and (Stop = Length(ATypedLower)) then
        Continue;
      Candidate := ReadAsRussian(ConvertStringSwap(
        Copy(ATypedLower, Start, Stop - Start + 1)).ToLower);
      Trimmed := 0;
      for I := 1 to Start - 1 do
        Inc(Trimmed, PunctuationCost(ATypedLower[I]));
      for I := Stop + 1 to Length(ATypedLower) do
        Inc(Trimmed, PunctuationCost(ATypedLower[I]));
      Inc(Candidate.Cost, Trimmed);
      if Candidate.Cost < Result.Cost then
      begin
        Result := Candidate;
        AStart := Start;
        AStop := Stop;
      end;
    end;
end;

function TryRussianTrailingPunctuation(const AWord: string;
  out APunct: Char): Boolean;
var
  Stem: string;
  Whole: TReading;
  I: Integer;
begin
  Result := False;
  APunct := #0;
  // A one- or two-letter stem is too short to tell "нож" from "но;".
  if Length(AWord) < 4 then
    Exit;
  case AWord[Length(AWord)] of
    'б': APunct := ',';
    'Б': APunct := '<';
    'ю': APunct := '.';
    'Ю': APunct := '>';
    'ж': APunct := ';';
    'Ж': APunct := ':';
    'ъ': APunct := ']';
    'Ъ': APunct := '}';
    'э': APunct := '''';
    'Э': APunct := '"';
    'ё': APunct := '`';
    'Ё': APunct := '~';
    'Х': APunct := '{';
  else
    Exit;
  end;
  for I := 1 to Length(AWord) do
    if not (((AWord[I] >= 'А') and (AWord[I] <= 'я')) or (AWord[I] = 'Ё') or
            (AWord[I] = 'ё')) then
      Exit;
  Whole := ReadAsRussian(AWord.ToLower);
  if Whole.Listed then
    Exit;
  Stem := Copy(AWord, 1, Length(AWord) - 1);
  Result := ReadAsRussian(Stem.ToLower).Cost + PunctuationCost(APunct) <
    Whole.Cost;
end;

function ReadAsEnglish(const ALower: string): TReading;
var
  First, Last, Start, Stop, I: Integer;
  Candidate: TReading;
  Trimmed: Integer;
begin
  Result := Default(TReading);
  First := 1;
  Last := Length(ALower);
  while (First <= Last) and IsRussianLetterKey(ALower[First]) do
    Inc(First);
  while (Last >= First) and IsRussianLetterKey(ALower[Last]) do
    Dec(Last);
  if First > Last then
    Exit;
  // Start and Stop run over the edge keys: the text between them is read,
  // the keys outside are punctuation.
  for Start := 1 to First do
    for Stop := Last to Length(ALower) do
    begin
      Candidate := ReadWord(Copy(ALower, Start, Stop - Start + 1), lkEN);
      Trimmed := 0;
      for I := 1 to Start - 1 do
        Inc(Trimmed, PunctuationCost(ALower[I]));
      for I := Stop + 1 to Length(ALower) do
        Inc(Trimmed, PunctuationCost(ALower[I]));
      Inc(Candidate.Cost, Trimmed);
      if (not Result.Valid) or (Candidate.Cost < Result.Cost) then
        Result := Candidate;
    end;
end;

end.
