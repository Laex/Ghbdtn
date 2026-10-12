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
  Ghbdtn.Buffer,
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
    procedure SelectionConversionDoesNotUndoCorrectRussian;
    [Test]
    procedure ManualSelectionSwapsOneScriptAndKeepsTheOther;
    [Test]
    procedure WordAtCaretReadsTheWordUnderTheCaret;
    [Test]
    procedure InvertsEachLetterCase;
    [Test]
    procedure ProtectsTechnicalTokensAndAbbreviations;
    [Test]
    procedure ConvertsRussianTailAfterEnglishPrefix;
    [Test]
    procedure UsesHigherMarginForUnknownLayout;
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
    procedure SupportsWildcardExclusionsAndRules;
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
    procedure CapturesReplayOnlyWhilePending;
    [Test]
    procedure PreservesReplayOrder;
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
    procedure RejectsOwnAndShellTargets;
    [Test]
    procedure DetectsPasswordControlStyle;
    [Test]
    procedure SkipsAutomationProbeForClassicEdits;
    [Test]
    procedure RussianLettersOnPunctuationKeysStayInTheWord;
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
  Analysis := AnalyzeWord('cjr', lkEN);
  Assert.IsFalse(Analysis.NeedsSwitch);
  Phrase := PhraseOf([lkRU, lkRU]);
  Analysis := AnalyzeWord('cjr', lkEN, hmBalanced, nil, nil, Phrase);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('сок', Analysis.ConvertedText);
  Phrase := PhraseOf([lkRU, lkRU, lkRU]);
  Analysis := AnalyzeWord('cjr', lkEN, hmCautious, nil, nil, Phrase);
  Assert.IsFalse(Analysis.NeedsSwitch);
end;

procedure TAnalyzerTests.EnglishContextKeepsABorderlineWord;
var
  Analysis: TAnalysisResult;
begin
  Analysis := AnalyzeWord('jryj', lkEN);
  Assert.IsTrue(Analysis.NeedsSwitch);
  Assert.AreEqual('окно', Analysis.ConvertedText);
  Analysis := AnalyzeWord('jryj', lkEN, hmBalanced, nil, nil, PhraseOf([lkEN, lkEN]));
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

  Assert.IsFalse(TryWordAtCaret('', 0, Start, Finish));
  Assert.IsFalse(TryWordAtCaret('hello world', -1, Start, Finish));
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

procedure TAnalyzerTests.ProtectsTechnicalTokensAndAbbreviations;
begin
  Assert.IsFalse(AnalyzeWord('user_name', lkEN).NeedsSwitch);
  Assert.AreEqual(Ord(dmLeave), Ord(AnalyzeWord('user_name', lkEN).Mark));
  Assert.IsFalse(AnalyzeWord('test@example.com', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('folder/file', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('abc123', lkEN).NeedsSwitch);
  Assert.IsFalse(AnalyzeWord('API', lkEN).NeedsSwitch);
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
    Source.DoubleLeftShiftEnabled := False;
    Source.AutoSwitchEnabled := False;
    Source.AutoStart := True;
    Source.ClearExclusions;
    Source.AddExclusion('example.exe');
    Source.SaveToFile;

    Loaded.LoadFromFile;

    Assert.IsFalse(Loaded.SoundOnRussianInput);
    Assert.IsFalse(Loaded.SoundOnSwitch);
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
    Assert.IsTrue(Queue.TryDequeueReplay(Input));
    Assert.AreEqual(Integer(Ord('A')), Integer(Input.VirtualKey));
    Assert.IsTrue(Queue.TryDequeueReplay(Input));
    Assert.AreEqual(Integer(Ord('B')), Integer(Input.VirtualKey));
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
    Assert.IsTrue(Text.Contains('RU_total='));
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

procedure THookHelperTests.RussianLettersOnPunctuationKeysStayInTheWord;
begin
  Assert.IsTrue(IsRussianLetterOnPunctuationKey('б'));
  Assert.IsTrue(IsRussianLetterOnPunctuationKey('Ю'));
  Assert.IsTrue(IsRussianLetterOnPunctuationKey('ё'));
  Assert.IsFalse(IsRussianLetterOnPunctuationKey(','));
  Assert.IsFalse(IsRussianLetterOnPunctuationKey('.'));
  Assert.IsFalse(IsRussianLetterOnPunctuationKey('-'));
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
  Assert.AreEqual(2, PhraseScoreBias(Phrase, lkRU));
  Assert.AreEqual(0, PhraseScoreBias(Phrase, lkEN));
end;

procedure TPhraseTests.ThreeMatchingWordsRaiseTheBias;
var
  Phrase: TPhraseContext;
begin
  Phrase := PhraseOf([lkEN, lkEN, lkEN]);
  Assert.AreEqual(3, PhraseScoreBias(Phrase, lkEN));
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

initialization
  TDUnitX.RegisterTestFixture(TLayoutTests);
  TDUnitX.RegisterTestFixture(TUpdateTests);
  TDUnitX.RegisterTestFixture(TAnalyzerTests);
  TDUnitX.RegisterTestFixture(TInputBufferTests);
  TDUnitX.RegisterTestFixture(TLeftShiftStateTests);
  TDUnitX.RegisterTestFixture(TSettingsTests);
  TDUnitX.RegisterTestFixture(TInputQueueTests);
  TDUnitX.RegisterTestFixture(TDiagnosticsTests);
  TDUnitX.RegisterTestFixture(TSingleInstanceTests);
  TDUnitX.RegisterTestFixture(THookHelperTests);
  TDUnitX.RegisterTestFixture(TLearningTests);
  TDUnitX.RegisterTestFixture(TPhraseTests);

end.
