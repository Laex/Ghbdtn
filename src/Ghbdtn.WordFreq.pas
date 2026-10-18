unit Ghbdtn.WordFreq;

{ Frequent words of English and Russian with their cost in quarter-bits:
  four times the negated base-2 logarithm of the share of running text the
  word makes up. The lists are generated from text of both languages. }

interface

uses
  Ghbdtn.Layout;

{ The cost of a lowercase word, or -1 when the word is not in the list. }
function WordCost(const ALower: string; ALang: TLangKind): Integer;

{ Whether some word of the list begins with the lowercase text. }
function HasWordWithPrefix(const ALower: string; ALang: TLangKind): Boolean;

implementation

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TWordTier = record
    Cost: Integer;
    Words: string;
  end;

const
  EnglishTiers: array[0..11] of TWordTier = (
    (Cost: 20; Words:
      'and of the '),
    (Cost: 24; Words:
      'a in to '),
    (Cost: 28; Words:
      'by for is on that '),
    (Cost: 32; Words:
      'all are as at be from i it not or this with you your '),
    (Cost: 36; Words:
      'about an but can do free has have he home if information may more my new no one other our page search site ' +
      'they time up us was we what which will '),
    (Cost: 40; Words:
      'admin also alter am android any api array asap awesome back bad been bool boolean brb btw business buy bye ' +
      'byte call case char class click client code com config const contact cool create css data date day debug ' +
      'delete demo directory docker double download drop else email error event exit fail false file find fine first ' +
      'float folder font form ftp function fyi game get git github gitlab gmail go good google great had health ' +
      'hello help here hey hi hide his how html http https i''ll idk imho imo index info insert install int integer ' +
      'into iphone item its json just key last like link linux list log login logout lol long mail main make me menu ' +
      'method most music name net news next nice nope now null object ok okay omg online only open org out over pass ' +
      'password path people play please pls plz post price procedure products property request response save see ' +
      'select send server service services settings setup show size so some sorry sql state stop string struct sure ' +
      'table test text than thank thanks their then there these thx top true two type unit update upload url use ' +
      'used user username value var view void warning web were when where who windows work world would wtf www xml ' +
      'ya yeah year yep yes youtube '),
    (Cost: 44; Words:
      'access account add address after american area art available based because before being best between big ' +
      'black board book books both car care center change check children city comments community company computer ' +
      'control copyright could county current days design details development did digital does don''t down during dvd ' +
      'each ebay education end even family following forum found full games general government group guide her high ' +
      'him history hotel hotels house including international internet it''s items jan january know law level life ' +
      'line links local location made management many map media member members message much must national need ' +
      'network north number off office order own pages part per personal phone photo pictures place policy posted ' +
      'posts power prices privacy product program project public rate rating read real related report research ' +
      'reserved resources results return review reviews right rights said same school section security set sex she ' +
      'shipping shop shopping should sign since sites small software south special sports states store students ' +
      'subject such support system systems take technology terms that''s them think those three through times today ' +
      'total travel under united university usa using version very video want water way website well while white ' +
      'within without women years '),
    (Cost: 48; Words:
      'able above accessories act action activities added additional advanced again against age agreement air ' +
      'already always america analysis another application april archive areas around article articles arts ask ' +
      'association audio august australia author average away baby beach become below better blog blue body box ' +
      'browse building calendar california called canada card cards cars cart categories category cell central ' +
      'changes child china close club collection college color come comment committee common companies compare ' +
      'complete computers conditions conference content cost costs council country course court credit customer ' +
      'daily database david dec december delivery department description different direct director discussion ' +
      'display district done drive due east easy edition electronics energy english enter entertainment environment ' +
      'equipment estate events every example experience faq fax features feb february feedback few field files film ' +
      'financial five food format forums four france friend friends fun further future gallery garden gay gift girls ' +
      'give given god going gold got green groups hand hard having he''s head hot hours however human image images ' +
      'important include includes industry insurance interest island issue issues job jobs john join journal july ' +
      'june keep land language large latest learn learning least left legal less let library light limited listed ' +
      'listing little live living london look looking lot love low major making man mar march market marketing means ' +
      'medical meeting memory men messages microsoft might million mobile model money month months movie movies ' +
      'natural needs never night non note notice nov november oct october offer offers official old once options ' +
      'original others paper park party past pay payment performance period person photos picture plan planning ' +
      'point poker popular porn possible powered president press previous print private pro problem problems process ' +
      'professional profile programs provide provided provides put quality question questions quote radio range ' +
      'rates really recent record records red reference region register release reply reports required result road ' +
      'room rss run safety sale sales san say says schools science second self sell seller sep september series ' +
      'several shall share short side similar single social society solutions something source space specific staff ' +
      'standard star start status still stock stores stories story street student studies study sun tax team ' +
      'technical teen tell term texas there''s things thread title too tools topic track trade training try until ' +
      'updated upon users visit war washington we''ll weather week welcome west what''s whether why window working ' +
      'write yahoo yet york young '),
    (Cost: 52; Words:
      'ability abstract academic accommodation according across active activity actually addition administration ads ' +
      'adult advertise advertising advice africa agency agent ago airport album allow allows almost along ' +
      'alternative although amazon among amount anal animal animals annual answer answers anti anyone anything apple ' +
      'applications apply approach appropriate approved apr archives artist artists asia asian asked ass assessment ' +
      'assistance associated aug authority authors auto availability award awards background band bank bar base ' +
      'basic basis battery bay beautiful beauty bed behind believe benefits bid bill bin bit blood boards born ' +
      'boston boy boys brand brands break bring british brown browser budget build built bush button buying cable ' +
      'came camera cameras can''t canadian cancer capital career carolina cases cash casino catalog cause centre ' +
      'century certain channel chapter character charge chat cheap chicago chinese choice choose christian christmas ' +
      'church cities classic clear clothing cnet comes coming command commercial commission communication ' +
      'communications completed components condition connection consider considered construction consumer contains ' +
      'contents continue contract copy core corporate corporation countries courses cover created cross culture ' +
      'currently custom customers cut dance dark dating deal deals death debt decision deep default defined degree ' +
      'designed detailed develop developed device didn''t directly disclaimer discount disease distance distribution ' +
      'division document documents dog doing domain door downloads drug early earth economic edit editor educational ' +
      'effect effective effects either electronic employees employment engine engineering england enough ensure ' +
      'enterprise entire entry environmental especially est established etc eur europe european ever everyone ' +
      'everything evidence excellent except exchange executive existing expected express external extra eye face ' +
      'facilities fact faculty fall far fast father''s favorite feature featured federal fee feed feel fees feet ' +
      'female figure filter final finance fire fish fitness flash floor florida flowers focus follow football force ' +
      'foreign forms forward foundation french fri friday friendly front functions fund funds furniture gas george ' +
      'german germany getting gifts girl glass global gmt god''s golf goods grade grand graphics greater ground ' +
      'growth guest guides hair half hall happy hardware heart held here''s higher hill hit hold holiday homepage ' +
      'homes hope horse hospital hosting hour housing huge i''m idea ideas iii impact improve inc incest included ' +
      'income increase independent india indian individual industrial inn input inside instead institute interested ' +
      'interface internal introduction investment involved iraq ireland islands italy itself james japan japanese ' +
      'java jewelry joined jul jun keywords kids kind king king''s kingdom kit kitchen knowledge known lake larger ' +
      'las late later lead leading leave length lesbian let''s letter levels license likely lines listings lists loan ' +
      'loans located locations logo longer los loss lost lower ltd lyrics mac machine magazine mailing maintenance ' +
      'makes male man''s manager manufacturer maps mark mary master match material materials matter mature max ' +
      'maximum maybe mean medicine medium meet membership metal methods mexico michael middle miles military mind ' +
      'mini minutes mission mode models modern modified mon monday morning mortgage mother mountain move moving msn ' +
      'multi multiple names nature navigation near necessary needed networks newsletter nokia none normal northern ' +
      'notes nothing nude numbers often oh oil operating operation operations opinion opportunities opportunity ' +
      'option orders organization organizations otherwise outdoor output outside overall overview owner owners ' +
      'pacific pack package paid panel papers parents particular parties partner partners parts patients paul paypal ' +
      'pdf percent perfect peter phentermine phones photography php physical pics places plans plant player players ' +
      'playing plus points police policies political politics pool pop population port position positive potential ' +
      'practice pre present pressure pretty prev primary printer prior probably processing production programme ' +
      'programming projects properties proposed protection protein providing publication publications published ' +
      'publisher purchase purpose purposes pussy quick quite race rape rated rather ratings reader reading ready ' +
      'reason receive received recently recommended regional registered registration regular relations released ' +
      'releases remember remote rent rental rentals reported republic require requirements resolution resource ' +
      'responsibility responsible rest restaurants retail returns richard ring risk river robert rock role rooms ' +
      'round rule rules running safe sample sat saturday schedule score screen sea searches season secure seems seen ' +
      'selected selection sellers senior sense sent session sets sexy she''s ship ships shoes shown shows significant ' +
      'silver simple simply six skills skin smith solution someone son song sony soon sort sound sources southern ' +
      'spain speed sponsored sport spring stage standards stars started starting statement station statistics stay ' +
      'step storage strategy strong structure studio stuff style submit submitted subscribe success summary summer ' +
      'sunday super supplies supply survey taken takes taking talk target teaching tech technologies teens tel ' +
      'telephone television testing therefore thing third thomas though thought throughout thu thursday thus tickets ' +
      'tips together told took tool topics tour town toys trademarks traffic transfer transportation treatment tree ' +
      'trial trust trying tue tuesday turn types understand union unique units unless usb useful uses usr usually ' +
      'vacation valid valley values van various vehicle via videos views virginia virtual voice volume vote wall ' +
      'wanted watch ways wed wedding wednesday weeks weight went western whole wide william win wine winter wireless ' +
      'wish woman won''t wood word words works worldwide writing written wrote yellow you''ll you''re yourself youth ' +
      'zip '),
    (Cost: 56; Words:
      'abuse academy acc accept acceptance accepted accounting accounts accuracy achieve acid actions actual adding ' +
      'addresses administrative administrator adobe adults advance advantage adventure advertisement advisor affairs ' +
      'affiliate affiliates african agencies agents agree agreed agriculture ahead aid aids aim ain''t alabama alaska ' +
      'alert allowed alone alpha amateur amazing amendment americans amounts andrew andrew''s angel angeles anime ann ' +
      'announced announcements anonymous apartment apartments apparel appeal appear appears applicable applied ' +
      'approval approximately architecture argument arizona arms army aspects assembly assets assist assistant ' +
      'associate associates atlanta atom attack attention attorney auction auctions austin australian austria ' +
      'automatic automatically automotive ave avenue avg avoid aware babes bag bags balance ball banking banks bars ' +
      'baseball basket basketball bass bath batteries battle bbc bear beat became becomes bedroom began begin ' +
      'beginning behavior bell benefit beta beyond bible bids billion binding bird birth birthday block blogs blow ' +
      'boat bob bondage bonus bookmark bottom bought boxes brain branch brazil breakfast breaking breast brian ' +
      'bridge brief broadband broken brother brother''s brought bug buildings bureau bus businesses buyer bytes ' +
      'call''d calling calls camp campaign campus canon cap capacity cape careers carried carry cast cat caused cds ' +
      'cells census cent centers certainly certificate certificates certification certified chain chair chairman ' +
      'challenge chance changed changing characters charges charles chart charts checkout chemical chief chris ' +
      'christ circuit cisco civil claim claims classes classical classifieds clean cleaning clearly clients clinical ' +
      'clip clips clock closed clothes clubs coast cock codes coffee cold collectibles colorado colors colour ' +
      'columbia column combination combined comfort comics commerce communities compact compared comparison ' +
      'compatible competition competitive completely complex compliance component comprehensive computing con ' +
      'concept concerned concerns conduct configuration congress connect connected conservation constitutes ' +
      'consulting contacts contain contained containing contemporary context continued continuing controls ' +
      'convention conversion copies corner correct couldn''t count counter couple coverage covered covers cream ' +
      'creating creation creative credits creek crime criminal criteria critical cruise crystal cultural cum cup ' +
      'currency cvs cycle dakota dallas damage dan daniel dates daughter dave davis dead dealer decided decisions ' +
      'dedicated defense define definition degrees del delivered dell delta demand departments depth des described ' +
      'designated designer designs desk desktop despite destination detail determine determined dev devel developer ' +
      'developing devices diamond dick dictionary die died diego diet diff difference difficult dining dinner ' +
      'direction directions directors disc discover discuss discussions disk disney displayed distributed dna doc ' +
      'doctor documentation dogs dollar dollars domestic don dot draft dream dress drink driver drivers drives ' +
      'driving drugs dry dsl dual duty dvds dynamic earlier easier easily eastern eat economics economy edge ' +
      'editorial effort efforts eight election electric electrical element elements eligible emergency emperor''s ' +
      'employee empty enable encyclopedia ended ending ends enjoy enlarge enterprises entries equal equity eric ' +
      'errors essential estimated estimates euro evaluation evening evil evolution exactly examples exclusive ' +
      'exercise exist expect expert experts explore exposure expression extended extension extreme eyes facility ' +
      'factor factors factory facts failed failure fair faith falls families famous fan fans fantasy faqs farm ' +
      'fashion faster fat father favorites fear feeds feeling felt festival fiction fields fight figures filed fill ' +
      'films finally finding finish finished firm firms fishing fit fix fixed flag flat flight flights flow flower ' +
      'fly followed follows foot forced forces ford forecast forest forgot former fort fourth frame frames framework ' +
      'francisco frank freedom frequency frequently fresh fuck fucking fuel fully functional funding funny gain ' +
      'galleries gambling gaming gamma gave gear gender gene generally generated generation generic georgia gets ' +
      'gives giving goal goals goes golden gone gps graduate grant graphic gratis greatest grow growing guarantee ' +
      'guaranteed guess guidelines guitar guy guys handle handling hands happen hardcore harry hawaii he''ll ' +
      'headlines healthcare healthy hear heard hearing heat heavy height helpful helps henry hentai hidden highest ' +
      'highly hills himself hip hire historical hits hiv hole holidays hong host household houses houston hunter i''d ' +
      'i''ve ibm ice icon ideal identified identify identity illinois immediately implementation import importance ' +
      'improved improvement inch inches increased increasing indeed indiana individuals industries influence ' +
      'informed infrastructure initial injury ink installation installed instance instant institutions instructions ' +
      'instruments integrated integration intel intelligence intended interactive interesting interests interior ' +
      'interracial interview introduced iowa ipod irish iron isbn israel issued italian jack jackson javascript jazz ' +
      'jersey jesus jim joe johnson joint jones joseph judge jump junior justice kansas keeping kelly kentucky kept ' +
      'keyword kinds knew kong korea lab label labor laboratory lack ladies lady languages laptop largest laser ' +
      'latin laws lawyer lawyers layer lcd leader leaders leadership leads league leather led lee legislation les ' +
      'letters liability libraries licensed lighting lights limit lingerie listen literature lives llc load logged ' +
      'looked looks lord lots louis louisiana love''s lowest luxury machines magazines magic maine maintain ' +
      'maintained majority manage managed manner manual manufacturers manufacturing marine marketplace markets ' +
      'marriage married martin maryland mass massachusetts matching math matrix matters meaning measure measures ' +
      'meetings men''s mental mentioned merchant met miami michigan mid mike milf miller min mine minimum minister ' +
      'ministry minnesota minor minute miscellaneous miss missing missouri mix mixed module mom moment monitor ' +
      'monitoring monthly moon mostly mother''s motion motor motorola mount mouse moved movement multimedia museum ' +
      'musical myself naked named napoleon''s nation nations native nearby nearly negative netherlands networking ' +
      'newsletters newspaper nine nor noted nuclear nursing nutrition objectives objects obtain obtained ocean ' +
      'offered offering officer officers offices officials ohio oklahoma older on''t one''s ones ontario onto opening ' +
      'operator opinions optical optional oral orange ordering oregon origin originally orlando outdoors owned ' +
      'packages pain pair palm panasonic paperback parameters parent paris parking parks participants participation ' +
      'particularly partnership passed patch patient pattern patterns payments pda peace peak pennsylvania perform ' +
      'performed perhaps permalink permanent permission permit personnel persons pet pets pharmacy phase ' +
      'philadelphia philosophy phoenix physics pic pick piece pieces pierre''s pink placed planet plants plastic ' +
      'platform played pocket poetry poor porno portable portal portfolio positions postal poster posters posting ' +
      'powerful practical practices premium preparation prepared prescription presence presentation presented ' +
      'prevent prevention preview previously pricing prime principal principles printed printers printing prints ' +
      'priority procedures processes produce produced professionals professor profiles profit progress promote ' +
      'promotion proof proper proposal protect protected protocol provider providers provision provisions pst ' +
      'publishing pubmed quantity quarter queen query quickly quotes racing rain random rank rare ratio ray reach ' +
      'readers reality reasonable reasons recipe recipes recommend recommendations recorded recording recovery ' +
      'recreation reduce reduced reduction refer references referred regarding regions regulation regulations ' +
      'relationship relationships relative relevant relief religion religious remain remains removal remove removed ' +
      'repair replacement replies reporting represent representative requests requires reserve residential residents ' +
      'resort respect respective restaurant returned revenue reviewed revised revision rich ride rings ringtones ' +
      'rise roll rom root rose route row royal runs rural russia russian saint salt samples samsung santa satellite ' +
      'savings saw saying scale scene scheme sciences scientific scotland scott script seat seattle sec secondary ' +
      'seconds secret secretary sections sector seeing seeking seem selling senate separate sequence serial serious ' +
      'serve served servers serving setting seven sexo sexual sha''s shape shared shares sharing sheet shemale shirt ' +
      'shirts shops shot showing signal signature signed signs singapore singles sitemap situation ski skip sky ' +
      'sleep slightly slow smart smoking snow soccer soft sold solid sometimes songs sorted soul sounds spa spam ' +
      'spanish speak speaker speakers specials species specifically specifications specified specs speech spend ' +
      'spent spirit sponsor spot springs square src stand standing stated statements static stations stats steel ' +
      'steps steve stone straight strategic strategies stream strength stress structures sub subjects subscription ' +
      'successful suggest suggested suggestions suite suites supplied suppliers supported supports surface surgery ' +
      'sweet switch sydney tables tag tags talking tape task taxes taylor tea teacher teachers teams techniques ' +
      'temperature ten tennessee tennis tests theater theatre theme themselves theory therapy thinking thoughts ' +
      'thousands ticket tim tip titles tits toll tom toronto touch tourism tours toward towards toy trackback ' +
      'tracking trademark trading traditional train transit translation transport trees trends tried trip ' +
      'tripadvisor truck truth turkey turned ultimate understanding universal unknown updates upgrade upper ups ' +
      'urban usage usd utah utilities utility variable variety vegas vehicles vendor vhs viagra vice victoria viewed ' +
      'viewing village vintage violence virus vision visitors visual vol votes voyeur wait waiting wales walk wants ' +
      'warranty wars waste watches wear webmaster websites weekend weekly whale''s whatever wheel where''s who''s ' +
      'wholesale whom whose wife wild williams wilson wind winning wire wisconsin woman''s won wonderful worked ' +
      'workers workshop worth wouldn''t writer wrong xbox xxx yesterday zealand zero zone zoom zum '),
    (Cost: 60; Words:
      'abc abroad absence absolute absolutely acceptable accessibility accessible accessory accident accordance ' +
      'accurate achieved achievement acquisition acres acrobat acting actor acts adam adams adapter addressed adds ' +
      'adequate admission admissions adopted adoption adventures advisory affect affected affordable afghanistan ' +
      'afternoon aged agenda ages agreements agricultural ahab''s aircraft airline airlines alan alarm albert alberta ' +
      'albums alcohol alerts alex alexander algorithm alive allen alliance allocated allowing alternate aluminum ' +
      'alumni amd amended amp amsterdam analog analyst ancient anderson andy angels angle animation anna anne ' +
      'anniversary annotation announcement anthony antique antiques antonio anytime anyway anywhere aol apache apart ' +
      'apparently appearance appeared appearing appendix appliances applicant applies applying appointed appointment ' +
      'appreciate approaches arab arcade arena argentina arguments arkansas arm armed arrangements arrival arrived ' +
      'arthur asking asp aspect asset assigned assignment associations assume assumes athletic atlantic atmosphere ' +
      'attached attachment attacks attempt attend attendance attorneys attractions attribute attributes aud audience ' +
      'audit aunt''s authentication authorities authorized automated avatar aviation awarded awareness babe babies ' +
      'backup baker balls baltimore bands bandwidth bang bankruptcy banner barbara bargain barry baskets bathroom ' +
      'bears beast beastiality becoming bedrooms beds beer begins behalf behaviour belgium believed believes belt ' +
      'ben berlin bestiality bet betting bidding bigger biggest bike billing bills billy bio biography biological ' +
      'biology birds birmingham bits biz blackjack blank blind blocks blogger blonde blowjob blowjobs blues ' +
      'bluetooth blvd bmw boats bodies bold bond bonds bone boobs booking boost boot boots booty border boss bottle ' +
      'bound boundary bowl brass bread breaks breasts bright bringing brings bristol britain broad broadcast broker ' +
      'brothers bruce buddy buffalo buffer bugs builder bukkake bulgaria bulk bulletin burn burning busty busy butt ' +
      'buttons buyers cabinet cables cache cached caesar''s cafe cake cal calculate calculated calculator cam ' +
      'cambridge camcorder campbell camping cancel candidate candidates candy capabilities capability capable caps ' +
      'captain capture carbon carefully caribbean carrier carrying carter cartoon cartoons cartridge casinos castle ' +
      'casual catalogue catch catering catholic cats caught causes celebrity cellular centres ceo chairs challenges ' +
      'chamber champion championship channels chapters characteristics charged charger charity charlie charlotte ' +
      'charter cheats checked checking checks cheese chemicals chemistry cherry chest chevrolet chicken childhood ' +
      'chile chip chips chocolate choices choosing chosen christopher chronic churches cialis cincinnati cinema ' +
      'circle circumstances citizen citizens citysearch clark classics classification classified classroom clause ' +
      'clay clearance cleveland clicking climate clinic clinton closely closer closing cloudy cluster coach coastal ' +
      'cocks coins collaboration collect collectables collected collections colleges collins columbus columns combat ' +
      'combine comedy comfortable comic commands commentary commissioner commit commitment committed committees ' +
      'commons communicate compaq compensation compiled complaint complaints completion comply composition ' +
      'concentration concepts concern concerning concert conclusion concrete conducted conferences confidence ' +
      'configure confirm confirmed conflict connecticut connections consent consequences conservative consideration ' +
      'considering consistent consists console consolidation constant constitution consultant consultants ' +
      'consultation consumers consumption contest continental continues continuous contractor contractors contracts ' +
      'contrast contribute contributed contribution contributions controlled controller convenient conversation ' +
      'convert converted converter cook cookies cooking cooling cooperation coordinator copper correction ' +
      'corrections correctly corresponding costa cotton counsel counseling count''s counties country''s counts couples ' +
      'coupons courts covering cpu crack craft crafts craig crash crazy creates crew crisis crm crown cruises cst ' +
      'cuba cumshot cumshots curriculum customize cute cuts cutting cyprus czech dad damages dancing danger ' +
      'dangerous databases dated daughter''s day''s deadline dealers dealing dean dear debate debian decide deck ' +
      'decrease def defence definitely definitions delaware delay deliver deluxe democracy democratic demonstrate ' +
      'den denmark dennis density dental denver dependent depending depends deposit depression deputy der derived ' +
      'describe describes descriptions desert designers desire desired desktops destinations detection determination ' +
      'detroit deutsch developers developments devil diabetes diagnosis dial diary dicke diesel differences digest ' +
      'dildo dimension dimensions directed directories dirty disabilities disability disabled disaster disclosure ' +
      'discounts discovered discovery discrimination discussed diseases dish disorders displaying displays districts ' +
      'diverse diversity divided divorce doctor''s doctors dodge doen''t dolls domains donald donate donations dont ' +
      'doors dora''s dose doubt douglas downtown dragon drama draw drawing drawn dreams drinking driven drum dublin ' +
      'duke''s duration dust dutch duties dynamics eagle ear earn earnings earrings ease eating ebony echo edinburgh ' +
      'edited editing editions editors edt edward edward''s effectively effectiveness efficiency efficient egg egypt ' +
      'elected elections electricity elementary eligibility elite elizabeth elsewhere emails emerging emissions ' +
      'emotional emphasis empire employed employer employers enabled enables encourage enemy enemy''s enforcement ' +
      'engineer engineers engines england''s enhance enhanced enjoyed entered entering entirely entitled entity ' +
      'environments epa epinions episode epson equation equipped equivalent era ericsson erotic escape essays ' +
      'establish establishment estimate ethernet ethics ethnic evaluate eve eventually everybody everyday exact exam ' +
      'examination examine exceed excel excellence exception excess exciting execution exhibit exhibition existence ' +
      'exists exp expand expanded expansion expectations expense expenses expensive experienced experiences ' +
      'experiment experimental experiments expertise explain explained explanation explorer export exposed expressed ' +
      'extend extensive extent extras extremely fabric faces facial facing fairly familiar fantastic farmers fault ' +
      'favourite favourites featuring federation fell fellow fetish fiber fifth fig fighting filing filled filters ' +
      'financing finder findings finds finger finland firefox fiscal fits flags flashing flexibility flexible flood ' +
      'florist fluid flying focused folk folks foods forever forget forgotten formal formation formats formed ' +
      'formula forth fortune''s foster foto founded fox franchise francis franklin fraud fred fruit functionality ' +
      'fundamental funded funeral gang gap garage gardens gary gate gateway gcc generate generator genetic genre ' +
      'genuine geographic geography ghost giant glad glance glasses globe glory glossary gnu gonna gordon gourmet ' +
      'governance governments governor grace grades graham granted grants graph grass gray greece greek greg grey ' +
      'grid gross grounds grove grown guard guardian guestbook guests guidance guinea gulf gun hairy hamilton ' +
      'hampshire handbook happened happens harbor hardcover harris hat hate haven''t header heads healing heart''s ' +
      'hearts heating heaven heaven''s heights hell helped helping hence henry''s heritage herself highlights highway ' +
      'hilton hist historic hobbies hockey holdem holder holders holding holds hollywood holy honda honor hop horror ' +
      'horses hospitals hosted howard hrs humans humor hundred hundreds hungary hunt hunting hurricane hurt husband ' +
      'husband''s hybrid ian icons idaho identification ignore ill illegal illustrated imagine imaging img immediate ' +
      'immigration implement implemented implementing implications impossible improvements improving in''t incident ' +
      'incorporated increases independence indexed indicate indicated indicates indicators indonesia indoor infant ' +
      'infection ing ingredients initiative initiatives injuries inner innovation innovative inquiry insider insight ' +
      'inspection institution institutional instruction instructor instrument integrity intellectual intelligent ' +
      'inter interaction intermediate interpretation interviews introduce inventory investigation investing ' +
      'investments investor investors invited involvement involves involving iran iraqi isn''t iso jacket jane jason ' +
      'jay jean jeff jennifer jerry jessica jet jewellery jewish jimmy johnny jokes jon jonathan jordan jose ' +
      'journals journey joy judgment jurisdiction karen kate keeps keith ken kent kenya kernel kerry kevin keyboard ' +
      'keys kick kid kill kill''d killed kim kings kiss kits knowing knows korean labels labour labs lady''s laid ' +
      'lakes lamp lan lands landscape lane laptops larry lat latina latter launch launched laura lawrence lay layout ' +
      'lbs leaf learned lease leaves leaving lecture leg legacy legend legislative legs leisure lens lesbians lesson ' +
      'lessons lets lewis lib liberal liberty licensing lie lies lifestyle lifetime lift limitations limits ' +
      'limousines lincoln linda linear linked liquid lisa listening literary livecam lived loaded loading locate ' +
      'lock lodge lodging logic logos loop lose losses lounge lov''d loved lovely luck lucky lunch machinery mad ' +
      'madison magnetic mainly maintaining maker makers malaysia mall managers managing manchester manga mapping ' +
      'marc margaret maria marie marked marks mars marshall mary''s massage massive master''s masters matches ' +
      'mathematics matt matthew mayor meal meant measured measurement measurements meat mechanical mechanism ' +
      'mechanisms med medication medline meets melbourne memorabilia memorial memories mens mention merchandise ' +
      'merchants mercury mesh messenger meta metabolism meter metro mexican mhz micawber''s micro mile milfhunter ' +
      'milfs milk mill millions milwaukee mining minority mint mirror misc missed mississippi mit mod modeling modem ' +
      'moderator modes modify modules molecular monitors monster montana moore moral morgan mortgages motorcycle ' +
      'motors mountains mouth moves mpeg mph municipal murder muscle mutual mysql mystery n''s nancy narrow nasa ' +
      'nashville nationwide nature''s navigate navy nba nearest nebraska nec necessarily neck neighborhood neither ' +
      'nelson nevada newest newly newspapers nfl nick night''s nights nikon nintendo nipples nobody node noise ' +
      'normally northwest norway notebook notebooks noticed notices notification notify nova novel nsw numerous ' +
      'nurse nutten oak objective obligation observations observed obvious obviously occupation occur occurred ' +
      'occurs odds offline offset oldest ongoing opened opens opera operate operated operational operators ' +
      'optimization oracle ordered ordinary organic organisation organisations organized orgy orientation oriented ' +
      'orleans other''s ourselves outcome outcomes outlet outlook outstanding overnight overseas ownership oxford ' +
      'packaging packard packet pad paint painting pakistan palace pan pants par para paradise paragraph parallel ' +
      'parameter parliament partial participate participating partly passenger passing passion pat patches patent ' +
      'patrick payday paying pci pcs pdas pdt pearl pee peer peggotty''s pen penalty penis pension people''s pequod''s ' +
      'percentage performing periods perl permitted personally personals perspective phil philip philippines philips ' +
      'photographs phrase physician physicians piano picks pill pills pilot pin pine pioneer pipe pipeline ' +
      'pittsburgh pizza placement plain plane planned plasma plate plates platforms platinum plays playstation plaza ' +
      'pleased pleasure plenty plot plug pmid poems poland polish poll polls pollution popularity portion portions ' +
      'portland ports portugal possibility possibly postage postposted pot potter pottery pound pounds pour poverty ' +
      'powers prayer precision prefer preferences preferred pregnancy pregnant preliminary premier prepare ' +
      'presentations presents priced pride primarily prince prince''s princess principle printable prison prize ' +
      'probability proceedings processed processor producer producing productions productivity profits programmes ' +
      'progressive prohibited promise promoting promotional promotions properly proposals proteins proud prove ' +
      'proven province psp psychology pub publish publishers puerto pull pulse pump pupils purchased purchases ' +
      'purchasing pure purple pursuant push putting puzzle python qty qualified quarterly que quebec queries quest ' +
      'quiet rack radar radiation rail raise raised raising ram ran ranking rapid raw reached reaction reads realize ' +
      'rear receipt receiver receiving reception recognition recognize recognized recommendation recorder ' +
      'recruitment reducing ref reflect reform refund reg regard regardless regards registry regularly regulatory ' +
      'rehabilitation relating relation relatively reliability reliable remaining rep repeat replace replaced ' +
      'reporter representation representatives represented represents reproduction republican requested requirement ' +
      'res rescue researchers reservation reservations reserves residence resident resistance resorts respectively ' +
      'respond responses responsibilities restricted restrictions resulting resume retirement revealed revenues ' +
      'reverse reviewer revolution rhode rice richmond rick rico ridge riding ringtone rising risks roads rob ' +
      'roberts robot rod roger roles rolling roman romance romantic rome ron roof roses ross router rpm rubber rugby ' +
      'rush russell ryan sacramento sad safari salary sam samuel sand sarah satisfaction satisfied saudi saved ' +
      'saving scan scenes scheduled schedules scholarship sci scientists scope scores scottish screening scripts ' +
      'seal sealed sean searching seats secrets sectors securities seed seek seeker seemed segment semester semi ' +
      'seminar seminars senator sending sensitive sensor sentence seriously serves sessions settlement severe sexcam ' +
      'shadow shareware sharp shaved she''ll sheets shell shift ship''s shipped shit shock shoe shoot shooting shopper ' +
      'shoppers shorts shots showed shower showtimes sick sides siemens sierra sight signals significantly silent ' +
      'silk simon simpson simulation sin sir sister sit sitting situations sized sizes skill slide slip slot slowly ' +
      'smaller smile smoke smooth sms socket soil solar soldiers sole solo solve somewhat somewhere son''s sons ' +
      'southwest sov''s spaces spanking speaking specialist specialists specialty specification specify spectrum ' +
      'spending spin spiritual split sponsors sporting spray spread spy spyware sri stability stable stainless ' +
      'stamps stands starts statistical stephen stereo sterling steven stewart stick stocks stopped stored storm ' +
      'strange streets strike strip strongly structural studied studios stupid styles sublime submission ' +
      'subscriptions subsection subsequent substance substances substantial successfully suck sufficient sugar ' +
      'suggests suit suitable sum summit superior supplement supplements supplier supporting supposed supreme ' +
      'surprise surrounding surveys survival susan suspension sustainable sweden swedish swimming swing swiss ' +
      'switzerland symbol symbols symptoms syndrome syntax tab tabs taiwan talent talks tall tampa tank targets ' +
      'tasks taste taught teach technique telecom telecommunications telling tells template templates temple ' +
      'temporary tend terminal territory terrorism terry tested testimonials textbooks thai thailand theft themes ' +
      'thermal they''ll they''re thick thin thompson thongs thousand threads threat throat throw thumbnail tie tiffany ' +
      'tiger tight till timon''s tiny tion tissue tobacco toe tokyo tomorrow tone tones tonight tony toshiba totally ' +
      'tough tourist tournament tower towns toyota tracks tradition trail trailer trailers trained tranny trans ' +
      'transaction transactions transition transmission traveler treat treated trembl trend trials trips troops ' +
      'tropical trouble trucks truly trusted tube turn''d turning turns tutorial tutorials tvs twenty twice twiki ' +
      'twin typical typically ukraine ultra unable und undergraduate underground unfortunately uniform uniprotkb ' +
      'universe universities unix unlike unlimited unsubscribe upcoming upskirt urw usc usual utc v''s vacations ' +
      'vacuum valentine valuable vancouver variables vary vat vbulletin vector vendors venture venue verify vermont ' +
      'versions versus vertical verzeichnis victims victory vietnam villa vinyl violation virgin visa visible ' +
      'visited visiting visitor visits vista vital vitamin voip voltage volunteer volunteers von voting wake walker ' +
      'walking wallpaper wallpapers walls ward warehouse warm warren watching waters wave wayne weak wealth weapons ' +
      'webcam weblog welfare wells wet wheels whenever whereas widely width wife''s wiki wikipedia wildlife willing ' +
      'wing wings winner winners wins wisdom wise wishlist witness wolf womens wonder wooden woods worker workplace ' +
      'workshops world''s worry worse worship worst wow wright writers writes wyoming yard yards yield yoga you''d ' +
      'you''ve yours zov''s '),
    (Cost: 64; Words:
      'aaa aaron accommodations ace acoustic acquired activation actors acute additions adjustable adjusted ' +
      'adjustment administrators adopt advantages adverse advertisers affiliated afford afraid aging aims aka albany ' +
      'algorithms alice alien all''s allocation alphabetical alternatives amber amendments amenities amy animated ' +
      'announce announces another''s answered antenna anybody anymore app appeals applicants arabia arc architectural ' +
      'archived arising arrangement arrive arrow artificial artwork aside assess assignments assumed assurance ' +
      'astronomy athens athletics atlas attachments attempts attended attitude attraction attractive authentic ' +
      'authorization automation automobile axis bachelor ban barcelona bargains basically basics basin bbw beads ' +
      'beam bearing bedding beef belief berkeley besides bestsellers bibliography bidder bikes bikini binary bishop ' +
      'blade blogging boat''s bookstore bracelet brad branches breath brilliant britney broadcasting broadway ' +
      'brochure broke brokers brooklyn browsing builders bull bunch cad calendars camcorders camel camps candle ' +
      'canvas canyon careful carl carol carpet carriers cartridges cassette causing ceiling cemetery cents charm ' +
      'chase chi cited civic claimed cleaner clerk climbing cloud coaching coal coalition coat cod coding coin cole ' +
      'collective collector colombia colored combo commonly commonwealth comparative compatibility compilation ' +
      'complexity compression conclusions conditioning confidential confirmation connectivity connector considerable ' +
      'constantly constitutional constraints constructed consult container contests convenience conventional cookie ' +
      'cooper cooperative coordination cord corn corp corporations corps cosmetic costume cottage counters coupon ' +
      'courtesy creator cricket crimes criticism critics croatia crop crossing crowd cry cultures curve customized ' +
      'customs cycling damn dawn dealtime death''s deaths decade decades declaration declared decline decor deemed ' +
      'defendant deleted delhi demands democrats demonstrated denied departure depend destruction detected ' +
      'determining diagnostic dialogue diameter diamonds differ difficulties difficulty dildos dimensional dir ' +
      'discharge discipline discs disorder dispatched disposal dispute distinct distributor diving docs documentary ' +
      'doesn''t doll donation dos doug downloaded drew drinks dropped drunk duke durham earned ecommerce edwards eggs ' +
      'elegant eliminate embedded eminem encoding encouraged eng engaged engagement enrollment ensuring ent entities ' +
      'entrance equally espn essay establishing ethical evaluated evans everywhere examined excerpt exercises ' +
      'expenditure explains exploration ext extensions extract facilitate fails fake falling fame farmer favor fed ' +
      'feeding feelings feels fewer firewall fisher fisting fleet flickr floral florists flows flu fonts formerly ' +
      'fortune fotos founder framed freeware frequent friend''s fucked furthermore fusion gadgets gains gamecube ' +
      'gangbang gardening gates gathering gbp gel gen genealogy genes genetics ghz glasgow gloucester''s gloves gnome ' +
      'gospel goto governor''s grain greatly grew grill guilty guns habitat hacker hadn''t halloween handheld hang ' +
      'hanging happening harvard hats haven hazardous heading headquarters headset herald herbal herein hero heroes ' +
      'hewlett highlight hiking hispanic holdings holes holland honest hood hook hopefully horizontal horny ' +
      'hospitality hosts households housewares hub identifying ieee illness impacts inclusion inclusive increasingly ' +
      'incredible indianapolis indicator induced inform informational initially injection inkjet ins inspired ' +
      'installing instantly intent interactions interfaces intervention intro invite involve ion islam islamic isp ' +
      'israeli jacksonville jam jamaica jeans jefferson jelsoft jews joining jpg juan judges judicial juice jury ' +
      'juvenile katrina kennedy killer killing knife knight lamps lanka largely latex latinas lawn lebanon ' +
      'legislature lenses liable licence life''s liked linking lion lite literacy litigation liver liverpool locator ' +
      'locked logical lokhov''s look''d lookup loose losing lottery louisville loves loving lung lycos lynn macintosh ' +
      'madrid manhattan manuals margin marriott mart mask mathematical meals measuring median medicare melissa ' +
      'memphis mercedes merely messaging meters methodology metropolitan mice michelle midnight migration mills ' +
      'mineral minimal minneapolis mins mistake mitchell mitsubishi mlb mobility moderate modification moments ' +
      'monica montgomery montreal mood moreover morris moscow mounted movements mozilla mrs msg murray museums ' +
      'muslim naturally ncaa neil nepal netscape neutral nhl nigeria nike nissan noble nodes norfolk northeast ' +
      'norton nose nski''s nurses nyc nylon oakland obligations observation occasion occupational oclc odd oem ' +
      'olympic omega opposed opposite opposition opt optimal orchestra organizational ottawa outer outline ' +
      'outsourcing oxygen pace packs painted paintings palestinian panama panties pantyhose parenting parish parker ' +
      'partnerships passage passes payable pending pentium perfectly perfume peripherals permits personality ' +
      'personalized peru petition pharmaceutical phd photograph photographer photoshop picked pierre pissing pixels ' +
      'planner plc pleasant plugin podcast pointed pointer polyphonic populations portrait portuguese potentially ' +
      'powder preference preparing presidential priorities proceed processors procurement producers projection ' +
      'projector prospective protective protocols proxy psychological pulled punk puts qualifications quantum ' +
      'queen''s quit quiz railway rainbow ralph ranch ranging rankings rap rapidly rat realized recall receives ' +
      'recipient recordings recycling redeem reed referral refers refinance refine regime remained remarks renewal ' +
      'repairs representing reputation requiring resistant resolve resolved restoration restore resulted retailer ' +
      'retired returning reuters rev rfc rica rio rivers robin robinson rocks rocky rogers romania roots rough ' +
      'roulette routine routing roy ruby salon sampling sauce saver scanner schemes scoring screens seasonal seasons ' +
      'secured seeds seeks sees selecting seniors seo sequences shaped sharon shelf shore shoulder shut sigma ' +
      'similarly sing singer singing sisters situated skiing skype slave sleeping sleeve slideshow slots soap solely ' +
      'somebody sought soup southeast spears specialized spectacular spoke spoken spots ssl stack stadium stages ' +
      'stanley starring statutory stayed std steam steering stem stones stood strap stretch strictly strings stroke ' +
      'struggle submissions subscriber subscribers substitute sucking suddenly sue suffering suicide sunglasses ' +
      'sunset supervisor suppose sur surf surprised surveillance switches tablet tagged tail tale tales targeted tcp ' +
      'tee teenage temp termination territories terror terrorist texts theoretical thereof thesis thirty thou ' +
      'threshold thru thumbs ties timing tin tired tit titans titten todd toner tons toolbar tops torture totals ' +
      'township trace tracked tracker tramadol transferred transfers transformation translate treatments trek trim ' +
      'triple trunk tune turkish turner twelve ultimately uncle''s underlying understood underwear untitled unusual ' +
      'val valve variation vast venezuela verification verified veterans victim vid vincent violent virtually ' +
      'vitamins vlovna''s voices voluntary voted wage walked walter wanna warner wash wasn''t watched waves we''re ' +
      'wearing weddings weird winds wishes wizard women''s workforce worlds wrap wrestling xhtml yorkshire younger ' +
      'zdnet zimbabwe zoo zus ')
  );

  RussianTiers: array[0..12] of TWordTier = (
    (Cost: 16; Words:
      'в '),
    (Cost: 20; Words:
      'и '),
    (Cost: 24; Words:
      'на '),
    (Cost: 28; Words:
      'года из по с '),
    (Cost: 32; Words:
      'а англ был году для до к как области от районе род также '),
    (Cost: 36; Words:
      'была во входит год деревня его за или не о он после при россии село советский состав сша что является '),
    (Cost: 40; Words:
      'август августа автобус ага административный адрес адреса алло американский апрель апреля без берем берет ' +
      'берешь беру берут благодарю близко блин более болен болит больница большая больше большие большое большой ' +
      'брал брала брали брат брать будем будет будете будешь будто буду будут будь будьте бы бывает бывало были было ' +
      'быстро быть в-третьих важно важный вам вами вариант вас ваш ваша ваше ваши вашу вверх вдруг ведь везде весной ' +
      'весь вечер вечером взял взяла взяли взять видел видела видели видеть видим видимо видит видите видишь видят ' +
      'вижу вместе вместо вниз во-вторых во-первых вода возможно возраст возьми войны вон вообще вообще-то вопрос ' +
      'вопросу вопросы восемь воскресенье вот вперед врач временем времени время все всегда всего всем всех встреча ' +
      'встречи встречу всюду вся вторая вторник второй вчера вчерашний вы где где-то главный говорил говорила ' +
      'говорили говорим говорит говорите говорить говоришь говорю говорят годах годы город города городе городом ' +
      'готов готова готово готовы да давал давала давать давно даем дает даешь даже дай дайте дал дала далеко дали ' +
      'дать даю дают два две дверь девочка девушка девять декабрь декабря дела делаем делает делаете делаешь делал ' +
      'делала делали делать делаю делают дело делом делу денег день деньги десять детей дети деятель дней днем дни ' +
      'дня доброе доброй добрый договор договора документ документы должен должна должно должны дом дома домой домом ' +
      'дому дорога дорогая дорогие дорогой доставка доставки дочь друг друга другая другие другое другой другом ' +
      'другу друзей друзья друзьям думаем думает думаете думаешь думал думала думали думать думаю думают еда едем ' +
      'едет едете едешь еду едут ее ей ему если есть ехал ехала ехали ехать еще ею ждал ждала ждали ждать ждем ждет ' +
      'ждешь жду ждут же женщина живем живет живете живешь живу живут жизни жизнь жизнью жил жила жили жить забудь ' +
      'забыл забыла забыли забыть завтра завтрашний заказ заказа заказы заканчивает заканчивать заканчиваю закончил ' +
      'закончила закончить закрой закрывать закрыл закрыла закрыть замечательно занят занята заняты зато зачем ' +
      'заявление звонил звонила звоним звонит звонить звонишь звонка звонок звоню звонят здесь здорово здоровье ' +
      'здоровья здравствуй здравствуйте зимой знаем знает знаете знаешь знал знала знали знать значит знаю знают ' +
      'идем идет идете идешь идея идти иду идут извини извините им имени именно ими имя иногда иной институт ' +
      'интересно интересный интернет искать итак их ищет ищешь ищу июль июля июнь июня каждая каждое каждый кажется ' +
      'как-то какая какие какое какой какой-нибудь какой-то каша квартира кем клавиатура класс когда когда-то кого ' +
      'код комната компьютер кому конечно короче которая которое которые который кофе красивая красивое красивый ' +
      'кровать кроме круто кстати кто кто-нибудь кто-то куда куда-то купил купила купим купит купите купить купишь ' +
      'куплю купят кухня ладно лат легко лежал лежала лежат лежать лежим лежит лежишь лежу лет летом ли либо лишь ' +
      'логин лучшая лучше лучший любил любила любили любим любит любите любить любишь люблю любят людей люди людьми ' +
      'людям магазин май маленькая маленький маленькое мальчик мама март марта мать машина машину машины мая ' +
      'медленно между меньше меня месяц месяца метро минута минуты мир мира миром миру мне мной мною мог могла могли ' +
      'могло могу могут мое можем может можете можешь можно мои мой молоко мою моя мужчина мы мышь мясо наверное над ' +
      'надо назад название найди найду найти нам нами написал написала написан написано напишем напишет напишете ' +
      'напишешь напиши напишите напишу напишут нас население находится начал начала начали начать начинаем начинает ' +
      'начинаешь начинать начинаю начинают наш наша наше нашел наши нашла нашли нашу недавно недели неделя нельзя ' +
      'нем нему неправильно нет нечего нею ни нибудь нигде никогда никого никто ними ниче ничего ничему но новая ' +
      'новое новые новый номер номера норм нормально ноутбук ночи ночью ноябрь ноября нравилась нравилось нравится ' +
      'нравятся ну нужен нужна нужная нужно нужны нужный об образом огромное один одна однако одни одно окей окно ' +
      'около октябрь октября она они оно оплата оплаты опять осенью ответ ответил ответила ответим ответит ответите ' +
      'ответить ответишь ответы ответят отвечает отвечаешь отвечал отвечаю отвечу отдельно отец открой открывать ' +
      'открыл открыла открыть откуда отлично отправил отправила отправить отправлено отправлю отправь отсюда оттуда ' +
      'отчет отчета очень ошибка ошибки ошибку папа папка парень пароль первая первое первый перед писал писала ' +
      'писали писать письмо пишем пишет пишете пишешь пишу пишут плохая плохие плохое плохой площадь под подожди ' +
      'подождите подруга подруги подскажите подумаем подумает подумаете подумаешь подумал подумала подумаю подумают ' +
      'поезд пожалуйста позавчера позвони позвонил позвоним позвонит позвоните позвонишь позвоню позвонят поздно ' +
      'пойдем пойдет пойдешь пойду пойдут пойти пока пока-пока покупка получено получил получила получить помнил ' +
      'помнила помним помнит помнить помнишь помню помнят помог помогите помогла помогу помогут поможем поможет ' +
      'поможете поможешь помочь понедельник понимаем понимает понимаете понимаешь понимал понимала понимать понимаю ' +
      'понимают понял поняла поняли понятно поселения последний последняя послезавтра посмотрел посмотри посмотрим ' +
      'посмотрит посмотрите посмотришь посмотрю посмотрят потом потому похоже почему почему-то почта почти пошел ' +
      'пошла пошли поэтому правда правильно прекрасно привет приветик приветствую придем придет придешь приду придут ' +
      'приедем приедет приедете приедешь приеду приедут приехал приехала прийти приложение пример примеры причина ' +
      'пришел пришла пришлет пришлешь пришли пришлите пришлю про проблема проблему проблемы проверил проверила ' +
      'проверим проверит проверите проверить проверишь проверь проверьте проверю проверят программа программы продал ' +
      'продать прости простите просто простой прочитай прочитал прочитала прямо пятница пять работа работаем ' +
      'работает работаете работаешь работал работала работали работать работаю работают работе работой работу работы ' +
      'равно рад рада рады разумеется район района рано ребенок редко результат река реки республики родители ' +
      'российский российской рублей рубль рыба рядом сайт сам сама самая сами само самое самолет самый сахар ' +
      'свободен свободна свободны свое свои свой свою своя сделаем сделает сделаете сделаешь сделал сделала сделали ' +
      'сделан сделана сделано сделаны сделать сделаю сделают себе себя сегодня сегодняшний сейчас секунда сельского ' +
      'семь семья сентябрь сентября сестра сеть сидел сидела сидеть сидим сидит сидишь сидят сижу скажем скажет ' +
      'скажете скажешь скажи скажите скажу скажут сказал сказала сказали сказано сказать склад сколькими сколько ' +
      'скоро слева следующая следующий словно сложный слушаем слушает слушаешь слушал слушала слушать слушаю слушают ' +
      'смотрел смотрела смотрели смотреть смотрим смотрит смотрите смотришь смотрю смотрят смысл снова собой собою ' +
      'совещание совсем согласен согласна согласны соль сообщение составе составляет спасибо спокойной способ справа ' +
      'справка спрашивает спрашиваешь спрашивал спрашиваю спроси спросил спросила спросить сразу среда среди ссср ' +
      'ссылка старая старик старое старуха старые старый сто стоим стоимость стоит стоишь стол стою стоял стояла ' +
      'стоят стоять страна стране страница страны студент стул суббота суп супер счастья счет счета сын сюда та так ' +
      'такая такие таким такое такой такси там твое твои твой твою твоя те тебе тебя телефон телефона телефонный ' +
      'территории типа то тобой товар товары тогда тоже только тот третий три трудно туда тут ты тысяча у уважаемая ' +
      'уважаемый увидимся угу удачи уже узнаем узнает узнаете узнаешь узнал узнала узнаю узнают укр украины улица ' +
      'улице улицы университет урок утро утром учитель файл файлы фамилия февраль февраля фильм футболист хлеб ' +
      'хорошая хорошее хорошие хороший хорошо хотел хотела хотели хотелось хотеть хотим хотите хотя хотят хочет ' +
      'хочешь хочу хуже цена центр цены чай час часа части часто часы чего чей человек чем чему через четверг четыре ' +
      'читаем читает читаете читаешь читал читала читали читать читаю читают что-нибудь что-то чтобы чье чьи чья шел ' +
      'шесть школа шла шли экзамен экран эта эти это этот я январь января ясненько ясно '),
    (Cost: 44; Words:
      'александр альбом армии берегу века вид впервые герой годов государственный греч группы двух длина доктор ' +
      'других европы занимает заслуженный затем игр из-за известен имеет исп истории итал клуб клуба коммуна коммуны ' +
      'которого которой которых место мировой москва наиболее населения настоящее наук немецкий несколько них ' +
      'область округ округа округе олимпийских партии первой переписи писатель политик поселение поселок премии ' +
      'призер провинции протекает против профессор рамках ранее расположен расположена рода российская русский ' +
      'сборной сельсовета семейства со совета союза спорта стал стала того том труда участие участник федерации ' +
      'франции французский центра церкви часть человека чемпион чемпионата член этого этой этом '),
    (Cost: 48; Words:
      'автор административно-территориального академии актер актриса александрович альбома американская ' +
      'американского американской араб бассейна бел британский веке великобритании великой версии виде видов ' +
      'включает включая владимир военный впадает впоследствии выступал вышел германии главным городского городской ' +
      'государства государственной граф группа губернии губерния данным движения департамент депутат деревни дороги ' +
      'другими единица епископ женщин журналист защитник здание земле значения иванович игра играх игры известные ' +
      'известный имеют империи империя индекс института искусства испании используется историк италии итальянский ' +
      'категории качестве кино кит класса книги коатуу команды компанией компании компания композитор конце котором ' +
      'края кубка культуры лауреат летних лиги линии мастер международного менее метров мире михайлович млн многих ' +
      'момент моря москве московской музей муниципалитет муниципального муниципальное названием нападающий например ' +
      'населенных науки национального национальной начале начало него нескольких николай носители ныне образование ' +
      'образования общества общине обычно одним одного одной озера озеро организации ордена основе основном остров ' +
      'острова отечественной относится париж педагог первого первым первых период песня плотность победитель позже ' +
      'позиции пол политический полузащитник помощью порт почтовый поэт православной представляет преимущественно ' +
      'премьера примерно приток производства происхождения прошел пункт пунктов раз различных расположенный ' +
      'расстояние растений регионе режиссера результате реке родился роли роль роман россия рсфср русской самым ' +
      'самых сборная сборную своего своей связи северной сезон села сельское сельсовет серии сил система системы ' +
      'смерти совет советского современной согласно соревнования составляло состоит состоялась состоянию ' +
      'социалистического специалист список сср стали станции станция старший стран студийный считается таких театра ' +
      'тем течение титул тренер трех турнир уезд украинский университета управления устье ученый фильма фильмов фон ' +
      'футболу футбольный художник центральной центром церковь частью чел чемпионат чемпионка честь числе число ' +
      'школы штат штата штате южной являются язык языке японии '),
    (Cost: 52; Words:
      'августе австралии австралийский автодороге автономного административная административно-территориальная ' +
      'административного административному азерб азербайджана азии академик алекса александра алексей америки англии ' +
      'английский андре андрей апреле арм армении армия архиепископ архитектор ассоциации асср атлетике безопасности ' +
      'беларуси беларусь белорусский благодаря ближайшие болг болгарии большинство большого бразилии бразильский ' +
      'британская британской бронзовый бывший васи василий васильевич веков вел великого вида виды вка владимирович ' +
      'власти власть влияние вновь водосборного воды воеводство военачальник военного войне войск войска вокруг ' +
      'вологодской волости волость вооруженных восток востоке восточной вошла времен вскоре встречается второго ' +
      'втором входил входила входило входят выборах выборы выпущен выпущенный высота высоте выступает генерал ' +
      'генерал-майор генри глава главного главной главных городов городском государственного гражданской границе ' +
      'греции груз данный данных дважды двукратный двумя действие действия действующий дел деления деятельности ' +
      'деятельность джеймс джон джона дивизии дивизия династии дипломат директор диск дистанции дмитрий должность ' +
      'драматург евич европе единственный жанре железнодорожная железной женской женскую живописец животных жителей ' +
      'журнал журнала зависимости занимал занял западе западной записи звезда звезды земли зимних значение золотой ' +
      'зрения ива иван игрок известна известная известно известного известных изменения изначально имел именем ' +
      'императора индии информации искусств испанский использовать исследований исследования исторических историю ' +
      'история италия кавалер каз казахстана калифорния канадский канады кандидат кантон кантона карьеру карьеры ' +
      'километрах китая книга кнр князя количество команд команда командир комитета компаний комплекс контракт конца ' +
      'корабль королевство король короля которому которую которым крае край красной крепость крупнейших крупных ' +
      'кубок левому левый легкой ленинград ленинградской линия литературы лондон лучших мае мария медали ' +
      'международной международных места месте местного министерства министр мифологии миха михаил многие много ' +
      'множество модель монастырь море москвы московского мост мужчин музыкальный музыки муниципалитета ' +
      'муниципальном наград назван названия называется называют народ народного народной народный народов наряду ' +
      'населенные населенный научных находился находятся национальный начиная ней некоторые некоторых немецкая ' +
      'немецкого несмотря нид ние ниже нижегородской никола николаевич ним новгородской нович нового новой нью-йорк ' +
      'обеспечения обладатель обороны общего общей общественный общество община общины объект объектов одновременно ' +
      'одноименного одноименной одном означает означать октябре олимпийский организаций организация орден оскар ' +
      'основан основана основателей основатель основной основные основу особенно острове островов открыт отличие ' +
      'отца официально официальный очередь палаты памятник париже парк партия певица певицы первом первоначально ' +
      'первую первые переводчик периода персонаж персонажей песен песни петр петрович пиньинь писателей писателя ' +
      'питер площади победу подсемейства подчиняется позволяет позднее поле полка полностью польская польский польше ' +
      'польши помимо помощи пор поселка поскольку пост построен почетный права правительства правительство правому ' +
      'председатель представителей представители представитель представлен президент президента премию ' +
      'приблизительно принадлежит приняли проведения провел провинцию провинция продюсер проект проекта прозаик ' +
      'произведений произведения происходит протяжении профессиональный проходит прошли псковской публицист пункты ' +
      'пути пяти работ работник развитие развития различные разных разработки разряде районного районов ран ' +
      'располагается расположенная расположено распространено расстоянии революции регион региона редактор редакции ' +
      'режиссер режиссером республика республике розыгрыш романа российского руководитель руководством рус русская ' +
      'русского ряд ряда самой самоуправления санкт-петербург своим своими своих святого святой север севере ' +
      'северная северо-востоку северу сезона секретарь селе сельский сельской серб серге сергей серебряный середине ' +
      'серия силы сингл систем системе систему скорость славы слова службы случае смоленской снятый собор ' +
      'собственное советник советская советской совместно современного содержит соединение созвездии создан создана ' +
      'создания созданный созыва солнца сообщества соответственно соответствии соревнованиях состоялся списке спустя ' +
      'стадион стало статус степени стиле стиля сторону стороны странах существует сценарист сыграл тверской театр ' +
      'тела телевидения теории термин территория тех техники технических течет тип топоним точки транспорта тур ' +
      'турнира турнире турниров тыс тысяч уезда украина умер университете упоминается упр управление уровне уровнем ' +
      'урожденная условиях устройства устья участвовал участников участница училище федорович философии фильмах ' +
      'фильме фин флота форма формирования формы франция фронта ходе хозяйственный хоккеист хоккею храм ' +
      'художественный хутор цвета целом целью центре частности чаще чемпионате чемпионатов чемпионом четвертый ' +
      'четырех численность член-корреспондент членов членом швед шведский швейцарии швейцарский швеции ширина широко ' +
      'шотландии шоу экономики эпохи эскобар этим этих этому эту юге югу юрий юрист являлась являлся языка японская ' +
      'японский ярославской '),
    (Cost: 56; Words:
      'авиакомпании авиакомпания авиации авиационная австралия австрии австрийский автодороги автомобиль автономной ' +
      'автора авторов автором административно административным администрации адыг азербайджанский акрон активно ' +
      'алексе алексеевич али алтайского альбомов альпы американским американских американском америке анатолий ' +
      'английского английской англия андреев андреевич анны антонио аргентинский аргентины арденны арене армения ' +
      'армией армянская армянский армянской артист артистка архангельской архитектора архитектуры ассоциация ' +
      'астероид аул африки бавария базе байон бангладеш банка барон бассейн баш башкортостан башкортостана башня ' +
      'беге бегу белого белоруссии бельгии бельгийский бельгия берег берега бертуччи библиотека битва битве близ ' +
      'блок бога богдановская боевых боец болгарский большим большинства больших большую борец борьбе борьбы ботаник ' +
      'братом братьев браунинг бригады британского брянской будучи букв бывшая бывшего бюллетень бюро валерий ван ' +
      'вариантов вариация вблизи ввс вдоль ведущий ведущих век великий великобритания величина велогонщик вена венг ' +
      'венгрии вернулся вероятно версия верхней верхний верхняя верховного весе весовой взрослых видео видимая ' +
      'виктор вильгельм вич вклад включается включают включен включена влади владимира владимирской властями ' +
      'влиянием вмс вне внимание внук внутренних внутри воду военной военных возглавил возглавлял возможность ' +
      'возничего возрасте войн война войну войсками вопросам вопросов воронежской ворота восстания восстановления ' +
      'востока востоку восточная восточнее восьми вошел вошли вплоть вратарь времена вручения всей вселенной всеми ' +
      'всемирного всему вский вследствие встречаются всю второе вторым входили выбор выборов выиграл выиграли ' +
      'вынужден выполнения выпуск выпущена высотой выставки выступавший выступала выступающий выступил высшего ' +
      'высшее высшей выход выхода выше вышедший вышла вышло газа газета газеты галактика галерея гарри гвардии ' +
      'генерал-лейтенант генерала генеральный генрих генриха георгий герб германия героев героя главе главную ' +
      'главные глубина глубине годом головы голосов голосования гомельской гонке гор гора горных городах городок ' +
      'городских государств государственное государственных государство граждан гран-при границы граничит графа ' +
      'графстве грейвз грейвза греческий греческого греческой григо григорьевич гродненской гроссмейстер грузии ' +
      'грузинская грузинский групп группе группу губернатор давления далее дальнейшем дании данной данные дат ' +
      'датский движение двое дворец дворянский дебютный девушек действий действительный действует декабре делам ' +
      'делению дель департамента департаменте депутатов деревне десятилетия детали детских джеффри джо джордж ' +
      'джорджа дидану директором дирижер дисциплине длиной дми дмитриевич довольно доктора документальный должности ' +
      'долина долине долларов доме домов дороге достаточно достиг достигать достижения доход дочери древнего другим ' +
      'другого думы евгений еврейской европейских европейского европейской единственным ежегодно епархии епископа ' +
      'жанра железнодорожной железных жена женская женского женщины жены жилых журнале журналистов заведение завод ' +
      'завода завоевал задачи заказник заказу закон законом закончился заместитель замок замужестве занимался ' +
      'занимают запад запада западная западу заслуги зачете защитника защиты звезд звездная здании зданий здания ' +
      'земля знак значительно значительную золотая зоне зоны зрителей ивана ивановской ивр игорь игравший играл игре ' +
      'идеи избран известной известность известны известным издание издания изданная измерения изображение ' +
      'изображения израильский израиля иллинойс имеется имела имен иметь индийский индия инженер инициативе ' +
      'иностранных интерес ирана ирландии исключением искусство испания испанского исполнил исполнитель ' +
      'исполнительный использовался использование использованием использования использует используют используются ' +
      'исследователь исток историческая исторический исторического исторической источниках итальянская итальянского ' +
      'итогам итоге июле июне йлович кавказский каждого каждой каждом казахская казахстан казахстанский калужской ' +
      'камаз кампании канада канаде канал капитан карелия карл карла картина картины кат каталога катастрофа ' +
      'категориях като католический католической качества киевской кинорежиссер киностудии кинофестивале кинофильм ' +
      'кировской кислоты китае китай китайская китайский китайского китайской кладбище классе книг книге книгу ' +
      'княжества князь количества колхоза команде командном командованием командой команду комарки комедийный комета ' +
      'коми комиксов комиссии комитет коммунистической комплекса композиция компьютерная конгресса конкурса ' +
      'константин конструктор контроль конференции конфликт кор корея королевского королевской королевства королевы ' +
      'королем короткие корпус корпуса костромской кпк красного красноярского красный кристаллы критик критики ' +
      'критиков крупнейший крупнейшим крупный крыла крым крыма крымской крымскотат кубке культура культурного ' +
      'курганской курской кыргызстана кэмпбелл латвии латыш лев левом легкоатлет легкоатлетка лейбле лейблом ' +
      'лейтенант леса лига лиге лидер лидером лий лит литвы литературе литературный литературовед литовского лиц ' +
      'лица лицо лодка лондоне лос-анджелес лос-анджелесе луи луны лучшие лучшую льва львовской льда льское лютор ' +
      'мадрид майкл макробертс максим малая малый мари марии марий марк марка марте массовой математик матери ' +
      'материала материалов матч матча матчах матче матчей матчи мвд медаль медалью медицинских международная ' +
      'международный международным мезорегиона мексике мексики мелких мере мест местах местности местные местных ' +
      'местом месяцев метод метра микрорегион милан миллионов министра министров миннесота мирового михаи мкртумян ' +
      'младший млрд многозначный многочисленные множества могилевской модели молодежи молодой момента монастыря ' +
      'морских морской московская мотивам мужской мужчины музее музея музыкальной музыкальных музыкант муниципальный ' +
      'муравьев мячом наблюдения награды награжден названа названий назначен называемый называли наибольшая наличие ' +
      'написанная направление направлении направления напротив народа народная насекомых наследия научной научный ' +
      'находилась национальная национальном национальную началась началом началось начался началу начальник ' +
      'начинается нашей нба ндр ндрович небольшой недалеко нее независимости независимость неизвестно некоторое ' +
      'немецкой необходимо неорганическое непосредственно несколькими нидерландов нидерландский нижнем нижняя ники ' +
      'николая ния нко нобелевский нов новых номером номинации норв норвегии ноябре нский нью-джерси нью-йорке оба ' +
      'обеих областей областного областях обозначения обработки образ образован образована образует обсерватории ' +
      'обучения общая общее обществе общин общину объединение объединения объем объема огайо огф одержал одиночном ' +
      'одноименном одноименный одну одобрен озер оказался океана окончания окончил окрестностях округов округу окс ' +
      'олег олимпиады олимпийского опера операции операция описан описания оппозиции определяется опубликованный ' +
      'орган организатор органов орденов орденом оренбургской оригинальной оркестр орловской орсини оружия основании ' +
      'основания основанная основанный основано основная основным основными основных остается остальные островах ' +
      'осуществляется отдельных отзывы открыта открыто открытый отличается относительно относятся отношений ' +
      'отношения отряда отсутствует отто оттон отцом офицер официальным охраны павел павлович памяти память папы ' +
      'парижа парка парламента парном партий партийный певец первенств первенства первенстве переводе переулок ' +
      'перечисленных перешел пермского пермском перс персонажа перу песню петра петров пианист писательница плато ' +
      'платформы племени площадью победителем победительница побережье побережья поверхности повести поддержка ' +
      'поддержку подобных подполковник подразделяется подряд позициях покровителем пола политики политическая ' +
      'политических политической полиции полк полковник полное полный половине половины положение положения ' +
      'полузащитника полуострова получения получили польского польской польша популярных породы портрет португалии ' +
      'порядка поселе поселении поселковой последнего последнее последней последние посол посполитой постоянного ' +
      'построена почитается поэзии поэтесса появился пояса прав правило правительстве правительством правления право ' +
      'правом православный правый праздник празднование практически пределами пределах предположительно ' +
      'предприниматель предприятие председателем председателя представлена представления представлены представлял ' +
      'представляют прежде президентом премий премия премьер-министр преподаватель пресвятой привело признан ' +
      'применение применяется принадлежат принимает принимал принцесса принял принято природы причем проблем ' +
      'провинций проводились проводился проводит проводится проводятся программ программирования программного ' +
      'продолжение продолжением продуктов проектов проекту проживало произведение производство производству ' +
      'произошло происхождение прокат промышленности пространства простых профессионального профессиональном ' +
      'проходил проходили процесс процесса процессе процессов процессора прошла прошлом прямой псевдоним псевдонимом ' +
      'психологии птиц путем путь пэн пятый рабоче-крестьянской рабочих радио раза развитию различными размера ' +
      'разные разработанная разработанный райо районах району ранга ранних раньше расположенное расположенной ' +
      'расположены распространен распространение рассказов растение растения раунде реал регионального региональных ' +
      'результатом результаты рейс рейтинге рек рекорд ректор реку ресурсов реформы речи решение решения рий рим ' +
      'риме римский римской ркка роберт роберта ров родилась родов рождении рождения рок-группы ролям российских ' +
      'роста руководил рум румынии руси русские русских русском рыб рыбы ряде рязанской сад самого санкт-петербурга ' +
      'санкт-петербурге саратовской сборник сборные свердловской сверху свет световых своем свыше связана связанных ' +
      'связано святых священник священной севера севернее северного северный северо-востоке северо-восточной ' +
      'северо-западе северо-западной северо-западу сезоне сезонов сельди сельском сельскому сельсовете семейство ' +
      'семи семье семьи сенатор сентябре сербии сербской сергеевич середины сериал сериала серий серию сети силами ' +
      'сильно сингла синглом скончался скрипач следует следующие слов словаря словац слово сложности служил случаях ' +
      'смог смоленск смысле сначала снят собора соборе собрание собрания событий события советских современном ' +
      'современные современный современных содержание соединенных создал создание созданная солдат соли ' +
      'соответствует сопротивления соревнование соревнований состава составила составляла составляют составная ' +
      'составной сотрудник софия социальных союз специализируется специализирующийся специально спортивный спорту ' +
      'спутник сравнению сражение среде средневековой среднего средней среднем средняя средств средства среды срок ' +
      'ста став стадионе сталинской стандарт старому статусом стать статьи статья стек стекла степанович степень ' +
      'стиль столица столице столицы стороне стрелкового стрелковой строительства строительство студентов студии ' +
      'суда судно судья существовавшая существования существуют сценарий счетом счету считался сыграла сына сыном ' +
      'сэда тат татарстан тауншип театральный текст текстов телеканале телесериал телесериала тельца теперь ' +
      'территорию тесно техас технологии технологий течении течения титулом той токио томас тому тони точка ' +
      'травянистых трад традиции традиционно традиционного тремя третьего третьей третья трехкратный труд ту ' +
      'тульской тура турецкий турнирах турции тысячи тюменской тяжелой тяжести удалось уефа ужасов узел уильям ' +
      'уильяма украине украинская украинского украинской управлением управлению упразднен упразднения упраздненная ' +
      'упраздненного упраздненный уровень уровня условия успех успешно усср установлен устар участвовали участием ' +
      'участии участия участники учебное фактически фамилии фамилий феврале федерального федеральной федор фестиваль ' +
      'фестиваля физик физики физической философ фильму фильмы финал финале финляндии флаг флорида форме форму ' +
      'формулой формулы французская французского французской фридрих фронт функции футбольного футбольной характер ' +
      'характера хикава-мару хмельницкой хозяйства хорв хорватии хорватский хосе хребта христа хуан художественная ' +
      'художника художников царства царя цветы центрального центральный центров церемонии церемония цзу чарте часов ' +
      'частей частиц частично человеческого чемпиона чемпионатах чемпионов черниговской чехии чехословакии ' +
      'чехословацкий чеш чешский чикаго чили чисел числа члены шайбой шахматист швеция шести школе шоссе шотландский ' +
      'штаб-квартира штатов экземпляров экономико-статистический экономист экономических экономической экранизация ' +
      'элементы эпоху эры эст эстафете эстонии этажа юар юга юго-востоке юго-востоку юго-восточной юго-западе ' +
      'юго-западной юго-западу югославии южная южнее южного южном южный юношеских языках языки языков языком ' +
      'яковлевич якутии яна январе япония японских японской '),
    (Cost: 60; Words:
      'абайской аббаси аббревиатура абердин-ангусскую абов абу авеню авиационный авраамия австралийской австрия ' +
      'австро-венгрия автоматизации автомобилем авторами авторы агентство агрогородок адвокат ' +
      'административно-территориальное административно-территориальному административной администрацию адмирал ' +
      'адольф адольфа адонис адресу аженуа азербайджане азербайджанской азиатских аймака айылного академией ' +
      'академической академия аквитания аккад аккерман аккуш акмолинской аксай актера актеров активности активный ' +
      'актов аламо алб алгоритм александров алексея алеппо алма-ата алтай алфавита альбоме альбомом альфа альянса ' +
      'американское анализа анатольевич английская английском андлау андреевна андреем андрея анимации аниме анна ' +
      'аномалий анри ансамбля анто антон антропологии апостольский аппарат арабского арбитр ардханаришвара аренды ' +
      'арестован аристократ армию арт артиллерийских артур архиерей архипелаге ассамблеи астана астрономии ' +
      'астрономом асука атака атаки атланте атомов аудитории аутентификации африке аэропорт аэропорта аэрофлот ' +
      'бабаджи баку балет банк барона барселона барселоне баскетболист бассейне батальона бахрейна бежал бейсбола ' +
      'белая белгородской белорусская белорусского белорусской белый белых бен-ами берегах берегов береговой беркли ' +
      'берлин берлине берри берримор бесхвостых библиотеке библиотеки биг-бенд бизнеса билл бильбао бинарное ' +
      'биологии биологических биржа биржи битвы бластоцисты ближе близости блоков блюда блюдо богини богородицы ' +
      'боевик боевые божества боксер боксер-профессионал болгария болгарской болезни болезнь боливийский большевиков ' +
      'большей большинстве большом бори борис борислав борисович борту борьбу боснии бою боя браз брата братья ' +
      'бренда брестской бригадир британских британском бронзовые бсср буква буквально бур бутана бухта буэнос-айрес ' +
      'бхуты бывшей быстрее бюджет бюджета вадим важнейших важных вале валенсии валентин валерьевич валовой варианты ' +
      'варшава вашингтон введен ввиду вдвое ведении ведет великим великое великомихайловский величайших величества ' +
      'величине величины венгерский венгрия вене венеция вернуться версию верст верхнего верхние верховьях вершины ' +
      'веселая весов весовых весьма ветви взаимодействие взглядов видам видами видах видеоигра видом виду виктора ' +
      'викторович вин вингер вино виргиния виртуальной витебской вице-президент включающая включены владение ' +
      'владения владимировна властью влиятельных внесен внешней внешних внутренней вод воде водой водорода воевода ' +
      'воеводства военное военнослужащий военнослужащих военным возглавляет возглавляли воздушная возле возможности ' +
      'возможностью возник возникли возрождения воинское волгоград волгоградской волейболу волны волокон вольного ' +
      'вольтера воронеж ворот воспитанник воспоминаний восстание восстановлен восстановление восточного восточном ' +
      'восточный восточных восьмой вошло впадения вполне временного временный вселенная всемирной всеобщих ' +
      'всероссийского всесоюзной вская вступил вський вторжения вторую вход входящий выбран выдающиеся выделяют ' +
      'выиграв выиграла выполняет выпуска выпущенная выпущено выражение высокая высокого высокое высокой высоту ' +
      'выступавшая выступать выступила выступили выступить выступлений выступления высшая высший высших вытекает ' +
      'выходил выходит вышли вэньчан габала газете галактик галактики галерее галереи гало гамбург гвардейского ' +
      'гвардейской гвардия гвинеи гдр генерал-полковник генерального генеральным геннадий гео геолог георгиевич ' +
      'георгиевский георгия германская герои герстнер герцеговины герцог герцога герцогство гибели гирке главными ' +
      'главы глаза глазго глобус глюкозо глюкозы гмина годами голландский головой гомельская гонка гонках гораздо ' +
      'горах горе горная горного горной горный городище городке городская городу горы государственная ' +
      'государственном гравер гражданин гражданская гражданских гражданского границ граница границу грант график ' +
      'графом графства графство гребец гребле греков греция греческих гриб григорий григорьев группой грэмми гуго ' +
      'густав дагестана дагестанская далмации дальнего данного данное данном дано дантас дата датская двадцати ' +
      'двадцать двенадцати двигателей двигателем двигатель двойная двойной двора дворе дворца дворянин дворянского ' +
      'двукратная двукрылых дебют дебютировал дебютного дева девичестве девы девяти девятый действительно действиях ' +
      'действующая деккерс делегация делится демократической денежных дерево деревьев десяти десятилетий деталь ' +
      'детройт детский детства детство деятелей джамоата джаната дже джейкоб джеймса джерри джесси джим джованни ' +
      'джозеф джоном джонс джоши джузеппе диалект диалло диаметр дивизион дивизионе дизайн дизайна дизайнер дин ' +
      'динамо династия дипломатические директора директоров диска длинные длину дмитрия днепровский документальных ' +
      'документах документов домашних дометий дон дональд донецкой дону дончев дополнительные дорог дорогу дословно ' +
      'достигает достигла достижение доступа доступен дочерей драма драматический древнегреческий древнегреческой ' +
      'древней древние древний древних дрезден дрездене другую дружбы ду-сул дуги дух духовное духовной дуэт ' +
      'дхармашастры дэвид дэвида ева евгения евгеньевич евна евр еврейская еврейский еврейского еврейства европа ' +
      'египта единиц единоборств единого единственная единственной единство ежегодного ежегодный екатерина елена ' +
      'елизавета елизаветы епархия епископов ереван ермолинский жан жана жанейро жанр железная железнодорожного ' +
      'желтого желтый женат женой женский женских женское живописи живший живых жилой жители житомирской жуков ' +
      'журналиста журналистики журналистка журналом заведующий завершении завершения завершил завершился зависит ' +
      'заводе заводом завоевала завоевали задач задача заключается заключения закона законодательный закону законы ' +
      'закрытия зал залив залива заменен замены заместителем заместителя замуж занимается занимала занимали заняла ' +
      'заняли занятия западнее западного западном западный записей запись заповедник запуска захвата захватил ' +
      'защитить защиту звание звания звук звуков здравоохранения зеландии земель землю земноводных знаком знамени ' +
      'знаменитых знания значимых значительное значительной значительные значительный золота золото золотов золотую ' +
      'золотые золотых зона зоопарк ибн ибо ивано-франковской ивановна ивата игоревич играет играть играют игровой ' +
      'игроков идей избежать избирателей избранный известными издавался издан издана изданный издатель издательства ' +
      'издательством изменение изображен изображений изобретатель израиль изучал изучение изучения изящных икэя ' +
      'ильич илья имели имена имеются имеющий имеющих император императорский императорского императорской ' +
      'императору иначе индийского индонезии инициализации институте инструментов интеллекта интервью интересов ' +
      'интересы иоанн иоганн иран иране иркутской ирл исключен исключительно искусстве искусственного испанию ' +
      'испанская испанской исполнении исполнения исполнила исполнили исполнительница использовал использовалась ' +
      'использовали использовались использовалось использовании использоваться используемая используемый ' +
      'исследование исследованиях исследователей истока историей историка исторически исторические историческое ' +
      'историческом источник источники источников источником исэ итальянских иудаизм йский кабинет казани казань ' +
      'казахский казахского казахской казни календаре календарь календарю калининском каменского камень камеры камня ' +
      'кампания кан канадская канадской канале карате кардинал карелии каролина карпентер карт карте картине картину ' +
      'карты карьера карьере кастилия каталоге категорий категория катера кафедральным кафедре кафедрой кафедры ' +
      'квадратных квартале квартета квебек квентин кемеровской кент керлингистка киев киева киевская километров ' +
      'кинематографа кинофестиваля кирг киче кишинев кладбища классах классу клетки клеток климов клубов ключ князей ' +
      'князем коалиции когда-либо когозес кода кодекс кожа коз количестве количеством коллегии колледжа коллектив ' +
      'коллектива коллекции коллекция колорадо колумбии колумбия колчака кольцо командной командовал командующий ' +
      'комбината комедии комедия комиссар коммерческих коммун коммуникации коммутаторов компанию компаниями ' +
      'комплекта композитора композиции компьютерной компьютерных конгрегации конгресс конде конец конечном конкакаф ' +
      'конкурс конкурсе коннектикут консервативной консерватории консерватория константина константинович констанция ' +
      'консул контактов контролем контроля конференция конфликта концентрации концертный концертов концу кораблей ' +
      'корабли корбин коренных корни королевский королевстве короткой короткометражный космических космического ' +
      'космической космос косово костанайской кох кпсс крайне крайней красная красновидово краснодарского красные ' +
      'красоты кратер кратный крепости крещение кривой кризис кристиан критиками крови круг крупная крупнейшая ' +
      'крупнейшей крупного крупной крупные крупным крупными крыло крыму ктор кубков кульсум культуре культурной ' +
      'культурных куполом куруш кхмер-кром лаборатории лагранжа лазурный ларье латвийский латвия лахуд легких ледюк ' +
      'лена ленина ленинской леон леони леонид лесах лесом лесу либретто лиг лидделл лидера лидеров ликвидации ' +
      'линейный линий лиона липецкой листьями литератор литературного литературной литовский лицензии личном лодок ' +
      'ломбардия лонгфорд лондона лондонского лотарингия лотереи лоу луганской луис лучшее лучшим львов львове ' +
      'льевич льский льська любовь магазинов магазины майами майдана майкла майор майя македонии македонского макс ' +
      'макса максимальная максимович мали мало малое малые мальвазия мантии манчестер марийская марийской марки ' +
      'марсей мартин мартина маршрут масса массачусетс массив массовое массы математики материал материалы матерью ' +
      'машин медалей медицине медицинского медицины международном международные международными мексика мексиканский ' +
      'мелкие мелодрама мероприятия мертвого мертвый местность месторождение месторождения месту металла методов ' +
      'метрополитена механизм мехико меценат мечети мечеть мид микки мин минимум министерство министром минск ' +
      'минской минут минье мировая мировых мис мисс митрополит михаила михайловна мичиган мкм младшего млекопитающих ' +
      'мнению мнения многоборье многократный многолетнее многочисленными многочисленных мобильных мов мович моделей ' +
      'молдавии молекулы молодежная молодых монастыре монашестве монг монголии морем москву московский мощность ' +
      'мужская мужских мужского музеев музыкальная музыкального музыкальное музыке музыку мультипликационный ' +
      'мультфильм муниципалитете муниципальных мфа мыс мыса мэр мэра мюнхен наблюдается набор набором навигации ' +
      'награда награду награждена награждения надпись наездников назвал названиями назначения назначил называемая ' +
      'называемых называлась назывался называть называются наибольшее наименование найдены наката наконец нан ' +
      'нападающего написана написанный направлений напрямую народных насекомые населением населенного наследие ' +
      'наследство настолько настоящая насчитывает насчитывается насчитывалось наталья науке научного научное ' +
      'находились находилось находящихся наций национальности национальность национальным национальных начались ' +
      'начинающийся неба небольшая небольших невисокосный негативные независимо неизвестна неизвестны некоммерческая ' +
      'некоторым немецких немногих немного немцев немцы необходимости неоднократно неожиданно неподалеку нередко ' +
      'нефти нидерландах нидерландская нидерланды нидзе нижнего нижнее нижней нижний низким низовьях ний николаем ' +
      'николас нка нквд нобелевской нова новом новоселье новосибирской новости новотроевка новую новым новыми ног ' +
      'ногами номеров номинаций номинирован номинирована норвежский нортфилд носил носит ночь нумерации нфл ные оао ' +
      'обе обелиск обеспечение обеспечивает обитает обитания обитают обладает обладателем обладают облако областью ' +
      'обмена обнаружены обозначается обозначение оборудования образовании образованию образованная образовано ' +
      'образуют обращения обсерватория общем общественного общественное общественной общие общий общим общих объекта ' +
      'объектом объекты объявил объявила объявления обязанности оглы огня одежды одесса одесской одиночная одних ' +
      'одному озере озу оказалась оказались оказывает океане оккупации окленд окна околозвездный окончании окраине ' +
      'окружающей октябрьской оле олегович омской онтарио оон опалев операционная операционной описание описывает ' +
      'определения определенное определенной определяет опубликовал опубликован опубликована опубликовано ' +
      'опубликованы опус опыт органа организаторов организацией организациями организма органист орденами орегон ' +
      'оригинальный оркестра оркестром осадков освобождения осетинского османской основал основанное основанной ' +
      'основателем основателя основного основное основой основоположников основы особей особенностей особенности ' +
      'особо особой особый оставалась оставались оставить остальных остатки осуществляет отбора отборочном ' +
      'ответственности отдела отделения отделом отдельного отдельной отдельные отдельный отказался открытия открытой ' +
      'открытым отличаются отличия отметить отмечается отмечены относят отношение отношению отношениях отражает ' +
      'отставку отсутствие отсутствуют оттенки отцу официальной оценка оценки очков ошибок пабло падения пак палате ' +
      'палату палеонтолог палл памятников памятником панамериканских папой пара парагвайский паралимпийских паре ' +
      'парижской паркер парламент парламентские парламентских парсеков партией партизан партию пары паскарелла ' +
      'патриархата патрик пгт пекине пензенской пенсильвания первоначальное первыми перевод переводится переворота ' +
      'передан передачи переименован переменная пересекает переход перешла периоде перми песней петро петроград ' +
      'петросянц пехоты печати печать печени пещеры пике пиренеи писателем письма письменности питания план плана ' +
      'планировалось пластинка платформ платформе плей-офф племен племя племянник плен плотина по-видимому побед ' +
      'победил победителей победители победы поведения поверхность повествование повествует повесть повет поводу ' +
      'поворачивает повят погиб погибли погибших подводная подводных подготовке подготовки поддерживает поддержке ' +
      'поддержки поджи подземных подписал подписи подразделение подразделения подчинен подчинения поединка поединок ' +
      'поезда пожар позволило позволяют позднего позднем позицию показ показал показан покемон покинул поколение ' +
      'поколения полет политика политике политику политического полного полнометражный полномочный половина ' +
      'положении полтавская полтавской полуостров получают получив получивший получило пользователя пользу ' +
      'пользуются польских поля поляна помещении помощник помощь помпиньян понятие попал попель попо попов ' +
      'популярности популярность популярностью популярный попытки поражение пород порода породу порядке порядок ' +
      'посвятил посвящен посвященный посвященных поселке последним последних последовали последующие посмертно ' +
      'посола посоле посредством постановке постановлением постепенно постоянным построения построенная построенный ' +
      'построено построил постройки посту поступил потерял похода похожие почтовых поэма поэмы поэта поэтов ' +
      'появилась появилось появлением появления появляется появляются правах правая правды правил правила правителей ' +
      'правитель правителя правление правящей прага праге прагматизма превышает преданию предков предложений ' +
      'предложил предмет предметом предполагается предполагалось предприятий представителем представительства ' +
      'представление представляла предшествовал предыдущего предыдущих преемником прежнее президентских прелат ' +
      'премьер-лиги премьер-министра преподавал престола преступления префектуре префектуры привалово привел привела ' +
      'приводит приводится приднестровье приднестровья приз признание призы приказ приказал приказу приложений ' +
      'применения применяют принадлежал принадлежали принадлежащий принимавшее принимала принимали принимают принц ' +
      'принципу принят принять приобрела природный прирост присвоено притоков прихода причине пришлось прованс ' +
      'проведен проведение проведено провести программе программу продаж продажу продлен продолжает продолжал ' +
      'продолжения продукта продукты продукции проекты проживает прозвище произведениях производителей ' +
      'производительности производится производстве производственных произношение произошедшая произошел произошла ' +
      'происходил происходило прокате пролив промышленных пророка просвещения проспект противника противостояние ' +
      'протока протокол прототип протяженность профессором проходила проходят процессоров прочность прошло прошлого ' +
      'пскова птица публикации пункта пунктах пустыни путать путешествие пушкина пытался пьер пьетро пятна пятой ' +
      'раав работавший работами работах рабочего рабочей равновесия разведки развитием развитии разворачивается ' +
      'раздел разделена разделение различия различного различным размер размеров размеры разновидность разное ' +
      'разными разработан разработана разработка разработке разработчиков районы ранкина раннего раннее раннем ' +
      'ранние распада располагавшееся располагалась располагаются распространена распространения распространенный ' +
      'распространены распространяется рассказ рассказывает растительного ратных реакции реализации реальности ' +
      'реальных ребенка революционер регби регбист регионах регионов регулярно редактором реестр режим режима режиме ' +
      'резерва резко резолюции результатам результатов рейн рейсы рейтинг рекой религии религиозной религиозные ' +
      'религиозный религиозных релиз реон республиканской республикой республику ресторан референдум референдума ' +
      'речь решением решил рига римско-католической римского рио-де риу-гранди ричард ричарда робби рова рович ' +
      'ровненской родила родом родословной роду рок-группа ролон ролями ролях романе рославль россией российские ' +
      'российским российское рост ростовского ростовской рский руаири руд руины рук руки руководителей руководителем ' +
      'руководство румынский русло русским русское ручей рынка рынке рынок рэнди рэпера сада сайте саксаганский ' +
      'саксония сальви самарской самки самоа самок самолета самолетов самом самостоятельно самцов самые сан-паулу ' +
      'сан-франциско санкт-петербургского санкт-петербургской сантьяго сарду сахалин сбора сборнике сборных сведений ' +
      'сведения свердловская света свидетельствует свидригайло свободным свободу свободы своему связан связанные ' +
      'связаны связей связь святая священнослужитель северное северном северо-восток северо-восточнее седьмой сей ' +
      'сейма секретарем сектора сельских сельскохозяйственных семен семенович сената сербский сервер сергея серебро ' +
      'серебряную серебряные сержант сериале серого сестры сибири сиднее сиквел силу символ символов символом сирии ' +
      'системах системой сити ситуации ситуация сих сиэтл сказки скопления скородумки скорости скота скрещивания ' +
      'скульптор славян следствие следующих слишком слияния словакии словам словами словарь словацкий слову сложной ' +
      'сложных слой служба службу служит случаев случай сменил смерть смешанных сми смит смита смогли снг снизу ' +
      'собором собрании собраний собственно собственности собственную собственные собственный собственных событиях ' +
      'сов совершил совете советов советское советском совместное совместной совокупность современников содержания ' +
      'содержат содружества соединений соединения соединенного соединяет создали создании созданных создано ' +
      'создателем создатель создать созывов сокр сокращенно солнечной сольный сон сообщения сооружения соотношение ' +
      'соседних составил составили составило составлял составляли состоял состояла состояло состоялось состояние ' +
      'состоянии состоящая состоящий сотрудников сотрудничества сотрудничестве софья сохранения сохранить ' +
      'сохраняется социалистической социального социальный социологии сочи сочинения союзе специализирующаяся ' +
      'специалисты специального специальной специальные специальных списание списка спора спортивная спортивного ' +
      'спортивной спортивные спортивных спортсмен спортсменка спортсменов спортсмены способен способность способом ' +
      'справедливости спущен сражения средневекового среднее средние средний средних средствами ссылки ставшая ' +
      'стадии стадия сталин сталина стамбул стандарта стандартов стандарты станет станислав становится станций ' +
      'станциями старейших старого старт старшего старшей старшим старшина старших статей статский статусе статье ' +
      'ствола стены степан стивен стилем стихи стокгольм столицей сторон сторонник сторонниками страной страну ' +
      'стратегии стрелковая стрелок стремится строчку структура структуры студенческий студией студийного студийных ' +
      'стэнли субрегион суворова судна судов сумме сумская сумской супермена супруга сути суток существенно ' +
      'существовавшее существование сфере сформирована схема сценарию сцене сцены считалась считалось считать ' +
      'считают съемки сыграли сыновей сыновья сюжета тадж таджикистана таиланде тайный такими такт тамбовской тан ' +
      'тандыр-нана танец тани танк танка татарстана татьяна ташкент тбилиси тва творчества театральная театре тексты ' +
      'тел телеведущая телеведущий телевидении телеканал телесериале телескопа телефильм тело тель теме температуры ' +
      'темы теннесси теннисист теннисного теннисный теоретик теорию термометров термоприбор территориях техаса ' +
      'технического технология тигренок тираж титула титулярная тихого тич тобаго товаров толедо томаса томос тонн ' +
      'топ торговли торговый торонто точке точно траве трагедии традиционной традиционный транспорт трассе ' +
      'трассировка требований третье третьем третьим третью треугольник тридцать триевич триллер тропических трудов ' +
      'трудовой труды туманган туре туризма туркм туркменистана турцией турция тысячелетия тюрингия тяжелом тяжелый ' +
      'уайт убийца убит увеличение углерода удмуртии удостоен уезде узб узбекистана узбекский узла узлов узлы ' +
      'уильямом указом укреплений улиц улучшение умерла унаследовал университетов управлении управляет управлять ' +
      'управляющий упразднена упраздненное урала урочище уругвайский усадьба условий услуг услуги успеха установить ' +
      'установка установлена установлены установок устройств устройство уступил устьем утверждает утвержден ' +
      'участвовала участвовало участвует участию участке участки участника участок учебных ученик учеников ученые ' +
      'ученых учетных учетом учился учреждение учреждений факультет факультета фантастики фантастический фарс фатьма ' +
      'фауны федерация федора федоровна фестивале фигура фигурист физико-математических физических физическое ' +
      'филантроп филиал филипп филиппа филиппин филологических фильмом финала финальный финансов финансовой ' +
      'финансовых финская финский финской фирмой фирмы фифа флора флоренции флот флотилии фонд фоне форе форм ' +
      'формально формате формирование формой формула фортепиано фотограф фотографии фраза франжоли франкенштейн ' +
      'франкенштейна франс франсуа франц французских французском фрг фрегезия фрейман фридриха фронте функций ' +
      'функционер футбол футбола футбольных хакка халецкий хан характеризуется характерны харьковской хаэн хвост ' +
      'хельсинки херсонской химии химик химических хинди хип-хоп хит-параде хмельницкого ход хоккейной хорватия ' +
      'храма хранения хранится художеств художественной художественных художница хьюстон царство царь цвет цветов ' +
      'цветом цели цель целях центральная центральном центру церковной церковью ции цикла цин цусима цыган чана ' +
      'чарльз чарльза часовня частицы частями человеком челябинской чемодан черкасской черная черного черной черный ' +
      'черных четверти четвертого четырехкратный четырьмя чехов чехова чехословакия чеченской чешской чилийский чису ' +
      'членами чрезвычайный чув чуть шампань шаранта шасси шведская шведского швейцария шекспира шестой широкое ' +
      'широкой широком школ школу шлема шоссейный шотландского штаба штатах штурмовой эберштейн эгидой эдвард эдуард ' +
      'экипажа экологии экономического экране экраны экспедиции экспедиция экспериментов эксперт электронной элемент ' +
      'элемента элементами элементов элизабет эльзас эмили эмилия эндрю энергетики энергии энтони энциклопедии ' +
      'эпизод эпизодов эрик эссеист эстонский этап этапа этапах этапе этапов эфиопии эффектов юго-восток юго-запад ' +
      'юго-западнее югов южноафриканский южное южнокорейский южных юлианскому юнеско юниоров юридических юрия ' +
      'юрьевич юстиции явлений являлись являющаяся являющегося языковой японского ярослав яшково '),
    (Cost: 64; Words:
      'авиационного австрийская австрийского агар агостино адмирала азан азия акватории активистка альберта альбомы ' +
      'андерсон аномалии антонович ареал арена ареной армий артура археолог архитектурный астероида афинская ' +
      'бархатную баскетбольный белка бильтин бланко бойцов борьба бразильская бронзу буддийский валенти варианта ' +
      'васхнил введена ведущей веках верховный взвода виллануэва вина винограда влиятельным влчек внимания ' +
      'внутренний военными воздуха возможностей возникает волейбольный вонг вооружении восточное восьмая врача ' +
      'вращения всесоюзного вслед входа выделены выполнении выполняется выпускается выступали выступлениям ' +
      'вычислительной вышедшая выяснилось вьет вьетнама вязьма галактике гемоглобина географических герба герман ' +
      'германский гиг гипотезы главном глаз голова гонки горсовета гражданский границах графику греческие губерний ' +
      'даг дагестан датируются датой двоюродный действовать деле демократического дер дерева десятки десятков ' +
      'деятельностью деятеля джей джейн джонни димопулос диско длинным домашние достопримечательностей доцент дрю ' +
      'дурновка дяди дядя еж евдокимовка единственном единый жак железнодорожник железнодорожный железную женском ' +
      'живших житель жития жорж забегов заведующая зайбт заключении западнорусской записал записан заслуженная зимон ' +
      'знака знаменитого зоолог ибраима играла игроком идиш известное изгнание издается изданиях изменением ' +
      'изображением икс инструмент информационные иосиф ирина историков источникам иудаизма йович йра йская ' +
      'кавалерии кавалерийская казначейство канцелярии капеллы кауфман кевин кейп-фир кеолред керлингу кинематограф ' +
      'кинопродюсер киримизе кислота классицизма клерк кодовое колеблется коллинз командиром комитетом коммутатор ' +
      'конституции конструкции конструкций консу концерта королева космический кратная крупнейшего крымскотатарский ' +
      'культуру курган кутузова кухни кызы ларионов ленинграда лесные лесов летнего летописи ливии лидеры лиссабон ' +
      'литература личности лодки лошадей лусио львова львович льевна любой людвиг мавритания мадонны мак македония ' +
      'максимилиан мар маркиз марокко мастерской математической медалями медик менеджмента мертвых механики мика ' +
      'миллион миллиона мировые миссии митрополитом михайлов миш многократная многом моделирование молдавской ' +
      'моллюсков молодежного моряк моусон музыковед мустафа мяса названии названный называемой накануне насакино ' +
      'насчитывало натрия национальное начальника наших неаполь небе небольшом невский недель недолго независимой ' +
      'независимых некоммерческой немецким немецком несет низкой никольский нила новгород новна ночной нынешнее ' +
      'обвинения обоих оболочка оборонительная оборону образцом обращение общественности общественные общественных ' +
      'обществом объявлено океании октябрьского олимпиад олимпиаде оператор ополчения определенную оптимизации ' +
      'орбитальный организме оси осталось островами отделение отдыха открытие открытых отложениях отмечает ' +
      'отношениям отправился отправлен отряд отставке отсутствия официальное оценивается памятника параллельно ' +
      'парных пере передовик перенесен перечислены периодом петровича питание плане пловец победила погореловское ' +
      'подвида поддержали подобная подробно подсемейство подтверждения поездами поездов полков полномочия половину ' +
      'полуострове помещениях популярен популярного портретист посвящена поселился последовательности поста ' +
      'поставленный построены появление правнук правовед предприятием предприятия прежних президентские президиума ' +
      'прибыл примером принадлежность присвоен проводила проводящегося продается продажи продолжил проживали ' +
      'проживающие проживающий проиграл проиграла произошедшее происходящее пространстве протяженностью ' +
      'профессиональных профессора процессом процессы пруссия птицы пунктом работающие развивается разделены ' +
      'размером разрешения разу разыграно ралли располагался расположенного рафах реальном ред резня рейн-вестфалия ' +
      'религиозного религия риги рисованный рная рогозиниха роды рок россман ростов-на росту роты рудава руссо ' +
      'рязанский сай сантос сахненко сборников свободный северных сезоном сейдж сельская сельскохозяйственного ' +
      'сигналов симон симона симонов синглов ско скопление следующего слога слонский служат смоленская снял собрал ' +
      'собственной сове советским совместимости соглашение создается созданное солдатских сорта составленный ' +
      'сохранение срока ставропольского ставшей станцией староста стартовал стен стивена стихотворения стоддарт ' +
      'сторонников строение строить судьба суркис считает таблице таблицы таджикский тамбовская татарская тейт ' +
      'температуре тенденцией теннисистка теория термина тигра типу титулов тойнби томай томов топонимов торговые ' +
      'точек травянистое трамвай транзитивное трасса требует трудах туризм угрозой удается узбекистан украину ' +
      'университетом употребление урожд урожденной установления участником учреждения ушел феодосий физике филолог ' +
      'фирма фондов фонтан фредерик фридрихом фрэнк функция футуна фэнтези хаббард ханты-мансийского характеризует ' +
      'харли хирург хозяйством христианин хунты центральных центры цепи цифровой чартах чемпионкой чемпионство ' +
      'черно-белый чечено-ингушская численности числом чтения чувашской шахматный шин шириной широкие широкий ' +
      'широкую широты шотландия штаты штутгарт шушпанка экзопланета экстаз эмануэль эмиль эмиха эрнест эх юго-восточная ' +
      'юго-восточнее юлия юнайтед явление явно яков яхтсмен ')
  );

var
  GEnglishWords: TDictionary<string, Integer>;
  GRussianWords: TDictionary<string, Integer>;

function LoadTiers(const ATiers: array of TWordTier): TDictionary<string, Integer>;
var
  Tier: TWordTier;
  Word: string;
begin
  Result := TDictionary<string, Integer>.Create;
  for Tier in ATiers do
    for Word in Tier.Words.Split([' '], TStringSplitOptions.ExcludeEmpty) do
      Result.AddOrSetValue(Word, Tier.Cost);
end;

function WordCost(const ALower: string; ALang: TLangKind): Integer;
begin
  if ALang = lkEN then
  begin
    if not GEnglishWords.TryGetValue(ALower, Result) then
      Result := -1;
  end
  else if not GRussianWords.TryGetValue(ALower.Replace('ё', 'е'), Result) then
    Result := -1;
end;

function HasWordWithPrefix(const ALower: string; ALang: TLangKind): Boolean;
var
  Words: TDictionary<string, Integer>;
  Prefix, Word: string;
begin
  if ALang = lkEN then
  begin
    Words := GEnglishWords;
    Prefix := ALower;
  end
  else
  begin
    Words := GRussianWords;
    Prefix := ALower.Replace('ё', 'е');
  end;
  for Word in Words.Keys do
    if Word.StartsWith(Prefix) then
      Exit(True);
  Result := False;
end;

initialization
  GEnglishWords := LoadTiers(EnglishTiers);
  GRussianWords := LoadTiers(RussianTiers);

finalization
  GEnglishWords.Free;
  GRussianWords.Free;

end.
