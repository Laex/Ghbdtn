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

implementation

uses
  System.SysUtils,
  Ghbdtn.LetterModel,
  Ghbdtn.WordFreq;

const
  // What it costs the English reading to treat an edge key as punctuation:
  // a comma or a period after a word is common, other keys are rarer.
  CommaPunctuationCost = 16;
  KeyPunctuationCost = 40;

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
