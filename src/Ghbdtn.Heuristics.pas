unit Ghbdtn.Heuristics;

interface

uses
  Ghbdtn.Layout;

function IsCommonRussianWord(const S: string): Boolean;
function IsCommonEnglishWord(const S: string): Boolean;
function IsFileExtension(const ALower: string): Boolean;

{ Whether a lowercase word has a vowel of the language; a word without one
  is an abbreviation or noise, not a word of that language. }
function HasVowel(const ALower: string; ALang: TLangKind): Boolean;

type
  TScoreParts = record
    Total: Integer;
    NGrams: Integer;
    Dictionary: Integer;
  end;

function ExplainEnglish(const ALower: string): TScoreParts;
function ExplainRussian(const ALower: string): TScoreParts;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  Ghbdtn.LetterModel;

const
  RuVowels = 'аеёиоуыэюяАЕЁИОУЫЭЮЯ';

  CommonFileExtensions: array[0..61] of string = (
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'csv',
    'json', 'xml', 'html', 'htm', 'css', 'js', 'zip', 'rar', 'exe', 'dll',
    'msi', 'bat', 'cmd', 'png', 'jpg', 'jpeg', 'gif', 'bmp', 'svg', 'ico',
    'mp3', 'mp4', 'avi', 'mkv', 'wav', 'iso', 'log', 'ini', 'cfg', 'md',
    'py', 'pas', 'dfm', 'dpr', 'dproj', 'cpp', 'java', 'sql', 'bak', 'tmp',
    'lnk', 'odt', 'ods', 'tar', 'gz', 'yml', 'yaml', 'toml', 'sh', 'ps',
    'rs', 'go'
  );

  { Everyday Russian words, including the one- and two-letter function words.
    A word is omitted when its English-layout spelling is itself a common
    English word. }
  CommonRuWords: array of string = [
    'привет', 'как', 'дела', 'что', 'очень', 'мне', 'тебе', 'меня', 'тебя',
    'кто', 'где', 'когда', 'зачем', 'почему', 'так', 'кому', 'друг', 'день',
    'добро', 'человек', 'знает', 'значит', 'может', 'можно', 'нет', 'если',
    'только', 'много', 'просто', 'другой', 'новый', 'один', 'пункт', 'текст',
    'слово', 'строка', 'набор', 'после', 'сейчас', 'русский', 'английский',
    'спасибо', 'это', 'для', 'читается', 'что-то', 'как-то', 'чо', 'чё',
    'и', 'о', 'в', 'к', 'с', 'я', 'а', 'у', 'не', 'по', 'на', 'за', 'от', 'до',
    'из', 'ну', 'ли', 'то', 'но', 'ты', 'че',
    'он', 'она', 'мы', 'вы', 'они', 'мой', 'моя', 'мое', 'моё', 'твой', 'наш',
    'ваш', 'его', 'ее', 'её', 'их', 'нас', 'вас', 'этот', 'эта', 'эти', 'того',
    'тут', 'там', 'здесь', 'туда', 'сюда', 'уже', 'еще', 'ещё', 'тоже',
    'всегда', 'никогда', 'сегодня', 'завтра', 'вчера', 'потом', 'тогда',
    'был', 'была', 'было', 'были', 'будет', 'есть', 'могу', 'надо', 'нужно',
    'хочу', 'хотел', 'хорошо', 'плохо', 'большой', 'маленький', 'люди',
    'работа', 'дом', 'время', 'жизнь', 'город', 'страна', 'место', 'мама',
    'папа', 'сын', 'дочь', 'сказать', 'сказал', 'говорит', 'говорить', 'знаю',
    'знаешь', 'думаю', 'вижу', 'пока', 'пожалуйста', 'все', 'всего', 'потому',
    'поэтому', 'чтобы', 'или', 'перед', 'между', 'через', 'старый', 'хороший',
    'первый', 'два', 'три', 'года', 'ночь', 'утро', 'вечер', 'вопрос', 'ответ',
    'вот', 'который', 'которая', 'которые', 'куда', 'откуда', 'ничего', 'никто',
    'делать', 'сделать', 'работать', 'жить', 'идти', 'смотреть', 'видеть',
    'хотеть', 'любить', 'понимать', 'думать', 'ждать', 'давать', 'взять',
    'стать', 'будто', 'хотя', 'ведь', 'свой', 'своя', 'свои', 'сам', 'сама',
    'такой', 'такая', 'такие', 'каждый', 'больше', 'меньше', 'лучше', 'снова',
    'опять', 'почти', 'совсем', 'конечно', 'кажется', 'сказала', 'сказали',
    'утром', 'вечером', 'ночью', 'дома', 'женщина', 'мужчина', 'семья',
    'друзья', 'конец', 'начало', 'часть', 'сторона', 'рука', 'руки', 'глаза',
    'голова', 'школа', 'книга', 'улица', 'дорога', 'машина', 'вода', 'минута',
    'неделя', 'месяц', 'лето', 'зима', 'осень', 'весна', 'солнце', 'дождь',
    'снег', 'ветер', 'море', 'река', 'небо', 'земля', 'белый', 'черный',
    'чёрный', 'красный', 'синий', 'зеленый', 'зелёный', 'молодой', 'добрый',
    'быстрый', 'высокий', 'последний', 'следующий', 'слишком',
    'иду', 'идёт', 'идет', 'идём', 'идем', 'идут', 'шёл', 'шел', 'шла', 'шло',
    'шли', 'людей', 'людям', 'людьми', 'человека', 'ребёнок', 'ребенок',
    'дети', 'детей', 'детям', 'лучше', 'лучший'
  ];

  CommonEnWords: array[0..195] of string = (
    'hello', 'hi', 'hey', 'ok', 'okay', 'bye', 'thanks', 'please', 'sorry', 'yes', 'no',
    'world', 'test', 'demo', 'info', 'link', 'code', 'page', 'user', 'file', 'view',
    'http', 'https', 'ftp',
    'text', 'help', 'site', 'mail', 'call', 'send', 'save', 'open', 'exit', 'stop',
    'play', 'game', 'work', 'home', 'news', 'post', 'list', 'item', 'menu', 'show',
    'hide', 'font', 'size', 'type', 'data', 'name', 'main', 'form', 'unit', 'pass',
    'fail', 'true', 'false', 'null', 'void', 'byte', 'char', 'int', 'long', 'float',
    'double', 'bool', 'class', 'struct', 'const', 'var', 'function', 'procedure',
    'string', 'integer', 'boolean', 'case', 'then', 'else', 'from', 'into', 'select',
    'where', 'insert', 'update', 'delete', 'create', 'drop', 'alter', 'table', 'the',
    'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'i', 'it', 'for', 'not', 'on',
    'with', 'he', 'as', 'you', 'do', 'at', 'this', 'but', 'his', 'by', 'they', 'we',
    'say', 'her', 'she', 'or', 'an', 'will', 'my', 'one', 'all', 'would', 'there',
    'their', 'what', 'so', 'up', 'out', 'if', 'about', 'who', 'get', 'which', 'go',
    'me', 'when', 'make', 'can', 'like', 'time', 'just', 'him', 'know', 'take',
    'people', 'year', 'your', 'good', 'some', 'could', 'them', 'see', 'other', 'than',
    'then', 'now', 'look', 'only', 'come', 'its', 'over', 'think', 'also', 'back',
    'after', 'use', 'two', 'how', 'our', 'first', 'well', 'way', 'even', 'new', 'want',
    'because', 'any', 'these', 'give', 'day', 'most', 'us', 'is', 'are', 'was', 'were',
    'am', 'been', 'being', 'has', 'had', 'did', 'does'
  );

  DictionaryScore = 10;

var
  GFileExtensions: TArray<string>;
  GEnglishWords: TArray<string>;
  GRussianWords: TArray<string>;

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

function IsCommonRussianWord(const S: string): Boolean;
begin
  Result := ContainsSorted(GRussianWords, S);
end;

function IsCommonEnglishWord(const S: string): Boolean;
begin
  Result := ContainsSorted(GEnglishWords, S);
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

function ExplainEnglish(const ALower: string): TScoreParts;
begin
  Result := Default(TScoreParts);
  Result.NGrams := LetterModelScore(ALower, lkEN);
  if IsCommonEnglishWord(ALower) then
    Result.Dictionary := DictionaryScore;
  Result.Total := Result.NGrams + Result.Dictionary;
end;

function ExplainRussian(const ALower: string): TScoreParts;
begin
  Result := Default(TScoreParts);
  Result.NGrams := LetterModelScore(ALower, lkRU);
  if IsCommonRussianWord(ALower) then
    Result.Dictionary := DictionaryScore;
  Result.Total := Result.NGrams + Result.Dictionary;
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
  GEnglishWords := SortUnique(CommonEnWords);
  GRussianWords := SortUnique(CommonRuWords);

end.
