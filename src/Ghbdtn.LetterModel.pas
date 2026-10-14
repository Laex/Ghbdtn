unit Ghbdtn.LetterModel;

{ Letter model of English and Russian words. The cost tables are generated
  from word lists of both languages. Each cell is the cost of one letter after
  the two before it, in quarter-bits (4 points = 1 bit): common sequences are
  cheap and impossible ones are expensive. Rows are indexed by the two
  previous letters (word start, the alphabet, any other character), columns by
  the next letter (the alphabet, any other character, word end). }

interface

uses
  Ghbdtn.Layout;

{ How improbable a lowercase word is in the given language: the summed cost
  of its letters and of the word end, in quarter-bits. Lower is more
  plausible; only the difference between two costs means anything. }
function LetterModelCost(const ALower: string; ALang: TLangKind): Integer;

{ The same cost for the beginning of a word still being typed: the word end
  is not counted. }
function LetterModelPrefixCost(const ALower: string; ALang: TLangKind): Integer;

implementation

const
  EnglishLetters = 27;
  RussianLetters = 33;
  CostBase = 48;
  // A key that types a Russian letter on the English layout ("," "." ";" "["
  // "]" and their shifted forms) is almost never part of an English word.
  InnerKeyCost = 60;

  EnglishCosts =
    '=B@CDBFD@KMDBE@@RC?<HJBUIVlDlVDBAWHGVK`Y?E7ZD[>@AEIN[]WlD;<RUY8^]Y@_^AVZ<Zi>VX;a_g<flDH9XULCW[<Eab?TR5UiBSUCV_eOYlDH' +
    ';TPU7Z^W9T\WUS:WdAQWCHU]OclDH?FF@SELZJW_@?:XKFFAGF>Y:LWlDC=\XX?V[_;deBW^6Zk:XR@hZ][jlDJ;ORU:YZO>baBLO9Of9RR>`VbR[lDG' +
    '8XXT8^\\<b\]Wa8P_QUMC_ZcK^lDJVTOHSDU_Nc`MC4SPbK;<cTb_jcGD>8URR=W\WGVXWTZ7MgPRX8SXa_dlDD>HTN8XNM8WXKJ:AS`GNUHTPZIZlDA' +
    '9TQV:\U]7_bOZZ8Ud\VOG\_^JilDH6RMR:XUY=`]TRW9QiQLT@[\\BglDI<SOT7TTRBTbVSX5UfTPQAUTbLWYDESHHTX5[PQePJS:WBl<PC@FITbWlDL' +
    ':ZMO=[WACb[?GZ;Sg7MUA[_dWklDKJTPXVZ^\Q]_OUYSWVVSH1VS^a_lD?=ZUS3T[P?^c]VX>ThWLVCZT\VglDH?YBW9Z[>?dKJIP=@QUV;=YKeFclDI' +
    'D^[^A__3Dhfa[\9`lAZ]JRKXMilDNVTQV[XRWUhEJO7_;gE5FZVX]eXlDG:OPW9XTN5baPUY=RfVLRN\Y]adQDD:^\_9a`:8f^^Y\<\lFXY\[S^UllDK' +
    'FBNLEJRIEUYF?KMBWLGIPKW?NTlD4CdaY:eb_Oge`[V2^jS]]MZagYblDE?UYH:V[G:\\QSQ8X^TJX?XPULNlD:lll?lllllll:IllllI3;lJlllllDl' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl?D@IYKMPQSOCJAWGW;BIMRlllZlD5CHPSBef\=ik6dT7bhGCXHbTiElPDD' +
    'G`<T=cb<Bl9OXZK]MGS8Il`aBilDGAPO<;VPR>KaICSDUUNBWE>QlEdlD8MXMCVNHlRlS5EKDRl<<HPSK[lWlD;ETV];7JhKl]N[YJTl>P6ccl\\hlDD' +
    '?ba\2cIRCllNQGCYlAHbGldl^llDE:\ZW@blQGUlJGK6WlGPPJaT`RllD7W]O?^_H`NXV7D6YWl<FEbUQ[f^lDF?\Tl>lllCRSYRl2RlTZlHlllXllD@' +
    'FZ^P3H\N;lULaPG\lRGNQ]YlTflD=GLMOANR^@jI8L]HPlO@BGRNlJ^\D5@DOS6\_[>llSCPB=lXAYOhWaRdZD9C[@5IZC[D`H[_FJd`kC?H\`]BYND:' +
    'PPJORVWIFlA9GGYFl==FKlllXllD6?UW^<^b>Cb\LWVD7ZAB@PjefKllD<TVlllLlW@llY^^lll]=Z:l^llllD2DL>>:VD^AbBFGFIQ]DC;VRX_@^WD=' +
    'NYLZ;bYBBjDZPVFL\c;;HecgIh\D6EaHl8TkD7l^QObEalMKDC\`d[aID8YPC>QP<bTcN?NClUa@97lWaMl]lDC;gad3kNj;lla^]@`lUXgYYljIllDJ' +
    '6EYTEHURClEGQAR\lH?N^lVlBllD7DlYZ?[Zl9lbMTlFIllWIclNQJllD3KJYR@WWYFleKDNKJlT<OXaWlhcOD2=laI=ll_6lUWW]<XXLbOJlblA?KD=' +
    'llllllllllllllllll0llllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl[A:E]]FOLYK=M<]Ql>:?Q\cZ?ZlDD' +
    'BI?V9YY`;_[>\Y@`JGDWWlE[<lHD<:OLIIUSFIl\EQS=PlKLKLllllllD3;NME=SVl:SlPQV?SlI=N>llllllD8@`AE@EGHEkX@_Dai_8A@fR[[N^lD8' +
    '>lHBGGCl?llKHl=IlFDLDllllllD4GJ?HFlFlGllCJCO?l:DJGlllJllD5;SMCBPllElRlOl:ElRJP;llRlllD6?EHADY?]k[G7[<@URAF=]\_`lHlDH' +
    'TlI\0lll`allllQTllWlYllllllDEllllJlIGClHJlIlllHAIlllllllD1>lhY4kll9cYl`h<_lhceCSllDllDM<_NJ=]Ol4Tl[llRMl\NYllBNlllD;' +
    '9SJO?NXlGllMPW?MlYJlllHllllD4>JRBUaTUOkWENB9Zl?G@8EHAD]lDI9UNLKSTMNllJDP@OTA:LllUQlllD5llllllllllllllllllGl?llllllD1' +
    '7gdX;fil9le]f^8jlk]e?l`lLklDKT]<I<a_M9l^\bWALa^]<Pg\lSllD67ZRlALlVClYDXPAYlDD[KPFYLllD5cQIDTHG`?aPBEGZ]T>97gll_<QlDQ' +
    'SRll=lll2llHllSllMNllllllllD<<lOl7lllIllPll=JllKllIHllllD5lHllFGllJlll<llllEE?lllllllD2T^_^Qc_aVllRfXbUlQSH\^blh\lD0' +
    'lllFGlll3lllllJlllllllIllllD7llllllllllllllllll0llllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl' +
    'XHOISSN]R`T9A:]Dl;@9DRUlVdlDBDG@CCOHl?TSJKL?Ml@:FTllllllD6BaSQ5]ZOD^bLXX7WlIVR<eallllD@KCIQKPS^M_UPKEAM_F=GUWQVlllD2' +
    'NZYAMW_aGfcCE=VEjA9QVd^k[lUD5=NEEHSHlFllAEKBEl;BGMllRlllD5DTFQCRIL8llMJRDQl:HJBlMlMllD6:X\Z;Yab<ldRMB?`lDVQHlUlUl[D6' +
    '7WVC;@PhVllAP>G@lF@;THdllTlDIKlEAElllll>llElllFCllllllllD2DJWV<RJQARgFTKKNhR>PM\OlHaXD39]S_8kll9l``hf<_lY[b9fglRllDK' +
    '>QBBBKKPBVVKIUC@lL>HFOUROllD5ALFR3RPRAllZQ?MNlIHGMYPXMllD<KTNGWRNRSl_@77GDf?FK<FS[]`lDF>QEGEOIDDUUFHQJGXFCH:WWTJllD5' +
    'Vlllllllllllllllllll1lUllllD<=cX]6die8ki^Q[;`lgXVBfbdFllDIPUQSMUPVIl^ZW[LUlUDHSVY^lllD1JbbfAZde7llJ[_=dlC>a>Yb^allD7' +
    'OGUVKTllIka9=MXDl79>PaflaTlDNAOLIDlQlJlllMPONlN3OlllllllD9<IHDlOlNCllNFK<MlGFDMllllllD4llDlllll8lllllBllllllll>lllD3' +
    'SI=a^gPYlllKLM_JlQOIgllllllD1Hlll2lllllDllBllllllllllJllD:lll?lllllll:IllllI3;lJlllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    '=B@CDBFD@KMDBE@@RC?<HJBUIVlDleKRLUWKOFiMED@_IW>J7KDQa7YlD=3VHUBURUGSlDL[?SlHPQES\SFMlD<7[MUPS\EQllKR[8JlEKQLll\lllD6' +
    'JX\X;^eL8hc?ecLal:G\YlfgDllD8CJB@KEM\Ze`AD=ECU:=CTBVHf\lD:@WQYIVRl>llGUW;WlKHO@lKUlllD3I_aa1`llClTVD[Z\lRQcRlPlUllDE' +
    ':SEF7NlN>llKZl:OlIHGFlllNllD?=R?CABEjee`ML:CPj@:<LCgRZUlDI?lllHSXlBlllRl;lllEl5VlllllD8=lll?lll?l@llACllHElLllllllD4' +
    'AlT^5aZa9llM_lGOlZVUXll[9llDC=XLV=\V^3l`[ZWBZlROXKS_K_WlDB=VPT5RllC]lR`YJQlQFG`YllVl6D@YM?N@\FYH^ZC?;CIjCHJDP:SYPlD9' +
    '=WMRCLU=>lJAJl@Ml=GKOURlVllD6llllllClllllllllllNl1MlllllD;;_Zg5e]a9lfbT`=aleWb?bSdDalDDR[J^IYgISlYJM]IQlaYIWYXkallD1' +
    'F[OJEZS8GlYSLUEPl>DTQ@WYSllD5?K4QCSW]QlK>IHRKa=?GlXl\i\lDH8SY87`cc:ll_XlFXlPZ\lll]lllDH4l^W>XRl7llQ[Y@YlKXXllllQllDF' +
    'lKlllAHDllllllllllLllllllllD1XJR^J^XlGlQLO@allcG]ldVlllDD1GllBHlll9lllll?lllllCl;llllD4llllllllllllllllll0llllllllDl' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDllTA=hRLThlE=DBlJl8;;IH\ik`lDC:LHVE\dSH`dGG[?Pb<;EE^\[KclD7' +
    'BeTX>kf?=lBKa_<ilFQ5AjilSelDEPLdMG[JZ>llQWPOelQHWDjRlRllD1]TK;UR_YNg@CD:_BYAC?iQUalPlD7DlVl::_g:ljD_];dlGK??fcbZjSD>' +
    ':h_l=ZFX7llMLI;al>Ja?eclElTDA8\l\;`la7llOLR9_lFURFl_lJllDCVTGJYR;f_PQDI9ZLl7E@a=i`fNlDG8Fll6lllFlllNU;lllll=lVllllD@' +
    'IYbN<bYV@lL?\SOllY;L\lXlP\lD4@QJC;ERW>lT:P\@@lN@IRL_lAclD:<;\[9dhl@ll^PU?>lc>aSldlLlZD:HW?>AUDQGQ^QYJK^YOA5LKYlVUPD:' +
    '[[NN^HE[WeaDK=d7_<@JAKM[lflD8:`[^?^fACll=]a;Kl?E:Dl[hXllD<_lld`llllllfl`lbl_W\0llllllDGAOIR=IKUAbWLECLNaH;CXAQlDZMD6' +
    'PPHO@fcNDlQX\YGG]c;<H_dl[llD4>PK`>X^?>llSZRJRhE@>CaAkEXLD6[RKIGXH^SlKO=ElFl4D<lLSMl]lD@@lcc3gbl7ll]glEglQ]hYiljSllDE' +
    'CPR[AUbKElcMUYHOdT8Qilel]iOD3=b=iA\cH@lb^TjK9Za\8G_g[JllD:OHQ]A^WWTl`SONFUlWCZX_ClklHD1ELOZ9lZY?llZORCllHVl>KllIDlD5' +
    'lllIlllllll:lllllK1llLlllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDlXI8QU]ZY>cQ@=@YfC>??EA[CP\lDJ' +
    'IHKlBlll7llKNl>OlKJKlllllllD4@Q<SGSllKlRJPOBJlICQJlUllllD37QCD>LOl;NlGFLHMlFIPPllllllD7?B=D<gV\RljEGCW`l7@DYTD^ZeMD=' +
    'E_eb6Zjb7llGRZBglNGZSl`^OllD9=lOK=Nl5llllJlSllJMllllllllD6?lNlIlllOllMHlNNllHl2lDlPllD<RN9K>NBliWh;d9V`e<EBgIlGk]lDK' +
    '>ll=llllllllll:llllllllllllD3>lllllll>l?lllGB=llllllllllD39l^[<lcl<llbel7_l]]^>fblAllD@9lGNJNTlJllGSSGJlIHCKOlTlllD3' +
    '=JJ@:NlllllNDl<LllJNllllMllD5XaK_^hYlYlfB]MD`l1QRBkZPbllDD@lGLNlBlCllHIl?NlA>IHRlllllD4lll?llllllllllllll?llllllllD1' +
    '=lag7egl<lli`i5gle[kKljlUllDKGHJR=NU@HlSUORLFlTMFKlVllllD2QQQW7\aJIlgT\\MJl[?d]d9gLglD6laAVFiKefLX6J7heb=B@lllllRlDO' +
    '<lBlllllllllllllllllll=llllD2=lO8HllLKllllO>NlGDlllllIKlD4llllllllFlllllKllMIllllllllD0SllRX[ll9llVU]YllR][lllllllD1' +
    ';lllllll@llllllllllllllllllD1llllllllllllllllll0llllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl' +
    'XKQMQ^C^>lb<:<XIl<C=NKXlBClDC:lJlLllMCllLVl?=lGQJ@YlV<llD6GS7MGQHDNJlINH@KlH>NOllllllD6AFOlDWllMlPVOW2AlNNWQYllWllD>' +
    'LT_DPZi^WljHC<E_l><=iZZ``j[D5@SMKFQll7lQKQl>GlEGO9llHlQlD:AlYa4`V`<ll@l^CUl@C]XlllEllD>FH_VCc`lPlcEgWGYl^N3\lMl_SlD8' +
    'DG@OC@NgfbeIM7?[a@<@M>lajSlDJBlllllll@lllll:llllllllllllD2BHllMlll=llllM3llJlllllllllD:9Z_a7fle:ll_cV:_laYlGl``@llDJ' +
    ':CES7XYlPl[KXlIKlSK8FllURllD<<lZX:all;YlXF^@Zl`BTEaglgelD5EU]AH[QbAca?PA;Tl<G?J>NfZ_lD9ClKSMPHRCll=IWCOlA7PFlWOlllD6' +
    'llllllll7llllllllllllllllllD25d`c7lllBllkle9^l_egPllfPklDPOV[\V[bPOl]ON\VVQXZCW\X\belD0IaVXN^X7FlIXZa3QZJS[`TlUlUlDA' +
    ':^R_;l_g8Xe=EDRWl=>Mdl`lB[lDQClDIllIJ9lllll;lllllllEllllD4:Lll;lRO:llLlN<Ol=NlRlll?llD<llllllll;llllllEl>lllllllllD2' +
    'R\lYdXlllllQFLXClTTll_`llMlD1Dllllll:3llllllllllllllllGlD9lll<llllllllllllll1llllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    '=B@CDBFD@KMDBE@@RC?<HJBUIVlDl]LQCMWTXFdRBE;XEf=>7Q<MlSRTDJ@lPlCWlPGlUPVl3NlBLYBOllIllD<5PKRQJMEGllAMR<Al@NPWIlllllD9' +
    '7SMDNNXZFllIJl@Nl:O?ZOUllllD8B\KHMXi]FkgDGCRY`;DO_YVaFdLD3HLJSJlll9llLll=llEEl7llllllD7<lHlELl;lllMlJFll?MAAKlllllD5' +
    'HKMl=ll=AlllOl;LlL=llOlllllD5MJ=NGQA`c]T?F:K?lD6C]Glff\lDIllClElllAlllll9llElElllllllD3ElBB>MLl>ll;lN?llMEKAllllllD6' +
    '>U[]9lWl:ll]Y_?Xl\VTQlZl7llD?9TMX6lWl@llUDl>YlU@\PMlllllD;Ml`[Ec`d8ll\lH6d[l@lTll_UllD8XPMGJXSbLj[?<@?@l?A<;T=c]lSDA' +
    'B@NRQVKZIllFMNFMYPMTDLRYlllD2llllllllJllLllllllll4llllllD5DhY\6lf`9l`\Xl6_a`L\HYbeLllDDNOKVIZ[JIlZQRJHMlVRAQR__]llD1' +
    'RSUXAN]NFllGCOL[lT:KZ[PlLbOD3FEKJOM?QQcSH8:ZRl9<Cll^[VflDA<lllFlll2llOllOllKNlllllOllD<4lll6lSFCllllLAllMTlTlllBllDD' +
    'lllAFlllllllllllllllllDllllD1KG\?XcMeZllFIR^@lK9HMd]`lllD3llllQllllllllllllllllllllllD0lll5llllllllllllll3llllllllDl' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl\EPWZdGRWcb7D9UWgHK<bZYdlVYD8FFQR:cXf;`l8GVI[l<IR;i_ZQllDD' +
    '9hZd9gl?Al>Ea^Ib\J@AGbilFflD:?]\E4^EeDbgN\IM[lXCME_RbWcZD8cYK?VGObfbbCR;lalA6CUE:llblD?Oi]Y<<ll8ijQj[CalVV>GllkBllD7' +
    'A^aiD_I4>llVO9N_lJO\Clcl^hlDA:lJSASlM?llJNH8Pl?GK?lQlHllD9FTVTW[Tl:l_]VDXWlTKNl\llXllD29lVQJVll4VDlNDFSlVHl>llllSlD=' +
    'G_^_2llN<lK[\aEllZSTTl]l_llDB@T]?;LZ[<lO7H]J`lXCFOLSlBl[D;:IXY7YS[=llWC[E:l\E`Dh[lfllD=DXCA>D6WDUFSSKMVZeC?KKccXdXD9' +
    '^`VLabQa_llJU1lWlGOODYU[lllDD?TTe@]cKHjU@AcF;lK<;Mj]_][MD8STlWlll[^llll]l]ll\l0llllllDECSED7PH_DlQBDTBI\I=AKRSlKhlD9' +
    'HPBTAR\@AfLIIRGHaQA9O[flZk^D5AbJh:`e:<lbISPGblPBCEhdl<RKD:l[PPKl^l\l]O1RlSlN<Ullll]llDC<lkl2cll:lllliKll\e_bllXYlSDH' +
    '3lHlAPll<lllKlASlRLlSlPlEllDAKX\^8ll`Cll]KlG\llW?R`Z]]llD34lllAlllKlllllBllNllHlNllllD68\`^3ll_BQVeRgAclMeTNlXllDlDC' +
    'lllBlllllll1>lllllEllBlllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl[M<NWVLPJcKS=4l>^GFaZAPQGFlDG' +
    'DlJllllllll;ll:KllDlBllllllD3ECHPIOlPFlLKLMlAlHD8JllllllD4I=ClBKllKE@lDlCllIGLMllllllD3D[3PJD_Xl^XIVCS]l?ACQZ>fl^lDL' +
    'llClllllll7lHllllHAlllCllHlD3lllllllllllllllBlllllllllllD0;BllEEll>lllGlllllDlCllllllD3BETPRGDIWADA7=lRlIL@RILl[JlD:' +
    'IFlllllllCllHllllllllllllllD1llllHlllGll>ll@llHE?JHHllllD2@HGlllllEllllG@lllGllllllllD1BHFD@IMlGllKlllBlG@lFllFlllD3' +
    'llG?GlllAlECllCllAlllllllllD2K9PRDhT;:VHMcBRVl=BY=Pcg@blDIGROl8l7llllEHCOlllLlllllBllD7llllllllllllllllllllkllllllD0' +
    'HlGlDlllOllOlGNllE@lJllllllD1FlAlDCllKlllKlN;lDM>FllllllD4<G@lGGlGllllGlllllDllllllllD2JTl?SlMcI`R:B9lOl@6XlKl]lelDS' +
    'll3lllllllll@llLllllHllllllD8llllllll@llllllllEEGlllllllD1lllllllll=lllllllll;lllllllD2@lllllllllllll?llll;lllllllD2' +
    'llll9llllllllllllllllllllllD1lll?lllllll:IllllI3;lJlllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl' +
    'QEUNTU9KEUFFG<SJd<F<JPKlBGlD;8lUQ@lllJllXll:DlJQlClllGllD5:LIl@ll<NOlEll<ll>ElAllllllD7:PKN7MllBlSRMl8RlAHllRPSlllD=' +
    'SV]>BTZTPldDQ?VMl<A;VNRe?dQD75lLlKTll<ll?ll9llJlS=llllWlDFENPlHWllllllQlKll3FlVllllllD77lVlAlllFlllJl7PWN>KFlllVClD<' +
    'E`KBF`^_PRY?I3WFjEE@^\Vd_lQDB4lll5lllOlllllNlllNllDlllllD@6lll;llR:lKOll@lllPlDllllllD:8lll8^l[:lllKlClllllJYll7llDI' +
    '4lQl@NlXNllMRlFPllGRMlXllllD6Hlll=lll?lllcc1lllllPlllSllDROIJCMHRGNTDFF9CLl:B=<HJlXSlD?7lPlPOlNAll7HQ8TlKTlllPDlllDC' +
    'llll>lllllllllllllll8?lllllD38LYlClll:lUlll<XllMO8lNlISlD<VUW_RlRCRla]QlETll]GRWQlTllD1@lllClQ@@llWOl3llDNlKSlllWlD<' +
    'GGKCWWUKOlKAC@L6l=BIlV@lUTlD;?lllKllJ5lll8llllLlllllllllD94QUN=llE@llllU:llPllUlllFllD>lllllllllllllll;lllllllllllD1' +
    'EQlNL]lXPll@XP=BlEO\O\NllllD2llllllllEllllA=lll=?lllllllD3lll2llllllllllllll7llllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    '=B@CDBFD@KMDBE@@RC?<HJBUIVlDl_@?G^YIODeJ\H:ZK[=<;HMDQ?QlDB;^Yl;\llGXlLlX;RlGAT7lY]DllD>C^R?I_XBElZTV`5VlKN[9allVllD:' +
    'PVPg?QXQ@dlMUGIXlACZ[^Hl\lLD2=N@BKKD[Oc_TDCONgA<@TESJH`RD6BaYcIUPFCllRX\GRlEDOJlOllllD28MY\;SlQ9llZll;OlATVKlWllllD<' +
    ':lEN<lll8lllll7NlLHQIllllllD>AF;FACB[fbCTE9GHR\<<VBhZaH]DM:lllBlllllGlllHlllll=llllllD2ENll=llP:llHNQGllX=M`lPlIllD4' +
    'BWQ\;]fc?llfST@Ql\D[K_\l>gPD4=SUV;\YTCllTLT9Tl^>XOlWlQllD5HNOX4lIlLlURYlQUllCS@lQXlllD7@H>MYW;ZQhURM??@]@@BEC;]DdlDG' +
    'BlYQDBV<CllNaYK]lJCIalll`llD3llllllllllllllllllll6llllllD3MPPT5lTlElll\U?T\]PSRlTl7llD>NUW[AglONlYebc:Xl]ZKZa]l^llD2' +
    'Ae^F>di9;lg]Z`B`lF=]@aXgASlD9C@D9;QEhKZPI=CPRlF=<cW]Fl[lDH<laE2lll<llRR\Hll[Yl`l\lZllDI1U[ZHZllIlZZlYCRlUU\llZlLllDG' +
    'lllGDCllEllllllGl@llllBFlllD2Z`PWR`ZdJli[JJWPlHDO_hPflPlD1D=ll>ll7MlllLlBllMllllNllllD5lll3llllllllllllll5llllllllDl' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl^WEE[`AR=JB@S:^Dl<C:S[eJ@LlDDC]^Q3ciR>lj@fKBTlCJ]Glhl[RlDB' +
    '>J<@JH?GClACDE=GQLEVSSS\lllD8DCKOAMLWIlNFLQAPlKFFXYVPlllD2FWO@I_SZ[efJB7NPl>>BecPP\^YD7JlGPJWClBWlKTS4LlAKIBlTlJllD:' +
    'ENILIMlQGlQS>UQIlEJFVllMUllD2AlCK>lJlHllllR<JlPFNGllll6lD7KT<CJYEhcbL;T7U[]I<<MdlI]IlDFlJlDGlHlFlllJlJllJJl@llllllD1' +
    'HlF=Blll=llHlLlCllD<lElIlllD4DCQU@Z^X@ZR\KPKVlTDV\\]lBllD2=dV`5[gc:ldbRg=`laPb:\`bHllDD@lTU>SWP8llR\lGZlS=LQlllllBD5' +
    'TEK=[[QVP_LII9HWl7??@>Y^\QlDH9R^^?]TGCgW7b_=ck@EB>eefYllDAllllllll?lllllllll=llllllllD1BTGRGRVlBlURSAAKTQ<LGWllKllD3' +
    'RSSRCTJHPlYZXFJWfUWEH^[_ZllD1GINLGQKCIlYNTIDBlFGUKCQQZllD2[a>KMSKUUX^;A9]ZjD6Fl_lY\QlDMDL@K@lllAllKKEl;lHENMllllllD4' +
    '9lLR:FlLFlNlSl=SlJLlllllKllD5lAlLlllllllMlFlGlOlllllllllD1MaNXLZ_c[lXR^\O\fK?Ic\l[YgID1=lllllllElll>llllllllllllllD1' +
    'lll2llllllllllllll8llllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl[FKDYX@RKfM7>@]JlCG9NHWWXWXD=' +
    ':UAV:lllCllF[Y:PlAFX:llZHllD>J\\f3kl@>l[>ajBblDZCNkllAllDGBU\h>ZdV@[iKR^DZlKBXGhVlPlTD2HUF@BLM_MhbGMJOT[=<@NI;EEWQD7' +
    'FbZi>Xll=ll@e`2ZlDVWHllglllDJMVbP@WcQGl\E__OhlNAGIc\ladQD14lNl<V]V>lYC[l?WlQERGl]XNllD;@U<QCFCXcgNNC:BKHU=:MAjLlDlDF' +
    '>l\\=lllGllll\6lll[l7llllllD<IfYl@NX\>MlFZERRhJ8TalUlKllD4BhbZAlbl6llb[d:[l]^aZ]ll6llDI@_ZY1XlZOllc^lHMlRU`Yll\bllDB' +
    '>lb^6blW9l^bd[=cldFSBcYl@llD>VONNUUQ_KhMBCANOl>I6DB;TV]lD<=WJMIXOLIlUAYT>Sl;IM5TlllllD=OllllTlllllllllllllW0llllllD@' +
    'AlIW8WRS<lYQSZ9RlZJNOlPl9llD=GVMZ?I[H=lSLN`DFlhU<@VHkOllD4=_ab:\[G>lkHVgD[l@<fKe^lIaTD69UFB=@SgFiMH9MILlCB=WdeCVllDB' +
    'Blbb4lfl7llfYl<^X^blXlllTllDF8lUl<WlA:llTlO=Ql@GDllZlKllD;llllllll7llllll>lQDIlRl:lllD6HONVSldYPfbIEcCZf\NC\ZFXcllD1' +
    '8TlJ;llH>llMll@lllPlUlSR<llD7lllCllllllllllllll82lllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl' +
    'S[?6gTXQ]eEAL>_LX:A>Z\lRlclDF=CXc;ab`<?i;l]F`lO;DMIbiNllD<9]A_<jlE<l9NajEciGP>>lkeS`lDE?ROI9XIXAl\PWUIXlSAd8fRfA^ID8' +
    'WNIJ`JVTKlQFC?^UlL3AQJTSMllD:XlejH>llFllaglXlld\BbllegllD1G^[W@ZCV<kkDZDC[l7CQGlYl;hlD;@lTXBl`U<[lML4?]lQO\Y[_lLllD:' +
    'Rb=?UcVlll_=T3lJlF?ElalTl\lDGEWXl0lllPl^lllFllll^YllllllDIIOTc:ZlN;lVGHbQbl]9VL`TgLlOD6CPU=?IWd;lL:QR<SlhBL?EalHalD<' +
    'BH^j7ObjBljZ;XF:l`I_]lelMllD8AaIC?JEfG]YDNKJ]`[<?VLXfM\JD4lNY:_JHWbj8;?BTFl@E@lSfa_\YD?KaX^8_cE?eW?BcD?fGD@Dlbl?WlD:' +
    'llllllllllllllFlllll1llllllD>ETK@=YGXAlBG@GMKbIC=I_QlChTD6GVIb9[]I?lWQMUEDXe=6IbX]QllD<BNVd:a_9@\TNYY?ZlSFBVlTlPclD6' +
    'bLNPaeAlPjj?g;lD^8?:lUi_jjLD;Bleg3lgl8llelSNjl]XY]lll\lHDDFPTN;\aWANfET9WalX>IZkbl[lRD5PPVY?C`\9llPlVOTllRSlMVM@llD3' +
    '=QIF8LXZFd]K=OEdl^:XLllllTKD8:lVl8llX>llSWN?lllVWJlllEBlD7lll=llllllllllllll1llllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    '=B@CDBFD@KMDBE@@RC?<HJBUIVlDl[N?J[i;^B`QDM=]CS7A?ISWYA]lDFD<NN8VRlOlPJGl9SlI@RElUFlllD9HIMTRWKOAl^NGS=OlH@FTWUUlllD3' +
    '2NRZI:W_Ql_WUXLPWQQAP\lWl_lDA@`<CFVMlYg\I\<APV5EBUdXV`VlD>ClGOETllAlSFRUKNlENV3lNVlllD9BRPUKYlUPlSQONZCl5AXlZTlZllD6' +
    '=gdP=jll:llWiX6FlIHTRfld<llD@Hb8E?aMk]fOAS7FH^@E>[WlIlOlDFHlGl>lllllllBlDlllDllllllllD2JRHODS:l5lNlP=lQlIMHQlDllRlD:' +
    '6lUc6lll;llbda?jllZbDlll@`lDML]L\5cWdHleS`bUZl_P]Yf_lWllD3FLLP;l@l>llSRJ=FlTGIHlQlHllD4_aMKLiVfBlG<X>GDl78DJSA[^dlDK' +
    'E_S_:b^T:lj8Tc9Tl<NY\bldEdlDEllllllll@llllllll=lG4llllllD7Elbh9jil8lgkhb4gll\jSldi`llDJL[PXCZ`FFlGZY[CIeYVBJbTZAllD2' +
    'BfLf:[gH5lhQdi?^lQC`D]jhHglD:S7TTKRTjZa_<HEjHl;@8lgfd^KlDKGl8GNllllllNHllAl@H;lllllllD56OEC@lNl=llLFKDPl?BlllGllllD9' +
    'llllGlllBlllKllElJJllllllllD1UWTT]cTlHZbLa[T[l4YEllDllllD6llllllll1lllllIllllKlllllllD<llllllllllllllllll0llllllllDl' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDlJLlN:lllAllLJClllGJ7llDllOlD7;lllDlllllllll<lllCllllllllD2' +
    '?Hl<lllllllllllFlllllllllllD2llllllll@llll@lllllllllllllD1lll6llllDlll;=llllCllllllllD75lllElllllllll>Dlll8lllllllD9' +
    'lllllllllllllllllllllllllllD0:llllllllllll?lllllllllllllD2CPMNlNFllllll=lJll;lKllllllD2lllllllllllllllllllllllllllD0' +
    'lllllllllllllllllllllllllllD0lll>QlllIlllllNlllPllllllllD18llEllllllllllllll9llllllllD49lllBllBllllBllllllllll:lllD4' +
    'lClllllllll>llllll2lFllllllD:llBll;lllllAllBll><>lllllllD5llllllllllllllll8llllllllllD2llll@llllllllllAll;6lllllllD5' +
    'JlLlNllllllIllHllOlElllllllD1QlPlAllllllKlllll?GllMll2llD:9blk6llc6lllgl?ll\lcflll^llDZ<l6lllAlCllllllllllllllllllD4' +
    'llll3lll=lllllllllElllCllllD8lllllllllll;lllllllllllllllD1lllllllllllllllllllllllllllD0lllllllllllllllllllllllllllD0' +
    'lll?lllllll:IllllI3;lJlllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDlcH>@PHDPAZS=@;VBOFF9QEJ\INXDB' +
    '7cVS>`la;l_Gal:clLCcBlll@`lD>Hfb[8ie3AlYK\fG\lKTPDaYlLllDEBTI^:WaZ>lbLZTJSlP:WS^GlSlMD5=R@A@GEROYZDFAUCHO;FXDNZS]LD7' +
    '9UIZ<Z[lBl^E`c6QVKP]<llllllD@:S\]5lhG=llPY\BelFRiBYll?llD?6\WY;\llAll[lX7SllMWMl[l?llDA@C;D<L?dl]QGF;CCbh?>R@kRaJlDH' +
    '=lll6lllllllll=llJNO@lllKllD6IU]]9NYU=haMQPOMl[;ZR\SbSllD4?T^7?Pee<lll\lCRll?PXh]l:clD;5\\a?Vf\<ldQgfD[l`=XJeTdJlRD:' +
    '9V]W:bbT;l][AhD]lkAR]lTlQlND7ECB?RDBTOFMB;@C@^HCC=@BNMX^DEGlMb?`JCFllBHX5`l:FEMlll]llD>GllllllQllllOlllllOl1llllllD=' +
    '<ea`6llQ9ll[_Z;RlYXgIdll<jlDFJXTM?]eE?lZ^Wf@OjiJ?M[cjYklD3?ZUa@NK>:ljLDGHYkM=`CeUhBVUD7BF:JCR@\Ab\@:=dElJ;EdYi\_QlDG' +
    '>ljj6lll3llVblLjlfZlehdl]lSDK5lZX<llF9lllll@l_HX^lllIQllD;lMlNHlll9llHllLOlIlllLlOlllD2NR]QRhl^Hl[KZUIOllJHd^SfldMD1' +
    '?Oll2lllBlPlllAQllSlPlIlIllD=lll?llllllllllllll0llllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl' +
    'RFEI\B=V?aO<>>VKbBF?H@JU@klD><\JSD_l`8I^LZ=?XlJO\;lllFllD:>eZbBaa9=leD[e:\l8N^?kaiellDC3WRUERWUA\KKTFCOlHISLll]lllD9' +
    '>SA?ARTTTl^@I@WGN;@CQKREOi^D7>WO[7UVl>llNSW<UlILM9_RRCllD=BRMHBSlD<llQHT=Pl=<D?llQWllD8<TXZ:Zdf9f\NLV7]lMcVLTUlVlTD:' +
    'ED@@KL>lkl[GD:;QaNA9UFfMcFlDM>lDl@lllElllKl<llHClAllllllD3?W`l:Zgl7T\WlaNblWAAJbelAllD76_X]9e\l;l]_`c=[lOYRE[ld>llD@' +
    '7SRX=V^X:leWcc>Tf[CMJelcTflD8;IWS:VZ_@lXPJ^9MlOPGH`llLl=D9PW?NX@a[Pdd>=9JKl=WM;O\XWflD;<Z[[6ZcH>lfAcS8\lAQ`M_iaJllDE' +
    'XllllNlllll7RWYllKll2UlllllDA9L=TCUPY@l]MPQ;F][MQDPYSTllD6>]]_<MeU9k^PKU?UkP`YAgHiKl[D5:XWY<]ZV=ljOLZ>Vl<CiCf\lKllD7' +
    'C;>NAJFeEf]>?A[;l:CTaXffgRlDKDlAO:lES5lSNQBKClLHOTllWlllD<=^^T6RZ]7lc^_l9\lXXYXll``llDBllllKlEHMlllKIGHlHEJlllllllD1' +
    '^SAG^lYlla[C>>dVlH4VlllllllD9?lGl@lllllE=lllllll>HlllFllD3lll0lllllllllllllllllllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    '=B@CDBFD@KMDBE@@RC?<HJBUIVlDl_@@R^IDR=\B;J<]Ml>H:KWTGJclD?4VPKDVlZIllJZU8XlCFUDlllNllD@FVTYV^X2RlcJRZBJlSV]Jl^lHllD=' +
    'EXJMIXZXEVLXMV5TlQHZl]]l[llD5GUD;FYG^Pl[B@AYNi7?XTQTHgglD9EUTlF\\l=llERZ4VlNIB=l\llllD;3QUlAQW[KllMlS=Bl@TTGVlllUlD>' +
    '>aZW3^hd>llSW[CcaFPbMlVjRl[D<FO>VCGMilj[G@;5LSNDDX@lglSlDK?lllBlllllllll4llllllllllllD5@6lSClRR9llSNOIlllOlLlOlKllD7' +
    '>_WX4bggAlcl`iI\l^Wb[]ll6llDH<ZVT2Z^cLVl=c\CLl^SZTdellllDA>]UX2SSlEl^_`_FllWQMHllZYlID>[KIJU]JgVkULCAEBl:III\IVNi^D3' +
    '?NIFGYVEIlY=TZ=Xl@GX8lV]\llD7llllllllllll<lllllll9llllllD25j^e<kgl:liYb`<bll]e>lhi?llDMZRNZK^eSLl\cU]OVlccPP[Ud[llD0' +
    '@e^d5ZYL<lb=XY?MlDE[W]ZlDllD??JJ<EHNkMlaOHAYJl4D@lZl[gllDMIYQlRlZl@ll\]VlXlO@Y\lSllllD18l_^9lf_?llafX4SlWbccflh\llDL' +
    'lllMlllllllRlUlTlll?QllllllD1VfYgbh`T[l`C\Wa>lPPbl``bllMD1LSYl8VBNJlJLJlRJlOGIIIOlVllD3llllllllllllllllll0llllllllDl' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDleLSHWe@XPlN5QAkal8O<a][gMilDFFDJNEYVWH<i6>YQQjN;FIVQlOdlD>' +
    '>aBb>bl:Fl=HlbP`lTR5UlllTllDNGXdD5^@Y7llO`\JVlUIdTTWl?dlDAXMaCFWP^[klC_>\XlC6HQVck_RlD57aVlQ3llHZYQNlHll_VLRllllllDC' +
    'DN`g@[>4IalINbMil]C[?llllXlD;9lKlBAlGJlPCICPOlAKlKPlllllD4T^@;JXXllbY;\Ab@a:>:[Il^fLlDG:lll=lll3lllll@lllllJllllllDE' +
    'F\\l9lYQClCXllGllAYLKl[llllD3:SU9@MN\HlP=TPNPl_K8K[fhD_SD=@:YY:VefFlbW@EHAkc?[N[`llllD7GQ?8CNCV9[HHVFOR`NF9SZRl\_lD@' +
    'l\XBlW^lGlQPKIlWlAO2<P\SK^lDBIXL?@^HQGjcC^^C8lJ@FTeRlXllD6lllllllllllllllllllN0llllllDC@K@K9MGW@lOJS?GI`C@DRIUlIdUD8' +
    'DLMR8`YG;lVJ`WZNeMC9JfilUlXD8HUJJ<UX=<l`J[[ALlJEDGj[lH\lD5LlFIllNlKlll2ClJlHHNJllllllD:=QOl3lll@lllOlHllFFlOlLllllD:' +
    '5HKl;PllGlllIlLPllCllllllllD7UNZT;\[JEllPllKlllTL;lQllllD3G[_l=lYl>lbVbYT]l_?W\\lll`lD2A@Il>llLClllNXOlllll=lllJ4lD;' +
    'lll=lllllll4lllll7lll=lllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDlfM<I[lLZ<\O8R;cRi=E;Pkd^UclDA' +
    '@lPOQlllRllllPLllE@l5llllQlD5BlG<JQlKMQlJRlMMl<CLLllOlllD3LXOWXYllUlll_lQTlK<\YllllllD1RhRA`bNNU`i>G=gdl6@Phl`^M`UD7' +
    'DII?lDlllllIGGlDl><lHl@FlllD5<lHlMllllllllHLPlCSlPllllllD1MllHlBllllllllEQlN1PlllllllDCEP;;9lJkTcWB`=BWlA=B]Ll_l]lDN' +
    'lllllllllllllllllllllllllllD0lllllllllllllllllllllllllllD08OCJ=PFlDQllll6QlRFMJllllllD;=lJJElllHllMlllJlO=HLl@NlllD3' +
    '5lCHIlllBlllllOlllLNAMllLMlD6^YAMWgQl;lJ6RDOgf<L=@`PNBblDDMlJKllNlHllHl8ILlIDMJllKlllD3Alllllllllllllllll@llllllllD1' +
    'AOPl<Nll=lllGl7llSGSllllFllD6KURTLYllJlCQTAKQlGMJRlPPTllD1HlLJClllNlDlllAIlFHMlKlLlllD2SllK<lll?ll3JllllNF@lMlllllD>' +
    'llllClllClllllAlllGllAll5llD5llllllllllllDllllH?llll>lllD1JlllllllClllllllllllllFllllD0SlllllWlNllTlNWlllllllFllllD0' +
    'llllllllllllllllllllll<llllD1lll5llllllllllllll3llllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl' +
    'aSUSlZKWElN@W?jRl87>QJcU;WlDH?RLl6lll<llMll7llEOODlllPVlD>4KGLHQODEllRLR=KlSHPlEKllllD9NlMQ7PlPHllSHl>UlDCTLlPlFllD5' +
    'B;j@>fTdFll=^GlZl9@NlFlaXlGD:DlLMlQll@llCMS7FllOO7llllllD9IBLlBlll=llLlGlllBBFlllllllD29lll7lll7llgdl:jll^ahlllCllDV' +
    'elIDTJSk]dK9N:lVlFB4lTkflRlDMlllRlllllllSll0llllllllllllDAlllP<llD<llSlMllll8lQl@llllD5D\lW3]ll?llU]lL[l]DT\lll<llD:' +
    '5OMB=GllCllHll?KllHPNAlllllD:VVcV<VXOKll9^dY\l[CH_aRlYlMD3g^\_Z^lclfVK>BA`l3c];WOllglD=ASNNMQRl:llGOl6QlMJFLllRlllD7' +
    'll>lllllllllllllllll4llllllD5@lV^?[ll2lb^lb:cl^ZSZllXOllDG[UZV>RNMN^XAZaMF\QYPOhOd^jlD1NNLSCHY4=llYlY:PlRSZRlYlXllD>' +
    'lIGJllLFMll>N;l8lBBElllKlIlD7HllMGlllllllllllllMlDllllllD0RRUTBGllCWlXllMSlIRTYl5lSllD5lllBllBAllllMllBl7llllHlAllD5' +
    'GMFH4YKXllWJO?;llPELlRlllllD:llll>llllllllllllllllllllllD0lll5llllllllllllll4llllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    '=B@CDBFD@KMDBE@@RC?<HJBUIVlDlaK=Ul[M^_llQ4>lPlJ8D`OlllalDFQlllllllLllLTl1llFllClllNllDCAl_Z4ll:?ll;llR_lPllDllalllDI' +
    '9IllClKlEHllEl>llEEllllClllD4ll89l]ZlTll@@FOZl;:K[ll^VllDADlKlPCllDllFCF2llKHOlllGlllD>4lllFlll>llBlllllllllllllllD7' +
    '9lllVlll3lllllIllll<UllPlllDFGA;CCNWlKl`E9>FblT8@SLaSlllDCllll>lllllllllllll>llllllllD1@?llllll@lllll5llllllllllllD6' +
    'Flll8lll9lllllOllCCFlQlllllD59PllJIlSLll2IlJOllRllllllllDB?lllFllllllGlllllllllll2lllD:llKCWJKlVllKJ7GDl?F<lllLUllD6' +
    '>l\]5`a`Fll:``>_l<Y_VllaallDBllllFlllllllllllllll1llllllD>>lFJ>IllHlllllLMllLKll<llllD3GlAF<llACll7KlGBllICOlHllllD8' +
    'NGV^9[cLHllW`eK]l;IWDllePllD43OlRIlRllllOOllVl8>llllUlllDHllllllll2lllllEllllJlllllllD9BllI4lll?lllll:llllllll@lllD>' +
    'RlUllVllEllGllJlllZlQHl6YllD4lXGlll<lTllEQllOlRWPXVlllFlD1llllllll7llllllllllll;lll;lD5lll?lllllll:IllllI3;lJlllllDl' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDlXCGNY]G8[]G;D;QV]=HGX]PbNUID<=ZlR6lllMllLll6ll>llElllXllDL' +
    'C^ll@ll8K\T4l^>llNllVl^lRllDA;[lG<VWlFllZX;Fll6EllUllYllD;6V]?BlXZ\l]BRMXTl9<@HcTlg`lDB?lll?Ell:llCll=ll8ll9llllllDC' +
    '?llH6lll<llHJF>ll;lOBl?llllD?Alll;lllNlllll2lllllDlOllllDC_l`QBlllllU`W0[SllKR_XallllDJ6lll:llllllllllllllllllllllD4' +
    'CllL6llG7BlllM>llJDllllllllD;<aTU5lla<lXEXl<TllUSE>ZlYllD>B>Pa4allMllVGI<;lOIcXlllallDE:Z>=;lKXJllYWB>lllY;OlXJOllD;' +
    'g^W^kUQdllZYRC[^lCVO1bllellDM=lYY3lbD?llXlKBllDI?XlllZllDKllllllllllllllllllll4llllllD4EllMFlK]1llacNBllXHKJl\l`llDC' +
    'TZUcDTXR;lbOXaOOKhP6YZ`lbclD4LllS:ll3=llZ\l=llP_SlWlllllDIBJEJ>l<RQT=I>;lBl?EPlPlllOlD:;lll7lll6llllF<llllllllllllDA' +
    '8lSlFll;Glllll4llHlllllllllDMllll>lllDllllllllllllllBlllD1<lllllllKlllFlllllllllll6JlD4Alll4Nll=lllllIlll=llllllRlD:' +
    'lllAlllllll=lllll@2llClllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDlHAFU[TNSNlGHDA[Jl<Q4XWRl^[lD<' +
    'Blll3lllHlllll=llKll:llllllD?6llllllEllllll5llllllllllBlD:6lllGOlllllll4lllNlGENllNllD=COF9PbNaE]SIP?QJl<@KT]`flalD6' +
    'llll;llllll;llllll@llll@lllD3Glll1lllFllllllll>lllllllllD?8llN6lllEllllO9lllll?llllllD?MQVQEMK^lUW;D4E:lLOPl`l[\TlDD' +
    'llllllllllllll0llllllllllllD@<lllllll6lllll@ll=llllll>llD8Olll2lll<lllllBlllllIlRlCllDD6lllClll@lCBll7llllllllllllD;' +
    ';lll5lll;lllllClllllllllFllD8P^QIJlP[O]lDG3:DlEQ^RA[l\llDC4llAllllllllll?ll;lAlllllllD:llllllllllllllllllll2llllllD7' +
    '3lllClllGlllllDllllIlllllllD8Gl?lEll5EllLllMllll7CllllllD==lll6lll9llHll@llllllllllllD7llHW<lMSOl>B7GOll<<PlllllPlD<' +
    '6lllE@ll?lllll5llllllllllllD??llC9lll<lllll5llllllllllllD=lllllllllllllllllll?lllllllD0lDlDllIlQlTK:VlMlJMSlllJlllD2' +
    ':lTl@Oll?ll8VKDllYQlllMl?JlD7lll0lllllllllllllllllllllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=B@CDBFD@KMDBE@@RC?<HJBUIVlDl' +
    'YFACUMDRDXK=C:ZFW=@<IGNRER_D?=LPU9^]Y?J`<LS<Vc@DO>XYb?_[DA<[GQ;\\<AfABWW:XYCJ=C[agI^lDAlllllllllllllllllllllllllllD0' +
    'BMD@ELKUL`TCE>NJP<=DSHHHL\QD7@^X[>AY\<hdEY^9[k>QDCk\_PleD7?TXT:ZK?@j`FPE@Ul?ELCcZhIaVD7;WYV5]b_<ibQSL<UcHPEIaVhK^\D<' +
    'CK>DBGDaU^OAE8>HVD==UEaRdMQDE9UQS9X]XEWVYTX8NhQQY9TZc`dlDACMWT8PPP;UTHOCHRfN>NM[RcJaZD6lllllllllll0lllllllllllllllDl' +
    'lllllllllllllllllllllllllllD0BXC<>J=VBWKKQJBY]WA<INYaJZND8KJGFP?HRLUJC@:DDg;DB>FDRO[`D=<XPM<WTCAd[>HY<Ae:FDC^^cKc_D>' +
    'NXU[ZW_^MbdHX[W[YVKL1YXcfdlD=llll0llllllllllllllllllllllDllllllllllllllllllllllllllllD0lllllllllllllllllllllllllllD0' +
    'CDBECNE^D^O?B=PBa:;=^W_RLVTDBllll0llllllllllllllllllllllDl;TWU:X_=:XXMWC=XlHAQ\^R^RlXD;@N@V@O[J?baPKWJ;[UR;HTXGIalD6' +
    'JPMPB]X[Jk_JIL<IlIALU_Od`YPD2;QWN7[VM;VUJRT=Y`OOSEXS]GCVD:lll?lllllll:IllllI3;lJlllllDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDD';

  RussianCosts =
    'BB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlWB>FA]SFTH?;B;PE;ACIHISRMllllM^NXDR9Zll^9Xl?lZ@]\:X<Xl>lLlllYgEUMKXlDY>\LZM;`G=lGDNE9KEBJKlJYUZl\:OUZMXDQ' +
    ';WGRP:]l@lU?UJ8l9gY@ll]l]l]V]MPllDT=^@X^9>I<lUHLH9^@U^AlQYl^l^MOLMPZDVa]8A<L?LTNC>FD^A=@MhD^^]TNllllReeDJ;TlQG6dl8lNlUMBjPOl<lllfllllTTLljDQ' +
    '2VBZG?[lElcGO?BlIVZIlllllllQWWWR[DVQNDBEK\9SVJD?9GNC9DMVOUVNXlllTJ]\DNKLE]F?lZIlDCB=7^B>FfcLFHKllIllb`YD<8lH[]El]?llAWI6T<OU>]Sa`WlUOYOX[[DW' +
    ';UXVU8U\8lUIX[<\lWX?lXl\\l\KBK@GlDT7WWQY:`l;lRKRD:VTPW?YW[[ll`LULOJlDS5[ZPK8^l=lNlYN<YSNMFYlPSl^^LITOQUDUV8JFA]NH[Q@CLHW>><:UHHMJOUlllW_X]DU' +
    '>l]\d<l_Dl]B]X7[6LSETY`][ldQQU`LlD^6STPP9SXAlNQTN;WTNO>WU^[]l_ETLPJ[DW=LBVM<Xc@lCAFH:AEO;@NONMYlRKSSOScDW;XGll8l^?lLQlQ;Z9QS>lQll]\lINQHH]DU' +
    'JDBB@JJCEN@ACAG?@;AlMJ[=KTll[GZRkDP;llZl<lU9lT?XY;l:UX?TllllllgVMOlgDS7XFXl?ll=lSGKV8l=^T=WWllllTXNIMlhDJ<k>ll5lC9lHSglITSOlCljblklkETkGJbDN' +
    ':llll4Jl;lPDRKGlIWG?WOlWellQKSlliDP8lAll;ll<lBCIH?CIR=@lJlOlllOgLWleDR>hhhh4hh8hhhhO]hZhh:hbhhhhhhZhhhhDGINTTT4TTITNNTTKTKTTETTTTTTTHTFF:TD;' +
    'lCE?C@QCX>J?=?bCJFIeb>VLH\lllleWTD:]HJLF@[HK_F_E9KNU>EhJVJMGRh]haDBHD7lGDKBlRLXG9;?>OB??>MDQgXIllllllPgDQGGI:Fh:HQPFCC;lb:DFlQGZSPIlllQ]Q]DD' +
    'lF<C@ZR>KJ>IA<R?<@LllGROMJlllSY`SDD@ABC@PLFDO>B?DE>B?AHEDQHHVbbbGMNbDbDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDl' +
    '_CCBHRUHWP>@=?`I;=BUFDSTVZlllaSLXD;:CSlE>JW?lW?kH8l?AWBXLklk^VGjSbWMDF<lRML@]X;lF;V@?SEA@Nll\S=SlGNVUHWDB8SMWI>ll>leGD@9W<MSBlSllllQRlWWlWDE' +
    ';NMTK;DI;lEGC@?OCCTE[PERIlPCHkTVLDAc`;UW`PNgXSM9H`^OQ3VRa`_VelllllgVDC;SlS:7Sl=lZSS:MhiGlDllkdllll`dflhDC;G>F@AlT>lMED><WAJ[CllLNllO?UllYTDD' +
    'WB>OFN^EUPA;;:O[EBBcMOWIKblllkZKMD=HFHL>FlFMlC?A<@JE<@TMMIRCllMXlNMMD=;TJSSCP[?lDBPZ:lB?9AWPERRl[[T[[[ND@<P[PQ>Wl:lICMj>VaFIJQSl[ll[I7aQLKD>' +
    '?CO]U;]R6lNNCJ>EUFVGWRTU\llGVl]KND;>T_D>CQR:lEZ_>>_P=?JXRFNP[[GHbXKID?[FCEJNRPEEEC@BXEA9DZUIYEX]lllJ`VID89VlVl?ll:lMElV:A<FD@jVVRRllMVVlVRDF' +
    ';IMGA@RR=lBFEB>NI@>ERCROG\_HGWXJPDCBXXl]DllAlACQAD@Y;7IQMPKGUlI@]WUKDA=[Ml_:ll;lGHQC;lBEJBPRYJlllB=_TURDAHJ\D@RXAOb@?C<aO=@>iJRM=NZlOlDSROD?' +
    '>SlOl?lQ6lRPeH=O@DBFCllllllMMSaSOD>>lGlPEllAlTNAG>XHCCIXllNXlllXellJD4Il\llDlU1lCMVlXjlilJllMllllRUleedDE7ljll7bl9lG`U?KT`KPGlUlJblljLlllIDC' +
    '=NJSl9ll9l>FJ?BNRBEESLlgSllSScljLD@;llll5ll5llllTbl_llKlgllllll_llllD\INTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=iJBJK=ONU<GH<G`IGCFc_;TIFYiiiicTRD8' +
    '\GJKF@ZHK^F^D9KNU=DgJUJMFRg\gaDBHD7gPLSE^[S^IC:G=WL6=@TMWWZPggggggVWD@bZd[Yl[[fdS[]YlfUO5lkc^Wd3lllfalTDDlhLUbcfaliPZQJ\[aCLXlR\[lbllllbiVD0' +
    '?BAA>_JNB^?B?BI?@@BKGDPKHPlllFKPlDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlPEDGDHRBO@B=H=QN;@>IWBQMFilllYbKOD?' +
    '6UZeY?\a<lID]M:b>O]DjU\_]PQL\XTY\DB;dYXV:gU5lLHWH?XLEOLfXYZJ[fAT_aOWDB:TMUO?da?kPCOI6\>LS?XZ]ZZkBW\TTdQDD?YKXS;IP>lOOQEARHIW5cWTURlZKRWUPUDB' +
    'YSSDAQBCPDA;R?Ub7?ClTRKUNOlllVlSkDA:S^XA5Th>hK^V@BZ[HaFhh\Vahh^QVXhZDC:JBJB:WY@jLID@8^FL^EjjWU[jYDO]ULVDGJBEKPIdHKBF;K;?V<G<SSOJGKKllllPIOD@' +
    'TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND29dRad>f_9lUL\V6`HLK>d]Uc\lc]a]beWDE8ilcU;fl6l^Yf_>ll_cJlklllllUGJACfDH;MU[^6^^>lTQLJ@IXKZ@Z\Z[_egITCZPTD;' +
    ';`dVSDcb@lVejN5lcOQI`cX^cfl8XkbJODJWG@@BHFGQDC:DDiM9D<OVRTGP[lll[SKVDD>\a]d>lcAlR<^M9K8BBDW[T[YggMQXbOVDK4cc^_=Rl<l_c_R<hdVVChcijellHFKEBhDU' +
    'JIVibBllOl7?XT?QZJ6C_NN^`lhYMNaKJDI9UD^U?l`?lKOTF;Y9FOFXY[UchdHE[UOQD>IM^F>KGLTO@?EBOV7@AVKBHEE\lllKIUODA<]dUd:dW8dTCSO;W=IFCE]dddddONQOXNDC' +
    '7bQb^ClhHlXSQM7aKOP;`eb_cl`b\W^lYD=;\K^a:hO8hCRXa8YaXhCh[Sh\h\AU\TTSDD8cYci6Qi9iHOV?ObOOLI^XiVQiiYM[c^UDB<\K\a:gg4gDFOEGMOKDH\T^X^ggWUU^[RDG' +
    '>llll3ll8llllFal^llHlfllllll^llllD\TX___2__S_XX__V_V__O_______R_QQ7_DHlZ<DZE^]dDA<ELlXV@<llDc<EillllldPD9`KNOJ9^LDbIbH<DRY?HkNYNQJVk`ke:=KD;' +
    'fOJRI\YF\;<AE;UC?;;RKUVXOffffffGVDIWOYP:aPH[YD<SNf[?B7fJXSLYClll[EaVD=hSKFLMP6_FNEG>FSELEclKTR]LllleMSUD7@@EACTOJGR9ECGHBF:ECBBULLZeeeJQQeDe' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlVUEOIBKOTIL;H8l_@H>j[LJQL^llllDCPD:=OS_S:VZ?jP<WG;[>HWAdOVYWIKFURNSVD=' +
    '=f[ZX6iV:lNJYJ:ZNAQNhZ[\L]hGVabPYDAC[T\V9kgFlWJVP7c<SI8_Idaala^c[[kXDK>]B\V<DT=lSSUC5UGLZKg[XYVl^FV[XSXDA^PXQ>PMHlGG?X:]W8?=l^ZGIQHllll]XUD@' +
    '<P[V?7Re8eI\T>DWXF_CeeYS_ee\NSUeWDF8DBBEF_aBlTAHF>g;TfNll_]claLXe]<_DADREG>GGCIID=O=O\EA=YX`E9ILllllOFTDETMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2' +
    '4l]llAli;l_;ga?SLNU?lh`lgllglgllaDS<Vldd5gl?lVZg`Cll`dTlllUlll_HkP8gDP=RZ`c3ccClYVQOAN]E_E_a_`djlFY\_UYD><Uk]Z;ji=l]llU7ljVT@hk`ejll:`lNEdDS' +
    'VHAC=AN@J>G>AHJG?>K[k[UKPVlll_SlID;6bgbi:li<lXBdS;Q=HRJ\aZa_llSW]hU[DG7^]XY6^h?SZ^YU9c^PVBc]dd_llQ^edRbDDLiall?llZl1RcXSKY\=UkUkiklleOlSOjDM' +
    'FNPjaIllDlW[LM1eEQ[Gdeg`lllKQgaP]DBIT[W@AWH]O??IORLMEJha?bEDFlll]8KbD9=^dUd;dX8dUDSO<W<JGDF^dddddPOROYOD?AbPb^KlhHlXRPL2aKOPL`eb^cl_a\V^lYD<' +
    '9_N`d7jQ;jFU[d@[c[jFj]Vj_j_:X_WWVDC;f\fl5Ul8lERZBFeRRPAa[lYTll]P_faYDE;l[ll7ll4lTW`UW^_\UFldlilllgeSllbDXAeeee;ee2eeeeMZeXeeKe_eeeeeeWeeeeDU' +
    'JOUUU4UUIUOOUULULUUEUUUUUUUHUGG;UD9lDDIA>PHJ@OL=Jl?D;Hll;ZEBllllllKQD@gRTVP5eR@iPiOCVY_HOlT`TWQ]lgll?9HD;cLGOFZVNZ<?:C9RG>C@OIRSULccccccQSD>' +
    'QISIH[JIUSHJLH`U8A=`YRMFR=fffUP[PD7l]U\IWP8iJJLM<f]VL7llUPFg:llllW]_DAA@@@DXSC@WD@=CD?F@CBDLYHP^jjjGHHjDjDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'BB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlQIEIEFRBLEP=@:VK=C?JNLJKOZlllTFITD;=RVbV;Y^8lSDZJ=^AKZ=gRY\ZLNIFUQVYD=5h]\ZAlY7lPL[L>]QFFQK\^_O_kFYdeS\DD' +
    '<XQXR:hd;lTFSD9_AAVB\]C^^l^Z_WXhUD=3\N[U=FS@lRHTH@TDKYAfZWXUl]BUZWRWDJeJJSII`NSDK>G7?O8EBWfbS`WglllllPSD>;O[U>6Qd;dH[S=DWWE^BddYR^dd[NRTdVDF' +
    '9IAIA@VX>iJHC?;]EK]DiiVTZiXCN[TKUD@QBJGCCPG?CIAD=@EECCjWH^;WillllIAPD=TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2=HGacKf_9lUL\H4_HLJDc]Hc\lc]a\beVD@' +
    '6glaa?dT;l\Wd];ll]P=kiljlllFJOECdDE4RZ`c:bc=lXUQNCN]P_?_a^`cilGX[_UYD@:_bTQ8a`:lTchL<jaMK;_bW]adkJWjaF[DF\RAJDTTRZNSAFDUO=CFYSlTPXZlllalRKD3' +
    ';\a]d>lc@lRC^M9K:LL;W[T[YggMQXbOVDB4dd_R;dl?l`d_V>idV]=iXjjellEePOHhDMDGJf_KkLLl3NUQGNWN:P]K\[]leWRc^FKDA@WFGW?lb@lMFVI6[ACQAZ\]WfkfDH]WBSD=' +
    'A>KMDONF^MN=@=SN=<CibZcNCHlllOKTcD;?`fWf;fZ9fVEUQ7Y@KIEH`fffffQPTQZQD>9\K\YAic?iSMKG=[@IKG[_\Y^iZ\VQYiSD6>ZI[_9eL7eAOV_EV^VeHeXQeZeZCSZRRQD9' +
    ':bYbi5Qi;iHOV>NbNNLH]XiVQiiYM[b]UD>=ZI[`9ff6fCENDEBNJ?F[S]W]ffVTT]ZQDF;````5``6````GU`R``E`Z``````R````DOBPVVV6VVJVPCVVBVMVV>VVVVVVVAVAH<VD=' +
    'lDFMNAR=X?JK@<cL?BCfb>WLB]llllfXUD:^AKMG>\IL`G`F:MPV?FiKWKNHTi^icE:ID9eECQH[XP[B=;<;FI=ABQJTUWEeeeeeeSUD@SKUDC]LDWUJ=E@bW;<@b[TNGT?hhhWR]RD9' +
    'cNFMGHKFZNIGB=VNGG@^iFOMXGiii`HNPD4C<@>AWRLJU?=FEE=I?DNKBGOO]hhhFSThDhDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDl' +
    'lS?HLDMWQLF=A;QK>Q>KSFQELlllllCMLD9?RWbV8Y^8lSDZK;_?LZ?hRY\ZMOJYFQVYDE=ledb;la7lXTcT7dYN[;ldfgWglG`llLdDJ=YSZTDjfBlGHUN4a9QXD]_b_`l`\aYZjWDB' +
    '<^I]W5NU:lTJVJ?VMN\DhCYZWl_AW\ZUZDEQHDNNMHMRAE:A8JI<BDUQQLSMlllllSILD>9bThQ7Pl:lSlON;jTOl@lllelllTaLglPDB=TLTL7ac:lVKNJ;iQLh?lla_elcDHMCGaDE' +
    'ANBOIGTJFCD?B9CJB@>LK`DFSRllllMCMD@TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND29jGgi@ld9lZBb\7NDQP@ic[iblibgbhk\DH@bf\\8^O6lWR_X:flN[IedleillWFbT@_DD' +
    '?V^dg>fg2l\YUHARaTc@cebdgllQ\_cY]DB?il^[:kj;lRllV7lkWYHhS`fkll9alNCeDPX@9HQMCKMGA>>?TE==GS[HWHOVllll\\PDBHfjflGll7lLLgW6U8VUI`e]ecllWZakX_DK' +
    '9``[\9Qk;l\`[X8T`SY=e_ffbllHaUMLdDDPPPUTAllNl4WJZHWTW6YedeTfll_ZlTVeDF<X8bY=ldAlGSXJ>H?ISE\]_XglhLE_YSDD;C?IEVGTOFQ@AB?dJBCHkV@KPA@lllH@VKD:' +
    '=^eVe=eX9eUDTP7X<JGDF^eeeeePORPYODD6aOa]ElgGlWRPK8`ENO?_da^bl_`[U]lXD:3bQcg:lT>lIW^gH^f^lPl`Ylblb?[bZZYDI=i_il5Wl5lNU\EThUUROd^l\Wll_Said[DH' +
    ':cRch6ll6lKNWLFKVSGOc[e`ell^\\ecZDO;````5``6````GU`R``E`Z``````R````DOMEYYY4YYMYRRYYOYEYYIYYYYYYYLYK<:YD>lQBCCGH^fGBXCElYAOWllAdMFjllllleRD3' +
    'g;TVP;LRIiEi>CUY_EIlT`TWQ]lgllB;RD8fP:RJ]ZR]=@@A<DK@C>SLDWYOffffffUVD=WEIHMaCO[C?PGAJF>6Df_XRFIClll[VaVD=lZSLDLMSfZISDAcZSK8jlI\IN6llllT[]D:' +
    'ABBB;YIHGWADCGG<C=CPBBZHQ_jjjFIVjDjDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDldKPEMWZC\UA7J:e@GE9ZZVXY[_lllfXQ^DA' +
    '>RRld:gk@lS>g=;l=DJAlSMMSO\FRcBKHDF=lZML>lS=lFMR@;\A<NIY\PPJ]lAPlYIOD<<KbPPAll;lCFON5lCOSAlRlLlllklhilfDF>TFlS;JW:lJEM><DF?TAXl\MElVHLlVMTDD' +
    '`\8LS]\McMMPBK\[G>EfaKKQ_bllllhdRD4;TlR:;dl:lEle;ILT@lGllPTTlllEegliDC;QDM;>IR;lHHL<=lMGlBllUhllkHPlU^UDDSWDHENZ:QLMM;=RVN<L_YFSN[^lllgVNFD8' +
    '[FNNHJlJllFHE>TLI:Dl[MHUBlllllZUND4<ZIlVGllClJEPg<SB:8BlRElQlllVZllPD>AYYQY:ll<lFBVV?_^QNNVll[_llJ6lL@[DC>JXXl;\X?lMGTB=CXHRCX\OTS\l@EllJXD7' +
    'ALWLFAbN8lFW_9BXSA>NSUINQP]DG_WLMD?S:L@?WIOJSC<F<bA<DCcCNO\aglTlSjS\DB<QlUl>ll<lI<UF9I;JBCUlGlkllPUjUGhDP=GDDG;DT>bFID??LF@CIPGNNGabIMllMJD?' +
    'HXP[lCllIl6HPDFEX?7L_UUNUl[QNllDQDD=NG^U?l^?lHJW??Z?;EIlRXNZllEHlVQMD9OGS==QOHTY@=@FX>A=B`YQYGCQlkhIJ\JD==klbl;le=lbD`K:O>V;LAklllllOO_\fID?' +
    '8SGSLFllAlDID9:SJGAHjlLNSlikf`SlcD?FkZll@l]9l7SflEKlOlYliKljlSJJRccFD79ljll6bl<lD`T:Hl_POIlilfblljClllfDH;QLil8ll<l?H\:FZ\CCFiakekllcIakhQD@' +
    '6llll4ll?llllTJlNllLlgllllllMllllDJINTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=iJBJK=ONU<GH<G`IGCFc_;TIFYiiiicTRD8\GJKF@ZHK^F^D9KNU=DgJUJMFRg\gaDBHD7' +
    'bKFNEYUMYD<<B>QF<B=NAQ?TKbbbbbbPRDEVNIOM`OOZXMOQ?eZCK=e_WRKW8kkkZU`UD5lYKXFSVReYUK@?bYKD;MlJ[XcKlllkSYHD3@CAD?\WHEZ>@AD?>E?@KAG\GHblllHXYlDl' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlUGCHKBTIMBE<D9UT@F@T_I]TUAllllBGQD<9QVaU:X]?lRCYI>]@KY>fQX[YKM;XTPUXD@' +
    '9`USR<cP>lHDSD;THAKHbTUVFVb=P[\JSD>=UNVP@ea=lQDPJ4]>MT?YZ^[[l[X]UUeRDE8fWdR4U]Hl\[]QD^TPc>lc`a^lfCMcaJaDHfKCFLNbMYCG>D4XR@>BlNcQXYhllllYUjDA' +
    ';R]XA5Tg:gK^V@FYZHaEgg[Uagg^PUWgYDI8H@I@?UW>hJGB>=]EJ\DhhUSYhWBN[SJUDETQ8IBFNEPHF<B>QU?A>VbLJMdNllllQLfD@TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2' +
    '7eSbe?g`8lVG]W9aIML@e^Vd]ld^b^cfEDJ<UYOO;RZ8lJERK<Y`JNDXWlX\_aJ;UGCRDB;LUZ]9]];lSPKI=HWJY<Y[YZ^dfHSVYOSD:@dhZW<ge;lZilR6lgSUFdg\bgjl8\lOG`DS' +
    'HH?DEJV@IMC@D:\R:HOAKZ\VFalllHdKVD=:\a\c>lc@lRC^M9A7LLDV[T[YffMQWaOUDK9MMH@;MX;hIMHD;RMEFCRLSSO_aHNUTKQDDL[Sf_KllLl1NURJNWNCP][][]leWRc^M\DP' +
    ';RA\R<i]=lHLQC<V>CLCUVXRafaECXRLND<AIMRFUGJJE<@F>JK7L@M]UNPTFlllLH`^D=<]cTc;cW8cTCRN;V=HFCE]cccccONQNXNDB<ZIZWDga@gQKIE;YDGHDX]ZW[gXZTOWgQD5' +
    ';ZH[_9eL6e@OU_EV^VeGeXQeYeZ>SYRQQDA>cYci8Qi5iHOV?ObOOMI^XiVQiiYM[c^UDB;YHY^8dd9dACMBDKLI>EYQ[V[ddTRR[YODD;````5``6````GU`R``E`Z``````R````DO' +
    'INTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=iKCKK>ONU<HH=@`IGDGc`<TJFZiiiicURD8aLOPK7_LAcJcI=PSZBIlOZOQKWlalf@:LD;bKGNFYVNYD;>B7RG>B@CHRRTKbbbbbbQRDE' +
    'PHRIGZIITRG;BG_T>@>_YQLER<fffTOZOD8cMFMGHKFYNIFB@VMFG@^iFOMWGiii`GNPD3ABCDARMGEP=C>EF?D=>IF@RJJXcccHNOcDcDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'BB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlUC>DCNLVGK>A@<S=BDBPUCAK[EllllRKjD@?Y]i]9`d7lZJ`Q=e:Ra?lY`baSUJ_\W\`DI:lgfd7lc=lZFeV8fCS]@lfhiXilCbll]eDL' +
    '@^W_YElkBlZ7YC6f<V]Cbdgdeleaf^Ll\DD6gKe`9V^DlI\^;@_DVdAleab_lgGSebSSDBbQESOI^\QCH<;<LI8IEOE_RTadlllQkMfD<7R]X@6Tg<gK^U@FYZHaEgg[Uagg^PUWgYDH' +
    '7JBKBAWY:jLID@?_>M^FjjWU[jYDP]ULWDADUHN@HcMCDB@A=A_;F?VVTACdgllllMARD?TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2;gUdfBia6lWO_Y6bKNM@f`Xf_lf_d_ehYDK' +
    ';ae[[>]f8lVP^W6elVZ@dclchklEGaID^DG8[cil6klHla^ZM<WfYhBhjgilllDaRh^bD:4fj\Y>ig=l\klT:liUWGfi^dill=JlhKbDOS>6IFS_UMFI?A=GE@JDfVceJEjlllklRRDE' +
    ';\`\c=lc@lRB]M8J7LKCVZS[YffLPWaNUDK5ZZUV9[e@lNZVR=_[RS?_Z`a\llF[baA_DRGZRe^JjlKl1MTPIMVG>O\Z[Z\ldVPb]L[DH:RB\S=jA=lILQD;W?CMCVWYRafbFCYRMND@' +
    'B?ONM:UKP_M>@EPMEFLf_O`?OWlllP<IPD9<]cTc;cW8cTCRN;V=HFCE]cccccONQNXNDB<ZIZWDga@gQKIE;YDGHDX]ZW[gXZTOWgQD59\J]a<gN7gBQWa:X`XgAgZSg[g\@U[TSSDC' +
    '?dZdj9Rj4jIPW@PcPPNJ_YjWRjjZN\d_VDC9ZIZ_7ff9fBENCELMJCFZR\W\ffUSS\ZQDF;````5``6````GU`R``E`Z``````R````DOKPVVV3VVKVPPVVMVMVVFVVVVVVVIVHH9VD?' +
    'lJ6A[N_QeL9EEMNYDIWllLd?VjllllRebD:cNCGM<aOReCe8@RU\DKlQ\QTMYlclhE<GD8aJEM>XTLXC=;A;PE?A>N@PQSJaaaaaaPQDDRJTK<\KCVTIC><aVEB@aZSDGS>gggVQ\QD8' +
    'lJIVIDUPE8SBD<`WPE<glIJWaCllliQXZD9?DEFCSO=GRA@?AB>EB>?HGTKKYeeeJPPeDeDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDl' +
    'jNPHD^aQc\C6I8kGDD>RNQBUVfllll_XRDC=NRlc:fk>lE<gL:k?GS?lOfiKY[CLbHcSDC7lZlV?lZ@lKGk;=lOLcGllRV<ZlCRllNZD@:UQOb@ll;lTCIC:U9Jf@llllUlljlQhlJDC' +
    ':WKiI8DF>lJNS@=bBGNDlhMfclkDcQfJSD>[e@SQfdP[>TM<DeMGGPljSSdhkllllllQD3;^idI6`l>lEiL8IefAPGllgallli\acleDF<C=GADlZ<lFI;A<lEO[BllllQlZKZlZQRDF' +
    '_c[TTZX[]XXNSN]XKOXkeU_YgjlllXbZWD0lil]e]l]WlWffFSli;e^llK]flllll^lUD18]JllA]l<lNFWM8lFDGCYYQYSllllX]]GD;<R[SK@ll9lM=RV<UlCRLVXlllllL:lQHXD<' +
    '=JIlX<\\:lOTIG=ATC\FMVUX\llCX\lU\D8;RO@C@LT>lFR`E<Zl;CGKSHPaaaDHaZGOD>HGHCD\`CTXJBG3fHEDBSNRMWfklllTleTD@:llll=ll?lG=lK;>BDACglHPjllIbhlIID@' +
    '<QRIRBKS?lFJJE5[RCK<kSW[SlWPS[WNSDB?VN^VFllDl@AQLC?YA6HXILPZllI@WlMSDB:XK]]7ll>lKPNE>lDDJC]XTVlllE>\lTMD@JNTE<RPPVKME8HYCA:BaZS[MJRlliKK]ID:' +
    '=lldl@lf6lcLLI;f>NAFBllllllG]`^gPDC>lWllLllElURaR?lVAIKWllllllYlfllWD29W]ll:lV6l>dWlNWlklGllMlRll>hlWOSD@All\l3jl@lLhS=[lgIMM\ll\illlMlllSD:' +
    '=fFgl9ll=l=BF;EXZJABg_icOllbH`ifOD?8kkkk4kk>kkkk=`k^kkFkekkkkkk]kkkkDFINTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=iJBJK=ONU<GH<G`IGCFc_;TIFYiiiicTRD8' +
    '\GJKF@ZHK^F^D9KNU=DgJUJMFRg\gaDBHD7eNIPH[XP[F>8D;TI@E:Q@TUWMeeeeeeSUD@aYcRXkZZecRE\EleOVOljb]VbLllle`k`D0lhZhQc[Zlh[Q=Il[aWFll@jhlallllZiKD1' +
    '@>NGBIWFC[>>>DDBD>DTEALDFblllELYlDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlYKELHMOHRKH=>6EL?ECOOKMNPUlll\NGSD<' +
    ';V[fZ<]bBlW:^N8bEPH=kV]`^QRC]YUZIDA9eZYW=i=@lMIXI:ZN>PFhY[\L\hFUabPCD<>YRYS;ieAlUGTE9`BEW:]^a__l_[`EYi=D@:`KMZ7;FClVLXL?YJF^Aj^[\LlaFYG\G\D?' +
    'WSJPFTSEZKMDD:SR7?>]XTSRVYlllj_[CD;;O[U>7Qd;dH[S=DWWE^BddYR^dd[NATdVDF8GGPG6\^=lQNEFBdLGdAll\[`l^JUbZQ\DAJNGCJEQFHCDDE>INE=>VQHJERUlll^MEDD8' +
    'TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND27iHfh<kc<lHC`Z8dLGOBhaYgalgaeafiFD@>`dZL<\H;lUP]V6dkHYEcblcgjlF@`JNFD=6UHcM=ff?l\LKR;KL<bCbdbcgllE\_bLFD?' +
    '=IhNK>gP?lQOPR9lgBIGdTKbMjl:\lTOED<^OBFMQLDXMFCC6[K9CG]YB\UH`lllMcZVD@>`d`g:lgAlVBaQ<O<PEGZ_@_]jjQT[eR?D:8UUPE>U_?lQUPL:ZUMG>ZT[[Vgi?V]JRFD=' +
    'JOWlkJllLl3ZS^JZcL:QigigillQ^Wj>hDE<^Mh^8li:lIXMJ=bDAXFMId^lllKOd^XDD<ADKGCIGGMQD<ECPD?ACXQIRDHIlc`MBTRD9;_fWf<fZ:fV@UQ=Y?BH@>_fffffQPSQZBD@' +
    '8^M^[=keDkUOMI=]H<DB]a^[`k\^XS[kUD87bQcg8lF>lIW^g@^f^lHl`Ylblb;[bZZYD@:f\fl8Cl5lKRYBReRRPBa[lYTll]P_fGXDE?dSdi8ll4lLNX@OVLTHDd\f`fll_]]fdZDG' +
    '<````5``5````GU`R``F`Z``````R````DPINTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=kMDLM?QPW>I:>IbK<EIea;VKH[kkkkeVTD;]HJLF@[HA^F^E9KNU>DhJVJMGRh]haDBHD8' +
    '`IDLCWSKWB<<@<OD>@=LEOPRI``````NPDC=BSBH[JJUSHJBA`UDA?`ZRMFR=fffUP[PD6gDJQ@LOJ]RMJF@ZQC>DblJSQ[KllldKRTD3B>E@BXSNCW?>=?E=JF@PCFIPP^iiiGHUiDi' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlZIHQGKO?TLK@?>\H>EBONGHKMllll]N;PD88PT`T:W[@kQAWH;\?IX?ePWYXJLGVSNSWDB' +
    '5lcbM;l_8lVRPR?bVONHlbcdTelC^ikYaDF=EPXRBgc?lSFRL6_:OVA[\`]]l]Z_EWgTD?:WHUP=FN>lMLNB:CEFT>`UQROlWIPURMRD=FRD]GO`RNCNAE=QR<C?kWVaPVfllllPVOD5' +
    ':Q\W?5Sf<fJ]T?EXYG_DffZT_ff]OTVfXDG7MENE;Z\ClOLGA9bJOaIllZX^l\GR`XEZDCTSQYM?lST6TK=?TKFGG_S<^TR`llll_SRD:TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2' +
    '9jXgi8ld?lZKa[;eIKP:NbZhblhbGJhj\DE7ilcU=fl;l^Sf_<ll_UBlklllllTJO9CfDH<QY_b6ab@lWTPF?M\O^D^`]_bhkFWD^TXD8CMaKI?`_8lSbgK9iHLN>]ML[`cjGVh_9YDL' +
    'QM<:NBTNZ;OA:>QFAGHWWSdTSllllY`WGDD<_d`FAlf@lBFaP8E=BO?F^W^\jjPT[eRXD=7ed_`;UZ;lXe`\=je]M<idkkfll<eUNUYDK;J^VV=ll:l:YJFA>bO?DNVPegllN\liPGD@' +
    '=hWlh>ll9l^bgC9l<Yb>kWlhlllEYlVGHDAMDLTHLUGNRJ;ACSA;?COhMUNINlllP<ViD:;`fWf>fZ;fVEUQ9Y@KI;H`fffffQPSQZQD>6`O`]?lgBlWE:K=_JMNJ^c`]al^`ZU]lWD;' +
    'GeTfj@lW1lL[ajKaialSld\leleN^e]]\DE8cZcj6Rj;jIPW?OcBOMI^YjVQjjZN\c^VDC8_N_d:kk7kGJSAAQRODK_Wa\akkHXXa_VD@;````5``6````GU`R``E`Z``````R````DO' +
    '?QWWW7WWKWQQWWNWNWW;WWWWWWW?W?I=WD;lQIP?DG9[BMNCEfA<JBieAZO>_lllli[XD;`KNOJ=^LNbIbH=@RYAHkNYNQJVk`ke;8KD;fFKRE]ZR]HB@<>UE>C;CEFGX@ffffffEVD<' +
    'DJTJADJJVD?KMHaD@@=aZRM?S>gggVP[PD8eOHOIJMH\PKID9XO>IB`kHQOYIkkkbIPRD5=CE?D[KJAZ>C?CB<DBDKFE\EGalllEXJlDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'BB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlTG=A?JLISGFJB<XLF=AKSGSNJ^lll[TKKD96TYdX9[`BlUF\L=aAN\>iTD^\OPK[WSX[D@9cXWU@gT6lK@VG=WKDNKeWYZJZeDE_`NWDA' +
    '8_X`ZClk=l[IZT5g@W^Ecdheeleag^_l\DD9`Q^Y;EW<lVULK=JID]?iLZ[Xl`ALH[VCD<PI@D@OIFV@>OA7FKBB@TNQNJNSlll`WRQD@8Yd^E9Zl9lQd\:M`a?gLllb\glldD\^l_DO' +
    '9LDLD@Y[BlNKF<?`IN`BllYW]l[FQ_WNXD8KGCGJIKAJG?HE<GGF=?SJLD@MMllllPEQD:TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND28l[jlClg;l]OQE5hQGSDlQ^lelleQeklQDD' +
    ';ildd9fP8l_Yf`<llJcClVlllllFDjBEPD?7S\ad>dd<lZWRP=O^>`Dab`aekl?Z]`VAD=BadVS8cb9lVPjN9ldLQKadE_cflCYlc;]DGVG9<CL@MPICN?@RID?ALNMPGNKlllVlLKD>' +
    '8_d_f>lf;lUEEP9N<ONFY^V^\iiDSZdRXDC:NMH>8NX>iJNIE<SNFFCSMTTO`aHNUTKRDEQLXkdMllKlCNZWGNNK>Ob`b`blj\Whc2QDA7MMg^>li;lLX]O9bGFMBabd]Ill?NM^XIDD' +
    'E=P@K]<EER@NCAIHGDEWIHM:EUlllRMVQD<6bhYh<h\<hXCWS;[?MKGJbhhhhhSRVS\SDB8`E`\Ilf@lVQOJ6_IMND^c`]al^_ZC\lWD:<YGZ^9dK5d@NT^DU]UdGdWPdXdYBRXQQPD@' +
    '7e\el7Tl:lDRYABeRQOKa[lYTll\E^eaXDE=[J\`6gg9gDFOEFMOK>G\T^X^ggVTT^[RD?:bbbb5bb6bbbbIWbTbbGb\bbbbbbTbbbbDQJOUUU5UUJUBOUULULUUFUUUUUUUIUGG8UD;' +
    'lPEL[>@^e?@L@DlMWGLQl>dKAillllldQD5ZFGJCG\EQ`H`D6MKT<AlGTGKEOllllOFFD=fOKGD]ZR]<<B?<VE<CA@LGVGCffffffUVDDa<KM<kZEPL@MFNlLP?ATSb?8LKlllTRSSD?' +
    'lLFNF>KQlLG?@@QH=L@llFDQSVlllX=IMD8>FBB?HUOGXA?<GH=F=DQE?ZII`kkkHVWkDkDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDl' +
    'P\KDGLNKTDA=F:UY<A<NPHHOGllllXMGOD<:\`l`:cg9l]@dN>h=Kd<lHcfdVXGP_O`cDD;D\ZE?jWAlNKYJ5[BHCOiZ\]M]iDWbcQZDE;CPXR<gd?lSFR@8_AOEA[]D]]l]Z_WWgTD>' +
    ';WHUP9FN:lMLNB<O@FTD`UQROlWIPURMRD@WROOAOFNUDIAQ7Tf;@<llFIFIFllllMUSDB9R]X@8Tg:gK]U@FDZ?`@gg[U`gg]PUWgYDH5JBKCAXY>jLIEA<_GM_AjjWV[jYEP]VMWDH' +
    'RUWLIMlJKRBAQ<TV?DCZNGMCPZlll\PKQD4TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND28fTceAh`8lVNGI9a=MLAe^Vd^ld^b^dfXDC8KdZZ7\e?lUP]FGdIUYIcblcgjlDD`B;]DH' +
    ':YPgj9jj<l`PXBAOdWf7ghfhkllE`cf\PD@=cgYV@fe=lYhlQ4lSNTLcf[afil:[lSH_DGSF>AAHFJMCD=A:NN=>CJPLPJLIlllZ\SRDD:OlSl:ll8lS<l^<\BKKFSSdlLllOBSl_fDJ' +
    '6QQLM<R\:lNRMI>VRJJ?VQWXSdeLRYGOVD>DaYlQFllIl3TQWAT]J;JcabaclkQWid?QDA9BE`E@la?lLEUH8ZBAPGY[]VejeIG\VQRD?KU`OGVC@SWH>K=fY?CClSGXKLIlllTIjXD5' +
    '9ahYh:h[:hXGWS:[<MJGIahhhhhSRUS\RDA7^L^Z=jd>jCNLH=]GJLH\a^Z_j[]XRZjTD79]L_b8iP:iDSYb=ZbYiKiETi]i]=W]UUTDE8dZdj8Sj9jIQX@PcPCN>_YjWRjj[O]d_WDC' +
    ':[J[`9ff6fCFODAMNK@G[S]X]ffVTT][QDG<aaaa6aa4aaaaHVaSaaFaZaaaaaaSaaaaDPINTTT4TTITNNTTKTKTTETTTTTTTHTFG:TD:l]F]O?aSh<DO>Al[M>Oll<KO<llllllgPD9' +
    'ePSTH5cQ@gNgMBTW^FMlS^SVO[lelj@:PD;fOKGB]ZR]>BBC8VK9F<SLVWYOffffffUVD?SKUDI]L<WTJ<N:bVAH@b[SNGT?hhhAR]QD:lYR@KTWReZHRN8bYR=9jlR[AMFllllSZ\D9' +
    '@>JGAIEGDW@E<@AAF<CEGDYQG_jjjHVVjDjDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlWJGHDNOEKKG?BDYEAACHXEGAM\llllN<ND8' +
    ':X]h\7_dClYE`PAeDR`7lX_b`SUO_[C\_DK6g\[Y7kX=lOKZK?[PHRHi[]^N^iHWcdR[DF:LFVQ;lV@lQ=M]=l?DF@IOUlVllVlVTlHD<;PROe;FJ;lOMXK=d<AMAXURgKlYCUTgbHD?' +
    'LG@EDFIEKAFGA;DE=@CMHSEIJllll[XSQD<?Xc^D4Zl<lQdIFC_`Ng?lla[glldV[JlJDC;DJSJ=_a8lTILH9gOTfAll_]claCXe]J_D@OUHKL<JDAB;FCDOYGBDVTKBBUZlllXC:SDB' +
    'TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND29lLll@ll<lbHVc7VEKA?OkAVjllQVjllMDD7\`VV>Xa9lQLYR?`gQUF_^l_cfhBBHG=YDE8NVE_<__?lURMK?JYL[;[][\`fh@UD[QUD;' +
    '=]ldaCll@ldVl\6llS_D^lfllll6\l]RZDINN:<K?PNP;HJ<KQJF>NTOXVMO]lllV_QCD=<^c_f=le>lTA`O7M9NN?X]V][iiOSZdQWDM8UUOQ>UJ8lQUPL:ZUMMEZT[[VgiHV\\RYD=' +
    'EPX]TFllCl2LRVEIVW=GR\VllllRNWYYYDF9kPUk<ll:lQTWG<l<EfDWlUklllEKSTLHD>JSEQLJG[KeEAEHRWAD<WRPfIORlllG6SOD9@hl_l7lb;l_=^Y9b<KQIPhlllllZY\FcYDI' +
    '8cCc_:li?lYERG<b>PHDafc`dlaJ]C_lZD<>kZll7lK6lJEPlAhlTl@ljblklTAdTScSDC8ldll6El8lLNaIMlYYWChJla\llNXflh`DC<a?bg:ll9lJFUFLSUQ8GbZd^dll]Z[daEDB' +
    'Bgggg<gg1ggggN[gYggLg`ggggggXggggDVLPWWW6WWCWPPWWMWMWWGWWWWWWWJW?I9WD:lia_i:lll8f^:OlgWZ^ll8l[WlllllllWD;lZRFF>TRDl?TWGASgBQl\MHI?dllll=>GD7' +
    'cLHOBZWDZE=?<:SH?CAPISTELccccccRSD;XIEPNbQP\J=QSHg\?BEg`ISGCDlllG9bFD7l`BOZ>FElTD=FBi`MJ9llHb`OMllll>@PD:>?CA?_DUF^>AAGI?E=CGBCNINelllEOIlDl' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlbTALHUXFZS??A;KB>A:MHFVKX]lllLMOMD=BQJl\>UQ?lX?M?<l9BlClKl\O?ABXkUKlDL' +
    '9d]R_?cl?lEGPE;[L=SMl[RV\Q`AM`lUOD9C`VYLHll?llGYM2`?SWJ\lll\lll\`TlYDF=UELH>KM;lGKS;<ID@MC^ONI\lOFPZLCQDChdAQAdcJkQEUH=VYUURlhYVYfilllllkUD2' +
    '?dUj:6Jl:lHlh:NklElJlllgllllKgilkDK?M>C;=RT>lOID:AlBWlIllkLlllDNljCkDGY]ICAMS7WOKC>>X]M;<e`HEPadllll\TdDC^T^]NUlZllKVRFT]UFN^]lVNZ^lllllUOD1' +
    ';VTRVClP@lDDZM:T;AD?lQZ[NllU[ZllID;BQWFH>GV<lFDL@9T]NMBlPlNSTlJ:lGE\DI@J`l_@WaAlPSFGADlJa?llZa]laI`]lUND3;[PFF?YN=lEST==[R>@GJRGHYR_HMlULMD<' +
    'a7KODTXK[LADNGOA9G<`\GPIKHllldg]YDE=llll<ll<lN@lS9J;HG>YlQVRllEPYlUKDE>KJCB@MZ=lHLAA9MKB@DHULNQU]FJ^\FPDAERF`\BllClB?HB@DLB5EMQSTVllMCl`HODF' +
    '>JBlD=lS>l@DG@:I>CFI\SNI\\TFNTXKRDCT?JJAUSHE]D>EB\?B=AdKU^ACUlllENOHD:?llfl:li7lSGOR;SBAHGEllllllJFR`iJDC=kBkgLll?lRBQC5j:IKGQlkhllikN_glbDB' +
    'FgAil5lZ5l@IIlSdlclUlf^lglgLLg__^DHBlJll9cl<l=Ih5RlURAKljlhcllVJVllgDT>hLQQ6ll<l>;LEFZ[IJFQ`jejllcPaQhIDC8jjjj6jj;jjjj<_jDjjAjdjjjjjjCjjjjDK' +
    'INTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=iKCJK>ONU<GH=@`IGDGc_;TIFZiiiicURD9\GJKF@ZHK^F^D9KNU=DgJUJMFRg\gaDBHD7jSNVHa]EaAB=><YNDD7VAYK\JjjjjjjXKD?' +
    'VNYOMaO4ZXMHRBeZ>LDe_WRKXAlll[U`UD8lF;]IY\@j^M@F:g^?C;llJ`Qh>llllX_aD=BA>GAOO@Bd>FBDE>@??FEHUGJVlllGQMlDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'BB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDllTCK>INLVLD<F=SG8?@HOIKKIjllllJPQD@<OTBS8V[@kPAWG<\>AWAdOVYWJLFVRNSVDA;`UTR=cQ>lHDSD9THAAHbTVWFWbAP\]KSD<' +
    '<UNVP@fb=lQDPA7]?M@@Y[^[\l\X]UUfSD=<UFSN;DL<lKJL=<MCDRB^SOPMlUGNRPKPD>hdFPDTVVZEDDW@dR4D>WiIBAGNlll[llSDE;OZU>7Qd:dH[S=CVWE^BddYR^dd[MRTdVDF' +
    '9I@IA?VW>hJHC?>]?K]>hhVTYhWCN[TKUDFEXHOHOXJJDA?K>@W=7=RLSPDMIllllWJXDETMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2=dRadAf_8lULHV8`HFK=d]Uc\lcHa]beWD<' +
    '7ilcd7fV?l_Yf`9llUVDlklllllJJVLEfDN8KTZ\=\]<lROKH?AAIYCY[XZ]cfGRUYNSD9?]aSP9`^>lSbgK6hKLNE]`U[`cj9Uh_KYDLlH@G<MLDRNC8BCSE><CT_J`FS[lllJlKRDL' +
    '8hlhl>ll=l^IiY8WDEMCbg_gell>\cl[JD>=j_ef8Yl8lfjeb6ljVcLl^ll[llQ^_lJlDQ@]Ug`<ll8l7PVS@JYH@Q^\^\^lgLLeMN^D?>^Mh^>li7lUX]J9bHIX<ace^lllEOd^MZD@' +
    'I;]FLPZK_QJ<R@QVB9<kdKdFD@lllJTgUDA6ahFh>h\=hX@WS:[AMKGJahhhhhSRUS\RD>;]K]Y8icCiSMKG=\@IKG[`]Y^iZ\WQYiTD7>_N`d=jQ3jFT[dB[c[jMj]Vj^j_AXGWWVD@' +
    '8cYci4Qi=iHOV?ObOOLI^XiVQiiYM[c^UDB;\K\a7gg7gDFPEGNOL@H\T^X^ggWUU^[RDG<````5``5````GU`R``F`Z``````R````DPINTTT4TTITNNTTKTATTETTTTTTTHTFF:TD=' +
    'lVNLVIZY`GR?HRkTKO6lkA_TAIlllll`LD6ePRTN4cPSgNgMASW]FMlR^RUOZlelj7CPD?dMHP>[WO[?<@D9SH;D=PISTVMddddddETDGOGQHFYHH>QF@JF^SBD=^XPKDQ;eeeSNYND7' +
    'lWPWIRUPcXJILF`WPA2hlHYJaDllljQXZD<EFG<?VQKIF<CACJ?BDFM@>VNE\gggDBSgDgDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDl' +
    'UC?ICND=IGDAB<YMN>>LCHGKMJlll]QOQD=8]ala<dh:l^FdU:iDBe=l]QgeWYIQ`PadDD7ldca9l_;lWSbB:cWHZHlcdeUfl@NjkPbDD7TaUc<lT<lUHTF;lI@gCVVllOlVKlhhlHD;' +
    '<hLfa<?J9lPITH=`JCQFlKJcTlhDMeITJD;FC?D;KECKBCC@>ICJ>BPKFHEHOllllTPXDA7^jd;8`l9lAjbLGffNlEllPalllQ]bcleDF7OGOG:\^?lCEIBBcKGcBll\Z`l^DTaZQHD=' +
    'BECDDEKBEC?EB=EHF=?MKHHCJRlllUMCNDAUMQRINdOWjJJJB@SM>I[XTMRJdjYdjBUOD38lJLS=lk;lLKET9STBF?lPalNlTTlillND?8dh^^;`Q8lYTaZ;hlG]GgflgkllFAdVFIDE' +
    '6QUll<ll:leO]P<ZTDkBklklUllDSgUEeDB;NlTP@lk<lRlYT6llIVCYWbYWll9WllIQDDRG8D=FFGCGDD?@UDK>BPGKKIJRlllXZLJDE=fjfl9ll>l\HgK9K@GG=LeGecllKZakL_D>' +
    '9L[VW:[f7lWPVS;O\KTD`ZaOPllILcPY_DEBR`XQ@ll=l4[RP@JdM<KORigillNPlTZTDB;hFlX>lX9lPKM@<lEBW?IXlhlllELlQTED>ICS@>@?CMR>IBDT?J=F[OQTDDSlllP@PRD>' +
    '?hl_l=lb9l_I^D9aHDJNPhlllllHK\@GHD;;jJQg?lQ6laKY;=iTIPEQljgllMjQQglMD@?cJdh9lU7lJX_h7_g_lQlEZlKlcB\c[[ZDJ=jajl3Jl;lPJKFVjVVTAeKl]XllaIcje]DB' +
    '8gVgl8ll7lKQZHGN@WBJg_icillb``if]DC>bbbb6bb4bbbbJWbUbbHb\bbbbbbTbbbbDRKPVVV5VV>VPPVVMVMVVFVVVVVVVIVHH9VD;l@=JUFFLjEK?@Cl]\J=lUDHOClllllliND6' +
    'kCYKU6iWBl@lFHZ]dASlOdY\UalkllC>GD8iREU@F\TJ;?E>:X<GB@UNXY[IiiiiiiJYD>XPZAEGQI\F<FJDg\C;Dg`>SEDDlllKWbWD8SLMK9DA@kOEEA;h_XICllGaESFllllDMbD:' +
    'D?DA?\WRDL=A<BC=B@BSJC]TCblllRLYlDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlKKDOBLGRQFC?<9[K?IAHNDPOVklllYPPUD9' +
    '>X]h\;_dIlYB`P5e>R`;lX_b`SUO_[K\_DH?lfec7lb=lYUdU9fZS\LleghXhlMall7SDL;WPXR:gcBlSFRL6E;OVF[\`]]l]Z_WWgTDG;\D[U5DS>lRRTH<IEKYJfZWXUl]NUZESXDF' +
    'SK?ICJ[JSCA:?<NJ9FBRURLLhNlllllMUD@9Q\W?8Sf8fI\T>EXYG_DffZT_ff\OTVfXDG7I@IA=VW>hJGC?>]EK]DhhUTYhWCN[TKUDFLHDHBJZPEBB==<CH@@@PGFMIWllllSKDPD>' +
    'TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2<lP`lLll7l`MdW4lK[fDdlllllcddd]l[DG8llff7hl?la\ib8llae<lllllllIPTRJXDN:[Pil6kl<lb^ZW9WJYhDhjgilllBadh^bDD' +
    '>fjQY?ig=lRklT4liQWKfi^dikl;SlO?bDMQ>9HGESCXNA@B>CFB>ENFHDGTllll\H\TDG>RlXl9ll?lhDlc5a<bbAlljllllGgYlWlDM9OZUV3[eDlW[VR>O[SSK`Zaa\llM\NPX_D>' +
    '>YRll<ll8l:ADR=UHP?EjhjLjllE_lUZNDE:c:\b@ll<lIRZD<`;JcC^llllldGAYSLSDCBAGN;RDLUKG>ACSA@EASLCVOI=lllJMhPD=:gl^l:la=l]M\X5`BDPHOglllllXW[JaXDH' +
    '=f?fb@llAlLVTF3MOKTGdifbglce`Zbl\D?Ac@dh4lU8lFX^hF_g_lQlaZlblcEKb[[ZDJ:lbll7Zl5lQF_HXkXXURgal_ZllbVdlg^DK=bQbg9ll5lJMVKHTVR:EbZd_dll][[dbYDH' +
    '<aaaa4aa7aaaaHVaSaaFa[aaaaaaSaaaaDPMRXXX2XXLXRRXXOXOXXHXXXXXXXKXJJ>XDAlZ;@OG^IdKF@E>lBAGKllBcEUGlllllcaD6lNM_ZEl\_l@l@MJbiQXlTi^aZfllllFLSD1' +
    'eNIQA\XP\<<A;=TI=BBRKTFWNeeeeeeTUD=WOYH@a:C[YEEIEf[7LEf`XSGYClll[VJVD:lf^QX`cXlfU_NKRfU_DllPMHlMllll`fhD1;GBD?[IIIY@HAFI=@:BDON[JSalllJKXlDl' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlZG>LHIMONDD=A:\M>I@KMFHXM`llllHIJD:BW\g[@^c?lXI_O3c@Q_DlW^a_RSH^DH[^DH' +
    ';lllj6lY?l`Gk\7lOZc?llll_llMXllYlDB:WPWR:gc?lSFRL6^@OVF[\`]]l]D^VWgTDB9^O\W4MU<lTSUFCVLM[Kg\XYVl^CW[YTYDGJMKIU_NNRDB7B@IF9FEYPETJOllllllXTD>' +
    ':O[U>7Qd;dH[S=DWWE^BddYR^dd[NRTdVDF7KCKCBXZ>kMJEA@_GM_FkkXV\kZ:P^VMWDAHM<JLFNIGF?AE=LF@DBVIHJ<QXlll_OESD;TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2' +
    '7lSllAlj9l`Cga9k<WVClh`lgllhlSlObDJ9ch^^:`P8lYS`Z;hlY]BPelfklPJEdKCKDC:T]ce4ef@l[XSQ<Q_RaHbcacfllC[^aWED?=il^[Blj;l^llV6llWTGilaglll7alNNeDR' +
    'TH:DIJLRMDB@=?UE9HKQKYTBR[lll\lCMDB?afah=lhElWHcR;F5QQ=[`Y`^kkRV\gTZDC7hhW\;Yl;lYhdV7[T`a?lhlljllI\TWKVDGOTNllHllNl6SF_IVd[=HjhjYjllQ_lW5YDH' +
    '<`LP`9lk:lWBIR;eGF[HPeg`lllCHg`[HD<AMNIBT]HPUIBHDT;7EESUMHLFNlllUGRLD<?dj[j:j^8j[JZU6]@PMELdjjjjjVUXU_UDI9`O`]@lg>lWQOK7_JMOE_c`]bl^`Z@]lWD:' +
    ';^LFc:iP:iASYc;ZbZiBi\Ui]i^@W]VVUD<:K`jl7Yl5lOW^FViVVTFe_l]XllaUcjeFDD9ZAZ_:ff7fBENCELMJCFZR\W\ffUSS\ZQDF:aaaa5aa6aaaaHUaSaaFaZaaaaaaRaaaaDP' +
    'JOUUU3UUJUOOUULULUUFUUUUUUUIUGG;UD<l`?NV@dVj?GJ@Dl^?F\ll@iLGllllllOLD5l_bcTAl`NlNlMQUfl=\lQlbe^jlYll?AKD2eNIE?\XE\BA=?:TI=?BQJTDFNeeeeeeS?DC' +
    'AHZQDbDD\Z>A=?g\7MFg`GTMFDlll\WbWD=l<T@VV:Dh\FU<9eOKUBllA^[fDllllV\^D=?@HI?^MSCNC@>HD9E@@HFGNVMdlllBZNlDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'BB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDleWJXKY\DKAE9K;fK<D?Q\MDP\alllhZKKD;?JeUT<Tl:lA9SD<QAHKKlaHJhSHDTP_NTDF9la`J8l]>lTA_K@NJ>WMlNbc>clH\hiWJD?' +
    '7dGe_Dll?lR<MM8lCGc@hjljklRgNRRRRD@9iKhJ<GL<lLNK>9aHIRDlVdeHljHFVTNRDC]YDVQZY@aMMK9HYXKI3dLIZY\_llllfaaDD<BkR<7Rl9lKlRALgh@lKlliEllllQcelgDD' +
    '>BKZN:fR>l@BS@=RV>lKllfdjlh;CldPNDCSWOHENZ?QLC8I:QV?<C_YQSML^lllgVN]D=\EI=P@kW^lBHQCQIE9GE_[H?Rkl`klIHVD8;lFllDllAlHCUQ9l<B=ClQCULlUiQUTQQD>' +
    '?WQMK>WR<lDDNaAlXLHAlWlllllE7kT<JDA9CNPl8ll@lOPCBAMKEPFTlTNlll?dgjHKD<<VkE=EPP8l>RlB?lTEBKgRGRJVVFGPVUMD>[LDHJNRGUJA8G>XH<==ZUVYRE]lll^`IRD>' +
    ':llll?ll=lI?U<<>:LOJiSJllUlNcUlbhDH;FY<H?PO>lDKE<=UN@HBNRLQUlZCNlkLSDC>XTlkEllAl<BIEACP<8FigigillJJTXRPD>;ACOP=lO?lIJPC<V@?KBQVVRlllBDVVJPD=' +
    'JGMIEKIIOTF>8@SFA>AZSLTGJKlebODVTD:=ek\k;k_8k\KBV?^APBC;ekkkkkIIYV_IDC9LKPPFll@lKIGB6PJFBCgPPeOlgNcHelID>B`Gbe<lD3lBV\eL]e\lNl_Wl`lIBH`HGWDD' +
    '8ljll7Pl;lD`g>PlATPZUTlKAllUJlllTDK;hOil8ll;l:G\?HN\CJIiQkMklldQQkhID@Allll2ll8llllNclallJlPllllll`llllD^INTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=' +
    'iKCKK>ONU<HH=G`I<DGc`<TJFZiiiicURD9]HKLGA[ILBG_E:LO<>EiKVKNGSi]ibECID8lFAWOb_Fb>E8K=[P;@>XQ[M^UllllllZHD>d\f][l]]hfO]_[lhWK>lle`Ye9lllhclcD2' +
    'iSLCMNQ<_TOLH?\SL@FdlLUS]MlllfMTVD3@BIC=XHMFV@>A>E@B<BOLFHPP^iiiGTUiDiDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDl' +
    'gCCFKR^EM@>=A<hZ?C@HOJO\EclllF\UOD;:MR]Q;UY>iN?UF:Z=GU?cNUWUHJETPLQUDI:_TSQ<bP=lGCRC;SG@JGaSUVEVa@O[\JRD=7UNVP@ea@kQDPJ6]>MTDYZ^[[k[W]UUeRDE' +
    ';TFSM:CK<lJJK@<LBCQB^RNPMlUFMROJODBT]EZ;I][PC>=FAD\8<DhbKR]`cllllNJeDB;OZU>7Qd:dH[S=CVWE^BddYR^dd[MRTdVDF7IAIA@VX?iKHC?>^FK]?iiVTZiXCN\TKVD@' +
    'VVREJKe>EI?9F;HOEFFSTU=?QhllllODVDFTMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2:_M\^FaY;lOGVP8ZCFEC^XO]Wl]B[W]_QD:7`e[[<]e=lVP]W6ekVZHdblchjlUFIHF]DC' +
    '7LTZ]<]];lSOKI?HWJYCY[YZ^dfHSVYOSD9>VYKH@XW:lKE_C:aXDF@VYNSX[b9NaXMRDDfJCGNY]S`KFAD:cY4C@e`Td]NhlllikaTDH:\a\c=lc@lRB]M8K9LKCV[S[YffMPWaOUDA' +
    '5]]OY;]h9lY]YU<b^UVFb]cd_llL^HPMRDFHHPc\HhlIl6KRN<KBF8MZXYXZkbTN`[JYD?<[Fe[7lf?lIFZA<_GGUG^_a[jljHGa[?FD>KOUQDTRHW\EBH7KJ>F7cMT\OSTllkLI_]D>' +
    '>gl^l5la:l^M\X=`@SPMOKlllllJX[XbKD<:[I[WDgaAgQKIE;YDGIEY^[W\gXZTOWgQD5<YGZ^9dK5d@NT^DU]UdGdWPdXdYBRXQQPD@;`W`g5Og;gFMT<L`LLJF[VgTOggWKY`[SD@' +
    ';YGY^8dd8dACLBCJLHADYQ[U[ddTRR[XODD;````5``6````GU`R``E`Z``````R````DOINTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=lNFNNARDY?KK@JcLJGJfc?WMI]llllfXUD3' +
    '`KNOJ:^LCbJbH==RYBHlNYNQJVl`le@:LD:cLGNFYVNY@<<B8RG<C@OHCSUKccccccQSDERJTKI\KCVTICDIaV5G@a[SNGS>gggVQ\QD:dNGNHILGZOJGC>WNGGA_j?PNXHjjjaHOQD4' +
    '@EAG@TPJ@C@A>BI?B>@L@HULDZfffKQQfDfDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlPDGJJMSMI>F>A:QL9DCGIRVMNglllPQKMD<' +
    '9NS^R:UZ?jO@VF;[=HV=cNUXVIKEUQMRUDJ5i^][@lZAlQM\M7]QJTQk]_`O`kCYefTKDE=TNUO@ea=kQCPI5\>LSCXZ]B[k[W\TUeRDD:V>UO9EM<lLLM>=NDESD`TPROlWHOTQLQDD' +
    'HFGNDZXN`AD<=<@N;J@ONKOX\_lllleKOD=;OZU>7Qd:dH[S=CVWE^BddYR^dd[MRTdVDF8H=IA?UW>hJGB?>]EK]DhhUTYhWCN[SJUDFINCKBARMEHE><>NC@F;e_JQDaHlllSLEcD>' +
    'TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2=bE_a@c\?lRIYA8]8IHEaZR`Yl`Z^Z_bTD=9\aWW6Yb?lRLYS:agRVG`_l_dfiRB]HBZD@5T\be5deElZWSPGP_Ra?ac`beklIZ]aW[DB' +
    'D_cUR:b`7lUdiM6jbNPD_bW]belHWjJC[DEOK<J6\BBcJE?DFLH>EAMMMXPXklllTlXWDG>\a\c<lc@lBC^M8K8LL?V[T[YffMQWaOUDK4ZZUV?[e9lW[VR;_[SSC_Z`a\llU[baGODJ' +
    'I\Hg`CllMl9OVRCJXO:JH\]\^lfXSd_5]DJ8\Ge\;lg;lRVKM<`HCVA_`b\klkAMb\GXD=?IGJ6USLY^GDI?JKBA?d^M^LHVllIKNaKD<>^eVe;eY8eUDTP<X>AG?F^eeeeePORPYOD>' +
    ':[I[WDhaAhQLJE;ZDHIEY^[X\hYZUOWhRD5>Z=[_9eL6eAOU_EV^VeHeXQeYeZCSZRRQDA=bYbi5Qi:iHOV>NaNNLH]XiUPiiYM[bCUDA:YHZ_9ee8e>DMCDKMIBEZR\V\eeURS\YPDE' +
    ';````5``6````GU`R``E`Z``````R````DOJOUUU4UUJUOOUULULUUFUUUUUUUAUGH;UD:jLCKL>PBV=HI==aJHEHd`;UJGZjjjjdVSD:_JMNI?]KMaHaG<NQX@GjMXMPIUj_jD9;JD:' +
    'eEJQA\YQ\;;?@>UDAE:RKUVGNeeeeeeTFDCPHRAGZIITRGIBA_T:F<_YQLER<fffTOZOD8cMFMGHKFYNIFB@VMFG@^iFOMWGiii`GNPD3=ABGAUPJCS>A@CI@B><LIHUMM[fffKERfDf' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlgZLNPM^WSNLG<DiQ;T<^^ER]^cllljMPJD5<NS^R:UZ>jO@VF;Z=HV;cNUXVIJEUQMRUDJ' +
    'Ah][Z1kXDlPL[LC\PISPj\]^N^jIXcdR[DD<TMUO<d`?kPCOI6\;LSCXY]ZZkZW\TTdQDD<TFSN9DK<lJJL@<MCDRB^ROPMlUFMRPKPDBd`:OKRVKVAL>E7VC=AFjROUVcfllllWVFD>' +
    ';OZU>7Qd:dH[S=CVWE^BddYR^dd[MRTdVDF>NFOFB[]:lPMHDAcKPb>ll[Y_l]>TF=9[DK=TONMBhL:AHIPE9DBFHPJXR[Zlllll@<kDJTMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2' +
    '=l[jlIlg7lPTd^3QMTSMle]kelkeiejl_DF5X]SS8U^?lNHUO@]cNRH\[l[`beN>YKGVDF8LTZ]:\];lROKH?HWJYCY[XZ]cfGRUYOSD:<RVHE?US;lHW\@:]UACGRUJPUX_>J]TIND=' +
    '^O4<MQUSXLPF?H[QCKO]XYLU[`lllacYLD;>\a]d<lcAlBC^M6K:LLDW[T[YggMQXbOVDK:LLGH<LW=gHLHD:QMDE=QLRSN^`GMTSJQDDCRJ]V>chCl7=LI>ENE:GTRTRTe\NIZUDSDF' +
    ';QA[R<i]<lHKQC<V>BLBUVXQ`eaEBXRLND?PGICJIO9JJGICGJKE@D`YQZLPQlkhTE\JD6<]cTc;cW8cTCRN;V=HFCE]cccccONQNXNDB8[J[X?hbAhRLJF<ZEHJEY^[X]hY[UPXhRD6' +
    '7\K]a<gO8gCRXa=X`XgCg[Sg\g\EU\TDSDD;`W`g5Og;gFMT<L`LLJF[VgTOggWKY`[SD@;YHZ_8ee9eBDMCDAMI=EZR\V\eeURS\YPDE;````5``6````GU`R``E`Z``````R````DO' +
    'JNUUU5UUIUNNUUAUKUU?UUUUUUUHUGG:UD<lXPAXK\NbGTUJBlMTQTlOHaVSglllllbND1_JLNHB]JMa8aG;NQW@GjLXLOIUj_jdF@JD7aJ?MDWTLWB<=@;PE?A>M?PQSJaaaaaaOQDD' +
    '>ISJH\JJU@HJM?`U9G=`ZRMFS>gggUP[PD9fPIPJKNI\QBJE>?PIBCalIRPZJlllcJQSD4C>EGCTOCGR<AC?H<A?E@HHULLZeeeJQQeDeDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'BB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlkUFIP@b[RBG;J?TNA:;PbI`WLKlllX@HSD=<MR]Q;UY>iN?UF:Z=GU?cNUWUHJETALQUDI9aVUS9dR?lIETE<UIBLIcUVWGXc>Q\^LTD=' +
    '<TMTO?d`>jPBOI6[=KRCXY]ZZjZV[STdQD>;TFSM:CK<lJJK@<LBCQB^RNPMlUFMROJODBkJCN^TYNYGJDD:gR>4@lkKXMLlllllllWDF:T`ZC<Vi>iM`XB:\]Jc8ii^Wcii`S>Zi[DK' +
    '8H@I@?UW>hJGB>=]EJ\DhhUSYhWBN[SJUDEVS=LVFeUMH>>G:VKL=:iVFGLOMllllWHTD>TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND28iWfi>kd8lZQa[8eMQP>ibZhalhbfNgjMDJ' +
    'A[`UU3X`=lPKXQA`fQUK_]l^cegPA\MIXDD;MU[^7]^<lTPLI>IXKZDZ\Y[^dgHSVZPTD9>gk]ZCjh@l]llU5ljVXCgj_ejll6_liNcDRHE>AHFPOS@:A==WF=DJXHUWQV\lll\_UQD>' +
    '=[`[b=lb?lQ=]L8J8KKCUZSZXeeLPVaNTDJ@SSNO2S]ClOSNJAXSKKHXRYYTegMTHZPWDDHXPb[GhlHl2KQNGJTE@LYWYWYjbSN`[JYDD@ZJdZ9le>lQTJL5_FKUD^_aZiljDKaZUIDH' +
    'GO;A=SBQWL<FEB[I>BFb\F\ORKlljWIM\D:=^dUd<dX7dTDSO;W<IGCF^dddddONROXODC:\K\YFic?iSMKG8[FIK>Z_\Y^iZ\VQYiSD7<YGZ^9dK5d@NT^DU]UdGdWPdXdYBRXQQPD@' +
    '>cZcj6Rj6jIPW?OcOOMI^YjVRjjZN\cDVDC>^M^c6jj6jFIRGIPQNGA^V`[`jjYWW`^UDJ;````5``6````GU`R``E`Z``````R````DOINTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=' +
    'kLDLL?QOW=AA>>aKAEHda=CKG[kkkkdVSD9dPRTN9cP?fNfMASV]CLlR^RUOZlEli@;PD6aJFMEXTMXC==A7PE?A?NGPQSJaaaaaaPQDDOGQGEYGGSP?HJE^RBD<^WOJCP;dddSMYMD6' +
    'dNGNHILGZAJGCAWNGGA_jGPNXHjjjaHOQD3CDEF>TOIGR=A?BH=F=AKHBTLBDeeeJPQeDeDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDl' +
    'iIEGHF`XbHD@D<jK=I?LG?]^JUllllB:OD=:NS^R<UZ>jO@VF9[=HV@cNUXVIJEUBMRUDJ:h]\Z3kY<lPL[LB\PISPj\]^N_jIXceS[DF;TMUO=da?kPCOI5\>LSCXZ]ZZkZW\TTdQDD' +
    '<TFSN:DK:lJJL@<MCDRB^ROPMlUFMRPKPDBWK=>C@aWX=DAA9WOE>FNNMbJWgllllXiXDA;OZU>7Qd:dH[S=CVWE^BddYR^dd[MRTdVDF8H@I@?UW>hJGB>=]EJ\DhhUSYhWBN[SJUDE' +
    '^IBMK?eMU;MA><\L>CGjM;NPKillllWPSD@TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND28lOik<lf8l\Mc]7gOSR?kd\jcljdhdil^DP;ae[[7]f:lVP]W:elVZKdclchjlDFaEB^DN' +
    '6OX]`>``:lVSNL;KZM\F\^\]agiDVY\BVD=<_cUR8ba9lUdiM=jbNPE_bW]bel<WjF@NDD^P<AMEUTXA?DBB\R<=<>MM\L[allladZVD>=afbi=lh9lWHcR7P;QQA\`Y`^llRV]gT[DG' +
    ';QQLM;R\:lNRMI>VRJJ7VQWXSdeLRYXOVDDIYQc\HilIl1LROHKUKAMZXZXZkcTOa\JZDM6_Ki`9lk?lVZ_QAd@LZ<cdf_lllBPf`O\DFJCJGFJQPVCBA<FZI=DCb[J[NCJlljK:^HD<' +
    '=^dUd<dX9dTDSO8W>IGCF^dddddONROXODC:]L]Z8jdCjTNLH<\GJLB[`]Z^j[]WRZjTD8;YH[^:eL6e@OU^EV^UeGeXPeYeY>RYQQPDA:bXbh7Ph9hGNU>NaNNLH]WhUPhhCLZb]TDA' +
    ';YHY^9ee8eADMBDKLIB?YQ[V[eeTRR[YPDE;````5``6````GU`R``E`Z``````R````DOINTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=kLD?M?QOW>IJ>>bKIEHda=CKA[kkkkdVSD8' +
    '_JMNH?]JMaHaG;NQW@GjMXMOIUj_jdF@JD4cLGCFYVNYD<>B7RG>C@OHRSUKccccccQSD>OGQGFYHGSQ@HJE^S>D<^WPKDP;dddSNYND7dNGNHILGZ;JGCAWNGGA_jGPNXHjjjaHOQD4' +
    '>DFG>TOJBS=A<GCBF>ELIBUL>ZeeeJQQeDeDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDleWFL@>[T]ON>G@fXNQ@[[HYZ\`lllg>6^D@' +
    ';MR]Q;TY>iN?UE:Z<GU?bMTWUHJDTPLQTDI:_TSQ<bP=lGCRC;SG@JGaSUVEVa@O[\JRD=<SMTN>d`>jPBOH5[=KRBWY\YZjZV[STdQDC;TFSM:CK<lJJK@<LBCQB^RNPMlUFMROJODB' +
    'd`E=O?P^g>MHA7RJD:LUeaVVcflllllhhDA;OZU>7Qd:dH[S=CVWE^BddYR^dd[MRTdVDF8H@I@?UW>hJGB>=]EJ\DhhUSYhWBN[SJUDE]`LO\<dSZ9?M<>[PXU@hc9KWeHllll_WgDG' +
    'TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2:]KZ\D_W:lMEUO6XADCA\VN\Ul\UZU[^ODB<TYOO;QY:lJDQK<Y_JNDXVlW\^aJ:UGCQDB;JRX[;[[;lQMIG=FUHWAWYWX\bdEPTWMQD8' +
    '>X[MJE[Y7lN\bF7c[FHMX[PV[]d:PcZOTDGSD8@BFJIMBF@?APG?@DRNOQJPUlllVXOJD>=[_[b<kb?kQA\L8J8KJBUZRZXeeLOV`MTDJ;MMHI9MX>hIMIE;RNEFCRMSTO_aHNUT<RDE' +
    'AQI[T@agAl8DJG@CMC9ERPRPRc[LGYTBRDE;QA[R<i]<lHKQC<V>BLBUVXQ`eaEBXRLND?MJQFHOMMRW=GJHV>@FA^WOWENBlifR6ZXD=<]cTc;cW8cTCRN;V=HFCE]cccccONQNXNDB' +
    '<[I[WDgaAgQKIE;YDGIEY^[W\gXZAOWgQD5<YGZ^9dK5d@NT^DU]UdGdWPdXdYBRXQQPD@;`W`g5Og;gFMT<L`LLJF[VgTOggWKY`[SD@;YGY^8dd8dACLBCJLHADYQ[U[ddTRR[XODD' +
    ';````5``6````GU`R``E`Z``````R````DOINTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=iJBJK=ONU<GH<G`IGCFc_;TIFYiiiicTRD8^IKMGA\IL`G`F:LPV?FiKWKNHSi^ic<CID6' +
    '`IDLCWSKWB<<@<OD>@=LEOPRI``````NPDCNFPGEYGGRPEGJE]RAD<]WOJCP:dddRMXMD6cMFMGHKFYNIFB@VMFG@^iFOMWGiii`GNPD3@ABC@PLFDO>B?DE>B?AHEDQHHVbbbGMNbDb' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlVHB@EILEOGE<C<WI=B@LLHJKMQlllXKCPD<<MR]Q;UY>iN?UF:Z;GU?cNUWUHJETPLQUDI' +
    ':_TSQ<bP=lGCRC;SG@JGaSUVEVa@O[\JRD=<SMTN>d`>jPBOH5[=KRBWY\YZjZV[STdQDC;TFSM:CK<lJJK@<LBCQB^RNPMlUFMROJODBZVMG8WH=]N9E9FVUGEL`[WVVY\llllb^^DD' +
    ';OZU>7Qd:dH[S=CVWE^BddYR^dd[MRTdVDF8H@I@?UW>hJGB>=]EJ\DhhUSYhWBN[SJUDEHLEIG?OD?ABBC>GKCA>TOFHCPSlll\KCRD=TMPRIMcOViIIJBIRL=HZXTLQJciYciWTND2' +
    ':]KZ]D_X;lNEUO6YAEDA]VN\Ul\VZV[^PDB<UYOO;QZ;lJDQK<Y`JNDXWlW\^a@:UGCRDB;JRX[;[[;lQMIG=FUHWAWYWX\bdEPTWMQD8<RUGD?US;lHV\@:]U@BGRUJPUW^=J]TINDA' +
    'BD<=BFJHMAE@?@PF?@DRMNQJPUlllVXNJD>=[_[b<kb?kQA\L8J8KJBUZRZXeeLOV`MTDJ:LAGH<MW=hIMHD;QMEEBQLRSN_`GMTSJQD?AQI[T@agAl8DJG@CMC9ERPRPRc[LGYTBRDE' +
    ';QA[R<i]<lHKQC<V>BLBUVXQ`eaEBXRLND?HEKGCIGGMRD>=CQD?ACXQJREHAlc`BBTRD:<]cTc;cW8cTCRN;V=HFCE]cccccONQNXNDB<ZIZWDga@gQKIE;YDGHDX]ZW[gXZTOWgQD5' +
    '<YGZ^9dK5d@NT^DU]UdGdWPdXdYBRXQQPD@;`W`g5Og;gFMT<L`LLJF[VgTOggWKY`[SD@;YGY^8dd8dACLBCJLHADYQ[U[ddTRR[XODD;````5``6````GU`R``E`Z``````R````DO' +
    'INTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=jKCKL>PBV=HI=HaJ=DHd`<UJGZjjjjdUSD8\GJKF@ZHK^F^D9KNU=DgJUJMFRg\gaDBHD7aJFBEXUMXC==>;PE?A<NGPQSJaaaaaaPQD?' +
    'PHRHFZHHTQGIK@_SCE8_XPKDQ<eeeTNZND7jT5TNORM`UPCIG]TA;DelEVA^NlllgNUWD:@ABC@PLFDO>B?DE>B?AHEDQHHVbbbGMNbDbDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'BB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlUGAHDIKDNGD>B;VH?A?KKGIJLQlllXJCOD;<W\g[A_c;lGI_@6d<Q_DlX^a_RTA^ZV[KDE2lfdcBlaJlJUdF@eYR\QlefgAglHall[dDE' +
    '<^W_K=lj@lZ@HJ;f5V]BbcgddldLf]^l[DE9^>]W6HJFlTTVG=VMM[=h\YZKl_FW\YUYDEeaQ^Xb`OhYZUQQa_RUVkfSa`dglllllhWD0>Va\E;Hk9k:bZ7J]^LeIkk_YekkbTY[k]DF' +
    '=D:DBG]_FlQOAF>dDAdEll][al_8Uc[R\DDKNG5JFRGHDDEE@INFCDVQHJESUlll^NEUD?lehjTelgllXbbZajdPWllldiblllllllHD07jMgjCle>lGLbC8fNCGDjc[iblicgbhkFD=' +
    ':afML@^f=l?Q^K:flGMEeclNJklA<bSKJD=ISjllMll7lXe`^M]XHPSlllXlllKhklTTD3?EcJF<Oa>l@diE=jb<K?_bW]bel@FNJFMD<SD<@BFJHM>E@?@PF?@DRMNQJPUlllVXNJD<' +
    '=fkglHllFlMBhL7UCVV5ae^MMllWHblY`DL9HJHG9YNFlFJLD?^Z?IE^Y_N[klD@aMEID?DaPleFllJl?<KW8T]O7Kcaba@lkIXidCQDE:_KO_>Oj:lAY^B:dKKZPcdf_lll<Cf_B[DB' +
    'FCJFAHFFLPB@CAOB;?BWPHQCGHlb_KASQD<=^dUd:dX9dACSO;W>IGCF^dddddONQOXODCJlXll\llUliUbSDZ\`aWllllllVllgllSD06]C^b<hO9h=RXbHYaYhJh[Th\h]AV\UTSD@' +
    ';lbll:Zl:l?X_7LkXDUKgal_ZllbLMlg^DH=gVPl6ll?l@9KCHYZCDSg_LdillLN`ig]DA=bbbb4bb7bbbbIVbTbbAb[bbbbbbSbbbbDQINTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=' +
    'iJBJK=ONU<GH<G`IGCFc_;TIFYiiiicTRD8\GJKF@ZHK^F^D9KNU=DgJUJMFRg\gaDBHD7`IDLCWSKWB<<@<OD>@=LEOPRI``````NPDCAGQGEYGGSPFHJE^RBD<^WOJCP;dddSMYMD6' +
    'fQ8PKKOJ]QMJEDZQC=CalCSP[JlllcKRSD6E>GH?VQKIT;G=ADC@<>MDDVMM\gggLRSgDgDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDl' +
    'V@BIEILEOGE:C<WI?B@LLHJKMQlllXKCPD<9Y]i]8`e@lZHaQ8e@Ra=lY`caSU@`\X]`DL6i^\[<lY<lQM\M8]QJTDk]^_O_kDYdeS\DE:\U\W;lh8lXKWQ:c<I[A`aebblb^c[\lYDG' +
    '<HS`Z:CM:lWWJM=YOKNAk_[]ZlbII_\MND9a]8GI^LDdDWQDASS:DBgI^]]SclllliePD8:P[V?8Re;eI\B>>WXF_?eeZS_ee\NSUeWDG>SKTKC`bGlURMJ5hPVh8ll`_dlbCYf^ELDF' +
    'PTMQPKWLNIJJE8OSAIJ\WEPAX[llldSKBD5UMQRINdOWjJJJB@SM>I[XTMRJdjYdjWUOD2:NXgj?le8l[Db\6fNGQAjc[iblicgchk]DG:UYOO;RZ9lJERK<Y`JNDXWlX\_aJ;UGCRDB' +
    '8Nafi:ii<l_\WU;TcJeCfgefjllB_beJID;?klaXFll?la[lY5llZ\Cklcilll6clSRgDR[LAEFNRPUJG@A7XN;CLZUVYRX]lll^`VRD99afah?lh=lWHcG;P>Q8I[`Y`^kkCV\gGZDF' +
    ';ONIJ;OY9jKOJF9TOGGDTNUUPacIPVULSD>LV^liMllFl3X_\EXaS;JgNgegllUPlh:gDI;`Oj`:lk;lMZ_R?MAEO9Deg`lllGQgOOEDBFCIEAHFEKPB@CAOB>?AVPHPCGHkb_K@SQD<' +
    '<flGl>la8l]D\X9`>ROLHflllllXWZXaCD=8]K]YAic?iSNLG:\FJKA[`]Y^i[\WQYiTD7:GQIK6lB=lIX^g?_gIlIlaYlblbB[bZFDD@9h^hl7?l8lMT[DDgTTQGc]l[Vll^R`hcZDG' +
    ';eTej6ll8lMPYN=MMUBDe]gbgll`^^gG\DQ?dddd9dd2ddddKYdVddId^ddddddVddddDSINTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=jKCKK>PNV<@H=H`JHDGc`<UJFZjjjjcUBD8' +
    '\GJKF@ZHK^F^D9KNU=DgJUJMFRg\gaDBHD7`IELDWSLWB<<@<OD>@>MFOPRI``````OPD>PN`OIhVHG_IHOKlJIE=lP^YR_JlllL\g?D3l^GLMY\PjQDE>7gIGHFllENMhWllllX_ID5' +
    '>=GJ?LWKIZ?H=OEBFABHC>\BFblllEFFlDlDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlUGAHDIKDNGD>B;VH?A?KKGIJLQlllXJCOD;' +
    '@<WbV7Y^@lSDZJ?_<AZ=gRY\ZMNIYEQVYDN:I\II;jX:lFKZK8[BHHOI[]^M^iEWIdRZDC<WPDR=gc:lSFRC8E@OVA[\`]]lEY_VDgTDG?H?E@>DE9lIRCHAUGDZ=f[IXUl^OV[XSCDB' +
    'OK>HBLKIRCE?>;KJ<?AUPLKJNQlllbWSSD<<P[V?5Re;eI\T>DWXF_CeeZS_ee\NSUeWDG<LCLD@YZ9kMKFB7`H@`GkkYW\kZFQ^WNXDIHLDIGCODFAA>B>FKC=ATNFHBPSlll\KCRD<' +
    '^EA\?GKAKlGAC<SK@@GdKIV[JllcllIEGD8FQ@jlGl@@lJKQ^9Q>6EMle]kHlkeiejlMDGCdI^J5`i>lL=aZGQlJPNgPlfkllL8dVIaDE><^dg@fg8l\Y=R?>aTcDcMbdgllI\_KYMD>' +
    'AJdD;;cbClEIjCBlH?>VPdA_LfPLBLcOID<TF>BCGKJNCABA?QH>>ESOP>LQWlllWZPLD<Echcj=lj5lYIdT9E?HEJ]bZb`llTW^hVEDD>CJIIENJ;lUDF@9MBCDGNY_`[klGZF`WDD=' +
    'E\Kg`DllBl;JHRKAH=5K^L^\^lfXSdMNHD@9_Ki`@lj;lJGG<:dFL@GcdfOlllJFfOZDDABFLHDKIBNS;@FDREA?;ZSKDFJKlebNDVTD=Adj[j>j^8jHJYUB]AGMJ5djjjjjVUXU_UDB' +
    '>\B\YFic>iSMKG9[FIK>Z_\Y]iZ\VCYiSD7>[I\`;fB7fAPVCFW_Wf;fYRfZf[DTZSRQD=;bXbh7>h<hGNB>MaNNKH]WhUPhhXLZb]TD>=]L^c9ii=iBC<GHOBM=IFV`Z`iiYVW`]@D@' +
    ';````5``6````GU`R``E`Z``````R````DOINTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=iJBJK=ONU<GH<G`IGCFc_;TIFYiiiicTRD8\GJKF@ZHK^F^D9KNU=DgJUJMFRg\gaDBHD7' +
    '`IDLCWSKWB<<@<OD>@=LEOPRI``````NPDCNFPGEYGGRPEGJE]RAD<]WOJCP:dddRMXMD6ePHOJJMH\PB<@BYPIIB`kHQOZIkkkbJPRD4:?DEARMHFQ>>AFA@D@CJGFSJJXdddHOOdDd' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlYKELHMOHRKHBB7ZL8ECOOKMNPUlll\NGSD<?WIg[@^b6lX<^O8cFP_FlW^`_QSC]ZUZ^DR' +
    ';bWVT9eS;lJFUF<VJ?MJdVXYHYdCR^_MVD;<\IJW>liDlXGWQ3dFT[A`bebclc_d\JlZDD9_A]X::GAlUTDE;WMIKLh\YZWl_JI\ZHZDDOKBHCLKISCE=B;KJ=@AVPLLKNQlllbXSSD9' +
    'AXc^F8ZlAlQc[4G_`HfKlla[fllcV[]lEDH:QIQI>^`;lSPF9=fNIeGll^\Jl`FCd\S^D?JMFKBEQFGCCD=?HME:CUPGIDRTlll]MDTD:WPSUL?fRYlMM>ELUP;L^[WOTMfl\flZWQD3' +
    '9gUdgCib>lGOKY9cG;MKg`XG_lf`d_GhGD:A]aWW:Zb:lI=ZS>ahRVM`_l`dgiR8^G=ZDJ;QY_b9ab;lXTGN:FHC^H^`]HbikCDG^TXD=>\`DD>_L:lEHfG=g_GEIK@TZ_biA;gJCXDB' +
    'RD<@>EJHMAE@?@PF?@CQMNPJOUlllUXNJD>;]b]e;ld>lSD_N7L:MMEW\U\ZggNRXcPVD?@HZFV?Zd9lANL@>_GB@HOY``JllF@aKEID=A\Tg`<ll=l?OVKFOX<7G^\^\MlfXDdKA]D@' +
    'GdTld@llDlSPcDFiN7JUSikdlllNUkd_SD4FCJFAHFFLPB@CAOB>?>WPHQCGHlb_KASQD<;^dUd<dX9dUDTO:W>J@D@^dddddPORPYODC:^L^Z?kd>kTOMI9]GKCH\a^[_k\]XDZkUD7' +
    'C_Nad@kR1kFU[dK\d[kMk^Vk_k_IY_HWVDG7lcll5Ml:lKY`EMlYLVLhbl`[llcWeNh_DG<\K\a:gg7g<FP<?NOLEH\T^Y^ggWUU^\RDG<llll8ll3llll[ilfllEllllllllfllllDU' +
    'INTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=iJBJK=ONU<GH<G`IGCFc_;TIFYiiiicTRD8\GJKF@ZHK^F^D9KNU=DgJUJMFRg\gaDBHD7bKFNFYUNY@<7B<QF@B@OHQRTKbbbbbbQRD@' +
    'SKULJ]LKWU@LNJbWFHAb[TOHT?hhhWR]RD2dNGNHILGZOJG>AWNGGA_jGPNXHjjjaHOQD3DAF@<FPKI:@B<HJ>GCFMJIVMM[fffKRRfDfDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'BB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDlUGBH?ILDNGD>B<VI?B@LLGIJLQlllXJCOD;BUZIYA\a<lV<]MAb4O]GjUH_]PRL\XTY\DQClba_Jl^;lH5`E@aKIXVlacd9dlN]ijNaDC' +
    ';IU]W>lh;l>CWD8dET[;`aeJblb^J[\lYDL=aL`[;GN?l@WY=:ZAI_@k_\FZlbBJ_]G]D?[WCTNXWU^OKK8GWVHK3a\XWVZ]llllc__DH>YdKH2[lClDK]CM`aFhLllb\hlleW\^l`DF' +
    '6VDWN@ceDlFUPADkSYjLllcOgle7@iNEcDMIMEJHDPEGBCCD:HLDABUOGA;QTlll]LDSD=\TXZPUkV^lBDQAHZT4Ab_[CYQkl`kl_\VD8<hVehIjc<lYP`Z6dLAF<haYg`lgaeMfi[D:' +
    '9bg\\B_g8lHROY<Ol>GRfdlejllJBcTQ_D:CMdjlLMl4lO_[YBNgEiLikijlOlHcfi_RD7AUGKEDNg<lCjN@<lh9JBfiFMhklCClUNPD=UF?BDHLKODHB??RIABATPQSLRWlllXZCLD7' +
    '>cgcjBljBlIIdH4H?HR>]bZb`llTW^hV\D?CZIHFCZd?l@KH7:OZ>SF_YOJ[llF[OaWODAA^VibCllAl>FN;CLNF?C`^`^`lhN;fa9_DAAeMlU<ll:lGJe><jM?TRijUelll@<lfTUD=' +
    'GDJFBHFFLQCADBPC>=<WQIQDGIlb_LATQD<<]cTc;cW8cTCRN;V=HFCE]cccccONQNXNDBGiWieMllGl_YWSFgMUFSgliejlfhOOelOD1?`Nad;kR3kFU[dK\d[kMk^Dk_k`DY_WWVD@' +
    '=i_il6Wl;lDUI<BhUIRBd^l\Wll_Said[D>=[J[`:ff:f;FO=FMN>DG[S]X]ffVTT][QDG>llll4ll6llllIOl`llFlgllllll_llllD]INTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=' +
    'iJBJK=ONU<GH<G`IGCFc_;TIFYiiiicTRD8\GJKF@ZHK^F^D9KNU=DgJUJMFRg\gaDBHD7`IELDWTLWB<<@;PE>@>MFPPSI``````APDC[S^TRfTT_]STWRk_NK5kd\WP]4lll`ZeZDA' +
    'jUMTOOSNaUQNIH^UN>GelMWT_NlllgOVWD1BC=A>WGEJU@>E@KBA??FEJWOF]hhhMSGhDhDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDBB@CBLLEDT?DABA<A=CEFHMIIXlblHPMlDl' +
    'bC?DDVYG[BG;=8MH?CDYLMVMY^llleWP\DE7Z^j^9ae>l[BaR<NASb=lMacbTVQIGM^aDL>j`^L9l[=lRO]B5_FHVHl^`aQalBLMHL^DI>^J^Y?lj=lZBYS8L7U\>bcgddld`eGKl[DN' +
    '=bL`[6?J;lXWYH=ZDQ_@k_\]ZlbSJHHX]DAQM:J@NLKTEF>D;M>>ABWQNMLPRllldYTTD>:S_YB7Uh:hL_WA=[\Ib@hh]Vbhh_RWBhZDJ3PBPHA]_ClRFJD?eMRdBll][al_JUc[R]DM' +
    'QJEDILX>OJJBG;IFC7C]IIHLY\llleFL[D>WOSUKPfRYlLLLE5UO@K]ZVOTMfl[flZWQD57kDhkFlf?l\BcO8g=MR>kK\jcljFhLPl^DP;`dZZ8]e7lUP]V>dkUY@cblcgjlUCM@J]DM' +
    '7W`fi9hi=l^@WT:TcVO>egdfillM^OON_DF8\_QN9^]<lQ`eI8g^JLH\_TZ^ahGJgKFXDD[>E?@NREUJDAHEX@:<CZ>JYRJ]lllFaWSDA:jljl:llEl`Bk[8X8OYBKhaigllLFPlOcDY' +
    ':WWRS8Ka<lSWRN9\WOO<\V]]XikEX^HT[DN;_Gjc:ll;lDEGN@A[R<?`O`_aliZNg?Q`DM:]Ig^8lh?lTL]O;b:NXBabd]lllKJdGGYDCMJG>@NELAGBFBAGDB<HHVFW;FNlheGGYWDB' +
    ':fl]l<l`7l]D[W<_;QOGNflllllWDZW`WDK5dRd`?lj<lZFSN:cEQREbgd`elbc^G`l[D><[J\`8f<7fBPV`FW_WfAfYRfZf[DT[SSRDB:g]gl4Gl<lLAZCCfSSPFb\lZUll]QGgbYDF' +
    '7_?_d<jj=jGISH;CRO@K_Wa\ajjZXCa_UDJ<aaaa5aa5aaaaHUaSaaFaZaaaaaaRaaaaDPINTTT4TTHTNNTTKTKTTDTTTTTTTGTFF:TD=iJBJK=ONU<GH<G`IGCFc_;TIFYiiiicTRD8' +
    '\GJKF@ZHK^F^D9KNU=DgJUJMFRg\gaDBHD7gGFSK^IS^I:;@<WFA?=TFWWZBggggggVWD@RJT<I\KJVTIKDBaV6G@aZSNGS>gggVQ\QD:fQIPBKNJ]@MJ@<Z?>JCal@SP[JlllcKQSD6' +
    '@ABC@PLFDO>B?DE>B?AHEDQHHVbbbGMNbDbDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' +
    'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD';

function EnglishIndex(C: Char): Integer;
begin
  if (C >= 'a') and (C <= 'z') then
    Result := Ord(C) - Ord('a')
  else if C = '''' then
    Result := 26
  else
    Result := EnglishLetters;
end;

function RussianIndex(C: Char): Integer;
begin
  if C = 'ё' then
    C := 'е';
  if (C >= 'а') and (C <= 'я') then
    Result := Ord(C) - Ord('а')
  else if C = '-' then
    Result := 32
  else
    Result := RussianLetters;
end;

function ModelCost(const AWord, ACosts: string; ALetters: Integer;
  ARussian: Boolean; AWithEnd: Boolean): Integer;
var
  I, Rows, Width, Prev2, Prev, Next, Cell: Integer;
begin
  Result := 0;
  Rows := ALetters + 2;
  Width := ALetters + 2;
  Prev2 := 0;
  Prev := 0;
  for I := 1 to Length(AWord) + Ord(AWithEnd) do
  begin
    if I > Length(AWord) then
      Next := ALetters + 1
    else if ARussian then
      Next := RussianIndex(AWord[I])
    else
      Next := EnglishIndex(AWord[I]);
    Cell := Ord(ACosts[(Prev2 * Rows + Prev) * Width + Next + 1]) - CostBase;
    if (not ARussian) and (I <= Length(AWord)) and (Next = ALetters) and
       IsRussianLetterKey(AWord[I]) then
      Cell := InnerKeyCost;
    Inc(Result, Cell);
    Prev2 := Prev;
    Prev := Next + 1;
  end;
end;

function WordModelCost(const ALower: string; ALang: TLangKind;
  AWithEnd: Boolean): Integer;
begin
  if ALang = lkEN then
    Result := ModelCost(ALower, EnglishCosts, EnglishLetters, False, AWithEnd)
  else
    Result := ModelCost(ALower, RussianCosts, RussianLetters, True, AWithEnd);
end;

function LetterModelCost(const ALower: string; ALang: TLangKind): Integer;
begin
  Result := WordModelCost(ALower, ALang, True);
end;

function LetterModelPrefixCost(const ALower: string; ALang: TLangKind): Integer;
begin
  Result := WordModelCost(ALower, ALang, False);
end;

end.
