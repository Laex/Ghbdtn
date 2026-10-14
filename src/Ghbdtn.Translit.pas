unit Ghbdtn.Translit;

interface

type
  TTranslitDirection = (tdNone, tdToLatin, tdToCyrillic);

{ Russian text to Latin letters: "Щука" -> "Shchuka". The soft sign becomes an
  apostrophe and the hard sign two apostrophes, so FromTranslit can restore
  them. Letters in other alphabets, digits, punctuation and line breaks stay
  as they are. }
function ToTranslit(const AText: string): string;

{ Latin letters to Russian text: "Shchuka" -> "Щука". Longer groups win over
  single letters (shch, zh, kh, ts, ch, sh, yu, ya, yo, ye). "y" after a vowel
  is "й", otherwise "ы"; "e" at the start of a word is "э". }
function FromTranslit(const AText: string): string;

function ApplyTranslit(const AText: string;
  ADirection: TTranslitDirection): string;

implementation

uses
  System.SysUtils,
  System.Character;

const
  CyrillicLower = 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя';
  LatinForCyrillic: array[0..32] of string = (
    'a', 'b', 'v', 'g', 'd', 'e', 'yo', 'zh', 'z', 'i', 'y', 'k', 'l', 'm',
    'n', 'o', 'p', 'r', 's', 't', 'u', 'f', 'kh', 'ts', 'ch', 'sh', 'shch',
    '''''', 'y', '''', 'e', 'yu', 'ya');

  LatinPairs: array[0..11] of string = (
    'zh', 'kh', 'ts', 'ch', 'sh', 'yu', 'ya', 'yo', 'ye', 'ju', 'ja', 'jo');
  CyrillicForPairs: array[0..11] of string = (
    'ж', 'х', 'ц', 'ч', 'ш', 'ю', 'я', 'ё', 'е', 'ю', 'я', 'ё');
  CyrillicForLatin: array[0..25] of string = (
    'а', 'б', 'ц', 'д', 'е', 'ф', 'г', 'х', 'и', 'й', 'к', 'л', 'м', 'н',
    'о', 'п', 'к', 'р', 'с', 'т', 'у', 'в', 'в', 'кс', 'ы', 'з');
  LatinVowels = 'aeiouy';

function IsLatinLetter(C: Char): Boolean;
begin
  Result := CharInSet(C, ['a'..'z', 'A'..'Z']);
end;

function IsCyrillicLetter(C: Char): Boolean;
begin
  Result := Pos(C.ToLower, CyrillicLower) > 0;
end;

function ToTranslit(const AText: string): string;
var
  I, Index: Integer;
  C: Char;
  Part: string;
  AllCaps: Boolean;
  Builder: TStringBuilder;
begin
  Builder := TStringBuilder.Create;
  try
    for I := 1 to Length(AText) do
    begin
      C := AText[I];
      Index := Pos(C.ToLower, CyrillicLower);
      if Index = 0 then
      begin
        Builder.Append(C);
        Continue;
      end;
      Part := LatinForCyrillic[Index - 1];
      if C.IsUpper and (Part <> '''') and (Part <> '''''') then
      begin
        // A capital inside a run of capitals gives a fully capitalized
        // group (ЖУК -> ZHUK); a lone capital only the first letter (Жук).
        AllCaps := ((I < Length(AText)) and AText[I + 1].IsUpper and
            IsCyrillicLetter(AText[I + 1])) or
          ((I > 1) and AText[I - 1].IsUpper and IsCyrillicLetter(AText[I - 1]));
        if AllCaps then
          Part := Part.ToUpper
        else
          Part := Part.Substring(0, 1).ToUpper + Part.Substring(1);
      end;
      Builder.Append(Part);
    end;
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function FromTranslit(const AText: string): string;
var
  I, J, Len: Integer;
  C: Char;
  Lower, Token, Part: string;
  Upper, Done: Boolean;
  Builder: TStringBuilder;

  function PreviousIsLatin: Boolean;
  begin
    Result := (I > 1) and IsLatinLetter(AText[I - 1]);
  end;

  function PreviousIsVowel: Boolean;
  begin
    Result := (I > 1) and (Pos(AText[I - 1].ToLower, LatinVowels) > 0);
  end;

  function WithCase(const ACyrillic: string; AUpperFirst: Boolean): string;
  begin
    if AUpperFirst then
      Result := ACyrillic.Substring(0, 1).ToUpper + ACyrillic.Substring(1)
    else
      Result := ACyrillic;
  end;

begin
  Builder := TStringBuilder.Create;
  try
    Len := Length(AText);
    I := 1;
    while I <= Len do
    begin
      C := AText[I];
      if C = '''' then
      begin
        if (I < Len) and (AText[I + 1] = '''') and PreviousIsLatin then
        begin
          Builder.Append('ъ');
          Inc(I, 2);
          Continue;
        end;
        if PreviousIsLatin then
          Builder.Append('ь')
        else
          Builder.Append(C);
        Inc(I);
        Continue;
      end;
      if not IsLatinLetter(C) then
      begin
        Builder.Append(C);
        Inc(I);
        Continue;
      end;
      Upper := C.IsUpper;
      Lower := C.ToLower;
      if (I + 3 <= Len) and SameText(Copy(AText, I, 4), 'shch') then
      begin
        Builder.Append(WithCase('щ', Upper));
        Inc(I, 4);
        Continue;
      end;
      Done := False;
      if I < Len then
      begin
        Token := Lower + AText[I + 1].ToLower;
        for J := Low(LatinPairs) to High(LatinPairs) do
          if Token = LatinPairs[J] then
          begin
            Builder.Append(WithCase(CyrillicForPairs[J], Upper));
            Inc(I, 2);
            Done := True;
            Break;
          end;
      end;
      if Done then
        Continue;
      Part := CyrillicForLatin[Ord(Lower[1]) - Ord('a')];
      if Lower = 'c' then
      begin
        if (I < Len) and (Pos(AText[I + 1].ToLower, 'eiy') > 0) then
          Part := 'ц'
        else
          Part := 'к';
      end
      else if Lower = 'e' then
      begin
        // The apostrophe is a sign inside a word (pod''ezd), not its start.
        if not (PreviousIsLatin or ((I > 1) and (AText[I - 1] = ''''))) then
          Part := 'э';
      end
      else if Lower = 'y' then
      begin
        if PreviousIsVowel then
          Part := 'й'
        else
          Part := 'ы';
      end;
      Builder.Append(WithCase(Part, Upper));
      Inc(I);
    end;
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function ApplyTranslit(const AText: string;
  ADirection: TTranslitDirection): string;
begin
  case ADirection of
    tdToLatin: Result := ToTranslit(AText);
    tdToCyrillic: Result := FromTranslit(AText);
  else
    Result := AText;
  end;
end;

end.
