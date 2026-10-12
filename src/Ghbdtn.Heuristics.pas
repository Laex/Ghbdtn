unit Ghbdtn.Heuristics;

interface

function IsKnownEnToRuKey(const ALower: string): Boolean;
function IsShortLayoutWord(const ALower: string): Boolean;

type
  TScoreParts = record
    Total: Integer;
    NGrams: Integer;
    Dictionary: Integer;
    Vowel: Integer;
    Shape: Integer;
    Pairs: Integer;
    ConsonantRun: Integer;
  end;

function ExplainEnglish(const ALower: string): TScoreParts;
function ExplainRussian(const ALower: string): TScoreParts;
function ScoreEnglish(const ALower: string): Integer;
function ScoreRussian(const ALower: string): Integer;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults;

const
  RuVowels = 'аеёиоуыэюяАЕЁИОУЫЭЮЯ';
  RuConsonants = 'бвгджзйклмнпрстфхцчшщБВГДЖЗЙКЛМНПРСТФХЦЧШЩ';

  InvalidRuPairs: array[0..40] of string = (
    'ьь', 'ъъ', 'ыы', 'ьъ', 'ъь', 'ьы', 'ыь', 'ъа', 'ъо', 'ъе', 'ъи', 'ъя', 'ъу', 'ъы', 'ъэ',
    'ьв', 'ьз', 'ьд', 'ьк', 'ьт', 'ьс', 'ьр', 'ьн', 'ьп', 'ьг', 'ьу', 'ьщ', 'ьч', 'ьф', 'ьб',
    'цщ', 'щд', 'щк', 'щз', 'щц', 'щг', 'щп', 'щс', 'щт', 'щб', 'щв'
  );

  CommonEnToRuKeys: array[0..49] of string = (
    'ghbdtn',    // привет
    'rfr',       // как
    'ltkf',      // дела
    'ltkjl',     // делал
    'xnj',       // что
    'jxtym',     // очень
    'vyt',       // мне
    'ntot',      // тебе
    'vtyz',      // меня
    'ntyz',      // тебя
    'rjs',       // кто
    'utl',       // где
    'rjulf',     // когда
    'pfxtv',     // зачем
    'gjxtve',    // почему
    'nfr',       // так
    'nj-ybfeym', // то-нибудь
    'xnj-nj',    // что-то
    'rfr-nj',    // как-то
    'rjve',      // кому
    'lhuh',      // друг
    'lzym',      // день
    'ljfhj',     // добро
    'xtkjdtr',   // человек
    'pyftn',     // знает
    'pyfxbn',    // значит
    'vj;tn',     // может
    'vj;ys',     // можно
    'ytn',       // нет
    'tckb',      // если
    'njkmrj',    // только
    'vjyuj',     // много
    'ghjcnj',    // просто
    'lhujq',     // другой
    'yjdsq',     // новый
    'jlby',      // один
    'geyrn',     // пункт
    'ntrcn',     // текст
    'ckjdj',     // слово
    'cnhjrf',    // строка
    'yf,jh',     // набор
    'gjckt',     // после
    'ctqxpc',    // сейчас
    'heccrbq',   // русский
    'fyukbqcrbq',// английский
    'cgfcb,j',   // спасибо
    'lkz',       // для
    'xbnftncz',  // читается
    'xj',        // чо
    'x`'         // чё
  );

  { Russian function words typed as a whole token on the English layout. }
  ShortEnToRuKeys: array[0..23] of string = (
    'b',   // и
    'j',   // о
    'd',   // в
    'r',   // к
    'c',   // с
    'z',   // я
    'f',   // а
    'e',   // у
    'yt',  // не
    'gj',  // по
    'yf',  // на
    'pf',  // за
    'jn',  // от
    'lj',  // до
    'bp',  // из
    'ye',  // ну
    'kb',  // ли
    'nj',  // то
    'yj',  // но
    'jy',  // он
    'vs',  // мы
    'ds',  // вы
    'ns',  // ты
    'xt'   // че
  );

  { Everyday Russian words. A word is omitted when its English-layout
    spelling is itself a common English word. }
  CommonRuWords: array of string = [
    'привет', 'как', 'дела', 'что', 'очень', 'мне', 'тебе', 'меня', 'тебя',
    'кто', 'где', 'когда', 'зачем', 'почему', 'так', 'кому', 'друг', 'день',
    'добро', 'человек', 'знает', 'значит', 'может', 'можно', 'нет', 'если',
    'только', 'много', 'просто', 'другой', 'новый', 'один', 'пункт', 'текст',
    'слово', 'строка', 'набор', 'после', 'сейчас', 'русский', 'английский',
    'спасибо', 'это', 'для', 'читается',
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

  CommonEnBigrams =
    '|th|he|in|er|an|re|on|at|en|nd|ti|es|or|te|of|ed|is|it|al|ar|' +
    'st|to|nt|ng|se|ha|as|ou|io|le|ve|co|me|de|hi|ri|ro|ic|ne|ea|' +
    'ra|ce|li|ch|ll|be|ma|si|om|ur|';
  CommonEnTrigrams =
    '|the|and|ing|ion|tio|ent|ere|her|for|tha|nth|int|ter|est|ers|' +
    'ati|hat|ate|all|eth|hes|ver|his|oft|ith|sth|oth|res|';
  CommonRuBigrams =
    '|ст|но|ен|то|на|ов|ни|ра|во|ко|ро|по|пр|не|ос|ло|ре|го|ал|' +
    'ли|ве|ка|ла|ер|та|ти|ет|де|те|ль|ес|ил|да|ог|ол|ва|че|ми|' +
    'се|ри|ак|мо|ит|ив|ел|од|ди|ин|пу|ун|нк|кт|ек|кс|ов|';
  CommonRuTrigrams =
    '|про|ост|ени|ого|ать|ста|тор|ова|ние|ено|при|ств|что|это|как|' +
    'дел|вет|рив|енн|кот|оль|ной|его|ива|один|пун|ункт|тек|';

  DictionaryScore = 10;
  VowelScore = 2;
  InvalidStartPenalty = 4;
  InvalidPairPenalty = 4;
  ConsonantRunPenalty = 3;
  NoEnglishShapePenalty = 2;

var
  GEnToRuKeys: TArray<string>;
  GShortEnToRuKeys: TArray<string>;
  GEnglishWords: TArray<string>;
  GRussianWords: TArray<string>;
  GEnglishBigrams: TArray<string>;
  GEnglishTrigrams: TArray<string>;
  GRussianBigrams: TArray<string>;
  GRussianTrigrams: TArray<string>;
  GInvalidRuPairs: TArray<string>;

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

function SortPackedNGrams(const APacked: string): TArray<string>;
var
  Parts: TArray<string>;
  I, N: Integer;
begin
  Parts := APacked.Split(['|']);
  N := 0;
  for I := 0 to High(Parts) do
    if Parts[I] <> '' then
      Inc(N);
  SetLength(Result, N);
  N := 0;
  for I := 0 to High(Parts) do
    if Parts[I] <> '' then
    begin
      Result[N] := Parts[I];
      Inc(N);
    end;
  Result := SortUnique(Result);
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

function IsConsonantRU(C: Char): Boolean;
begin
  Result := Pos(C, RuConsonants) > 0;
end;

function HasConsecutiveConsonantsRU(const S: string; MaxCount: Integer): Boolean;
var
  I, Count: Integer;
begin
  Count := 0;
  for I := 1 to Length(S) do
  begin
    if IsConsonantRU(S[I]) then
    begin
      Inc(Count);
      if Count >= MaxCount then
        Exit(True);
    end
    else
      Count := 0;
  end;
  Result := False;
end;

function StartsWithInvalidRU(const S: string): Boolean;
var
  FirstChar: Char;
begin
  if S = '' then
    Exit(False);
  FirstChar := S[1];
  Result := (FirstChar = 'ь') or (FirstChar = 'Ь') or
            (FirstChar = 'ъ') or (FirstChar = 'Ъ') or
            (FirstChar = 'ы') or (FirstChar = 'Ы');
end;

function HasInvalidRuPairs(const S: string): Boolean;
var
  I: Integer;
  LowerS: string;
begin
  LowerS := S.ToLower;
  for I := 1 to Length(LowerS) - 1 do
    if ContainsSorted(GInvalidRuPairs, Copy(LowerS, I, 2)) then
      Exit(True);
  Result := False;
end;

function IsKnownEnToRuKey(const ALower: string): Boolean;
begin
  Result := ContainsSorted(GEnToRuKeys, ALower);
end;

function IsShortLayoutWord(const ALower: string): Boolean;
begin
  Result := ContainsSorted(GShortEnToRuKeys, ALower);
end;

function IsCommonEnglishWord(const S: string): Boolean;
begin
  Result := ContainsSorted(GEnglishWords, S);
end;

function IsCommonRussianWord(const S: string): Boolean;
begin
  Result := ContainsSorted(GRussianWords, S);
end;

function HasStrongEnglishVowel(const S: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if CharInSet(S[I], ['a', 'e', 'i', 'o', 'u']) then
      Exit(True);
  Result := False;
end;

function ScoreNGrams(const S: string;
  const ABigrams, ATrigrams: TArray<string>): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(S) - 1 do
    if ContainsSorted(ABigrams, Copy(S, I, 2)) then
      Inc(Result);
  for I := 1 to Length(S) - 2 do
    if ContainsSorted(ATrigrams, Copy(S, I, 3)) then
      Inc(Result, 2);
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

function HasConsecutiveConsonantsEN(const S: string; MaxCount: Integer): Boolean;
var
  I, Count: Integer;
begin
  Count := 0;
  for I := 1 to Length(S) do
  begin
    if CharInSet(S[I], ['a'..'z']) and
       not CharInSet(S[I], ['a', 'e', 'i', 'o', 'u', 'y']) then
    begin
      Inc(Count);
      if Count >= MaxCount then
        Exit(True);
    end
    else
      Count := 0;
  end;
  Result := False;
end;

function ExplainEnglish(const ALower: string): TScoreParts;
begin
  Result := Default(TScoreParts);
  Result.NGrams := ScoreNGrams(ALower, GEnglishBigrams, GEnglishTrigrams);
  if IsCommonEnglishWord(ALower) then
    Result.Dictionary := DictionaryScore;
  // 'y' alone is a weak English signal - Russian 'н' is typed as Y.
  if HasStrongEnglishVowel(ALower) then
    Result.Vowel := VowelScore
  else if HasEnglishVowel(ALower) and (Result.NGrams > 0) then
    Result.Vowel := 1;
  if (Result.NGrams = 0) and (Length(ALower) >= 4) and
     not IsCommonEnglishWord(ALower) then
    Result.Shape := -NoEnglishShapePenalty;
  if HasConsecutiveConsonantsEN(ALower, 4) then
    Result.ConsonantRun := -ConsonantRunPenalty;
  Result.Total := Result.NGrams + Result.Dictionary + Result.Vowel +
    Result.Shape + Result.Pairs + Result.ConsonantRun;
end;

function ExplainRussian(const ALower: string): TScoreParts;
begin
  Result := Default(TScoreParts);
  Result.NGrams := ScoreNGrams(ALower, GRussianBigrams, GRussianTrigrams);
  if IsCommonRussianWord(ALower) then
    Result.Dictionary := DictionaryScore;
  if HasRussianVowel(ALower) then
    Result.Vowel := VowelScore;
  if StartsWithInvalidRU(ALower) then
    Result.Shape := -InvalidStartPenalty;
  if HasInvalidRuPairs(ALower) then
    Result.Pairs := -InvalidPairPenalty;
  if HasConsecutiveConsonantsRU(ALower, 4) then
    Result.ConsonantRun := -ConsonantRunPenalty;
  Result.Total := Result.NGrams + Result.Dictionary + Result.Vowel +
    Result.Shape + Result.Pairs + Result.ConsonantRun;
end;

function ScoreEnglish(const ALower: string): Integer;
begin
  Result := ExplainEnglish(ALower).Total;
end;

function ScoreRussian(const ALower: string): Integer;
begin
  Result := ExplainRussian(ALower).Total;
end;

initialization
  GEnToRuKeys := SortUnique(CommonEnToRuKeys);
  GShortEnToRuKeys := SortUnique(ShortEnToRuKeys);
  GEnglishWords := SortUnique(CommonEnWords);
  GRussianWords := SortUnique(CommonRuWords);
  GEnglishBigrams := SortPackedNGrams(CommonEnBigrams);
  GEnglishTrigrams := SortPackedNGrams(CommonEnTrigrams);
  GRussianBigrams := SortPackedNGrams(CommonRuBigrams);
  GRussianTrigrams := SortPackedNGrams(CommonRuTrigrams);
  GInvalidRuPairs := SortUnique(InvalidRuPairs);

end.
