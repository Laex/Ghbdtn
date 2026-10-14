unit Ghbdtn.Heuristics;

interface

uses
  Ghbdtn.Layout;

{ One- and two-letter Russian function words ("и", "не", "на"). Longer words
  are judged by the letter model and the word lists. }
function IsRussianFunctionWord(const S: string): Boolean;

{ A word of the English frequency list. }
function IsCommonEnglishWord(const S: string): Boolean;
function IsFileExtension(const ALower: string): Boolean;

{ Whether a lowercase word has a vowel of the language; a word without one
  is an abbreviation or noise, not a word of that language. }
function HasVowel(const ALower: string; ALang: TLangKind): Boolean;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  Ghbdtn.WordFreq;

const
  RuVowels = 'аеёиоуыэюяАЕЁИОУЫЭЮЯ';

  // Above this cost a listed word is too rare to tell a typing slip from a
  // real word.
  CommonEnglishCostLimit = 60;

  CommonFileExtensions: array[0..61] of string = (
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'csv',
    'json', 'xml', 'html', 'htm', 'css', 'js', 'zip', 'rar', 'exe', 'dll',
    'msi', 'bat', 'cmd', 'png', 'jpg', 'jpeg', 'gif', 'bmp', 'svg', 'ico',
    'mp3', 'mp4', 'avi', 'mkv', 'wav', 'iso', 'log', 'ini', 'cfg', 'md',
    'py', 'pas', 'dfm', 'dpr', 'dproj', 'cpp', 'java', 'sql', 'bak', 'tmp',
    'lnk', 'odt', 'ods', 'tar', 'gz', 'yml', 'yaml', 'toml', 'sh', 'ps',
    'rs', 'go'
  );

  // A function word is omitted when its English-layout spelling is itself a
  // common English word.
  RussianFunctionWords: array of string = [
    'и', 'о', 'в', 'к', 'с', 'я', 'а', 'у', 'не', 'по', 'на', 'за', 'от', 'до',
    'из', 'ну', 'ли', 'то', 'но', 'ты', 'он', 'мы', 'вы', 'да', 'бы', 'же',
    'ни', 'об', 'во', 'со', 'им', 'их', 'ее', 'её', 'та', 'те', 'ту', 'че',
    'чо', 'чё'
  ];

var
  GFileExtensions: TArray<string>;
  GFunctionWords: TArray<string>;

function StringOrder(const Left, Right: string): Integer;
begin
  Result := CompareStr(Left, Right);
end;

function SortUnique(const AItems: array of string): TArray<string>;
var
  I, N: Integer;
begin
  SetLength(Result, Length(AItems));
  for I := 0 to High(AItems) do
    Result[I] := AItems[I];
  if Length(Result) = 0 then
    Exit;
  TArray.Sort<string>(Result, TComparer<string>.Construct(StringOrder));
  N := 1;
  for I := 1 to High(Result) do
    if Result[I] <> Result[N - 1] then
    begin
      Result[N] := Result[I];
      Inc(N);
    end;
  SetLength(Result, N);
end;

function ContainsSorted(const AItems: TArray<string>; const AValue: string): Boolean;
var
  LowIndex, HighIndex, Mid, Cmp: Integer;
begin
  LowIndex := 0;
  HighIndex := High(AItems);
  while LowIndex <= HighIndex do
  begin
    Mid := (LowIndex + HighIndex) div 2;
    Cmp := CompareStr(AItems[Mid], AValue);
    if Cmp < 0 then
      LowIndex := Mid + 1
    else if Cmp > 0 then
      HighIndex := Mid - 1
    else
      Exit(True);
  end;
  Result := False;
end;

function IsVowelRU(C: Char): Boolean;
begin
  Result := Pos(C, RuVowels) > 0;
end;

function IsFileExtension(const ALower: string): Boolean;
begin
  Result := ContainsSorted(GFileExtensions, ALower);
end;

function IsRussianFunctionWord(const S: string): Boolean;
begin
  Result := ContainsSorted(GFunctionWords, S);
end;

function IsCommonEnglishWord(const S: string): Boolean;
var
  Cost: Integer;
begin
  Cost := WordCost(S, lkEN);
  Result := (Cost >= 0) and (Cost <= CommonEnglishCostLimit);
end;

function HasEnglishVowel(const S: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if CharInSet(S[I], ['a', 'e', 'i', 'o', 'u', 'y']) then
      Exit(True);
  Result := False;
end;

function HasRussianVowel(const S: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if IsVowelRU(S[I]) then
      Exit(True);
  Result := False;
end;

function HasVowel(const ALower: string; ALang: TLangKind): Boolean;
begin
  if ALang = lkEN then
    Result := HasEnglishVowel(ALower)
  else
    Result := HasRussianVowel(ALower);
end;

initialization
  GFileExtensions := SortUnique(CommonFileExtensions);
  GFunctionWords := SortUnique(RussianFunctionWords);

end.
