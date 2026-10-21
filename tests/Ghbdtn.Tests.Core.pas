unit Ghbdtn.Tests.Core;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.SyncObjs,
  DUnitX.TestFramework,
  Ghbdtn.Layout,
  Ghbdtn.Analyzer,
  Ghbdtn.Reading,
  Ghbdtn.LetterModel,
  Ghbdtn.WordFreq,
  Ghbdtn.Buffer,
  Ghbdtn.Clipboard,
  Ghbdtn.Colors,
  Ghbdtn.FieldWatch,
  Ghbdtn.Fullscreen,
  Ghbdtn.Translit,
  Ghbdtn.KeyState,
  Ghbdtn.Learning,
  Ghbdtn.Phrase,
  Ghbdtn.Settings,
  Ghbdtn.InputQueue,
  Ghbdtn.Fixer,
  Ghbdtn.Diagnostics,
  Ghbdtn.SingleInstance,
  Ghbdtn.Password,
  Ghbdtn.Update;

type
  [TestFixture]
  TLayoutTests = class
  public
    [Test]
    procedure ConvertsEnglishKeysToRussian;
    [Test]
    procedure ConversionIsReversible;
    [Test]
    procedure LeavesUnsupportedCharactersUnchanged;
    [Test]
    procedure MapsVirtualKeysForBothLayouts;
    [Test]
    procedure MapsEnglishSymbolKeysToRussianLetters;
    [Test]
    procedure MapsMinusAndPlusOnBothLayouts;
    [Test]
    procedure MarksTheKeysThatTypeRussianLetters;
  end;

  [TestFixture]
  TUpdateTests = class
  public
    [Test]
    procedure ParsesVersionWithOptionalPrefixAndBuild;
    [Test]
    procedure TreatsAHigherReleaseAsNewer;
    [Test]
    procedure ParsesTheWin64ReleasePackage;
    [Test]
    procedure RejectsDraftPrereleaseAndOtherAssets;
    [Test]
    procedure FindsTheChecksumAssetOfThePackage;
    [Test]
    procedure ParsesChecksumFiles;
    [Test]
    procedure ChoosesQuietCheckOnlyForTheMarker;
  end;

  [TestFixture]
  TDetectionTests = class
  private
    procedure CountDetections(const AWords: string; AWrongLayout: Boolean;
      ALayout: TLangKind; out AFlagged, ATotal: Integer);
  public
    [Test]
    procedure DetectsMostRussianWordsTypedInEnglish;
    [Test]
    procedure DetectsMostEnglishWordsTypedInRussian;
    [Test]
    procedure KeepsRussianWordsTypedInRussian;
    [Test]
    procedure KeepsEnglishWordsTypedInEnglish;
    [Test]
    procedure DetectsRussianWordsWithLettersOnPunctuationKeys;
  end;

  [TestFixture]
  TReadingTests = class
  public
    [Test]
    procedure LetterModelPrefersTextOfItsOwnLanguage;
    [Test]
    procedure WordListKnowsFrequentWordsOfEachLanguage;
    [Test]
    procedure ListedWordIsAsCheapAsItsListCost;
    [Test]
    procedure EnglishReadingMayGiveUpEdgeKeysAtAPrice;
    [Test]
    procedure RussianReadingKeepsEveryKey;
    [Test]
    procedure RussianWordEndingInPunctuationKeySplitsOffTheMark;
    [Test]
    procedure RussianWordEndingInLetterOfItsOwnStaysWhole;
  end;

  [TestFixture]
  TAnalyzerTests = class
  public
    [Test]
    procedure DetectsRussianWordTypedWithEnglishLayout;
    [Test]
    procedure ConvertsSymbolKeysInsideRussianWord;
    [Test]
    procedure DetectsEnglishWordTypedWithRussianLayout;
    [Test]
    procedure LeavesCorrectEnglishWordAlone;
    [Test]
    procedure PreferredWordOverridesTheScore;
    [Test]
    procedure RejectedWordStaysOnTheCurrentLayout;
    [Test]
    procedure PreferredWordDoesNotBypassProtection;
    [Test]
    procedure FrequentRussianWordTypedInEnglishSwitches;
    [Test]
    procedure ShortWordNeedsRussianWordsBeforeIt;
    [Test]
    procedure RussianContextSwitchesANearMiss;
    [Test]
    procedure EnglishContextKeepsABorderlineWord;
    [Test]
    procedure RussianContextDoesNotOverrideEnglish;
    [Test]
    procedure LeavesCorrectRussianWordsAlone;
    [Test]
    procedure DetectsShortKnownWrongLayoutWords;
    [Test]
    procedure SwitchesCodeFenceTypedOnRussianLayout;
    [Test]
    procedure KeepsRussianInterjectionAndShortRuns;
    [Test]
    procedure SwitchesRussianPrefixTypedOnEnglishLayout;
    [Test]
    procedure SwitchesEnglishPrefixTypedOnRussianLayout;
    [Test]
    procedure KeepsPrefixThatStartsATypedWord;
    [Test]
    procedure FindsShortWordBeforeConvertedWord;
    [Test]
    procedure IgnoresPrecedingWordThatIsNotAShortFunctionWord;
    [Test]
    procedure WaitsForConfiguredNumberOfLetters;
    [Test]
    procedure KeepsPrefixBelowMinimumLength;
    [Test]
    procedure KeepsPrefixOfProtectedOrLearnedWord;
    [Test]
    procedure SelectionConversionDoesNotUndoCorrectRussian;
    [Test]
    procedure ManualSelectionSwapsOneScriptAndKeepsTheOther;
    [Test]
    procedure ManualConversionIsBolderThanAutomatic;
    [Test]
    procedure WordAtCaretReadsTheWordUnderTheCaret;
    [Test]
    procedure WordAtCaretTakesARunOfSymbolKeys;
    [Test]
    procedure ManualConversionSwapsStandaloneSymbolRuns;
    [Test]
    procedure InvertsEachLetterCase;
    [Test]
    procedure AppliesCaseModes;
    [Test]
    procedure FixesTwoInitialCapitalsOnly;
    [Test]
    procedure CountsCaretStepsAcrossLineBreaks;
    [Test]
    procedure FixesWordTypedWithCapsLock;
    [Test]
    procedure SwitchesFileExtensionTypedOnRussianLayout;
    [Test]
    procedure ProtectsTechnicalTokensAndAbbreviations;
    [Test]
    procedure ConvertsRussianTailAfterEnglishPrefix;
    [Test]
    procedure UsesHigherMarginForUnknownLayout;
    [Test]
    procedure ConvertsWordsWithLettersOnPunctuationKeys;
    [Test]
    procedure ConvertsRussianWordsInsideEdgeKeysOfPunctuation;
    [Test]
    procedure ShortWordWithLetterKeyAtTheEdgeIsNotAFunctionWord;
    [Test]
    procedure KeepsEnglishWordsWithPunctuationAroundThem;
    [Test]
    procedure KeepsTokensThatReadAsNoWord;
    [Test]
    procedure ConvertsRussianAbbreviationOfTheWordList;
  end;

  [TestFixture]
  TInputBufferTests = class
  public
    [Test]
    procedure TracksTextAndBackspace;
    [Test]
    procedure ClearResetsBuffer;
  end;

  [TestFixture]
  TLeftShiftStateTests = class
  public
    [Test]
    procedure HeldKeyDoesNotBecomeDoublePress;
    [Test]
    procedure TwoSeparatePressesBecomeDoublePress;
    [Test]
    procedure VeryFastDoublePressIsAccepted;
    [Test]
    procedure SlowDoublePressIsRejected;
    [Test]
    procedure RecognizesRightShiftByScanCode;
  end;

  [TestFixture]
  TSettingsTests = class
  public
    [Test]
    procedure SavesAndLoadsAllSettings;
    [Test]
    procedure PersistsInitialCapsOptions;
    [Test]
    procedure SupportsWildcardExclusionsAndRules;
    [Test]
    procedure AlwaysExcludesPasswordManagers;
    [Test]
    procedure RecognizesFullscreenNotificationStates;
    [Test]
    procedure DrawsBadgeBorderInADarkerShadeOfTheFill;
    [Test]
    procedure RecognizesEmailFieldLabels;
    [Test]
    procedure PersistsLearningAndHeuristicMode;
    [Test]
    procedure LoadsLegacyRulesAndLearning;
    [Test]
    procedure ResolvesStructuredApplicationProfiles;
    [Test]
    procedure RequiresRepeatedWeakLearningSignals;
    [Test]
    procedure KeptCorrectionForgetsWeakRejection;
    [Test]
    procedure ManualSwitchOverturnsRejection;
    [Test]
    procedure RepeatedRejectionRaisesScoreToTheCap;
    [Test]
    procedure KeepsConfirmedWordsWhenTheTableIsFull;
    [Test]
    procedure PersistsPreferSwitchLearning;
    [Test]
    procedure LoadsRejectAndPreferTogether;
    [Test]
    procedure ApplicationLearningOverridesTheSharedWord;
    [Test]
    procedure PinnedWordAppliesInEveryApplication;
    [Test]
    procedure RemovesOneExclusion;
    [Test]
    procedure ListsApplicationRules;
    [Test]
    procedure ForgetLearningRemovesOneEntry;
    [Test]
    procedure RecoversCorruptConfiguration;
    [Test]
    procedure BoundsLearningEntries;
    [Test]
    procedure CleansTemporaryFileAfterSaveFailure;
    [Test]
    procedure SupportsConcurrentReadLearnAndSave;
  end;

  [TestFixture]
  TInputQueueTests = class
  public
    [Test]
    procedure DropsWorkForAnotherControlOrAnOldItem;
    [Test]
    procedure CapturesReplayOnlyWhilePending;
    [Test]
    procedure PreservesReplayOrder;
    [Test]
    procedure WorkWaitsForKeysTypedBeforeIt;
    [Test]
    procedure RecognizesOwnInputSignature;
    [Test]
    procedure CompletesAtomicallyAtReplayBoundary;
    [Test]
    procedure CapturedReplaySignalsWorker;
    [Test]
    procedure BackgroundWorkDoesNotCaptureInput;
  end;

  [TestFixture]
  TDiagnosticsTests = class
  public
    [Test]
    procedure OffDoesNotCreateLog;
    [Test]
    procedure ReleaseClampsEffectiveLevel;
    [Test]
    procedure VerboseLogsHeuristicDecision;
    [Test]
    procedure InfoSkipsHeuristicDecision;
    [Test]
    procedure SupportsConcurrentLoggingAndConfiguration;
  end;

  [TestFixture]
  TSingleInstanceTests = class
  public
    [Test]
    procedure OnlyFirstGuardIsPrimary;
  end;

  [TestFixture]
  THookHelperTests = class
  public
    [Test]
    procedure LearningWindowExpires;
    [Test]
    procedure CountsMinutesLeftOnATimedPause;
    [Test]
    procedure RejectsOwnAndShellTargets;
    [Test]
    procedure DetectsPasswordControlStyle;
    [Test]
    procedure SkipsAutomationProbeForClassicEdits;
    [Test]
    procedure ColonAfterOneLetterDoesNotSwitch;
  end;

  [TestFixture]
  TLearningTests = class
  public
    [Test]
    procedure SmallEditIsNotARejection;
    [Test]
    procedure HalfOfALongFixIsAWeakRejection;
    [Test]
    procedure ErasingTheWholeFixIsAStrongRejection;
    [Test]
    procedure FullEraseAfterPartialEditPromotesOnce;
    [Test]
    procedure InflectedFormsShareALearnedStem;
    [Test]
    procedure ShortWordsDoNotShareAStem;
  end;

  [TestFixture]
  TPhraseTests = class
  public
    [Test]
    procedure OneRecentWordAddsNoBias;
    [Test]
    procedure TwoMatchingWordsBiasThatLanguage;
    [Test]
    procedure ThreeMatchingWordsRaiseTheBias;
    [Test]
    procedure WindowDropsTheOldestWord;
  end;

  [TestFixture]
  TTranslitTests = class
  public
    [Test]
    procedure ConvertsRussianToLatinLetters;
    [Test]
    procedure KeepsCaseOfGroupsAndLineBreaks;
    [Test]
    procedure ConvertsLatinToRussianLetters;
    [Test]
    procedure RestoresSignsAndLongGroups;
    [Test]
    procedure LeavesOtherCharactersAlone;
  end;

  [TestFixture]
  TClipboardTests = class
  public
    [Test]
    procedure RestoresEveryCopiedFormat;
    [Test]
    procedure RefusesContentThatCannotBeCopied;
    [Test]
    procedure SequenceChangesWhenTextIsWritten;
  end;

implementation

function UniqueTestPath(const AName: string): string;
begin
  Result := TPath.Combine(TPath.GetTempPath,
    'Ghbdtn-' + AName + '-' + TGUID.NewGuid.ToString.Replace('{', '').
      Replace('}', '') + '.json');
end;

procedure DeleteIfExists(const APath: string);
begin
  if TFile.Exists(APath) then
    TFile.Delete(APath);
end;

procedure TLayoutTests.ConvertsEnglishKeysToRussian;
begin
  Assert.AreEqual('привет', ConvertStringSwap('ghbdtn'));
end;

procedure TLayoutTests.ConversionIsReversible;
const
  Original = 'Ghbdtn, Vbh!';
begin
  Assert.AreEqual(Original, ConvertStringSwap(ConvertStringSwap(Original)));
end;

procedure TLayoutTests.LeavesUnsupportedCharactersUnchanged;
begin
  Assert.AreEqual('123 - =', ConvertStringSwap('123 - ='));
end;

procedure TLayoutTests.MapsVirtualKeysForBothLayouts;
begin
  Assert.AreEqual('q', MapVirtualKeyToChar(Ord('Q'), False, lkEN));
  Assert.AreEqual('Q', MapVirtualKeyToChar(Ord('Q'), True, lkEN));
  Assert.AreEqual('й', MapVirtualKeyToChar(Ord('Q'), False, lkRU));
  Assert.AreEqual('Й', MapVirtualKeyToChar(Ord('Q'), True, lkRU));
  Assert.AreEqual('1', MapVirtualKeyToChar(Ord('1'), True, lkRU));
  Assert.AreEqual(#0, MapVirtualKeyToChar(VK_F1, False, lkEN));
  Assert.AreEqual(';', MapVirtualKeyToChar(VK_OEM_1, False, lkEN));
  Assert.AreEqual('ж', MapVirtualKeyToChar(VK_OEM_1, False, lkRU));
  Assert.AreEqual('''', MapVirtualKeyToChar(VK_OEM_7, False, lkEN));
  Assert.AreEqual('э', MapVirtualKeyToChar(VK_OEM_7, False, lkRU));
  Assert.AreEqual('[', MapVirtualKeyToChar(VK_OEM_4, False, lkEN));
  Assert.AreEqual('х', MapVirtualKeyToChar(VK_OEM_4, False, lkRU));
  Assert.AreEqual(']', MapVirtualKeyToChar(VK_OEM_6, False, lkEN));
  Assert.AreEqual('ъ', MapVirtualKeyToChar(VK_OEM_6, False, lkRU));
end;

procedure TLayoutTests.MapsEnglishSymbolKeysToRussianLetters;
begin
  Assert.AreEqual('ж', ConvertStringSwap(';'));
  Assert.AreEqual('э', ConvertStringSwap(''''));
  Assert.AreEqual('х', ConvertStringSwap('['));
  Assert.AreEqual('ъ', ConvertStringSwap(']'));
  Assert.AreEqual('Ж', ConvertStringSwap(':'));
  Assert.AreEqual('Э', ConvertStringSwap('"'));
  Assert.AreEqual('Х', ConvertStringSwap('{'));
  Assert.AreEqual('Ъ', ConvertStringSwap('}'));
  Assert.AreEqual('также', ConvertStringSwap('nfr;t'));
  Assert.AreEqual('Также', ConvertStringSwap('Nfr;t'));
end;

procedure TLayoutTests.MapsMinusAndPlusOnBothLayouts;
begin
  Assert.AreEqual('-', MapVirtualKeyToChar(VK_OEM_MINUS, False, lkEN));
  Assert.AreEqual('_', MapVirtualKeyToChar(VK_OEM_MINUS, True, lkEN));
  Assert.AreEqual('=', MapVirtualKeyToChar(VK_OEM_PLUS, False, lkEN));
  Assert.AreEqual('+', MapVirtualKeyToChar(VK_OEM_PLUS, True, lkEN));
  Assert.AreEqual('-', MapVirtualKeyToChar(VK_OEM_MINUS, False, lkRU));
  Assert.AreEqual('_', MapVirtualKeyToChar(VK_OEM_MINUS, True, lkRU));
  Assert.AreEqual('=', MapVirtualKeyToChar(VK_OEM_PLUS, False, lkRU));
  Assert.AreEqual('+', MapVirtualKeyToChar(VK_OEM_PLUS, True, lkRU));
  Assert.AreEqual(':', MapVirtualKeyToChar(VK_OEM_1, True, lkEN));
  Assert.AreEqual(';', MapVirtualKeyToChar(VK_OEM_1, False, lkEN));
  Assert.AreEqual('Ж', MapVirtualKeyToChar(VK_OEM_1, True, lkRU));
end;

const
  RussianSample =
    'года мая так административный церкви европы типа призер рсфср композитор производства ' +
    'момент первого кроме испании располагается такие воды устье священной создан назван веке ' +
    'остров дел покровителем районного европейского разновидность средней проходит направлении ' +
    'местом орган критик музыкант официально марий серия грузинская работой курганской ' +
    'исторический авиакомпания выступала форма певица политики соль исключением поселе ' +
    'достаточно регионального положения евгений основы крымской законодательный конструктор ' +
    'международная достиг сидней космической счетом погибли решением введен должности дэвид ' +
    'подразделяется польша воду петров марийской достигать справа должна карате автономная ' +
    'пятый комет компаниями воевода основоположник насекомые нка статья иные завершении ' +
    'религиозной симон предшественника горного данное руководителем кинорежиссер антон ' +
    'разведывательного джаната дивизион готов стек известной кабинета красная резня исток ' +
    'иордании ведущим лучшим автодороги соединяет открытия верхний здравоохранения шоссе уезде ' +
    'квартале вариантов печени процессы императорской исторически музыкальными оборонительные ' +
    'путешественник лаборатории коммунистический положительные регистрируют яйском индейские ' +
    'квартиру нидерландская зарегистрировано символом прочие новогодний лагеря димопулос ' +
    'обществом уго авиакомпанией первомайском мог заявку устав советскими косвенно император ' +
    'различаются курская трамп руководителей ресурсов станет звукозаписи сделать амурской ' +
    'терехта весной смирно дворце сообществом изготовления штутгарт грей представителями ' +
    'аншлюса кодекс головном ручьевского ролон стокгольме разработчиком кислотность гиг объеме ' +
    'авиационного катаре профессора администрации столкновения воеводства тский соединений ' +
    'ашоки сутер начав минске муленберг уильямс расположенной мясо четырехколесное оясио ' +
    'кавказской израильский сделки повышенной зимбабве учения производстве аббаньяле сегодня ' +
    'даны величины нико сумской кировского парагвая отдать применяются матрица финансовая ' +
    'сайдшоу янжмаа копакабана ложек ';

const
  EnglishSample =
    'the who data need right technology pictures property point hot blog latest major ' +
    'president common conference mark jul engineering remember commission pdf rental george ' +
    'cnet chicago improve involved catalog output longer born itself beginning creative ' +
    'columbia applied visitors bob sec heat freedom sorted ipod leadership follows russia ' +
    'mouse brief votes specifications consulting banking samples delivered mentioned comfort ' +
    'gambling hiv ideal ink explain audience diseases entered controlled visa checks supreme ' +
    'oxford terminal collected contribution fighting relatively earnings templates pump ' +
    'hundred duration measured roman lease commissioner principle elected interpretation ' +
    'purple victims org dad losses targets glad uniform obligation arguments donald motors ' +
    'clay sons showtimes limitations boundary preparing genes atlas decor temp polyphonic ' +
    'quantum cleaner knife excerpt oakland arising ssl oem tablet resolve highlight cole ' +
    'solely monkey separation lotus bow oils diagram discounted verizon lil stuck satisfy ' +
    'microwave integral tap confused hiring monetary aggregate infected canal volt ons cabin ' +
    'chances extends edges walks slight behavioral rrp britannica witnesses mere loc monaco ' +
    'spice prospects lender gba enormous tar voyeurweb jaguar coordinates vacancies aerial ' +
    'participated titanium cheque entertaining travelling undo wrist shakira assured riders ' +
    'llp momentum simplified writings remainder urls arbitration tomato tribunal upset ' +
    'bleeding fridge dictionaries usps dividend somalia airplane creature burst sufficiently ' +
    'ranger ';

const
  // Frequent words with a letter on one of the punctuation keys of the
  // English layout: б ю ж э х ъ.
  RussianKeySample =
    'области входит июня футболист октября ноября декабря находится сентября более июля ' +
    'годах республики область союза олимпийских альбом других которых рамках берегу двух ' +
    'расположен этом этого сборной расположена играх летних губернии клуба сборную губерния ' +
    'заслуженный являются образование этой михайлович журналист наиболее южной населенных ' +
    'победитель поэт образования клуб включает трех нескольких первых помощью общине данных ' +
    'кубка частью самых общества состоянию обычно таких париж женщин позже включая некоторых ' +
    'художник араб футбольный режиссера британский футболу ходе общество движения благодаря ' +
    'входила жителей этих джон этим собор гражданской полностью имеют крупнейших большинство ' +
    'мужчин жанре республика корабль общественный нападающий своих община многих эпохи ' +
    'крупных архиепископ бассейна персонаж особенно азербайджана михаил британской службы ' +
    'различных работ сборная расположено альбома ';

const
  // Percent of a sample the heuristic must catch when typed in the wrong
  // layout, and may wrongly touch when typed in the right one.
  MinRussianDetected = 97;
  MinEnglishDetected = 95;
  MinKeyLettersDetected = 95;
  MaxRussianFalse = 1;
  MaxEnglishFalse = 1;
{ TDetectionTests }

procedure TDetectionTests.CountDetections(const AWords: string;
  AWrongLayout: Boolean; ALayout: TLangKind; out AFlagged, ATotal: Integer);
var
  Word, Typed: string;
begin
  AFlagged := 0;
  ATotal := 0;
  for Word in AWords.Split([' '], TStringSplitOptions.ExcludeEmpty) do
  begin
    if AWrongLayout then
      Typed := ConvertStringSwap(Word)
    else
      Typed := Word;
    Inc(ATotal);
    if AnalyzeWord(Typed, ALayout, hmBalanced, nil).NeedsSwitch then
      Inc(AFlagged);
  end;
end;

procedure TDetectionTests.DetectsMostRussianWordsTypedInEnglish;
var
  Flagged, Total: Integer;
begin
  CountDetections(RussianSample, True, lkEN, Flagged, Total);
  Assert.IsTrue(Flagged * 100 >= Total * MinRussianDetected, Format('%d of %d', [Flagged, Total]));
end;

procedure TDetectionTests.DetectsMostEnglishWordsTypedInRussian;
var
  Flagged, Total: Integer;
begin
  CountDetections(EnglishSample, True, lkRU, Flagged, Total);
  Assert.IsTrue(Flagged * 100 >= Total * MinEnglishDetected, Format('%d of %d', [Flagged, Total]));
end;

procedure TDetectionTests.KeepsRussianWordsTypedInRussian;
var
  Flagged, Total: Integer;
begin
  CountDetections(RussianSample, False, lkRU, Flagged, Total);
  Assert.IsTrue(Flagged * 100 <= Total * MaxRussianFalse, Format('%d of %d', [Flagged, Total]));
end;

procedure TDetectionTests.KeepsEnglishWordsTypedInEnglish;
var
  Flagged, Total: Integer;
begin
  CountDetections(EnglishSample, False, lkEN, Flagged, Total);
  Assert.IsTrue(Flagged * 100 <= Total * MaxEnglishFalse, Format('%d of %d', [Flagged, Total]));
end;

procedure TLayoutTests.MarksTheKeysThatTypeRussianLetters;
var
  C: Char;
begin
  for C in ',.;'':[]`<>"{}~' do
    Assert.IsTrue(IsRussianLetterKey(C), C);
  for C in 'abcxyzABCXYZ0123456789 -_=/\?!@#$%^&*()+' do
    Assert.IsFalse(IsRussianLetterKey(C), C);
  // Every such key types a letter on the Russian layout.
  for C in ',.;'':[]`<>"{}~' do
    Assert.IsTrue(Ord(ConvertCharSwap(C)) > $0400, C);
end;

procedure TDetectionTests.DetectsRussianWordsWithLettersOnPunctuationKeys;
var
  Flagged, Total: Integer;
begin
  CountDetections(RussianKeySample, True, lkEN, Flagged, Total);
  Assert.IsTrue(Flagged * 100 >= Total * MinKeyLettersDetected, Format('%d of %d', [Flagged, Total]));
end;

procedure TReadingTests.LetterModelPrefersTextOfItsOwnLanguage;
begin
  Assert.IsTrue(LetterModelCost('привет', lkRU) < LetterModelCost('ghbdtn', lkEN));
  Assert.IsTrue(LetterModelCost('hello', lkEN) < LetterModelCost('руддщ', lkRU));
  // A key that types a Russian letter is almost never inside an English word.
  Assert.IsTrue(LetterModelCost('a,b', lkEN) > LetterModelCost('abb', lkEN) + 40);
  Assert.AreEqual(LetterModelCost('еще', lkRU), LetterModelCost('ещё', lkRU));
end;

procedure TReadingTests.WordListKnowsFrequentWordsOfEachLanguage;
begin
  Assert.IsTrue(WordCost('привет', lkRU) >= 0);
  Assert.IsTrue(WordCost('hello', lkEN) >= 0);
  Assert.AreEqual(-1, WordCost('привет', lkEN));
  Assert.AreEqual(-1, WordCost('ghbdtn', lkEN));
  Assert.AreEqual(WordCost('еще', lkRU), WordCost('ещё', lkRU));
  // A more frequent word costs less.
  Assert.IsTrue(WordCost('и', lkRU) < WordCost('привет', lkRU));
  Assert.IsTrue(WordCost('the', lkEN) < WordCost('hello', lkEN));
  Assert.IsTrue(WordCost('еж', lkRU) >= 0);
  Assert.AreEqual(WordCost('еж', lkRU), WordCost('ёж', lkRU));
  Assert.IsTrue(WordCost('эх', lkRU) >= 0);
end;

procedure TReadingTests.ListedWordIsAsCheapAsItsListCost;
var
  Reading: TReading;
begin
  Reading := ReadAsRussian('привет');
  Assert.IsTrue(Reading.Valid);
  Assert.IsTrue(Reading.Listed);
  Assert.IsTrue(Reading.Cost <= WordCost('привет', lkRU));
  Reading := ReadAsEnglish('ghbdtn');
  Assert.IsFalse(Reading.Listed);
  Assert.AreEqual(LetterModelCost('ghbdtn', lkEN), Reading.Cost);
end;

procedure TReadingTests.EnglishReadingMayGiveUpEdgeKeysAtAPrice;
var
  Plain, Comma, Quoted: TReading;
begin
  Plain := ReadAsEnglish('hello');
  Comma := ReadAsEnglish('hello,');
  Quoted := ReadAsEnglish('''hello''');
  Assert.AreEqual('hello', Comma.Core);
  Assert.IsTrue(Comma.Cost > Plain.Cost);
  Assert.AreEqual(Plain.PlainCost, Comma.PlainCost);
  // A comma after a word is more common than a quote around it.
  Assert.IsTrue(Quoted.Cost > Comma.Cost);
  Assert.IsFalse(ReadAsEnglish(',.').Valid);
  Assert.IsFalse(ReadAsEnglish('').Valid);
end;

procedure TReadingTests.RussianReadingKeepsEveryKey;
var
  Reading: TReading;
begin
  Reading := ReadAsRussian('было');
  Assert.AreEqual('было', Reading.Core);
  Assert.IsTrue(Reading.Cost > 0);
  Assert.AreEqual(Reading.Cost, Reading.PlainCost);
end;

procedure TReadingTests.RussianWordEndingInPunctuationKeySplitsOffTheMark;

  procedure AssertMark(const AWord: string; AExpected: Char);
  var
    Mark: Char;
  begin
    Assert.IsTrue(TryRussianTrailingPunctuation(AWord, Mark), AWord);
    Assert.AreEqual(AExpected, Mark, AWord);
  end;

begin
  AssertMark('приветб', ',');
  AssertMark('приветю', '.');
  AssertMark('приветж', ';');
  AssertMark('приветЖ', ':');
  AssertMark('приветъ', ']');
  AssertMark('приветэ', '''');
  AssertMark('приветЭ', '"');
  AssertMark('приветё', '`');
  AssertMark('приветБ', '<');
  AssertMark('приветЮ', '>');
  AssertMark('приветХ', '{');
  AssertMark('приветЪ', '}');
  AssertMark('приветЁ', '~');
  AssertMark('Приветб', ',');
  AssertMark('сообщениеб', ',');
end;

procedure TReadingTests.RussianWordEndingInLetterOfItsOwnStaysWhole;
var
  Mark: Char;
begin
  Assert.IsFalse(TryRussianTrailingPunctuation('нож', Mark), 'нож');
  Assert.IsFalse(TryRussianTrailingPunctuation('моё', Mark), 'моё');
  Assert.IsFalse(TryRussianTrailingPunctuation('своё', Mark), 'своё');
  Assert.IsFalse(TryRussianTrailingPunctuation('гараж', Mark), 'гараж');
  Assert.IsFalse(TryRussianTrailingPunctuation('рубль', Mark), 'рубль');
  Assert.IsFalse(TryRussianTrailingPunctuation('любовь', Mark), 'любовь');
  Assert.IsFalse(TryRussianTrailingPunctuation('привет', Mark), 'привет');
  Assert.IsFalse(TryRussianTrailingPunctuation('приветх', Mark), 'приветх');
  Assert.IsFalse(TryRussianTrailingPunctuation('об', Mark), 'об');
  Assert.IsFalse(TryRussianTrailingPunctuation('hello,', Mark), 'hello,');
end;

procedure TAnalyzerTests.ConvertsWordsWithLettersOnPunctuationKeys;

  procedure AssertConverts(const ATyped, AExpected: string);
  var
    Analysis: TAnalysisResult;
  begin
    Analysis := AnalyzeWord(ATyped, lkEN);
    Assert.IsTrue(Analysis.NeedsSwitch, ATyped);
    Assert.AreEqual(AExpected, Analysis.ConvertedText, ATyped);
    Assert.AreEqual(Integer(lkRU), Integer(Analysis.TargetLang), ATyped);
  end;

begin
  // The word starts with "б", "э", "х", "ё" or a capital typed with Shift.
  AssertConverts(',sk', 'был');
  AssertConverts(',tp', 'без');
  AssertConverts('<sk', 'Был');
  AssertConverts(',jkmijq', 'большой');
  AssertConverts('''nj', 'это');
  AssertConverts('[jhjij', 'хорошо');
  AssertConverts('`krf', 'ёлка');
  AssertConverts('to`', 'ещё');
  AssertConverts(':bpym', 'Жизнь');
  AssertConverts(':BPYM', 'ЖИЗНЬ');
  AssertConverts('<SK', 'БЫЛ');
  AssertConverts('ghbdtn:', 'привет:');
  Assert.IsFalse(AnalyzeWord('hello:', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('C:', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('10:30', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('NFR:T', lkEN).NeedsSwitch);
  // The word ends with "ю", or has one inside.
  AssertConverts('cdj.', 'свою');
  AssertConverts(';bpym.', 'жизнью');
  AssertConverts('c.lf', 'сюда');
  AssertConverts('c,jhrf', 'сборка');
  AssertConverts('Hf,jxbq', 'Рабочий');
  // A word of the other layout is found when the layout is not known as well.
  Assert.IsTrue(AnalyzeWord(',jkmijq', lkUnknown).NeedsSwitch);
  Assert.AreEqual('большой', AnalyzeWord(',jkmijq', lkUnknown).ConvertedText);
  // Nothing but the keys of Russian letters is left to read as English.
  AssertConverts('`;', 'ёж');
  AssertConverts('''[', 'эх');
  AssertConverts('t;', 'еж');
  AssertConverts('~;', 'Ёж');
  AssertConverts('"{', 'ЭХ');
  Assert.AreEqual(Ord(dmDictionary), Ord(AnalyzeWord('`;', lkEN).Mark));
  Assert.IsTrue(AnalyzeWord('`;', lkEN, hmCautious, nil).NeedsSwitch);
  Assert.IsTrue(AnalyzeWord('`;', lkUnknown).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('[]', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('<>', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('``', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord(';`', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('`.', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord(',.', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('ёж', lkRU).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('эх', lkRU).NeedsSwitch);
end;

procedure TAnalyzerTests.ConvertsRussianWordsInsideEdgeKeysOfPunctuation;

  procedure AssertConverts(const ATyped, AExpected: string);
  var
    Analysis: TAnalysisResult;
  begin
    Analysis := AnalyzeWord(ATyped, lkEN);
    Assert.IsTrue(Analysis.NeedsSwitch, ATyped);
    Assert.AreEqual(AExpected, Analysis.ConvertedText, ATyped);
  end;

begin
  AssertConverts('[ghbdtn]', '[привет]');
  AssertConverts('''ghbdtn''', '''привет''');
  AssertConverts('[ghbdtn', '[привет');
  AssertConverts('ghbdtn]', 'привет]');
  AssertConverts('(ghbdtn)', '(привет)');
  AssertConverts('Ghbdtn,', 'Привет,');
end;

procedure TAnalyzerTests.ShortWordWithLetterKeyAtTheEdgeIsNotAFunctionWord;
var
  Analysis: TAnalysisResult;
begin
  // "'nj" is "это"; without the first key it would be the function word "то",
  // which is left alone at the start of a phrase.
  Analysis := AnalyzeWord('''nj', lkEN, hmBalanced, nil, nil, EmptyPhrase);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('это', Analysis.ConvertedText);
  Assert.IsFalse(AnalyzeWord('nj', lkEN, hmBalanced, nil, nil,
    EmptyPhrase).NeedsSwitch);
end;

procedure TAnalyzerTests.KeepsEnglishWordsWithPunctuationAroundThem;
var
  Typed: string;
begin
  for Typed in ['hello,', 'world.', 'ok.', 'yes,', 'No.', 'it''s', 'I''m',
    'don''t', 'can''t', '''quoted''', '[test]', '<div>', 'e.g.'] do
    Assert.IsFalse(AnalyzeWord(Typed, lkEN).NeedsSwitch, Typed);
  // The same words typed on the Russian layout come back with their marks.
  Assert.AreEqual('hello,', AnalyzeWord(ConvertStringSwap('hello,'), lkRU).ConvertedText);
  Assert.AreEqual('world.', AnalyzeWord(ConvertStringSwap('world.'), lkRU).ConvertedText);
end;

procedure TAnalyzerTests.KeepsTokensThatReadAsNoWord;
var
  Typed: string;
begin
  // Letters joined by commas, periods or angle brackets are code, an
  // address or an abbreviation, not a Russian word typed on the wrong layout.
  for Typed in ['x.y.z', 'a,b,c', 'a.k.a', 'e<f', 'k.o', 'example.com',
    'readme.md', 'github.com', 'x,y', 'main.cpp', 'www.site.ru'] do
    Assert.IsFalse(AnalyzeWord(Typed, lkEN).NeedsSwitch, Typed);
end;

procedure TAnalyzerTests.ConvertsRussianAbbreviationOfTheWordList;
begin
  // A word without vowels is skipped unless it is a listed Russian word.
  Assert.IsTrue(AnalyzeWord('cyu', lkEN).NeedsSwitch);
  Assert.AreEqual('снг', AnalyzeWord('cyu', lkEN).ConvertedText);
  Assert.IsFalse(AnalyzeWord('dvd', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('pdf', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('зав', lkRU).NeedsSwitch);
end;

procedure TAnalyzerTests.DetectsRussianWordTypedWithEnglishLayout;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('ghbdtn', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual(Integer(lkRU), Integer(Analysis.TargetLang));
  Assert.AreEqual(Ord(dmDictionary), Ord(Analysis.Mark));
  Assert.AreEqual('привет', Analysis.ConvertedText);
end;

procedure TAnalyzerTests.ConvertsSymbolKeysInsideRussianWord;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('nfr;t', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('также', Analysis.ConvertedText);
  Analysis := AnalyzeWord('vj;tn', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('может', Analysis.ConvertedText);
end;

procedure TAnalyzerTests.DetectsEnglishWordTypedWithRussianLayout;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('руддщ', lkRU);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual(Integer(lkEN), Integer(Analysis.TargetLang));
  Assert.AreEqual('hello', Analysis.ConvertedText);
end;

procedure TAnalyzerTests.LeavesCorrectEnglishWordAlone;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('hello', lkEN);
  Assert.IsFalse(Analysis.NeedsSwitch);
  Assert.AreEqual(Integer(lkUnknown), Integer(Analysis.TargetLang));
end;

procedure TAnalyzerTests.PreferredWordOverridesTheScore;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('hello', lkEN, hmBalanced, nil,
    function(const AWord: string): Boolean
    begin
      Result := AWord = 'hello';
    end);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual(Integer(lkRU), Integer(Analysis.TargetLang));
  Assert.AreEqual(ConvertStringSwap('hello'), Analysis.ConvertedText);
end;

procedure TAnalyzerTests.RejectedWordStaysOnTheCurrentLayout;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('ghbdtn', lkEN, hmBalanced,
    function(const AWord: string): Boolean
    begin
      Result := True;
    end);
  Assert.IsFalse(Analysis.NeedsSwitch);
  Assert.AreEqual(Ord(dmLearning), Ord(Analysis.Mark));
end;

procedure TAnalyzerTests.PreferredWordDoesNotBypassProtection;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('hello1', lkEN, hmBalanced, nil,
    function(const AWord: string): Boolean
    begin
      Result := True;
    end);
  Assert.IsFalse(Analysis.NeedsSwitch);
end;

function PhraseOf(const ALangs: array of TLangKind): TPhraseContext;
var
  Lang: TLangKind;
begin
  Result := EmptyPhrase;
  for Lang in ALangs do
    RememberPhraseLanguage(Result, Lang);
end;

procedure TAnalyzerTests.ShortWordNeedsRussianWordsBeforeIt;
var
  Analysis: TAnalysisResult;
begin
  // At the start of a phrase "vs" and "c" read as English as easily as Russian.
  Assert.IsFalse(AnalyzeWord('vs', lkEN, hmBalanced, nil, nil, EmptyPhrase).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('c', lkEN, hmBalanced, nil, nil, PhraseOf([lkEN])).NeedsSwitch);

  Analysis := AnalyzeWord('vs', lkEN, hmBalanced, nil, nil, PhraseOf([lkRU]));
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('мы', Analysis.ConvertedText);

  // A word that is not a Russian function word is scored as usual.
  Assert.IsFalse(AnalyzeWord('hi', lkEN, hmBalanced, nil, nil, PhraseOf([lkRU])).NeedsSwitch);
  // A selection converted by hand has no tracked context.
  Assert.IsTrue(AnalyzeWord('vs', lkEN).NeedsSwitch);
end;

procedure TAnalyzerTests.FrequentRussianWordTypedInEnglishSwitches;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('vfibyf', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('машина', Analysis.ConvertedText);
  Analysis := AnalyzeWord('машина', lkRU);
  Assert.IsFalse(Analysis.NeedsSwitch);
end;

procedure TAnalyzerTests.RussianContextSwitchesANearMiss;
var
  Analysis: TAnalysisResult;
  Phrase: TPhraseContext;
begin
  Analysis := AnalyzeWord('celf', lkEN);
  Assert.IsFalse(Analysis.NeedsSwitch);
  Phrase := PhraseOf([lkRU, lkRU]);
  Analysis := AnalyzeWord('celf', lkEN, hmBalanced, nil, nil, Phrase);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('суда', Analysis.ConvertedText);
  Phrase := PhraseOf([lkRU, lkRU, lkRU]);
  Analysis := AnalyzeWord('celf', lkEN, hmCautious, nil, nil, Phrase);
  Assert.IsFalse(Analysis.NeedsSwitch);
end;

procedure TAnalyzerTests.EnglishContextKeepsABorderlineWord;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('pderf', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('звука', Analysis.ConvertedText);
  Analysis := AnalyzeWord('pderf', lkEN, hmBalanced, nil, nil, PhraseOf([lkEN, lkEN]));
  Assert.IsFalse(Analysis.NeedsSwitch);
end;

procedure TAnalyzerTests.RussianContextDoesNotOverrideEnglish;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('hello', lkEN, hmBalanced, nil, nil,
    PhraseOf([lkRU, lkRU, lkRU]));
  Assert.IsFalse(Analysis.NeedsSwitch);
end;

procedure TAnalyzerTests.LeavesCorrectRussianWordsAlone;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('привет', lkRU);
  Assert.IsFalse(Analysis.NeedsSwitch);

  Analysis := AnalyzeWord('дела', lkRU);
  Assert.IsFalse(Analysis.NeedsSwitch);

  Analysis := AnalyzeWord('как', lkRU);
  Assert.IsFalse(Analysis.NeedsSwitch);
end;

procedure TAnalyzerTests.SwitchesCodeFenceTypedOnRussianLayout;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('ёёё', lkRU);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual(Integer(lkEN), Integer(Analysis.TargetLang));
  Assert.AreEqual('```', Analysis.ConvertedText);

  Analysis := AnalyzeWord('ЁЁЁЁ', lkRU);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('~~~~', Analysis.ConvertedText);
end;

procedure TAnalyzerTests.KeepsRussianInterjectionAndShortRuns;
begin
  Assert.IsFalse(AnalyzeWord('ээ', lkRU).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('ЭЭ', lkRU).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('ёё', lkRU).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('```', lkEN).NeedsSwitch);
  Assert.IsTrue(IsCodeFenceKeys('ёёё'));
  Assert.IsFalse(IsCodeFenceKeys('ёё'));
  Assert.IsFalse(IsCodeFenceKeys('ёёз'));
end;

procedure TAnalyzerTests.SwitchesRussianPrefixTypedOnEnglishLayout;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWordPrefix('ghbd', lkEN, EarlyLettersDefault, hmBalanced, nil);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual(Integer(lkRU), Integer(Analysis.TargetLang));
  Assert.AreEqual('прив', Analysis.ConvertedText);

  Analysis := AnalyzeWordPrefix('Ghbdtn', lkEN, EarlyLettersDefault, hmBalanced, nil);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('Привет', Analysis.ConvertedText);

  Analysis := AnalyzeWordPrefix('cgfcb', lkEN, EarlyLettersDefault, hmBalanced, nil);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('спаси', Analysis.ConvertedText);
end;

procedure TAnalyzerTests.SwitchesEnglishPrefixTypedOnRussianLayout;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWordPrefix('цщкд', lkRU, EarlyLettersDefault, hmBalanced, nil);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual(Integer(lkEN), Integer(Analysis.TargetLang));
  Assert.AreEqual('worl', Analysis.ConvertedText);

  Analysis := AnalyzeWordPrefix('Пщщпд', lkRU, EarlyLettersDefault, hmBalanced, nil);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('Googl', Analysis.ConvertedText);
end;

procedure TAnalyzerTests.KeepsPrefixThatStartsATypedWord;
const
  EnglishPrefixes: array[0..5] of string = ('hell', 'chec', 'ghos', 'rece',
    'thin', 'pass');
  RussianPrefixes: array[0..2] of string = ('прив', 'раб', 'сегодн');
var
  Prefix: string;
begin
  for Prefix in EnglishPrefixes do
    Assert.IsFalse(AnalyzeWordPrefix(Prefix, lkEN, EarlyLettersDefault, hmBalanced, nil).NeedsSwitch,
      Prefix);
  for Prefix in RussianPrefixes do
    Assert.IsFalse(AnalyzeWordPrefix(Prefix, lkRU, EarlyLettersDefault, hmBalanced, nil).NeedsSwitch,
      Prefix);
end;

procedure TAnalyzerTests.FindsShortWordBeforeConvertedWord;
var
  Prev: string;
begin
  Assert.IsTrue(TryPrecedingShortWord('D yfxfkt', 6, Prev));
  Assert.AreEqual('D', Prev);
  Assert.IsTrue(TryPrecedingShortWord('привет, Yt yfxfkt', 6, Prev));
  Assert.AreEqual('Yt', Prev);
  Assert.IsTrue(TryPrecedingShortWord('text (d yfxfkt', 6, Prev));
  Assert.AreEqual('d', Prev);
end;

procedure TAnalyzerTests.IgnoresPrecedingWordThatIsNotAShortFunctionWord;
var
  Prev: string;
begin
  // "I" and "a" are not Russian function words once swapped.
  Assert.IsFalse(TryPrecedingShortWord('I yfxfkt', 6, Prev));
  Assert.IsFalse(TryPrecedingShortWord('a yfxfkt', 6, Prev));
  // Three letters or more are judged as words by the analyzer.
  Assert.IsFalse(TryPrecedingShortWord('the yfxfkt', 6, Prev));
  // Part of a longer token or no space between.
  Assert.IsFalse(TryPrecedingShortWord('x-d yfxfkt', 6, Prev));
  Assert.IsFalse(TryPrecedingShortWord('Dyfxfkt', 6, Prev));
  Assert.IsFalse(TryPrecedingShortWord('yfxfkt', 6, Prev));
  Assert.IsFalse(TryPrecedingShortWord('d  yfxfkt', 6, Prev));
end;

procedure TAnalyzerTests.WaitsForConfiguredNumberOfLetters;
begin
  Assert.IsFalse(AnalyzeWordPrefix('ghbd', lkEN, 5, hmBalanced, nil).NeedsSwitch);
  Assert.IsTrue(AnalyzeWordPrefix('ghbdt', lkEN, 5, hmBalanced, nil).NeedsSwitch);
  Assert.IsFalse(AnalyzeWordPrefix('ghb', lkEN, 4, hmBalanced, nil).NeedsSwitch);
  // Below the lowest setting the lowest one applies.
  Assert.IsFalse(AnalyzeWordPrefix('gh', lkEN, 1, hmBalanced, nil).NeedsSwitch);
  Assert.IsFalse(AnalyzeWordPrefix('ghbdtn', lkEN, EarlyLettersMax, hmBalanced,
    nil).NeedsSwitch);
end;

procedure TAnalyzerTests.KeepsPrefixBelowMinimumLength;
begin
  Assert.IsFalse(AnalyzeWordPrefix('ghb', lkEN, EarlyLettersDefault, hmBalanced, nil).NeedsSwitch);
  Assert.IsFalse(AnalyzeWordPrefix('', lkEN, EarlyLettersDefault, hmBalanced, nil).NeedsSwitch);
  Assert.IsFalse(AnalyzeWordPrefix('ghbd', lkUnknown, EarlyLettersDefault, hmBalanced, nil).NeedsSwitch);
end;

procedure TAnalyzerTests.KeepsPrefixOfProtectedOrLearnedWord;
begin
  Assert.IsFalse(AnalyzeWordPrefix('GHBD', lkEN, EarlyLettersDefault, hmBalanced, nil).NeedsSwitch);
  Assert.IsFalse(AnalyzeWordPrefix('ghb1', lkEN, EarlyLettersDefault, hmBalanced, nil).NeedsSwitch);
  Assert.IsFalse(AnalyzeWordPrefix('ghbd', lkEN, EarlyLettersDefault, hmBalanced,
    function(const AWord: string): Boolean
    begin
      Result := AWord = 'ghbd';
    end).NeedsSwitch);
end;

procedure TAnalyzerTests.DetectsShortKnownWrongLayoutWords;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('rfr', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual(Integer(lkRU), Integer(Analysis.TargetLang));
  Assert.AreEqual('как', Analysis.ConvertedText);

  Analysis := AnalyzeWord('Rjulf', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual(Integer(lkRU), Integer(Analysis.TargetLang));
  Assert.AreEqual('Когда', Analysis.ConvertedText);

  Analysis := AnalyzeWord('rjulf', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('когда', Analysis.ConvertedText);

  Analysis := AnalyzeWord('jlby', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('один', Analysis.ConvertedText);

  Analysis := AnalyzeWord('geyrn', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('пункт', Analysis.ConvertedText);

  Analysis := AnalyzeWord('lkz', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('для', Analysis.ConvertedText);

  Analysis := AnalyzeWord('b', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('и', Analysis.ConvertedText);

  Analysis := AnalyzeWord('yt', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('не', Analysis.ConvertedText);

  Analysis := AnalyzeWord('gj', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('по', Analysis.ConvertedText);

  Analysis := AnalyzeWord('yf', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('на', Analysis.ConvertedText);

  Assert.IsFalse(AnalyzeWord('a', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('i', lkEN).NeedsSwitch);

  Analysis := AnalyzeWord('xbnftncz', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('читается', Analysis.ConvertedText);

  Assert.IsTrue(IsEnglishQuestionMarker('hello?'));
  Assert.IsTrue(IsEnglishQuestionMarker('a?'));
  Assert.IsTrue(IsEnglishQuestionMarker('ok?'));
  Assert.IsFalse(IsEnglishQuestionMarker('hello ?'));
  Assert.IsFalse(IsEnglishQuestionMarker('hello'));
  Assert.IsFalse(AnalyzeWord('hello?', lkEN).NeedsSwitch);

  Analysis := AnalyzeWord('ьн', lkRU);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual(Integer(lkEN), Integer(Analysis.TargetLang));
  Assert.AreEqual('my', Analysis.ConvertedText);
end;

procedure TAnalyzerTests.SelectionConversionDoesNotUndoCorrectRussian;
var
  Analysis: TAnalysisResult;
  Converted: string;
begin
  Analysis := AnalyzeSelection('Когда', hmBalanced, nil);
  Assert.IsFalse(Analysis.NeedsSwitch);

  Analysis := AnalyzeSelection('Rjulf', hmBalanced, nil);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('Когда', Analysis.ConvertedText);

  Analysis := AnalyzeSelection('Ghbdtn rfr', hmBalanced, nil);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('Привет как', Analysis.ConvertedText);

  Converted := ConvertSelectionSmart('Привет hello как дела', hmBalanced, nil);
  Assert.AreEqual('Привет hello как дела', Converted);

  Converted := ConvertSelectionSmart('Ghbdtn hello rfr ltkf', hmBalanced, nil);
  Assert.AreEqual('Привет hello как дела', Converted);
end;

procedure TAnalyzerTests.ManualSelectionSwapsOneScriptAndKeepsTheOther;
begin
  Assert.AreEqual('привет мир',
    ConvertManualSelection('ghbdtn vbh', hmBalanced, nil, nil));
  Assert.AreEqual('руддщ',
    ConvertManualSelection('hello', hmBalanced, nil, nil));
  Assert.AreEqual('Привет привет',
    ConvertManualSelection('Привет ghbdtn', hmBalanced, nil, nil));
  Assert.AreEqual('Привет hello',
    ConvertManualSelection('Привет hello', hmBalanced, nil, nil));
end;

procedure TAnalyzerTests.ManualConversionIsBolderThanAutomatic;
var
  Typed, Flipped: string;
begin
  // Every word of a block is judged by itself.
  Typed := 'ghbdtn ltkf';
  Flipped := ConvertManualSelection(Typed, hmCautious, nil, nil);
  Assert.AreEqual('привет дела', Flipped);
  Assert.AreEqual('Привет hello мир',
    ConvertManualSelection('Ghbdtn hello vbh', hmBalanced, nil, nil));
  Assert.AreEqual('привет hello world',
    ConvertManualSelection('ghbdtn hello world', hmBalanced, nil, nil));
  // Text that already reads well in its layout is not touched.
  Assert.AreEqual('hello world', ConvertManualSelection('hello world',
    hmBalanced, nil, nil));
  Assert.AreEqual('привет мир', ConvertManualSelection('привет мир',
    hmBalanced, nil, nil));
  // Short Russian function words are flipped without a Russian word before.
  Assert.AreEqual('в доме', ConvertManualSelection('d ljvt', hmBalanced, nil, nil));
  // A single word is flipped even when it reads well as it is.
  Assert.AreEqual('руддщ', ConvertManualSelection('hello', hmBalanced, nil, nil));
  // The words the user taught the program to leave are left.
  Assert.AreEqual('ghbdtn мир', ConvertManualSelection('ghbdtn vbh', hmBalanced,
    function(const AWord: string): Boolean
    begin
      Result := AWord = 'ghbdtn';
    end, nil));
end;

procedure TAnalyzerTests.WordAtCaretReadsTheWordUnderTheCaret;
var
  Start, Finish: Integer;
begin
  Assert.IsTrue(TryWordAtCaret('hello world', 0, Start, Finish));
  Assert.AreEqual(0, Start);
  Assert.AreEqual(5, Finish);

  Assert.IsTrue(TryWordAtCaret('hello world', 5, Start, Finish));
  Assert.AreEqual(0, Start);
  Assert.AreEqual(5, Finish);

  Assert.IsTrue(TryWordAtCaret('hello world', 6, Start, Finish));
  Assert.AreEqual(6, Start);
  Assert.AreEqual(11, Finish);

  Assert.IsTrue(TryWordAtCaret('hello world', 11, Start, Finish));
  Assert.AreEqual(6, Start);
  Assert.AreEqual(11, Finish);

  Assert.IsTrue(TryWordAtCaret('привет', 3, Start, Finish));
  Assert.AreEqual(0, Start);
  Assert.AreEqual(6, Finish);

  Assert.IsTrue(TryWordAtCaret(',sk', 0, Start, Finish));
  Assert.AreEqual(0, Start);
  Assert.AreEqual(3, Finish);
  Assert.IsTrue(TryWordAtCaret('nfr;t', 3, Start, Finish));
  Assert.AreEqual(0, Start);
  Assert.AreEqual(5, Finish);
  Assert.IsTrue(TryWordAtCaret('cdj.', 1, Start, Finish));
  Assert.AreEqual(0, Start);
  Assert.AreEqual(4, Finish);
  Assert.IsTrue(TryWordAtCaret('hello,', 2, Start, Finish));
  Assert.AreEqual(0, Start);
  Assert.AreEqual(5, Finish);
  Assert.IsTrue(TryWordAtCaret('[ghbdtn]', 2, Start, Finish));
  Assert.AreEqual(1, Start);
  Assert.AreEqual(7, Finish);

  Assert.IsFalse(TryWordAtCaret('', 0, Start, Finish));
  Assert.IsFalse(TryWordAtCaret('hello world', -1, Start, Finish));
end;

procedure TAnalyzerTests.WordAtCaretTakesARunOfSymbolKeys;
var
  Start, Finish: Integer;
begin
  Assert.IsTrue(TryWordAtCaret('///', 3, Start, Finish));
  Assert.AreEqual(0, Start);
  Assert.AreEqual(3, Finish);
  Assert.IsTrue(TryWordAtCaret('a ??? b', 4, Start, Finish));
  Assert.AreEqual(2, Start);
  Assert.AreEqual(5, Finish);
  Assert.IsFalse(TryWordAtCaret('a  b', 2, Start, Finish));
end;

procedure TAnalyzerTests.ManualConversionSwapsStandaloneSymbolRuns;
begin
  Assert.AreEqual('...', ConvertManualSelection('///', hmBalanced, nil, nil));
  Assert.AreEqual('x ... y',
    ConvertManualSelection('x /// y', hmBalanced, nil, nil));
end;

procedure TAnalyzerTests.AppliesCaseModes;
begin
  Assert.AreEqual('ПРИВЕТ МИР 1', ApplyCaseMode('Привет мир 1', cmUpper));
  Assert.AreEqual('привет мир 1', ApplyCaseMode('Привет МИР 1', cmLower));
  Assert.AreEqual('HELLO', ApplyCaseMode('hello', cmUpper));
  Assert.AreEqual('Привет', ApplyCaseMode('пРИВЕТ', cmCapitalize));
  Assert.AreEqual('Hello world', ApplyCaseMode('hELLO WORLD', cmCapitalize));
  Assert.AreEqual('Один. Два! Три? Четыре', ApplyCaseMode('ОДИН. два! ТРИ? четыре', cmCapitalize));
  Assert.AreEqual('Первая'#13#10'Вторая', ApplyCaseMode('первая'#13#10'вторая', cmCapitalize));
  Assert.AreEqual('1Abc', ApplyCaseMode('1ABC', cmCapitalize));
  Assert.AreEqual('пРИВЕТ', ApplyCaseMode('Привет', cmInvert));
  Assert.AreEqual('', ApplyCaseMode('', cmCapitalize));
end;

procedure TAnalyzerTests.InvertsEachLetterCase;
begin
  Assert.AreEqual('ПРИВЕТ', InvertLetterCase('привет'));
  Assert.AreEqual('привет', InvertLetterCase('ПРИВЕТ'));
  Assert.AreEqual('пРИВЕТ', InvertLetterCase('Привет'));
  Assert.AreEqual('А', InvertLetterCase('а'));
  Assert.AreEqual('а', InvertLetterCase('А'));
  Assert.AreEqual('HELLO', InvertLetterCase('hello'));
  Assert.AreEqual('hello', InvertLetterCase('HELLO'));
  Assert.AreEqual('hELLO', InvertLetterCase('Hello'));
  Assert.AreEqual('пРИВЕТ МИР', InvertLetterCase('Привет мир'));
  Assert.AreEqual('ё', InvertLetterCase('Ё'));
  Assert.AreEqual('123', InvertLetterCase('123'));
  Assert.AreEqual('', InvertLetterCase(''));
  Assert.AreEqual('Привет', InvertLetterCase(InvertLetterCase('Привет')));
end;

procedure TAnalyzerTests.CountsCaretStepsAcrossLineBreaks;
begin
  Assert.AreEqual(0, CaretStepCount(''));
  Assert.AreEqual(3, CaretStepCount('abc'));
  Assert.AreEqual(3, CaretStepCount('a'#13#10'b'));
  Assert.AreEqual(3, CaretStepCount('a'#10'b'));
  Assert.AreEqual(3, CaretStepCount('a'#13'b'));
  Assert.AreEqual(2, CaretStepCount(#13#10#13#10));
  Assert.AreEqual(4, CaretStepCount(#13#10#13#10'ab'));
  Assert.AreEqual(1, CaretStepCount(Char($D83D) + Char($DE00)));
  Assert.AreEqual('a'#10'b'#10#10'c', NormalizeLineBreaks('a'#13#10'b'#13#13#10'c'));
  Assert.AreEqual(NormalizeLineBreaks('x'#13#10'y'), NormalizeLineBreaks('x'#10'y'));
end;

procedure TAnalyzerTests.FixesTwoInitialCapitalsOnly;
var
  Fixed: string;
begin
  Assert.IsTrue(TryFixInitialCapitals('ТОлько', Fixed));
  Assert.AreEqual('Только', Fixed);
  Assert.IsTrue(TryFixInitialCapitals('ПРивет', Fixed));
  Assert.AreEqual('Привет', Fixed);
  Assert.IsTrue(TryFixInitialCapitals('HEllo', Fixed));
  Assert.AreEqual('Hello', Fixed);

  // Correct words, acronyms and CamelCase names stay as they are.
  Assert.IsFalse(TryFixInitialCapitals('Только', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('только', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('ТОЛЬКО', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('США', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('HTTP', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('TForm', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('IUnknown', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('ПРиветМир', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('XMLParser', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('iPhone', Fixed));
  // Too short, mixed alphabets, digits and separators are never touched.
  Assert.IsFalse(TryFixInitialCapitals('ТВо', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('ТОлькоabc', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('ТОлько1', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('ТОлько-то', Fixed));
  Assert.IsFalse(TryFixInitialCapitals('', Fixed));
end;

procedure TAnalyzerTests.FixesWordTypedWithCapsLock;
var
  Fixed: string;
begin
  Assert.IsTrue(TryFixCapsLockWord('пРИВЕТ', Fixed));
  Assert.AreEqual('Привет', Fixed);
  Assert.IsTrue(TryFixCapsLockWord('hELLO', Fixed));
  Assert.AreEqual('Hello', Fixed);
  Assert.IsTrue(TryFixCapsLockWord('тЕСТ', Fixed));
  Assert.AreEqual('Тест', Fixed);

  Assert.IsFalse(TryFixCapsLockWord('Привет', Fixed));
  Assert.IsFalse(TryFixCapsLockWord('привет', Fixed));
  Assert.IsFalse(TryFixCapsLockWord('ПРИВЕТ', Fixed));
  Assert.IsFalse(TryFixCapsLockWord('iOS', Fixed));
  Assert.IsFalse(TryFixCapsLockWord('пРИВетт', Fixed));
  Assert.IsFalse(TryFixCapsLockWord('пРИВЕТ1', Fixed));
  Assert.IsFalse(TryFixCapsLockWord('пРИВ-ЕТ', Fixed));
  Assert.IsFalse(TryFixCapsLockWord('', Fixed));
end;

procedure TAnalyzerTests.SwitchesFileExtensionTypedOnRussianLayout;
var
  Mode: THeuristicMode;
  Analysis: TAnalysisResult;
begin
  for Mode := Low(THeuristicMode) to High(THeuristicMode) do
  begin
    Analysis := AnalyzeWord('юзва', lkRU, Mode, nil);
    Assert.IsTrue(Analysis.NeedsSwitch);
    Assert.AreEqual('.pdf', Analysis.ConvertedText);
    Assert.AreEqual(Integer(lkEN), Integer(Analysis.TargetLang));
  end;
  Assert.AreEqual('.docx', AnalyzeWord('ювщсч', lkRU).ConvertedText);
  // A Russian word that only starts with "ю" is not an extension.
  Assert.IsFalse(AnalyzeWord('юбилей', lkRU).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('юг', lkRU).NeedsSwitch);
end;

procedure TAnalyzerTests.ProtectsTechnicalTokensAndAbbreviations;
begin
  Assert.IsFalse(AnalyzeWord('user_name', lkEN).NeedsSwitch);
  Assert.AreEqual(Ord(dmLeave), Ord(AnalyzeWord('user_name', lkEN).Mark));
  Assert.IsFalse(AnalyzeWord('test@example.com', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('folder/file', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('abc123', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('API', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('OK.', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('IT.', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('AT.', lkEN).NeedsSwitch);
end;

procedure TAnalyzerTests.ConvertsRussianTailAfterEnglishPrefix;
var
  Analysis: TAnalysisResult;
begin
  // dev-c,jhrf -> dev-сборка: "dev" stays, "c" + "," is "сб", "jhrf" is "орка".
  Analysis := AnalyzeWord('dev', lkEN);
  Assert.IsFalse(Analysis.NeedsSwitch);

  Analysis := AnalyzeWord('c', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('с', Analysis.ConvertedText);
  Assert.AreEqual('б', ConvertCharSwap(','));

  Analysis := AnalyzeWord('jhrf', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('орка', Analysis.ConvertedText);

  Analysis := AnalyzeWord('http', lkEN);
  Assert.IsFalse(Analysis.NeedsSwitch);
  Analysis := AnalyzeWord('https', lkEN);
  Assert.IsFalse(Analysis.NeedsSwitch);
end;

procedure TAnalyzerTests.UsesHigherMarginForUnknownLayout;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('ghbdtn', lkUnknown);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual(Integer(lkRU), Integer(Analysis.TargetLang));

  Analysis := AnalyzeWord('hello', lkUnknown);
  Assert.IsFalse(Analysis.NeedsSwitch);
end;

procedure TInputBufferTests.TracksTextAndBackspace;
var
  Buffer: TInputBuffer;
begin
  Buffer := TInputBuffer.Create;
  try
    Buffer.AddChar('a', lkEN);
    Buffer.AddChar('b', lkEN);
    Buffer.RemoveLastChar;

    Assert.AreEqual('a', Buffer.BufferText);
    Assert.AreEqual(1, Buffer.BufferLength);
    Assert.IsFalse(Buffer.IsEmpty);
  finally
    Buffer.Free;
  end;
end;

procedure TInputBufferTests.ClearResetsBuffer;
var
  Buffer: TInputBuffer;
begin
  Buffer := TInputBuffer.Create;
  try
    Buffer.AddChar('a', lkEN);
    Buffer.Clear;

    Assert.IsTrue(Buffer.IsEmpty);
    Assert.AreEqual(0, Buffer.BufferLength);
    Assert.AreEqual(Integer(lkUnknown), Integer(Buffer.InputLang));
  finally
    Buffer.Free;
  end;
end;

procedure TLeftShiftStateTests.HeldKeyDoesNotBecomeDoublePress;
var
  IsDown: Boolean;
  LastPressTime: UInt64;
  Transition: TLeftShiftTransition;
begin
  IsDown := False;
  LastPressTime := 0;

  Transition := TrackLeftShiftState(IsDown, True, False);
  Assert.AreEqual(Integer(lstPressed), Integer(Transition));
  Assert.IsFalse(IsDoubleLeftShift(LastPressTime, 1000, 0, 650));

  Transition := TrackLeftShiftState(IsDown, True, False);
  Assert.AreEqual(Integer(lstRepeated), Integer(Transition));
  Assert.AreEqual(UInt64(1000), LastPressTime);
end;

procedure TLeftShiftStateTests.TwoSeparatePressesBecomeDoublePress;
var
  IsDown: Boolean;
  LastPressTime: UInt64;
begin
  IsDown := False;
  LastPressTime := 0;

  Assert.AreEqual(Integer(lstPressed), Integer(TrackLeftShiftState(IsDown, True, False)));
  Assert.IsFalse(IsDoubleLeftShift(LastPressTime, 1000, 0, 650));
  Assert.AreEqual(Integer(lstReleased), Integer(TrackLeftShiftState(IsDown, False, True)));
  Assert.AreEqual(Integer(lstPressed), Integer(TrackLeftShiftState(IsDown, True, False)));

  Assert.IsTrue(IsDoubleLeftShift(LastPressTime, 1200, 0, 650));
  Assert.AreEqual(UInt64(0), LastPressTime);
end;

procedure TLeftShiftStateTests.VeryFastDoublePressIsAccepted;
var
  LastPressTime: UInt64;
begin
  LastPressTime := 0;
  Assert.IsFalse(IsDoubleLeftShift(LastPressTime, 1000, 0, 650));
  Assert.IsTrue(IsDoubleLeftShift(LastPressTime, 1000, 0, 650));
  Assert.AreEqual(UInt64(0), LastPressTime);

  LastPressTime := 0;
  Assert.IsFalse(IsDoubleLeftShift(LastPressTime, 2000, 0, 650));
  Assert.IsTrue(IsDoubleLeftShift(LastPressTime, 2015, 0, 650));
end;

procedure TLeftShiftStateTests.SlowDoublePressIsRejected;
var
  LastPressTime: UInt64;
begin
  LastPressTime := 0;
  Assert.IsFalse(IsDoubleLeftShift(LastPressTime, 1000, 0, 650));
  Assert.IsFalse(IsDoubleLeftShift(LastPressTime, 1700, 0, 650));
  Assert.AreEqual(UInt64(1700), LastPressTime);
end;

procedure TLeftShiftStateTests.RecognizesRightShiftByScanCode;
begin
  Assert.IsTrue(IsRightShiftKey(VK_RSHIFT, 0));
  Assert.IsTrue(IsRightShiftKey(VK_SHIFT, $36));
  Assert.IsTrue(IsRightShiftKey(VK_SHIFT, $136));
  Assert.IsFalse(IsRightShiftKey(VK_SHIFT, $2A));
  Assert.IsFalse(IsRightShiftKey(VK_LSHIFT, $2A));
  Assert.IsFalse(IsRightShiftKey(VK_LSHIFT, $36));
end;

procedure TSettingsTests.SavesAndLoadsAllSettings;
var
  Source: TSettings;
  Loaded: TSettings;
  ConfigPath: string;
  PreviousContent: TBytes;
  HadConfig: Boolean;
begin
  ConfigPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'config.json');
  HadConfig := TFile.Exists(ConfigPath);
  if HadConfig then
    PreviousContent := TFile.ReadAllBytes(ConfigPath);

  Source := TSettings.Create;
  Loaded := TSettings.Create;
  try
    Source.SoundOnRussianInput := False;
    Source.SoundOnSwitch := False;
    Source.SoundVolume := 75;
    Source.DoubleLeftShiftEnabled := False;
    Source.AutoSwitchEnabled := False;
    Source.AutoStart := True;
    Source.ClearExclusions;
    Source.AddExclusion('example.exe');
    Source.SaveToFile;

    Loaded.LoadFromFile;

    Assert.IsFalse(Loaded.SoundOnRussianInput);
    Assert.IsFalse(Loaded.SoundOnSwitch);
    Assert.AreEqual(75, Loaded.SoundVolume);
    Source.SoundVolume := 500;
    Assert.AreEqual(SoundVolumeMax, Source.SoundVolume);
    Source.SoundVolume := -3;
    Assert.AreEqual(0, Source.SoundVolume);
    Source.SoundVolume := 75;
    Assert.IsFalse(Loaded.DoubleLeftShiftEnabled);
    Assert.IsFalse(Loaded.SwitchLayoutAfterSelection);
    Assert.IsFalse(Loaded.AutoSwitchEnabled);
    Assert.IsTrue(Loaded.AutoStart);
    Assert.AreEqual(14, Loaded.CaretHintOffsetX);
    Assert.AreEqual(18, Loaded.CaretHintOffsetY);
    Source.CaretHintOffsetX := -8;
    Source.CaretHintOffsetY := 40;
    Source.SaveToFile;
    Loaded.LoadFromFile;
    Assert.AreEqual(-8, Loaded.CaretHintOffsetX);
    Assert.AreEqual(40, Loaded.CaretHintOffsetY);
    Assert.AreEqual(Integer(chTimed), Integer(Loaded.CaretHintMode));
    Source.CaretHintMode := chFollow;
    Source.SaveToFile;
    Loaded.LoadFromFile;
    Assert.AreEqual(Integer(chFollow), Integer(Loaded.CaretHintMode));
    Assert.IsTrue(Loaded.IsProcessExcluded('C:\Apps\example.exe'));
  finally
    Loaded.Free;
    Source.Free;
    if HadConfig then
      TFile.WriteAllBytes(ConfigPath, PreviousContent)
    else
      TFile.Delete(ConfigPath);
  end;
end;

procedure TSettingsTests.PersistsInitialCapsOptions;
var
  Source: TSettings;
  Loaded: TSettings;
  ConfigPath: string;
  PreviousContent: TBytes;
  HadConfig: Boolean;
begin
  ConfigPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'config.json');
  HadConfig := TFile.Exists(ConfigPath);
  if HadConfig then
    PreviousContent := TFile.ReadAllBytes(ConfigPath);

  Source := TSettings.Create;
  Loaded := TSettings.Create;
  try
    Assert.IsTrue(Source.FixInitialCaps);
    Assert.IsFalse(Source.IsCaseFixKept('Только'));
    Source.KeepCaseFixWord('ТОлько');
    Assert.IsTrue(Source.IsCaseFixKept('только'));
    Assert.IsTrue(Source.IsCaseFixKept('Только'));
    Source.FixInitialCaps := False;
    Source.FixCapsLock := False;
    Source.SaveToFile;

    Loaded.LoadFromFile;
    Assert.IsFalse(Loaded.FixInitialCaps);
    Assert.IsFalse(Loaded.FixCapsLock);
    Assert.IsTrue(Loaded.IsCaseFixKept('только'));
    Assert.IsFalse(Loaded.IsCaseFixKept('привет'));
  finally
    Loaded.Free;
    Source.Free;
    if HadConfig then
      TFile.WriteAllBytes(ConfigPath, PreviousContent)
    else
      TFile.Delete(ConfigPath);
  end;
end;

procedure TSettingsTests.AlwaysExcludesPasswordManagers;
var
  Settings: TSettings;
begin
  Settings := TSettings.Create;
  try
    Settings.ClearExclusions;
    Assert.IsTrue(Settings.IsProcessExcluded('C:\Program Files\KeePass\KeePass.exe'));
    Assert.IsTrue(Settings.IsProcessExcluded('bitwarden.exe'));
    Assert.IsFalse(Settings.IsProcessExcluded('notepad.exe'));
    Assert.IsFalse(Settings.IsProcessExcluded('keepass-notes.exe'));
    Assert.IsTrue(Settings.PauseInFullscreen);
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.RecognizesFullscreenNotificationStates;
begin
  Assert.IsTrue(IsFullscreenNotificationState(QUNS_BUSY));
  Assert.IsTrue(IsFullscreenNotificationState(QUNS_RUNNING_D3D_FULL_SCREEN));
  Assert.IsTrue(IsFullscreenNotificationState(QUNS_PRESENTATION_MODE));
  Assert.IsFalse(IsFullscreenNotificationState(QUNS_ACCEPTS_NOTIFICATIONS));
  Assert.IsFalse(IsFullscreenNotificationState(QUNS_NOT_PRESENT));
end;

procedure TSettingsTests.DrawsBadgeBorderInADarkerShadeOfTheFill;
var
  Fill, Border: Integer;
begin
  Fill := Integer(BadgeColorFor(lkRU));
  Border := Integer(DarkerShade(BadgeColorFor(lkRU)));
  Assert.AreEqual(247, Fill and $FF);
  Assert.AreEqual(148, Border and $FF);
  Assert.AreEqual(91, (Border shr 8) and $FF);
  Assert.AreEqual(16, (Border shr 16) and $FF);
  Assert.IsTrue((Integer(DarkerShade(BadgeColorFor(lkEN))) and $FF) <
    (Integer(BadgeColorFor(lkEN)) and $FF));
  Assert.AreEqual(Integer($FFFFFF), Integer(BadgeInkFor(lkEN)));
  Assert.AreEqual(0, Integer(BadgeInkFor(lkRU)));
  Assert.AreNotEqual(Integer(BadgeColorFor(lkRU)), Integer(BadgeColorFor(lkEN)));
end;

procedure TSettingsTests.RecognizesEmailFieldLabels;
begin
  Assert.IsTrue(IsEmailFieldName('Email'));
  Assert.IsTrue(IsEmailFieldName('E-mail address'));
  Assert.IsTrue(IsEmailFieldName('  Email or phone'));
  Assert.IsTrue(IsEmailFieldName('Электронная почта'));
  Assert.IsTrue(IsEmailFieldName('Адрес электронной почты'));
  Assert.IsTrue(IsEmailFieldName('Почта'));
  // Search boxes and free text keep the Russian layout.
  Assert.IsFalse(IsEmailFieldName('Search mail'));
  Assert.IsFalse(IsEmailFieldName('Поиск в почте'));
  Assert.IsFalse(IsEmailFieldName('Адрес доставки'));
  Assert.IsFalse(IsEmailFieldName(''));
end;

procedure TSettingsTests.SupportsWildcardExclusionsAndRules;
var
  Settings: TSettings;
begin
  Settings := TSettings.Create;
  try
    Settings.ClearExclusions;
    Settings.AddExclusion('*terminal*.exe');
    Assert.IsTrue(Settings.IsProcessExcluded('C:\Apps\myterminal.exe'));
    Assert.IsFalse(Settings.IsProcessExcluded('C:\Apps\editor.exe'));
    Settings.SetApplicationRule('Editor.EXE', False);
    Assert.IsFalse(Settings.IsAutoSwitchEnabledFor('C:\Apps\editor.exe'));
    Settings.SetApplicationRule('editor.exe', True);
    Assert.IsTrue(Settings.IsAutoSwitchEnabledFor('editor.exe'));
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.PersistsLearningAndHeuristicMode;
var
  Settings: TSettings;
begin
  Settings := TSettings.Create;
  try
    Settings.HeuristicMode := hmAggressive;
    Settings.LearnNeverSwitch('Example');
    Assert.AreEqual(Integer(hmAggressive), Integer(Settings.HeuristicMode));
    Assert.IsTrue(Settings.IsNeverSwitchWord('example'));
    Settings.ResetLearning;
    Assert.IsFalse(Settings.IsNeverSwitchWord('example'));
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.LoadsLegacyRulesAndLearning;
var
  Path: string;
  Settings: TSettings;
  Saved: string;
begin
  Path := UniqueTestPath('legacy');
  TFile.WriteAllText(Path,
    '{"AutoSwitchEnabled":true,"ApplicationRules":{"legacy.exe":false},' +
    '"NeverSwitchWords":["Example"]}', TEncoding.UTF8);
  Settings := TSettings.Create(Path);
  try
    Settings.LoadFromFile;
    Assert.IsFalse(Settings.ResolveProfile('C:\legacy.exe').AutoSwitchEnabled);
    Assert.IsTrue(Settings.IsNeverSwitchWord('example'));
    Assert.AreEqual(3, Settings.LearningCount('EXAMPLE'));
    Settings.SaveToFile;
    Saved := TFile.ReadAllText(Path, TEncoding.UTF8);
    Assert.IsTrue(Saved.Contains('"SchemaVersion": 4'));
    Assert.IsTrue(Saved.Contains('"AutoSwitchEnabled": false'));
    Assert.IsTrue(Saved.Contains('"NeverSwitchLearning"'));
    Assert.IsTrue(Saved.Contains('"PreferSwitchLearning"'));
  finally
    Settings.Free;
    DeleteIfExists(Path);
    DeleteIfExists(Path + '.bak');
  end;
end;

procedure TSettingsTests.ResolvesStructuredApplicationProfiles;
var
  Path: string;
  Settings: TSettings;
  Loaded: TSettings;
  Profile: TApplicationProfile;
begin
  Path := UniqueTestPath('profiles');
  Settings := TSettings.Create(Path);
  Loaded := TSettings.Create(Path);
  try
    Settings.SetApplicationRuleOverrides('editor*.exe',
      True, False, True, False, True, False, True, hmAggressive);
    Settings.SaveToFile;
    Loaded.LoadFromFile;
    Profile := Loaded.ResolveProfile('C:\Apps\EditorPro.exe');
    Assert.IsFalse(Profile.AutoSwitchEnabled);
    Assert.IsFalse(Profile.SoundOnRussianInput);
    Assert.AreEqual(Integer(hmAggressive), Integer(Profile.HeuristicMode));
    Assert.IsFalse(Profile.SoundOnSwitch);
  finally
    Loaded.Free;
    Settings.Free;
    DeleteIfExists(Path);
    DeleteIfExists(Path + '.bak');
  end;
end;

procedure TSettingsTests.RequiresRepeatedWeakLearningSignals;
var
  Settings: TSettings;
begin
  Settings := TSettings.Create;
  try
    Settings.RecordLearning('"Example,"', False);
    Assert.AreEqual(1, Settings.LearningCount('example'));
    Assert.IsFalse(Settings.IsNeverSwitchWord('example'));
    Settings.RecordLearning('example', False);
    Assert.IsFalse(Settings.IsNeverSwitchWord('example'));
    Settings.RecordLearning('EXAMPLE', False);
    Assert.IsTrue(Settings.IsNeverSwitchWord('example'));
    Settings.RecordLearning('Immediate', True);
    Assert.IsTrue(Settings.IsNeverSwitchWord('immediate'));
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.KeptCorrectionForgetsWeakRejection;
var
  Settings: TSettings;
begin
  Settings := TSettings.Create;
  try
    Settings.RecordLearning('example', False);
    Settings.RecordLearning('example', False);
    Settings.ObserveLearning('example', laAccept);
    Assert.AreEqual(1, Settings.LearningCount('example'));
    Assert.IsFalse(Settings.IsNeverSwitchWord('example'));
    Settings.ObserveLearning('fresh', laAccept);
    Assert.AreEqual(0, Settings.LearningCount('fresh'));
    Assert.AreEqual(1, Settings.LearningEntryCount);
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.ManualSwitchOverturnsRejection;
var
  Settings: TSettings;
begin
  Settings := TSettings.Create;
  try
    Settings.LearnNeverSwitch('hello');
    Assert.IsTrue(Settings.IsNeverSwitchWord('hello'));
    Settings.ObserveLearning('hello', laManualSwitch);
    Assert.IsFalse(Settings.IsNeverSwitchWord('hello'));
    Assert.IsTrue(Settings.IsPreferSwitchWord('hello'));
    Settings.ObserveLearning('hello', laRejectStrong);
    Assert.IsTrue(Settings.IsNeverSwitchWord('hello'));
    Assert.IsFalse(Settings.IsPreferSwitchWord('hello'));
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.RepeatedRejectionRaisesScoreToTheCap;
var
  Settings: TSettings;
  I: Integer;
begin
  Settings := TSettings.Create;
  try
    for I := 1 to 30 do
      Settings.ObserveLearning('often', laRejectStrong);
    Assert.AreEqual(LearningScoreCap, Settings.LearningCount('often'));
    Assert.IsTrue(Settings.IsNeverSwitchWord('often'));
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.KeepsConfirmedWordsWhenTheTableIsFull;
var
  Settings: TSettings;
  I: Integer;
begin
  Settings := TSettings.Create;
  try
    Settings.ObserveLearning('keep', laRejectStrong);
    for I := 1 to 300 do
      Settings.RecordLearning('word' + IntToStr(I), False);
    Assert.IsTrue(Settings.LearningEntryCount <= MaxLearningEntries);
    Assert.IsTrue(Settings.IsNeverSwitchWord('keep'));
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.PersistsPreferSwitchLearning;
var
  Path: string;
  Settings, Loaded: TSettings;
  Saved: string;
begin
  Path := UniqueTestPath('prefer');
  Settings := TSettings.Create(Path);
  Loaded := TSettings.Create(Path);
  try
    Settings.ObserveLearning('ghbdtn', laManualSwitch);
    Settings.SaveToFile;
    Loaded.LoadFromFile;
    Assert.IsTrue(Loaded.IsPreferSwitchWord('ghbdtn'));
    Assert.IsFalse(Loaded.IsNeverSwitchWord('ghbdtn'));
    Saved := TFile.ReadAllText(Path, TEncoding.UTF8);
    Assert.IsTrue(Saved.Contains('"PreferSwitchLearning"'));
  finally
    Loaded.Free;
    Settings.Free;
    DeleteIfExists(Path);
    DeleteIfExists(Path + '.bak');
  end;
end;

procedure TSettingsTests.LoadsRejectAndPreferTogether;
var
  Path: string;
  Settings: TSettings;
begin
  Path := UniqueTestPath('both-learning');
  TFile.WriteAllText(Path,
    '{"NeverSwitchLearning":{"hello":4,"same":3},' +
    '"PreferSwitchLearning":{"hello":1,"same":3,"ghbdtn":3}}',
    TEncoding.UTF8);
  Settings := TSettings.Create(Path);
  try
    Settings.LoadFromFile;
    Assert.IsTrue(Settings.IsNeverSwitchWord('hello'));
    Assert.IsFalse(Settings.IsPreferSwitchWord('hello'));
    Assert.IsFalse(Settings.IsNeverSwitchWord('same'));
    Assert.IsFalse(Settings.IsPreferSwitchWord('same'));
    Assert.IsTrue(Settings.IsPreferSwitchWord('ghbdtn'));
  finally
    Settings.Free;
    DeleteIfExists(Path);
    DeleteIfExists(Path + '.bak');
  end;
end;

procedure TSettingsTests.ApplicationLearningOverridesTheSharedWord;
var
  Settings: TSettings;
begin
  Settings := TSettings.Create;
  try
    Settings.LearnNeverSwitch('hello');
    Assert.IsTrue(Settings.IsNeverSwitchWord('hello'));
    Assert.IsFalse(Settings.IsNeverSwitchWord('hello', 'chat.exe'));
    Settings.ObserveLearning('hello', laManualSwitch, 'C:\Apps\chat.exe');
    Assert.IsTrue(Settings.IsPreferSwitchWord('hello', 'chat.exe'));
    Assert.IsFalse(Settings.IsNeverSwitchWord('hello', 'chat.exe'));
    Assert.IsFalse(Settings.IsNeverSwitchWord('hello', 'code.exe'));
    Assert.IsTrue(Settings.IsNeverSwitchWord('hello'));
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.PinnedWordAppliesInEveryApplication;
var
  Path: string;
  Settings, Loaded: TSettings;
begin
  Path := UniqueTestPath('pinned');
  Settings := TSettings.Create(Path);
  Loaded := TSettings.Create(Path);
  try
    Settings.PinLearning('hello', '', False);
    Settings.PinLearning('ghbdtn', 'notepad.exe', True);
    Assert.IsTrue(Settings.IsNeverSwitchWord('hello', 'code.exe'));
    Assert.IsTrue(Settings.IsNeverSwitchWord('hello', 'notepad.exe'));
    Assert.IsTrue(Settings.IsPreferSwitchWord('ghbdtn', 'notepad.exe'));
    Assert.IsFalse(Settings.IsPreferSwitchWord('ghbdtn', 'code.exe'));
    Settings.PinLearning('hello', 'chat.exe', True);
    Assert.IsTrue(Settings.IsPreferSwitchWord('hello', 'chat.exe'));
    Assert.IsTrue(Settings.IsNeverSwitchWord('hello', 'code.exe'));
    Settings.SaveToFile;
    Loaded.LoadFromFile;
    Assert.IsTrue(Loaded.IsNeverSwitchWord('hello', 'paint.exe'));
    Assert.IsTrue(Loaded.IsPreferSwitchWord('ghbdtn', 'notepad.exe'));
  finally
    Loaded.Free;
    Settings.Free;
    DeleteIfExists(Path);
    DeleteIfExists(Path + '.bak');
  end;
end;

procedure TSettingsTests.RemovesOneExclusion;
var
  Settings: TSettings;
  Items: TArray<string>;
begin
  Settings := TSettings.Create;
  try
    Settings.ClearExclusions;
    Settings.AddExclusion('cmd.exe');
    Settings.AddExclusion('keep.exe');
    Settings.RemoveExclusion('cmd.exe');
    Assert.IsFalse(Settings.IsProcessExcluded('cmd.exe'));
    Assert.IsTrue(Settings.IsProcessExcluded('keep.exe'));
    Items := Settings.ListExclusions;
    Assert.AreEqual(1, Integer(Length(Items)));
    Assert.AreEqual('keep.exe', Items[0]);
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.ListsApplicationRules;
var
  Settings: TSettings;
  Rules: TArray<TApplicationRuleView>;
begin
  Settings := TSettings.Create;
  try
    Settings.SetApplicationRuleOverrides('NotePad.exe',
      True, False, True, False, False, False, True, hmCautious);
    Rules := Settings.ListApplicationRules;
    Assert.AreEqual(1, Integer(Length(Rules)));
    Assert.AreEqual('notepad.exe', Rules[0].Pattern);
    Assert.IsTrue(Rules[0].HasAutoSwitch);
    Assert.IsFalse(Rules[0].AutoSwitchEnabled);
    Assert.IsTrue(Rules[0].HasSoundOnRussianInput);
    Assert.IsFalse(Rules[0].SoundOnRussianInput);
    Assert.IsFalse(Rules[0].HasSoundOnSwitch);
    Assert.IsTrue(Rules[0].HasHeuristicMode);
    Assert.AreEqual(Ord(hmCautious), Ord(Rules[0].HeuristicMode));
    Settings.RemoveApplicationRule('notepad.exe');
    Assert.AreEqual(0, Integer(Length(Settings.ListApplicationRules)));
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.ForgetLearningRemovesOneEntry;
var
  Settings: TSettings;
  Items: TArray<TLearningView>;
begin
  Settings := TSettings.Create;
  try
    Settings.LearnNeverSwitch('hello');
    Settings.ObserveLearning('ghbdtn', laManualSwitch, 'notepad.exe');
    Items := Settings.ListLearning;
    Assert.AreEqual(2, Integer(Length(Items)));
    Settings.ForgetLearning('notepad.exe', 'ghbdtn');
    Assert.IsFalse(Settings.IsPreferSwitchWord('ghbdtn', 'notepad.exe'));
    Assert.IsTrue(Settings.IsNeverSwitchWord('hello'));
    Assert.AreEqual(1, Integer(Length(Settings.ListLearning)));
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.RecoversCorruptConfiguration;
var
  Path: string;
  BackupPath: string;
  Settings: TSettings;
  CorruptFiles: TArray<string>;
  FileName: string;
begin
  Path := UniqueTestPath('config');
  BackupPath := Path + '.bak';
  TFile.WriteAllText(Path, '{broken', TEncoding.UTF8);
  TFile.WriteAllText(BackupPath, '{"AutoSwitchEnabled":false}',
    TEncoding.UTF8);
  Settings := TSettings.Create(Path);
  try
    Settings.LoadFromFile;
    Assert.IsFalse(Settings.AutoSwitchEnabled);
    CorruptFiles := TDirectory.GetFiles(ExtractFilePath(Path),
      ChangeFileExt(ExtractFileName(Path), '') + '.corrupt-*.json');
    Assert.IsTrue(Length(CorruptFiles) > 0);
  finally
    Settings.Free;
    DeleteIfExists(Path);
    DeleteIfExists(BackupPath);
    for FileName in CorruptFiles do
      DeleteIfExists(FileName);
  end;
end;

procedure TSettingsTests.BoundsLearningEntries;
var
  Settings: TSettings;
  I: Integer;
begin
  Settings := TSettings.Create;
  try
    for I := 1 to 300 do
      Settings.RecordLearning('word' + IntToStr(I), False);
    Assert.IsTrue(Settings.LearningEntryCount <= 256);
  finally
    Settings.Free;
  end;
end;

procedure TSettingsTests.CleansTemporaryFileAfterSaveFailure;
var
  Path: string;
  Settings: TSettings;
  RaisedError: Boolean;
begin
  Path := UniqueTestPath('save-failure');
  TDirectory.CreateDirectory(Path);
  Settings := TSettings.Create(Path);
  try
    RaisedError := False;
    try
      Settings.SaveToFile;
    except
      RaisedError := True;
    end;
    Assert.IsTrue(RaisedError);
    Assert.IsFalse(TFile.Exists(Path + '.tmp'));
  finally
    Settings.Free;
    if TDirectory.Exists(Path) then
      TDirectory.Delete(Path);
  end;
end;

procedure TSettingsTests.SupportsConcurrentReadLearnAndSave;
var
  Path: string;
  Settings: TSettings;
  Threads: array[0..3] of TThread;
  I: Integer;
  Failures: Integer;
begin
  Path := UniqueTestPath('concurrent');
  Settings := TSettings.Create(Path);
  Failures := 0;
  Threads[0] := TThread.CreateAnonymousThread(
    procedure
    var
      N: Integer;
    begin
      try
        for N := 1 to 100 do
        begin
          Settings.RecordLearning('writer-a-' + IntToStr(N), False);
          Settings.SaveToFile;
        end;
      except
        TInterlocked.Increment(Failures);
      end;
    end);
  Threads[1] := TThread.CreateAnonymousThread(
    procedure
    var
      N: Integer;
    begin
      try
        for N := 1 to 100 do
        begin
          Settings.RecordLearning('writer-b-' + IntToStr(N), True);
          Settings.SaveToFile;
        end;
      except
        TInterlocked.Increment(Failures);
      end;
    end);
  Threads[2] := TThread.CreateAnonymousThread(
    procedure
    var
      N: Integer;
      Profile: TApplicationProfile;
      Learned: Boolean;
    begin
      try
        Learned := False;
        for N := 1 to 2000 do
        begin
          Profile := Settings.ResolveProfile('editor.exe');
          if Profile.AutoSwitchEnabled then
            Learned := Settings.IsNeverSwitchWord('writer-a-1');
          if Learned and (N < 0) then
            TInterlocked.Increment(Failures);
        end;
      except
        TInterlocked.Increment(Failures);
      end;
    end);
  Threads[3] := TThread.CreateAnonymousThread(
    procedure
    var
      N: Integer;
      Count: Integer;
      Excluded: Boolean;
    begin
      try
        for N := 1 to 2000 do
        begin
          Count := Settings.LearningCount('writer-b-1');
          Excluded := Settings.IsProcessExcluded('notepad.exe');
          if Excluded and (Count < 0) then
            TInterlocked.Increment(Failures);
        end;
      except
        TInterlocked.Increment(Failures);
      end;
    end);
  try
    for I := Low(Threads) to High(Threads) do
    begin
      Threads[I].FreeOnTerminate := False;
      Threads[I].Start;
    end;
    for I := Low(Threads) to High(Threads) do
      Threads[I].WaitFor;
    Assert.AreEqual(0, Failures);
  finally
    for I := Low(Threads) to High(Threads) do
      Threads[I].Free;
    Settings.Free;
    DeleteIfExists(Path);
    DeleteIfExists(Path + '.bak');
  end;
end;

procedure TInputQueueTests.DropsWorkForAnotherControlOrAnOldItem;
begin
  Assert.IsTrue(IsWorkItemCurrent(10, 10, 1000, 1500));
  Assert.IsTrue(IsWorkItemCurrent(0, 20, 1000, 1500));
  Assert.IsTrue(IsWorkItemCurrent(10, 0, 1000, 1500));
  Assert.IsFalse(IsWorkItemCurrent(10, 20, 1000, 1500));
  Assert.IsTrue(IsWorkItemCurrent(10, 10, 1000, 1000 + MaxWorkItemAgeMs));
  Assert.IsFalse(IsWorkItemCurrent(10, 10, 1000, 1001 + MaxWorkItemAgeMs));
  Assert.IsTrue(IsWorkItemCurrent(10, 10, 0, 999999));
end;

procedure TInputQueueTests.CapturesReplayOnlyWhilePending;
var
  Queue: TInputQueue;
  Work: TInputWorkItem;
  Input: TQueuedInput;
begin
  Queue := TInputQueue.Create;
  try
    Input.VirtualKey := Ord('A');
    Input.ScanCode := 0;
    Input.Flags := 0;
    Assert.IsFalse(Queue.TryCaptureReplay(Input));
    FillChar(Work, SizeOf(Work), 0);
    Work.Kind := iwReplaceWord;
    Queue.EnqueueWork(Work);
    Assert.IsTrue(Queue.TryCaptureReplay(Input));
  finally
    Queue.Free;
  end;
end;

procedure TInputQueueTests.PreservesReplayOrder;
var
  Queue: TInputQueue;
  Work: TInputWorkItem;
  Input: TQueuedInput;
begin
  Queue := TInputQueue.Create;
  try
    FillChar(Work, SizeOf(Work), 0);
    Queue.EnqueueWork(Work);
    Input.ScanCode := 0;
    Input.Flags := 0;
    Input.VirtualKey := Ord('A');
    Queue.TryCaptureReplay(Input);
    Input.VirtualKey := Ord('B');
    Queue.TryCaptureReplay(Input);
    Assert.IsTrue(Queue.TryDequeueWork(Work));
    Assert.IsTrue(Queue.TryDequeueReplay(Input));
    Assert.AreEqual(Integer(Ord('A')), Integer(Input.VirtualKey));
    Assert.IsTrue(Queue.TryDequeueReplay(Input));
    Assert.AreEqual(Integer(Ord('B')), Integer(Input.VirtualKey));
  finally
    Queue.Free;
  end;
end;

procedure TInputQueueTests.WorkWaitsForKeysTypedBeforeIt;
var
  Queue: TInputQueue;
  First, Second: TInputWorkItem;
  Input: TQueuedInput;
begin
  Queue := TInputQueue.Create;
  try
    FillChar(First, SizeOf(First), 0);
    First.OldWordLength := 1;
    Second := First;
    Second.OldWordLength := 2;
    Queue.EnqueueWork(First);
    Input.ScanCode := 0;
    Input.Flags := 0;
    Input.VirtualKey := Ord('A');
    Queue.TryCaptureReplay(Input);
    Queue.EnqueueWork(Second);
    Assert.IsTrue(Queue.TryDequeueWork(First));
    Assert.AreEqual(1, First.OldWordLength);
    // The second item was queued after the key, so the key goes first.
    Assert.IsFalse(Queue.TryDequeueWork(Second));
    Assert.IsTrue(Queue.TryDequeueReplay(Input));
    Assert.IsFalse(Queue.TryDequeueReplay(Input));
    Assert.IsTrue(Queue.TryDequeueWork(Second));
    Assert.AreEqual(2, Second.OldWordLength);
  finally
    Queue.Free;
  end;
end;

procedure TInputQueueTests.RecognizesOwnInputSignature;
begin
  Assert.IsTrue(IsOwnInput(GHBDTN_INPUT_SIGNATURE));
  Assert.IsFalse(IsOwnInput(0));
end;

procedure TInputQueueTests.CompletesAtomicallyAtReplayBoundary;
var
  Queue: TInputQueue;
  Work: TInputWorkItem;
  Input: TQueuedInput;
begin
  Queue := TInputQueue.Create;
  try
    FillChar(Work, SizeOf(Work), 0);
    Queue.EnqueueWork(Work);
    Assert.IsTrue(Queue.TryDequeueWork(Work));
    Input.VirtualKey := Ord('A');
    Input.ScanCode := 0;
    Input.Flags := 0;
    Assert.IsTrue(Queue.TryCaptureReplay(Input));
    Assert.IsFalse(Queue.TryCompleteIfIdle);
    Assert.IsTrue(Queue.TryDequeueReplay(Input));
    Assert.IsTrue(Queue.TryCompleteIfIdle);
    Assert.IsFalse(Queue.IsReplacementPending);
    Assert.IsFalse(Queue.TryCaptureReplay(Input));
  finally
    Queue.Free;
  end;
end;

procedure TInputQueueTests.CapturedReplaySignalsWorker;
var
  Queue: TInputQueue;
  Work: TInputWorkItem;
  Input: TQueuedInput;
begin
  Queue := TInputQueue.Create;
  try
    FillChar(Work, SizeOf(Work), 0);
    Queue.EnqueueWork(Work);
    Assert.AreEqual(Integer(wrSignaled),
      Integer(Queue.WaitForWork(0)));
    Assert.IsTrue(Queue.TryDequeueWork(Work));
    Input.VirtualKey := Ord('A');
    Input.ScanCode := 0;
    Input.Flags := 0;
    Assert.IsTrue(Queue.TryCaptureReplay(Input));
    Assert.AreEqual(Integer(wrSignaled),
      Integer(Queue.WaitForWork(0)));
  finally
    Queue.Free;
  end;
end;

procedure TInputQueueTests.BackgroundWorkDoesNotCaptureInput;
var
  Queue: TInputQueue;
  Work: TInputWorkItem;
  Input: TQueuedInput;
begin
  Queue := TInputQueue.Create;
  try
    FillChar(Work, SizeOf(Work), 0);
    Work.Kind := iwPersistSettings;
    Queue.EnqueueWork(Work);
    Assert.IsFalse(Queue.IsReplacementPending);
    Input.VirtualKey := Ord('A');
    Input.ScanCode := 0;
    Input.Flags := 0;
    Assert.IsFalse(Queue.TryCaptureReplay(Input));
    Assert.IsTrue(Queue.TryDequeueBackground(Work));
  finally
    Queue.Free;
  end;
end;

procedure TDiagnosticsTests.OffDoesNotCreateLog;
var
  Path: string;
begin
  Path := UniqueTestPath('diagnostics');
  DeleteIfExists(Path);
  ConfigureDiagnostics(Path, dlOff);
  LogDiagnostic(dlError, deWorkerFailure, 123);
  Assert.IsFalse(TFile.Exists(Path));
end;

procedure TDiagnosticsTests.ReleaseClampsEffectiveLevel;
var
  Path: string;
begin
  Path := UniqueTestPath('diagnostics-level');
  ConfigureDiagnostics(Path, dlVerbose);
{$IFDEF RELEASE}
  Assert.AreEqual(Integer(dlError), Integer(EffectiveDiagnosticsLevel));
{$ELSE}
  Assert.AreEqual(Integer(dlVerbose), Integer(EffectiveDiagnosticsLevel));
{$ENDIF}
  LogDiagnostic(dlError, deWorkerFailure, 7);
  Assert.IsTrue(TFile.Exists(Path));
  DeleteIfExists(Path);
  ConfigureDiagnostics('', dlOff);
end;

procedure TDiagnosticsTests.VerboseLogsHeuristicDecision;
var
  Path, Text: string;
begin
  Path := UniqueTestPath('heuristic-log');
  DeleteIfExists(Path);
  ConfigureDiagnostics(Path, dlVerbose);
  try
    Assert.IsTrue(AnalyzeWord('ghbdtn', lkEN).NeedsSwitch);
    Assert.IsFalse(AnalyzeWord('user_name', lkEN).NeedsSwitch);
    Text := TFile.ReadAllText(Path, TEncoding.UTF8);
    Assert.IsTrue(Text.Contains('event=heuristic_decision'));
    Assert.IsTrue(Text.Contains('word="ghbdtn"'));
    Assert.IsTrue(Text.Contains('reason=score'));
    Assert.IsTrue(Text.Contains('switch=1'));
    Assert.IsTrue(Text.Contains('target=RU'));
    Assert.IsTrue(Text.Contains('RU_cost='));
    Assert.IsTrue(Text.Contains('reason=protected'));
    Assert.IsTrue(Text.Contains('word="user_name"'));
  finally
    ConfigureDiagnostics('', dlOff);
    DeleteIfExists(Path);
  end;
end;

procedure TDiagnosticsTests.InfoSkipsHeuristicDecision;
var
  Path: string;
begin
  Path := UniqueTestPath('heuristic-quiet');
  DeleteIfExists(Path);
  ConfigureDiagnostics(Path, dlInfo);
  try
    Assert.IsTrue(AnalyzeWord('ghbdtn', lkEN).NeedsSwitch);
    Assert.IsFalse(TFile.Exists(Path));
  finally
    ConfigureDiagnostics('', dlOff);
    DeleteIfExists(Path);
  end;
end;

procedure TDiagnosticsTests.SupportsConcurrentLoggingAndConfiguration;
var
  Path: string;
  Writer: TThread;
  Configurer: TThread;
  Failures: Integer;
begin
  Path := UniqueTestPath('diagnostics-concurrent');
  Failures := 0;
  ConfigureDiagnostics(Path, dlVerbose);
  Writer := TThread.CreateAnonymousThread(
    procedure
    var
      I: Integer;
    begin
      try
        for I := 1 to 1000 do
          LogDiagnostic(dlError, deWorkerFailure, I);
      except
        TInterlocked.Increment(Failures);
      end;
    end);
  Configurer := TThread.CreateAnonymousThread(
    procedure
    var
      I: Integer;
    begin
      try
        for I := 1 to 1000 do
          if Odd(I) then
            ConfigureDiagnostics(Path, dlInfo)
          else
            ConfigureDiagnostics(Path, dlVerbose);
      except
        TInterlocked.Increment(Failures);
      end;
    end);
  try
    Writer.FreeOnTerminate := False;
    Configurer.FreeOnTerminate := False;
    Writer.Start;
    Configurer.Start;
    Writer.WaitFor;
    Configurer.WaitFor;
    Assert.AreEqual(0, Failures);
  finally
    Writer.Free;
    Configurer.Free;
    ConfigureDiagnostics('', dlOff);
    DeleteIfExists(Path);
    DeleteIfExists(Path + '.1');
    DeleteIfExists(Path + '.2');
  end;
end;

procedure TSingleInstanceTests.OnlyFirstGuardIsPrimary;
var
  Name: string;
  First: TSingleInstanceGuard;
  Second: TSingleInstanceGuard;
begin
  Name := 'Local\Ghbdtn.Tests.' + TGUID.NewGuid.ToString;
  First := TSingleInstanceGuard.Create(Name);
  try
    Second := TSingleInstanceGuard.Create(Name);
    try
      Assert.IsTrue(First.IsPrimary);
      Assert.IsFalse(Second.IsPrimary);
    finally
      Second.Free;
    end;
  finally
    First.Free;
  end;
end;

procedure THookHelperTests.CountsMinutesLeftOnATimedPause;
begin
  Assert.AreEqual(30, PauseMinutesLeft(1800000, 0));
  Assert.AreEqual(30, PauseMinutesLeft(1800000, 1));
  Assert.AreEqual(1, PauseMinutesLeft(60000, 0));
  Assert.AreEqual(1, PauseMinutesLeft(1, 0));
  Assert.AreEqual(29, PauseMinutesLeft(1800000, 60000));
  Assert.AreEqual(0, PauseMinutesLeft(1000, 1000));
  Assert.AreEqual(0, PauseMinutesLeft(1000, 2000));
end;

procedure THookHelperTests.LearningWindowExpires;
begin
  Assert.IsTrue(IsWithinLearningWindow(1000, 3999, 3000));
  Assert.IsTrue(IsWithinLearningWindow(1000, 4000, 3000));
  Assert.IsFalse(IsWithinLearningWindow(1000, 4001, 3000));
  Assert.IsFalse(IsWithinLearningWindow(0, 1000, 3000));
  Assert.IsFalse(IsWithinLearningWindow(2000, 1000, 3000));
end;

procedure THookHelperTests.RejectsOwnAndShellTargets;
begin
  Assert.IsFalse(IsUsableExternalTarget(42, 42, 'EditorWindow'));
  Assert.IsFalse(IsUsableExternalTarget(100, 42, 'Shell_TrayWnd'));
  Assert.IsFalse(IsUsableExternalTarget(100, 42, 'WorkerW'));
  Assert.IsTrue(IsUsableExternalTarget(100, 42, 'CabinetWClass'));
end;

procedure THookHelperTests.ColonAfterOneLetterDoesNotSwitch;
begin
  Assert.IsTrue(ColonEndsASingleLetter('C', ':'));
  Assert.IsTrue(ColonEndsASingleLetter('d', ':'));
  Assert.IsFalse(ColonEndsASingleLetter('dev', ':'));
  Assert.IsFalse(ColonEndsASingleLetter('C', '-'));
  Assert.IsFalse(ColonEndsASingleLetter('', ':'));
end;

procedure THookHelperTests.DetectsPasswordControlStyle;
begin
  Assert.IsTrue(LooksLikePasswordControl(ES_PASSWORD, 0));
  Assert.IsTrue(LooksLikePasswordControl(0, Ord('*')));
  Assert.IsFalse(LooksLikePasswordControl(0, 0));
end;

procedure THookHelperTests.SkipsAutomationProbeForClassicEdits;
begin
  Assert.IsTrue(IsClassicEditClass('Edit'));
  Assert.IsTrue(IsClassicEditClass('RichEdit20W'));
  Assert.IsFalse(AutomationPasswordProbeApplies('Edit'));
  Assert.IsFalse(AutomationPasswordProbeApplies('RICHEDIT50W'));
  Assert.IsTrue(AutomationPasswordProbeApplies('Chrome_RenderWidgetHostHWND'));
  Assert.IsTrue(AutomationPasswordProbeApplies(''));
end;

procedure TUpdateTests.ParsesVersionWithOptionalPrefixAndBuild;
var
  Major, Minor, Patch, Build: Integer;
begin
  Assert.IsTrue(TryParseVersion('v0.2.0', Major, Minor, Patch, Build));
  Assert.AreEqual(0, Major);
  Assert.AreEqual(2, Minor);
  Assert.AreEqual(0, Patch);
  Assert.AreEqual(0, Build);

  Assert.IsTrue(TryParseVersion('1.2.3.4', Major, Minor, Patch, Build));
  Assert.AreEqual(1, Major);
  Assert.AreEqual(4, Build);

  Assert.IsFalse(TryParseVersion('', Major, Minor, Patch, Build));
  Assert.IsFalse(TryParseVersion('v', Major, Minor, Patch, Build));
  Assert.IsFalse(TryParseVersion('1.2.3.4.5', Major, Minor, Patch, Build));
  Assert.IsFalse(TryParseVersion('1.a.0', Major, Minor, Patch, Build));
end;

procedure TUpdateTests.TreatsAHigherReleaseAsNewer;
begin
  Assert.IsTrue(IsNewerVersion('0.2.0', '0.1.0'));
  Assert.IsTrue(IsNewerVersion('v0.2.0', '0.1.0.0'));
  Assert.IsTrue(IsNewerVersion('1.0.0', '0.9.9'));
  Assert.IsTrue(IsNewerVersion('0.2.0.1', '0.2.0'));
  Assert.IsFalse(IsNewerVersion('0.1.0', '0.1.0.0'));
  Assert.IsFalse(IsNewerVersion('v0.1.0', '0.1.0'));
  Assert.IsFalse(IsNewerVersion('0.1.0', '0.2.0'));
  Assert.IsFalse(IsNewerVersion('', '0.1.0'));
  Assert.IsFalse(IsNewerVersion('0.2.0', ''));
end;

const
  cSampleRelease =
    '{' +
    '"tag_name":"v0.2.0",' +
    '"draft":false,' +
    '"prerelease":false,' +
    '"html_url":"https://github.com/Laex/Ghbdtn/releases/tag/v0.2.0",' +
    '"assets":[' +
    '{"name":"notes.txt","browser_download_url":"https://example.invalid/notes","size":1},' +
    '{"name":"Ghbdtn-v0.2.0-win64.zip",' +
    '"browser_download_url":"https://example.invalid/Ghbdtn-v0.2.0-win64.zip",' +
    '"size":12345,' +
    '"digest":"sha256:ABCDEF"}' +
    ']}';

procedure TUpdateTests.ParsesTheWin64ReleasePackage;
var
  Release: TUpdateRelease;
begin
  Assert.IsTrue(ParseLatestReleaseJson(cSampleRelease, Release));
  Assert.AreEqual('v0.2.0', Release.Tag);
  Assert.AreEqual('0.2.0', Release.Version);
  Assert.AreEqual('Ghbdtn-v0.2.0-win64.zip', Release.AssetName);
  Assert.AreEqual('https://example.invalid/Ghbdtn-v0.2.0-win64.zip', Release.AssetUrl);
  Assert.AreEqual<Int64>(12345, Release.AssetSize);
  Assert.AreEqual('abcdef', Release.AssetSha256);
end;

procedure TUpdateTests.RejectsDraftPrereleaseAndOtherAssets;
var
  Release: TUpdateRelease;
begin
  Assert.IsFalse(ParseLatestReleaseJson(
    StringReplace(cSampleRelease, '"draft":false', '"draft":true', []), Release));
  Assert.IsFalse(ParseLatestReleaseJson(
    StringReplace(cSampleRelease, '"prerelease":false', '"prerelease":true', []), Release));
  Assert.IsFalse(ParseLatestReleaseJson(
    StringReplace(cSampleRelease, 'Ghbdtn-v0.2.0-win64.zip',
      'Ghbdtn-v0.2.0-win64-portable.zip', [rfReplaceAll]), Release));
  Assert.IsFalse(ParseLatestReleaseJson('{', Release));
  Assert.IsFalse(ParseLatestReleaseJson('{}', Release));
end;

procedure TUpdateTests.FindsTheChecksumAssetOfThePackage;
var
  Release: TUpdateRelease;
  Json: string;
begin
  Json := StringReplace(cSampleRelease, ',"digest":"sha256:ABCDEF"}',
    '},{"name":"Ghbdtn-v0.2.0-win64.zip.sha256",' +
    '"browser_download_url":"https://example.invalid/sum"}', []);
  Assert.IsTrue(ParseLatestReleaseJson(Json, Release));
  Assert.AreEqual('', Release.AssetSha256);
  Assert.AreEqual('https://example.invalid/sum', Release.ChecksumUrl);
  Assert.AreEqual('https://example.invalid/Ghbdtn-v0.2.0-win64.zip',
    Release.AssetUrl);
end;

procedure TUpdateTests.ChoosesQuietCheckOnlyForTheMarker;
begin
  Assert.IsTrue(UpdatePromptMode(False, False) = upNone);
  Assert.IsTrue(UpdatePromptMode(True, False) = upInteractive);
  Assert.IsTrue(UpdatePromptMode(True, True) = upInteractive);
  Assert.IsTrue(UpdatePromptMode(False, True) = upQuiet);
end;

procedure TUpdateTests.ParsesChecksumFiles;
const
  Hash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
begin
  Assert.AreEqual(Hash, ParseChecksumText(Hash + ' *a.zip' + #13#10, 'a.zip'));
  Assert.AreEqual(Hash, ParseChecksumText(UpperCase(Hash), 'a.zip'));
  Assert.AreEqual(Hash, ParseChecksumText(
    StringOfChar('f', 64) + '  other.zip' + #10 + Hash + '  a.zip', 'a.zip'));
  Assert.AreEqual('', ParseChecksumText(Hash + '  other.zip', 'a.zip'));
  Assert.AreEqual('', ParseChecksumText('not a hash', 'a.zip'));
  Assert.AreEqual('', ParseChecksumText(StringOfChar('g', 64), 'a.zip'));
  Assert.AreEqual('', ParseChecksumText('', 'a.zip'));
end;

procedure TPhraseTests.OneRecentWordAddsNoBias;
var
  Phrase: TPhraseContext;
begin
  Phrase := PhraseOf([lkRU]);
  Assert.AreEqual(0, PhraseScoreBias(Phrase, lkRU));
  Assert.AreEqual(0, PhraseScoreBias(Phrase, lkEN));
  RememberPhraseLanguage(Phrase, lkUnknown);
  Assert.AreEqual(1, Phrase.Count);
end;

procedure TPhraseTests.TwoMatchingWordsBiasThatLanguage;
var
  Phrase: TPhraseContext;
begin
  Phrase := PhraseOf([lkRU, lkEN, lkRU]);
  Assert.AreEqual(2 * PhraseBiasUnit, PhraseScoreBias(Phrase, lkRU));
  Assert.AreEqual(0, PhraseScoreBias(Phrase, lkEN));
end;

procedure TPhraseTests.ThreeMatchingWordsRaiseTheBias;
var
  Phrase: TPhraseContext;
begin
  Phrase := PhraseOf([lkEN, lkEN, lkEN]);
  Assert.AreEqual(PhraseBiasCap, PhraseScoreBias(Phrase, lkEN));
  Assert.AreEqual(0, PhraseScoreBias(Phrase, lkRU));
  Phrase := PhraseOf([lkEN, lkEN, lkEN, lkEN, lkEN]);
  Assert.AreEqual(PhraseBiasCap, PhraseScoreBias(Phrase, lkEN));
end;

procedure TPhraseTests.WindowDropsTheOldestWord;
var
  Phrase: TPhraseContext;
begin
  Phrase := PhraseOf([lkRU, lkEN, lkEN, lkEN, lkEN, lkEN]);
  Assert.AreEqual(PhraseWindow, Phrase.Count);
  Assert.AreEqual(0, PhraseScoreBias(Phrase, lkRU));
  Assert.AreEqual(PhraseBiasCap, PhraseScoreBias(Phrase, lkEN));
end;

procedure TLearningTests.SmallEditIsNotARejection;
var
  Action: TLearningAction;
begin
  Assert.IsFalse(BackspaceLearningAction(0, 10, Action));
  Assert.IsFalse(BackspaceLearningAction(2, 10, Action));
  Assert.IsFalse(BackspaceLearningAction(3, 10, Action));
end;

procedure TLearningTests.HalfOfALongFixIsAWeakRejection;
var
  Action: TLearningAction;
begin
  Assert.IsTrue(BackspaceLearningAction(5, 10, Action));
  Assert.AreEqual(Ord(laRejectWeak), Ord(Action));
  Assert.IsTrue(BackspaceLearningAction(3, 4, Action));
  Assert.AreEqual(Ord(laRejectWeak), Ord(Action));
end;

procedure TLearningTests.ErasingTheWholeFixIsAStrongRejection;
var
  Action: TLearningAction;
begin
  Assert.IsTrue(BackspaceLearningAction(2, 2, Action));
  Assert.AreEqual(Ord(laRejectStrong), Ord(Action));
  Assert.IsTrue(BackspaceLearningAction(1, 1, Action));
  Assert.AreEqual(Ord(laRejectStrong), Ord(Action));
  Assert.IsTrue(BackspaceLearningAction(10, 10, Action));
  Assert.AreEqual(Ord(laRejectStrong), Ord(Action));
end;

procedure TLearningTests.FullEraseAfterPartialEditPromotesOnce;
var
  Entry: TLearningEntry;
begin
  Entry := Default(TLearningEntry);
  Entry := ApplyLearningAction(Entry, laRejectWeak);
  Entry := ApplyLearningAction(Entry, laRejectStrong);
  Assert.AreEqual(LearningPromotionCount, Entry.Reject);
  Assert.AreEqual(0, Entry.Prefer);
  Assert.IsTrue(LearningBlocksSwitch(Entry));
end;

procedure TLearningTests.InflectedFormsShareALearnedStem;
var
  Settings: TSettings;
begin
  Assert.IsTrue(LearnedFormsMatch('машина', 'машины'));
  Assert.IsTrue(LearnedFormsMatch('привет', 'привета'));
  Assert.IsTrue(LearnedFormsMatch('vfibyf', 'vfibys'));
  Settings := TSettings.Create;
  try
    Settings.LearnNeverSwitch('машина');
    Assert.IsTrue(Settings.IsNeverSwitchWord('машины'));
    Assert.IsFalse(Settings.IsNeverSwitchWord('кот'));
  finally
    Settings.Free;
  end;
end;

procedure TLearningTests.ShortWordsDoNotShareAStem;
begin
  Assert.IsFalse(LearnedFormsMatch('кот', 'кота'));
  Assert.IsFalse(LearnedFormsMatch('hello', 'world'));
  Assert.IsTrue(LearnedFormsMatch('идти', 'шёл'));
  Assert.IsTrue(LearnedFormsMatch('человек', 'люди'));
end;

function PutTextAndPayload(const AText: string; AFormat: UINT;
  const APayload: TBytes): Boolean;
var
  TextData, PayloadData: THandle;
  Ptr: Pointer;
begin
  Result := False;
  TextData := GlobalAlloc(GMEM_MOVEABLE, (Length(AText) + 1) * SizeOf(Char));
  PayloadData := GlobalAlloc(GMEM_MOVEABLE, Length(APayload));
  Ptr := GlobalLock(TextData);
  Move(PChar(AText)^, Ptr^, (Length(AText) + 1) * SizeOf(Char));
  GlobalUnlock(TextData);
  Ptr := GlobalLock(PayloadData);
  Move(APayload[0], Ptr^, Length(APayload));
  GlobalUnlock(PayloadData);
  if not OpenClipboardWithRetry then
    Exit;
  try
    EmptyClipboard;
    Result := (SetClipboardData(CF_UNICODETEXT, TextData) <> 0) and
      (SetClipboardData(AFormat, PayloadData) <> 0);
  finally
    CloseClipboard;
  end;
end;

function ReadPayload(AFormat: UINT): TBytes;
var
  Data: THandle;
  Ptr: Pointer;
begin
  Result := nil;
  if not OpenClipboardWithRetry then
    Exit;
  try
    Data := GetClipboardData(AFormat);
    if Data = 0 then
      Exit;
    Ptr := GlobalLock(Data);
    try
      SetLength(Result, GlobalSize(Data));
      Move(Ptr^, Result[0], Length(Result));
    finally
      GlobalUnlock(Data);
    end;
  finally
    CloseClipboard;
  end;
end;

procedure TTranslitTests.ConvertsRussianToLatinLetters;
begin
  Assert.AreEqual('Privet, mir!', ToTranslit('Привет, мир!'));
  Assert.AreEqual('shchuka', ToTranslit('щука'));
  Assert.AreEqual('Zhizn''', ToTranslit('Жизнь'));
  Assert.AreEqual('Yulya', ToTranslit('Юля'));
  Assert.AreEqual('Yozh', ToTranslit('Ёж'));
  Assert.AreEqual('Pod''''ezd', ToTranslit('Подъезд'));
  Assert.AreEqual('chasha, tsvet, khleb', ToTranslit('чаша, цвет, хлеб'));
  Assert.AreEqual('Yaroslav Yur''evich', ToTranslit('Ярослав Юрьевич'));
end;

procedure TTranslitTests.KeepsCaseOfGroupsAndLineBreaks;
begin
  Assert.AreEqual('Shchuka', ToTranslit('Щука'));
  Assert.AreEqual('SHCHUKA', ToTranslit('ЩУКА'));
  Assert.AreEqual('ZHUK', ToTranslit('ЖУК'));
  Assert.AreEqual('Zhuk', ToTranslit('Жук'));
  Assert.AreEqual('Ya', ToTranslit('Я'));
  Assert.AreEqual('Pervaya'#13#10#13#10'Vtoraya', ToTranslit('Первая'#13#10#13#10'Вторая'));
  Assert.AreEqual('a'#10'b', ToTranslit('а'#10'б'));
end;

procedure TTranslitTests.ConvertsLatinToRussianLetters;
begin
  Assert.AreEqual('Привет, мир!', FromTranslit('Privet, mir!'));
  Assert.AreEqual('Москва', FromTranslit('Moskva'));
  Assert.AreEqual('Хлеб', FromTranslit('Khleb'));
  Assert.AreEqual('Жук', FromTranslit('Zhuk'));
  Assert.AreEqual('ЖУК', FromTranslit('ZHUK'));
  Assert.AreEqual('Юля', FromTranslit('Yulya'));
  Assert.AreEqual('Ёж', FromTranslit('Yozh'));
  Assert.AreEqual('мяч', FromTranslit('myach'));
  Assert.AreEqual('Первая'#13#10'Вторая', FromTranslit('Pervaya'#13#10'Vtoraya'));
end;

procedure TTranslitTests.RestoresSignsAndLongGroups;
begin
  Assert.AreEqual('Щука', FromTranslit('Shchuka'));
  Assert.AreEqual('ЩИ', FromTranslit('SHCHI'));
  Assert.AreEqual('Жизнь', FromTranslit('Zhizn'''));
  Assert.AreEqual('подъезд', FromTranslit('pod''''ezd'));
  Assert.AreEqual('Сергей', FromTranslit('Sergey'));
  Assert.AreEqual('Толстой', FromTranslit('Tolstoy'));
  Assert.AreEqual('ты', FromTranslit('ty'));
  Assert.AreEqual('Это', FromTranslit('Eto'));
  Assert.AreEqual('цирк', FromTranslit('cirk'));
  Assert.AreEqual('Евгений', FromTranslit('Yevgeniy'));
  Assert.AreEqual('Привет', FromTranslit(ToTranslit('Привет')));
  Assert.AreEqual('Подъезд', FromTranslit(ToTranslit('Подъезд')));
end;

procedure TTranslitTests.LeavesOtherCharactersAlone;
begin
  Assert.AreEqual('', ToTranslit(''));
  Assert.AreEqual('', FromTranslit(''));
  Assert.AreEqual('abc 123 - ?', ToTranslit('abc 123 - ?'));
  Assert.AreEqual('привет 123 - ?', FromTranslit('привет 123 - ?'));
  Assert.AreEqual('x', ApplyTranslit('x', tdNone));
  Assert.AreEqual('Privet', ApplyTranslit('Привет', tdToLatin));
  Assert.AreEqual('Привет', ApplyTranslit('Privet', tdToCyrillic));
end;

procedure TClipboardTests.RestoresEveryCopiedFormat;
var
  Original, Snapshot: TClipboardSnapshot;
  CaptureResult: TClipboardCaptureResult;
  Format: UINT;
  Payload, Restored: TBytes;
  HadOriginal: Boolean;
begin
  HadOriginal := TryCaptureClipboard(Original, CaptureResult);
  try
    Format := RegisterClipboardFormat('Ghbdtn.Test.Payload');
    Payload := TBytes.Create(1, 2, 3, 4, 5, 0, 255);
    Assert.IsTrue(PutTextAndPayload('Ghbdtn clipboard', Format, Payload));

    Assert.IsTrue(TryCaptureClipboard(Snapshot, CaptureResult));
    Assert.AreEqual(Integer(ccOk), Integer(CaptureResult));

    Assert.IsTrue(TryClearClipboard);
    Assert.IsFalse(ClipboardHoldsText('Ghbdtn clipboard'));
    Assert.AreEqual(0, Integer(Length(ReadPayload(Format))));

    Assert.IsTrue(TryRestoreClipboard(Snapshot));
    Assert.IsTrue(ClipboardHoldsText('Ghbdtn clipboard'));
    Restored := ReadPayload(Format);
    Assert.AreEqual(Integer(Length(Payload)), Integer(Length(Restored)));
    Assert.IsTrue(CompareMem(@Payload[0], @Restored[0], Length(Payload)));
  finally
    if HadOriginal then
      TryRestoreClipboard(Original)
    else
      TryClearClipboard;
  end;
end;

procedure TClipboardTests.RefusesContentThatCannotBeCopied;
var
  Original, Snapshot: TClipboardSnapshot;
  CaptureResult: TClipboardCaptureResult;
  Meta: HENHMETAFILE;
  HadOriginal: Boolean;
begin
  HadOriginal := TryCaptureClipboard(Original, CaptureResult);
  try
    Meta := CloseEnhMetaFile(CreateEnhMetaFile(0, nil, nil, nil));
    Assert.IsTrue(OpenClipboardWithRetry);
    try
      EmptyClipboard;
      Assert.IsTrue(SetClipboardData(CF_ENHMETAFILE, Meta) <> 0);
    finally
      CloseClipboard;
    end;

    Assert.IsFalse(TryCaptureClipboard(Snapshot, CaptureResult));
    Assert.AreEqual(Integer(ccUnsupported), Integer(CaptureResult));
    Assert.AreEqual(0, Integer(Length(Snapshot.Items)));
    // Nothing was cleared: the content is still there for the user.
    Assert.IsTrue(IsClipboardFormatAvailable(CF_ENHMETAFILE));
  finally
    if HadOriginal then
      TryRestoreClipboard(Original)
    else
      TryClearClipboard;
  end;
end;

procedure TClipboardTests.SequenceChangesWhenTextIsWritten;
var
  Original: TClipboardSnapshot;
  CaptureResult: TClipboardCaptureResult;
  Before: DWORD;
  HadOriginal: Boolean;
begin
  HadOriginal := TryCaptureClipboard(Original, CaptureResult);
  try
    Before := ClipboardSequence;
    Assert.IsTrue(TryWriteClipboardText('Ghbdtn sequence'));
    Assert.AreNotEqual(Before, ClipboardSequence);
    Assert.IsTrue(ClipboardHoldsText('Ghbdtn sequence'));
    Assert.IsFalse(ClipboardHoldsText('Ghbdtn other'));
  finally
    if HadOriginal then
      TryRestoreClipboard(Original)
    else
      TryClearClipboard;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLayoutTests);
  TDUnitX.RegisterTestFixture(TUpdateTests);
  TDUnitX.RegisterTestFixture(TAnalyzerTests);
  TDUnitX.RegisterTestFixture(TDetectionTests);
  TDUnitX.RegisterTestFixture(TReadingTests);
  TDUnitX.RegisterTestFixture(TInputBufferTests);
  TDUnitX.RegisterTestFixture(TLeftShiftStateTests);
  TDUnitX.RegisterTestFixture(TSettingsTests);
  TDUnitX.RegisterTestFixture(TInputQueueTests);
  TDUnitX.RegisterTestFixture(TDiagnosticsTests);
  TDUnitX.RegisterTestFixture(TSingleInstanceTests);
  TDUnitX.RegisterTestFixture(THookHelperTests);
  TDUnitX.RegisterTestFixture(TLearningTests);
  TDUnitX.RegisterTestFixture(TPhraseTests);
  TDUnitX.RegisterTestFixture(TClipboardTests);
  TDUnitX.RegisterTestFixture(TTranslitTests);

end.
