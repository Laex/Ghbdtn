unit Ghbdtn.Learning;

interface

type
  TLearningAction = (
    laRejectWeak,
    laRejectStrong,
    laAccept,
    laManualSwitch
  );

  TLearningEntry = record
    Reject: Integer;
    Prefer: Integer;
    Stamp: Integer;
  end;

const
  LearningPromotionCount = 3;
  LearningScoreCap = 12;
  MaxLearningEntries = 256;

function ApplyLearningAction(const AEntry: TLearningEntry;
  AAction: TLearningAction): TLearningEntry;
function LearningBlocksSwitch(const AEntry: TLearningEntry): Boolean;
function LearningForcesSwitch(const AEntry: TLearningEntry): Boolean;
function LearningEntryWeight(const AEntry: TLearningEntry): Integer;
function BackspaceLearningAction(AErased, AConvertedLength: Integer;
  out AAction: TLearningAction): Boolean;
function LearnedFormsMatch(const ALeft, ARight: string): Boolean;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Ghbdtn.Layout;

function ClampLearningScore(AValue: Integer): Integer;
begin
  if AValue < 0 then
    Exit(0);
  if AValue > LearningScoreCap then
    Exit(LearningScoreCap);
  Result := AValue;
end;

function ApplyLearningAction(const AEntry: TLearningEntry;
  AAction: TLearningAction): TLearningEntry;
begin
  Result := AEntry;
  case AAction of
    laRejectWeak:
      begin
        Result.Reject := ClampLearningScore(Result.Reject + 1);
        if Result.Prefer > 0 then
          Dec(Result.Prefer);
      end;
    laRejectStrong:
      begin
        // The first explicit undo reaches the promotion line. Later undos
        // keep raising it, up to the cap, so a repeated correction outlives
        // a one-off entry when the table is full.
        if Result.Reject < LearningPromotionCount then
          Result.Reject := LearningPromotionCount
        else
          Result.Reject := ClampLearningScore(Result.Reject + 1);
        Result.Prefer := 0;
      end;
    laAccept:
      if Result.Reject > 0 then
        Dec(Result.Reject);
    laManualSwitch:
      begin
        if Result.Prefer < LearningPromotionCount then
          Result.Prefer := LearningPromotionCount
        else
          Result.Prefer := ClampLearningScore(Result.Prefer + 1);
        Result.Reject := 0;
      end;
  end;
end;

function LearningBlocksSwitch(const AEntry: TLearningEntry): Boolean;
begin
  Result := (AEntry.Reject >= LearningPromotionCount) and
    (AEntry.Reject > AEntry.Prefer);
end;

function LearningForcesSwitch(const AEntry: TLearningEntry): Boolean;
begin
  Result := (AEntry.Prefer >= LearningPromotionCount) and
    (AEntry.Prefer > AEntry.Reject);
end;

function LearningEntryWeight(const AEntry: TLearningEntry): Integer;
begin
  Result := AEntry.Reject + AEntry.Prefer;
end;

function BackspaceLearningAction(AErased, AConvertedLength: Integer;
  out AAction: TLearningAction): Boolean;
begin
  // Deleting one or two letters is an edit. Deleting the whole fix is an
  // explicit rejection. Deleting at least half of a longer fix, and at least
  // three letters, is a weaker rejection.
  AAction := laRejectWeak;
  Result := False;
  if (AConvertedLength <= 0) or (AErased <= 0) then
    Exit;
  if AErased >= AConvertedLength then
  begin
    AAction := laRejectStrong;
    Exit(True);
  end;
  if (AErased >= 3) and (AErased * 2 >= AConvertedLength) then
    Result := True;
end;

const
  MinStemLength = 4;
  RuSuffixSource: array of string = [
    'ами', 'ями', 'ого', 'ему', 'ому', 'ыми', 'ими',
    'ах', 'ях', 'ов', 'ев', 'ий', 'ый', 'ой', 'ая', 'яя', 'ое', 'ее',
    'ую', 'юю', 'ые', 'ие', 'ам', 'ям', 'ом', 'ем',
    'а', 'я', 'ы', 'и', 'у', 'ю', 'е', 'о', 'ь'
  ];

var
  GRuSuffixes: TArray<string>;
  GEnSuffixes: TArray<string>;
  GFamily: TDictionary<string, Integer>;
  GFamilySeq: Integer;

function SameFamily(const ALeft, ARight: string): Boolean; forward;

function EndsWithWord(const AWord, ASuffix: string): Boolean;
begin
  Result := (ASuffix <> '') and (Length(ASuffix) < Length(AWord)) and
    (Copy(AWord, Length(AWord) - Length(ASuffix) + 1, Length(ASuffix)) = ASuffix);
end;

function IsCyrillicLearningWord(const AWord: string): Boolean;
var
  I: Integer;
  C: Char;
begin
  Result := False;
  for I := 1 to Length(AWord) do
  begin
    C := AWord[I];
    if CharInSet(C, ['a'..'z']) then
      Exit(False);
    if ((C >= 'а') and (C <= 'я')) or (C = 'ё') then
      Result := True;
  end;
end;

function IsLatinLearningWord(const AWord: string): Boolean;
var
  I: Integer;
  C: Char;
begin
  Result := False;
  for I := 1 to Length(AWord) do
  begin
    C := AWord[I];
    if ((C >= 'а') and (C <= 'я')) or (C = 'ё') then
      Exit(False);
    if CharInSet(C, ['a'..'z']) then
      Result := True;
  end;
end;

function WordStem(const ALower: string): string;
var
  Suffixes: TArray<string>;
  Suffix: string;
begin
  Result := ALower;
  if IsCyrillicLearningWord(ALower) then
    Suffixes := GRuSuffixes
  else if IsLatinLearningWord(ALower) then
    Suffixes := GEnSuffixes
  else
    Exit;
  for Suffix in Suffixes do
    if EndsWithWord(ALower, Suffix) and
       (Length(ALower) - Length(Suffix) >= MinStemLength) then
      Exit(Copy(ALower, 1, Length(ALower) - Length(Suffix)));
end;

function LearnedFormsMatch(const ALeft, ARight: string): Boolean;
var
  Left, Right, LeftStem, RightStem: string;
begin
  Left := ALeft.ToLower;
  Right := ARight.ToLower;
  if Left = Right then
    Exit(True);
  LeftStem := WordStem(Left);
  RightStem := WordStem(Right);
  Result := (Length(LeftStem) >= MinStemLength) and (LeftStem = RightStem) and
    ((LeftStem <> Left) or (RightStem <> Right));
  if not Result then
    Result := SameFamily(Left, Right);
end;

function SameFamily(const ALeft, ARight: string): Boolean;
var
  LeftId, RightId: Integer;
begin
  Result := (GFamily <> nil) and
    GFamily.TryGetValue(ALeft, LeftId) and
    GFamily.TryGetValue(ARight, RightId) and
    (LeftId = RightId);
end;

procedure PrepareSuffixes;
var
  I, J: Integer;
  Swap: string;
begin
  SetLength(GRuSuffixes, Length(RuSuffixSource));
  SetLength(GEnSuffixes, Length(RuSuffixSource));
  for I := 0 to High(RuSuffixSource) do
  begin
    GRuSuffixes[I] := RuSuffixSource[I];
    GEnSuffixes[I] := ConvertStringSwap(RuSuffixSource[I]);
  end;
  for I := 1 to High(GRuSuffixes) do
  begin
    J := I;
    while (J > 0) and (Length(GRuSuffixes[J]) > Length(GRuSuffixes[J - 1])) do
    begin
      Swap := GRuSuffixes[J];
      GRuSuffixes[J] := GRuSuffixes[J - 1];
      GRuSuffixes[J - 1] := Swap;
      Swap := GEnSuffixes[J];
      GEnSuffixes[J] := GEnSuffixes[J - 1];
      GEnSuffixes[J - 1] := Swap;
      Dec(J);
    end;
  end;
end;

procedure AddFamily(const AWords: array of string);
var
  Id, I: Integer;
  Word, Latin: string;
begin
  Id := GFamilySeq;
  Inc(GFamilySeq);
  for I := 0 to High(AWords) do
  begin
    Word := AWords[I].ToLower;
    GFamily.AddOrSetValue(Word, Id);
    Latin := ConvertStringSwap(Word).ToLower;
    if (Latin <> '') and (Latin <> Word) then
      GFamily.AddOrSetValue(Latin, Id);
  end;
end;

procedure PrepareFamilies;
begin
  GFamily := TDictionary<string, Integer>.Create;
  GFamilySeq := 1;
  AddFamily(['идти', 'иду', 'идёт', 'идет', 'идём', 'идем', 'идут',
    'шёл', 'шел', 'шла', 'шло', 'шли']);
  AddFamily(['человек', 'человека', 'люди', 'людей', 'людям', 'людьми']);
  AddFamily(['ребёнок', 'ребенок', 'ребёнка', 'ребенка', 'дети', 'детей',
    'детям']);
end;

initialization
  PrepareSuffixes;
  PrepareFamilies;

finalization
  GFamily.Free;

end.
