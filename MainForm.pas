unit MainForm;

{ Drag racing tree reaction time trainer.

  A run:
    START  -> both cars roll up to the beams. The pre-stage bulb lights when
              the front tyre breaks the pre-stage beam, the stage bulb when it
              breaks the stage beam (7 in further on).
           -> once both lanes are staged and you are holding the car (on the
              brake with an automatic, clutch in with a manual), a random wait
              (0.8 to 3.0 s)
           -> countdown:
                Pro tree:       all three ambers together, green 0.400 s later
                Sportsman tree: ambers one after another 0.500 s apart,
                                green 0.500 s after the last amber
  You launch by letting the car go: release the brake (automatic gearbox) or
  drop the clutch (manual gearbox). Never more than two pedals at once, like
  two feet.
  Reaction time = release time - time the green is due.
  0.000 is a perfect light; anything below zero is a red light.

  Pedals are on-screen pads used with several fingers at once:
    BRAKE    always. Hold to stop, ease off to creep (manual staging).
    CLUTCH   with a manual gearbox. Hold it in whenever the car is stopped:
             on the brake with the clutch out the engine stalls. Once staged
             with the clutch in, the brake can come off so the right foot can
             go to the throttle; dropping the clutch is the launch. Dropping
             it with the brake on or no throttle stalls.
    THROTTLE with manual throttle. Hold for full revs (the pad shows the
             rpm); launching without it bogs an automatic.
  Without multi-touch (a mouse on Windows) only the brake is used. On Windows
  the space bar is also the brake.

  Rolling right through the stage beam is "too far forward" and ends the run.

  After the launch both cars run down the track. CarSim.pas works out each
  car's run from its power, weight, gearing and tyres, the track surface and
  (for your car) the throttle pad. The first car to the finish line wins:
  reaction time + elapsed time. A red light loses. The car, race length
  (1/8 mile, 1000 ft, 1/4 mile), track (prepped, dry street, wet) and units
  are on the Settings screen; the Car screen picks a preset and changes it.
  The computer car in the other lane drives the same car as you. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Diagnostics, System.Generics.Collections, System.IOUtils,
  System.IniFiles,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Objects, FMX.StdCtrls,
  FMX.Layouts, FMX.Controls.Presentation,
  CarSim;

const
  ProAmberMs: Double = 400.0;   // Pro tree: ambers to green
  SportAmberMs: Double = 500.0; // Sportsman tree: gap between each amber and green
  AutoStartMinMs = 800;     // random wait after both lanes are staged
  AutoStartRandMs = 2200;
  HistoryLines = 12;        // runs shown, two lines each

  // engine, for the rev bar and stalling (manual gearbox)
  IdleRpm: Double = 900.0;
  RevUpRate: Double = 14000.0;    // rpm per second, throttle held
  RevDownRate: Double = 9000.0;   // rpm per second, throttle off
  StallGraceMs = 500;             // brake on, clutch out this long = stall

  // Staging geometry in inches, measured from the pre-stage beam to the
  // leading edge of the front tyre. Positive is forward.
  StageBeamIn: Double = 7.0;    // stage beam is 7 in past the pre-stage beam
  PreStageOffIn: Double = 11.0; // deep staging: pre-stage bulb goes out
  TooFarIn: Double = 16.0;      // tyre has rolled right through the stage beam
  AutoStageIn: Double = 8.5;    // where auto staging stops (shallow stage)
  CarStartIn: Double = -40.0;

type
  TTreeMode = (tmPro, tmSportsman);
  TStageMode = (smAuto, smManual);
  TTransMode = (trAuto, trManual);
  TThrottleMode = (thAuto, thManual);
  TTreePhase = (tpIdle, tpStaging, tpWaiting, tpCountdown, tpGreen);
  TPedal = (pdClutch, pdBrake, pdThrottle);
  TPedals = set of TPedal;
  TSetting = (stTree, stLane, stStaging, stTrans, stThrottle, stCar,
    stLength, stSurface, stUnits);
  TOutcome = (ocNone, ocWin, ocLoss, ocTie);
  // what the Car screen's - / + buttons change
  TCarField = (cfPreset, cfPower, cfWeight, cfGears, cfFinal, cfShift, cfLaunch);
  // and its tap-to-change buttons
  TCarCycle = (ccDrive, ccEngine, ccTyres);

  TRunResult = record
    ReactionMs: Double;
    Foul: Boolean;
    BeforeTree: Boolean;   // left before the countdown had even started
    Bogged: Boolean;       // launched with the throttle closed
    Mode: TTreeMode;
    Finished: Boolean;     // reached the finish line
    ET: Double;            // s
    TrapSpeed: Double;     // m/s
    OppReactionMs: Double;
    OppET: Double;
    Outcome: TOutcome;
  end;

  TCar = record
    Pos: Double;           // inches, see the geometry constants above
    Launched: Boolean;
    RollAtMs: Double;      // opponent only: when it starts rolling in
    LaunchAtMs: Double;    // opponent only: when it will leave
    LaunchPos: Double;     // where it was when it left, inches
    RunStartMs: Double;    // when it left
  end;

  // A plain coloured button. The stock FMX button style looks greyed out
  // (disabled) on Android against the dark background, so the app draws its
  // own: a rounded rectangle with a centred white label, darker while pressed.
  // It looks the same on every platform and never takes keyboard focus.
  TTapButton = class(TRectangle)
  private
    FLabel: TLabel;
    FColor: TAlphaColor;
    FDown: Boolean;
    function GetText: string;
    procedure SetText(const Value: string);
    procedure SetColor(const Value: TAlphaColor);
    procedure UpdateFill;
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Single); override;
    procedure DoMouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Text: string read GetText write SetText;
    property Color: TAlphaColor read FColor write SetColor;
  end;

  TfrmMain = class(TForm)
    layTop: TLayout;
    lblReaction: TLabel;
    lblVerdict: TLabel;
    lblStats: TLabel;
    layOptions: TLayout;
    lblSummary: TLabel;
    layMiddle: TLayout;
    pbTree: TPaintBox;
    rectHistory: TRectangle;
    lblHistoryTitle: TLabel;
    lblHistory: TLabel;
    layPedals: TLayout;
    lblHint: TLabel;
    layPads: TLayout;
    layButtons: TLayout;
    tmrTree: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FitDesktopWindow;
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar;
      Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar;
      Shift: TShiftState);
    procedure FormTouch(Sender: TObject; const Touches: TTouches;
      const Action: TTouchAction);
    procedure pbTreePaint(Sender: TObject; Canvas: TCanvas);
    procedure tmrTreeTimer(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnResetClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure layButtonsResize(Sender: TObject);
    procedure layPadsResize(Sender: TObject);
  private
    FWatch: TStopwatch;
    FLastTickMs: Double;
    FTreeMode: TTreeMode;
    FStageMode: TStageMode;
    FTransMode: TTransMode;
    FThrottleMode: TThrottleMode;
    FUserLane: Integer;          // 0 = left, 1 = right
    FMultiTouch: Boolean;        // false: brake only
    FPhase: TTreePhase;
    FRunning: Boolean;
    FCountdownMs: Double;        // when the first amber lights
    FCars: array[0..1] of TCar;  // indexed by lane
    FRedLit: Boolean;            // red bulb in the user's lane
    FUserLaunched: Boolean;
    FBogged: Boolean;
    FRpm: Double;                // engine speed shown on the throttle pad
    FStallSinceMs: Double;       // manual gearbox: brake on, clutch out since
    FRevFill: TRectangle;        // rev bar inside the throttle pad
    FRevTimer: TTimer;           // runs the rev bar all the time, not just
    FRevLastMs: Double;          //   while the tree timer is going
    FEngineOn: Boolean;          // false after a stall until the next run
    FResults: TList<TRunResult>;

    // pedals
    FPads: array[TPedal] of TRectangle;
    FPadLabels: array[TPedal] of TLabel;
    FPressed: TPedals;           // what the car sees
    FTouchPedals: TPedals;       // from multi-touch
    FMousePedals: TPedals;       // from the mouse (or the primary finger)
    FKeyPedals: TPedals;         // from the keyboard
    FTouchSeen: Boolean;         // real touch events arrive: ignore the mouse
    FPendingUp: Boolean;         // one of several fingers lifted, see FormTouch
    FPendingUpMs: Double;
    FPendingUnder: TPedals;      // pedals under the fingers listed at that lift

    // buttons (made in code, see TTapButton)
    btnSettings: TTapButton;
    btnStart: TTapButton;
    btnStop: TTapButton;
    btnReset: TTapButton;
    btnClear: TTapButton;

    // settings screen
    FSettingsPanel: TRectangle;
    FSettingButtons: array[TSetting] of TTapButton;

    // the car and the race
    FCar: TCarSpec;              // the car both lanes drive
    FCarPreset: Integer;         // the preset it started from
    FRaceLength: TRaceLength;
    FSurface: TSurface;
    FImperial: Boolean;          // hp, lb, mph instead of kW, kg, km/h
    FRuns: array[0..1] of TCarRun; // each lane's run down the track
    FResultIdx: Integer;         // FResults entry of this run, -1 for none
    FRaceDone: Boolean;
    FWinLane: Integer;           // -1 none yet, 0 / 1 the lane, 2 a tie

    // car screen
    FCarPanel: TRectangle;
    FCarValues: array[TCarField] of TLabel;
    FCarCycles: array[TCarCycle] of TTapButton;
    FCarEstimate: TLabel;
    FRepeatTimer: TTimer;        // - / + held down: keep changing
    FRepeatTag: Integer;

    // time slip
    FSlipPanel: TRectangle;
    FSlipBox: TRectangle;

    // Android system bars (status bar, navigation bar), see ApplySystemInsets
    FInsetTimer: TTimer;
    FInsetTries: Integer;

    function NowMs: Double;
    function GreenDueMs: Double;
    function OppLane: Integer;
    function PreStageLit(Lane: Integer): Boolean;
    function StageLit(Lane: Integer): Boolean;
    function AmberLit(Index: Integer; T: Double): Boolean;
    function GreenLit(Lane: Integer; T: Double): Boolean;
    function EffTrans: TTransMode;
    function EffThrottle: TThrottleMode;
    function PedalUsed(P: TPedal): Boolean;
    function CarHeld(const S: TPedals): Boolean;
    function CarReady(const S: TPedals): Boolean;
    function ThrottleOpen: Boolean;
    function PedalsAt(const Touches: TTouches): TPedals;
    procedure StyleLabel(L: TLabel; Size: Single; Color: TAlphaColor;
      Bold: Boolean; Align: TTextAlign);
    procedure ApplyLook;
    function MakeButton(AParent: TFmxObject; const AText: string;
      AColor: TAlphaColor; AOnClick: TNotifyEvent): TTapButton;
    procedure CreateButtons;
    procedure CreatePads;
    procedure CreateSettingsPanel;
    procedure SettingButtonClick(Sender: TObject);
    procedure SettingsDoneClick(Sender: TObject);
    procedure UpdateSettingsTexts;
    function CarTitle: string;
    function PowerText(KW: Double): string;
    function WeightText(Kg: Double): string;
    function SpeedText(Ms: Double): string;
    procedure CreateCarPanel;
    procedure UpdateCarTexts;
    procedure ChangeCarField(F: TCarField; Dir: Integer);
    procedure CarStepDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure CarStepUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure CarStepLeave(Sender: TObject);
    procedure RepeatTimerTick(Sender: TObject);
    procedure CarCycleClick(Sender: TObject);
    procedure CarDoneClick(Sender: TObject);
    procedure CreateSlipPanel;
    procedure ShowSlip(const R: TRunResult; const Verdict: string;
      VerdictColor: TAlphaColor);
    procedure SlipDoneClick(Sender: TObject);
    procedure FinishRace;
    procedure PadMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure PadMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure PadMouseLeave(Sender: TObject);
    procedure PedalsChanged(T: Double);
    procedure UpdatePads;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure ResetTree;
    procedure StartRun;
    procedure StopRun(const Msg: string);
    procedure MoveCars(T, Dt: Double);
    procedure Launch(ReleaseMs: Double);
    procedure Stall(const Why: string);
    procedure UpdateRevs(Dt: Double);
    procedure RevTimerTick(Sender: TObject);
    procedure ShowResult(const R: TRunResult);
    procedure SetVerdict(const Text: string; Color: TAlphaColor);
    procedure UpdateHint;
    procedure UpdateStats;
    procedure ApplySystemInsets;
    procedure InsetTimerTick(Sender: TObject);
    procedure FormResized(Sender: TObject);
  end;

var
  frmMain: TfrmMain;

implementation

{$IFDEF ANDROID}
uses
  Androidapi.JNIBridge, Androidapi.JNI.JavaTypes,
  Androidapi.JNI.GraphicsContentViewText, Androidapi.Helpers,
  FMX.Platform;
{$ENDIF}

{$R *.fmx}

{$IFDEF ANDROID}
// Just the few Java methods needed to read the system bar sizes. Declared
// here so they don't depend on which Android API level Delphi's own
// headers cover. getRootWindowInsets is API 23+, the app's minimum is 24.
type
  JDTWindowInsetsClass = interface(JObjectClass)
    ['{6B0C2D7E-3F4A-4E8B-9C21-5A7D8E9F0B13}']
  end;

  [JavaSignature('android/view/WindowInsets')]
  JDTWindowInsets = interface(JObject)
    ['{8E2F4A61-7B3C-4D9E-A1F5-2C6B8D0E4F27}']
    function getSystemWindowInsetTop: Integer; cdecl;
    function getSystemWindowInsetBottom: Integer; cdecl;
  end;
  TJDTWindowInsets = class(TJavaGenericImport<JDTWindowInsetsClass, JDTWindowInsets>) end;

  JDTViewClass = interface(JObjectClass)
    ['{3A9D5E72-1C4B-4F6A-B8E3-7D2F0A5C9E41}']
  end;

  [JavaSignature('android/view/View')]
  JDTView = interface(JObject)
    ['{C47E1B95-2D8A-4E3F-9B6C-0F5A3D7E8B62}']
    function getRootWindowInsets: JDTWindowInsets; cdecl;
    function getHeight: Integer; cdecl;
  end;
  TJDTView = class(TJavaGenericImport<JDTViewClass, JDTView>) end;
{$ENDIF}

const
  clrBackground = TAlphaColor($FF121212);
  clrPanel      = TAlphaColor($FF1E1E1E);
  clrHousing    = TAlphaColor($FF262626);
  clrRim        = TAlphaColor($FF050505);
  clrTrack      = TAlphaColor($FF3A3A3A);
  clrStage      = TAlphaColor($FFFFF4C8);
  clrAmber      = TAlphaColor($FFFFB000);
  clrGreen      = TAlphaColor($FF19FF4A);
  clrRed        = TAlphaColor($FFFF2424);
  clrYou        = TAlphaColor($FF3DA5FF);
  clrOpponent   = TAlphaColor($FFB0B0B0);
  clrText       = TAlphaColor($FFF0F0F0);
  clrSubtle     = TAlphaColor($FF9A9A9A);
  clrPadIdle    = TAlphaColor($FF2C2C2C);

  // button colours
  clrBtnStart    = TAlphaColor($FF2E7D32); // green
  clrBtnStop     = TAlphaColor($FFC62828); // red
  clrBtnReset    = TAlphaColor($FFEF6C00); // orange
  clrBtnClear    = TAlphaColor($FF546E7A); // slate
  clrBtnSettings = TAlphaColor($FF1565C0); // blue
  clrBtnOption   = TAlphaColor($FF37474F); // settings rows

  PedalColors: array[TPedal] of TAlphaColor =
    (TAlphaColor($FF3D7BFF), TAlphaColor($FFE53935), TAlphaColor($FF2EBD4E));
  PedalNames: array[TPedal] of string = ('CLUTCH', 'BRAKE', 'THROTTLE');

  LaneNames: array[0..1] of string = ('Left', 'Right');
  TreeNames: array[TTreeMode] of string = ('Pro', 'Sportsman');
  StageNames: array[TStageMode] of string = ('Auto', 'Manual');
  TransNames: array[TTransMode] of string = ('Auto', 'Manual');
  ThrottleNames: array[TThrottleMode] of string = ('Auto', 'Manual');

{$IFDEF MSWINDOWS}
const
  SM_MAXIMUMTOUCHES = 95;

function GetSystemMetrics(nIndex: Integer): Integer; stdcall;
  external 'user32.dll' name 'GetSystemMetrics';
{$ENDIF}

function HasMultiTouch: Boolean;
begin
{$IF DEFINED(ANDROID) or DEFINED(IOS)}
  Result := True;
{$ELSEIF DEFINED(MSWINDOWS)}
  // a touch screen that reports two or more touch points
  Result := GetSystemMetrics(SM_MAXIMUMTOUCHES) >= 2;
{$ELSE}
  Result := False;
{$ENDIF}
end;

function FormatSecs(Ms: Double): string;
begin
  Result := Format('%.3f', [Ms / 1000], TFormatSettings.Invariant);
end;

function FormatET(S: Double): string;
begin
  Result := Format('%.3f', [S], TFormatSettings.Invariant);
end;

function IniFloat(Ini: TMemIniFile; const Section, Key: string;
  Def: Double): Double;
begin
  // always with a full stop, whatever the phone's language
  Result := StrToFloatDef(Ini.ReadString(Section, Key, ''), Def,
    TFormatSettings.Invariant);
end;

procedure IniWriteFloat(Ini: TMemIniFile; const Section, Key: string;
  Value: Double);
begin
  Ini.WriteString(Section, Key, FloatToStr(Value, TFormatSettings.Invariant));
end;

function DimColor(C: TAlphaColor; F: Single): TAlphaColor;
var
  R: TAlphaColorRec;
begin
  R := TAlphaColorRec(C);
  R.R := Round(R.R * F);
  R.G := Round(R.G * F);
  R.B := Round(R.B * F);
  Result := R.Color;
end;

function SettingsFile: string;
var
  Dir: string;
begin
  // Windows: %APPDATA%\DragTree. Phones: the app's private documents folder.
  // TPath is qualified because FMX.Objects also declares a TPath (a shape).
{$IFDEF MSWINDOWS}
  Dir := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetHomePath, 'DragTree');
{$ELSE}
  Dir := System.IOUtils.TPath.GetDocumentsPath;
{$ENDIF}
  Result := '';
  if (Dir <> '') and ForceDirectories(Dir) then
    Result := System.IOUtils.TPath.Combine(Dir, 'DragTree.ini');
end;

{ TTapButton }

function Darker(C: TAlphaColor): TAlphaColor;
var
  R: TAlphaColorRec;
begin
  R := TAlphaColorRec(C);
  R.R := R.R * 7 div 10;
  R.G := R.G * 7 div 10;
  R.B := R.B * 7 div 10;
  Result := TAlphaColor(R);
end;

constructor TTapButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  XRadius := 10;
  YRadius := 10;
  Stroke.Kind := TBrushKind.None;
  Fill.Kind := TBrushKind.Solid;
  HitTest := True;
  FColor := TAlphaColor($FF555555);
  UpdateFill;

  FLabel := TLabel.Create(Self);
  FLabel.Parent := Self;
  FLabel.Stored := False;
  FLabel.Align := TAlignLayout.Client;
  FLabel.Margins.Left := 4;
  FLabel.Margins.Right := 4;
  FLabel.HitTest := False;
  FLabel.WordWrap := True;
  FLabel.StyledSettings := FLabel.StyledSettings - [TStyledSetting.Size,
    TStyledSetting.FontColor, TStyledSetting.Style];
  FLabel.TextSettings.Font.Size := 15;
  FLabel.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLabel.TextSettings.FontColor := TAlphaColors.White;
  FLabel.TextSettings.HorzAlign := TTextAlign.Center;
  FLabel.TextSettings.VertAlign := TTextAlign.Center;
end;

function TTapButton.GetText: string;
begin
  Result := FLabel.Text;
end;

procedure TTapButton.SetText(const Value: string);
begin
  FLabel.Text := Value;
end;

procedure TTapButton.SetColor(const Value: TAlphaColor);
begin
  FColor := Value;
  UpdateFill;
end;

procedure TTapButton.UpdateFill;
begin
  if FDown then
    Fill.Color := Darker(FColor)
  else
    Fill.Color := FColor;
end;

procedure TTapButton.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Single);
begin
  FDown := True;
  UpdateFill;
  inherited;
end;

procedure TTapButton.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Single);
begin
  FDown := False;
  UpdateFill;
  inherited; // fires OnClick
end;

procedure TTapButton.DoMouseLeave;
begin
  FDown := False;
  UpdateFill;
  inherited;
end;

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Randomize;
  FResults := TList<TRunResult>.Create;
  FRuns[0] := TCarRun.Create;
  FRuns[1] := TCarRun.Create;
  FResultIdx := -1;
  FWinLane := -1;
  FWatch := TStopwatch.StartNew;
  FMultiTouch := HasMultiTouch;
  FitDesktopWindow;
  LoadSettings;
  CreateButtons;
  ApplyLook;
  CreatePads;
  FEngineOn := True;
  FRevLastMs := NowMs;
  FRevTimer := TTimer.Create(Self);
  FRevTimer.Interval := 30;
  FRevTimer.OnTimer := RevTimerTick;
  FRevTimer.Enabled := True;
  CreateSettingsPanel;
  CreateCarPanel;
  CreateSlipPanel;
  FRepeatTimer := TTimer.Create(Self);
  FRepeatTimer.Enabled := False;
  FRepeatTimer.OnTimer := RepeatTimerTick;
  ResetTree;
  UpdateStats;
{$IFDEF ANDROID}
  // The window isn't on screen yet, so the bar sizes aren't known. Try a
  // few times shortly after start, and again whenever the form resizes
  // (rotation, switching between gesture and 3-button navigation).
  OnResize := FormResized;
  FInsetTimer := TTimer.Create(Self);
  FInsetTimer.Interval := 150;
  FInsetTimer.OnTimer := InsetTimerTick;
  FInsetTimer.Enabled := True;
{$ENDIF}
end;

procedure TfrmMain.InsetTimerTick(Sender: TObject);
begin
  ApplySystemInsets;
  Inc(FInsetTries);
  if FInsetTries >= 20 then // about 3 seconds
    FInsetTimer.Enabled := False;
end;

procedure TfrmMain.FormResized(Sender: TObject);
begin
  ApplySystemInsets;
end;

procedure TfrmMain.ApplySystemInsets;
{$IFDEF ANDROID}
var
  Decor: JDTView;
  Insets: JDTWindowInsets;
  ScreenSvc: IFMXScreenService;
  Scale, DecorH, FormH, Gap, TopIn, BotIn, Covered, PadTop, PadBot: Single;
{$ENDIF}
begin
{$IFDEF ANDROID}
  // Android 15+ with targetSdk 35 or more always draws the app edge to edge:
  // the app runs under the status bar and the navigation bar. Pad the form
  // by however much of those bars actually lie over it. Delphi may already
  // keep the form below the status bar, so work out what is covered from
  // the gap between the window and the form rather than padding blindly.
  try
    Decor := TJDTView.Wrap(
      (TAndroidHelper.Activity.getWindow.getDecorView as ILocalObject).GetObjectID);
    if Decor = nil then
      Exit;
    Insets := Decor.getRootWindowInsets;
    if Insets = nil then
      Exit; // not attached yet, the timer tries again
    if not TPlatformServices.Current.SupportsPlatformService(
      IFMXScreenService, ScreenSvc) then
      Exit;
    Scale := ScreenSvc.GetScreenScale;
    if Scale <= 0 then
      Scale := 1;

    DecorH := Decor.getHeight / Scale;  // whole window, in form units
    FormH := Height;
    if (DecorH <= 0) or (FormH <= 0) then
      Exit;
    TopIn := Insets.getSystemWindowInsetTop / Scale;
    BotIn := Insets.getSystemWindowInsetBottom / Scale;

    // Window space the form doesn't use is space the bars can take
    // without covering anything.
    Gap := DecorH - FormH;
    if Gap < 0 then
      Gap := 0;
    Covered := TopIn + BotIn - Gap;
    if Covered < 0 then
      Covered := 0;
    PadBot := BotIn;
    if PadBot > Covered then
      PadBot := Covered;
    PadTop := Covered - PadBot;

    if (Abs(Padding.Top - PadTop) > 0.5) or
      (Abs(Padding.Bottom - PadBot) > 0.5) then
    begin
      Padding.Top := Round(PadTop);
      Padding.Bottom := Round(PadBot);
    end;
  except
    // never let a JNI problem stop the app; worst case the bar overlaps
  end;
{$ENDIF}
end;

procedure TfrmMain.FitDesktopWindow;
begin
  // On Windows and Mac open a phone-shaped window that fits the screen,
  // centred. Phones always run full screen, so nothing to do there.
{$IF not (DEFINED(IOS) or DEFINED(ANDROID))}
  ClientWidth := 390;
  ClientHeight := Min(780, Trunc(Screen.WorkAreaHeight) - 60);
  Left := Trunc(Screen.WorkAreaLeft + (Screen.WorkAreaWidth - Width) / 2);
  Top := Trunc(Screen.WorkAreaTop + (Screen.WorkAreaHeight - Height) / 2);
{$ENDIF}
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FRuns[0].Free;
  FRuns[1].Free;
  FResults.Free;
end;

procedure TfrmMain.LoadSettings;
var
  Ini: TMemIniFile;
  FileName: string;
begin
  FTreeMode := tmSportsman; // most users race on a Sportsman tree
  FStageMode := smAuto;
  FTransMode := trAuto;
  FThrottleMode := thAuto;
  FUserLane := 0;
  FCarPreset := 4; // V8 sedan
  FCar := Presets[FCarPreset];
  FRaceLength := rlQuarter;
  FSurface := sfPrepped;
  FImperial := False;
  FileName := SettingsFile;
  if (FileName = '') or not System.IOUtils.TFile.Exists(FileName) then
    Exit;
  try
    Ini := TMemIniFile.Create(FileName);
    try
      FTreeMode := TTreeMode(EnsureRange(Ini.ReadInteger('Options', 'Tree', Ord(tmSportsman)),
        Ord(Low(TTreeMode)), Ord(High(TTreeMode))));
      FStageMode := TStageMode(EnsureRange(Ini.ReadInteger('Options', 'Staging', 0),
        Ord(Low(TStageMode)), Ord(High(TStageMode))));
      FTransMode := TTransMode(EnsureRange(Ini.ReadInteger('Options', 'Trans', 0),
        Ord(Low(TTransMode)), Ord(High(TTransMode))));
      FThrottleMode := TThrottleMode(EnsureRange(Ini.ReadInteger('Options', 'Throttle', 0),
        Ord(Low(TThrottleMode)), Ord(High(TThrottleMode))));
      FUserLane := EnsureRange(Ini.ReadInteger('Options', 'Lane', 0), 0, 1);
      FRaceLength := TRaceLength(EnsureRange(Ini.ReadInteger('Options', 'Length',
        Ord(rlQuarter)), Ord(Low(TRaceLength)), Ord(High(TRaceLength))));
      FSurface := TSurface(EnsureRange(Ini.ReadInteger('Options', 'Surface', 0),
        Ord(Low(TSurface)), Ord(High(TSurface))));
      FImperial := Ini.ReadBool('Options', 'Imperial', False);

      // the car: a preset, then whatever was changed on the Car screen
      FCarPreset := EnsureRange(Ini.ReadInteger('Car', 'Preset', FCarPreset),
        0, PresetCount - 1);
      FCar := Presets[FCarPreset];
      FCar.PowerKW := EnsureRange(IniFloat(Ini, 'Car', 'PowerKW', FCar.PowerKW), 20.0, 5000.0);
      FCar.WeightKg := EnsureRange(IniFloat(Ini, 'Car', 'WeightKg', FCar.WeightKg), 100.0, 4000.0);
      FCar.Drive := TDrive(EnsureRange(Ini.ReadInteger('Car', 'Drive', Ord(FCar.Drive)),
        Ord(Low(TDrive)), Ord(High(TDrive))));
      FCar.Tyres := TTyres(EnsureRange(Ini.ReadInteger('Car', 'Tyres', Ord(FCar.Tyres)),
        Ord(Low(TTyres)), Ord(High(TTyres))));
      FCar.Turbo := Ini.ReadBool('Car', 'Turbo', FCar.Turbo);
      FCar.Gears := EnsureRange(Ini.ReadInteger('Car', 'Gears', FCar.Gears), 1, MaxGears);
      FCar.FinalDrive := EnsureRange(IniFloat(Ini, 'Car', 'FinalDrive', FCar.FinalDrive), 1.5, 8.0);
      FCar.ShiftRpm := EnsureRange(IniFloat(Ini, 'Car', 'ShiftRpm', FCar.ShiftRpm),
        1500.0, FCar.RevLimit);
      FCar.LaunchRpm := EnsureRange(IniFloat(Ini, 'Car', 'LaunchRpm', FCar.LaunchRpm),
        1000.0, FCar.RevLimit - 100);
      FCar.StallRpm := EnsureRange(IniFloat(Ini, 'Car', 'StallRpm', FCar.StallRpm),
        1000.0, FCar.RevLimit - 500);
    finally
      Ini.Free;
    end;
  except
    // no settings yet, keep the defaults
  end;
end;

procedure TfrmMain.SaveSettings;
var
  Ini: TMemIniFile;
  FileName: string;
begin
  FileName := SettingsFile;
  if FileName = '' then
    Exit;
  try
    Ini := TMemIniFile.Create(FileName);
    try
      Ini.WriteInteger('Options', 'Tree', Ord(FTreeMode));
      Ini.WriteInteger('Options', 'Staging', Ord(FStageMode));
      Ini.WriteInteger('Options', 'Trans', Ord(FTransMode));
      Ini.WriteInteger('Options', 'Throttle', Ord(FThrottleMode));
      Ini.WriteInteger('Options', 'Lane', FUserLane);
      Ini.WriteInteger('Options', 'Length', Ord(FRaceLength));
      Ini.WriteInteger('Options', 'Surface', Ord(FSurface));
      Ini.WriteBool('Options', 'Imperial', FImperial);
      Ini.WriteInteger('Car', 'Preset', FCarPreset);
      IniWriteFloat(Ini, 'Car', 'PowerKW', FCar.PowerKW);
      IniWriteFloat(Ini, 'Car', 'WeightKg', FCar.WeightKg);
      Ini.WriteInteger('Car', 'Drive', Ord(FCar.Drive));
      Ini.WriteInteger('Car', 'Tyres', Ord(FCar.Tyres));
      Ini.WriteBool('Car', 'Turbo', FCar.Turbo);
      Ini.WriteInteger('Car', 'Gears', FCar.Gears);
      IniWriteFloat(Ini, 'Car', 'FinalDrive', FCar.FinalDrive);
      IniWriteFloat(Ini, 'Car', 'ShiftRpm', FCar.ShiftRpm);
      IniWriteFloat(Ini, 'Car', 'LaunchRpm', FCar.LaunchRpm);
      IniWriteFloat(Ini, 'Car', 'StallRpm', FCar.StallRpm);
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
  except
    // settings are a convenience only
  end;
end;

function TfrmMain.NowMs: Double;
begin
  Result := FWatch.Elapsed.TotalMilliseconds;
end;

function TfrmMain.OppLane: Integer;
begin
  Result := 1 - FUserLane;
end;

function TfrmMain.GreenDueMs: Double;
begin
  if FTreeMode = tmPro then
    Result := FCountdownMs + ProAmberMs
  else
    Result := FCountdownMs + 3 * SportAmberMs;
end;

function TfrmMain.PreStageLit(Lane: Integer): Boolean;
begin
  Result := (FCars[Lane].Pos >= 0) and (FCars[Lane].Pos < PreStageOffIn);
end;

function TfrmMain.StageLit(Lane: Integer): Boolean;
begin
  Result := (FCars[Lane].Pos >= StageBeamIn) and (FCars[Lane].Pos < TooFarIn);
end;

function TfrmMain.AmberLit(Index: Integer; T: Double): Boolean;
var
  Start: Double;
begin
  Result := False;
  if not (FPhase in [tpCountdown, tpGreen]) then
    Exit;
  if FTreeMode = tmPro then
    Result := (T >= FCountdownMs) and (T < FCountdownMs + ProAmberMs)
  else
  begin
    // Sportsman: top to bottom, each one on for 0.5 s
    Start := FCountdownMs + Index * SportAmberMs;
    Result := (T >= Start) and (T < Start + SportAmberMs);
  end;
end;

function TfrmMain.GreenLit(Lane: Integer; T: Double): Boolean;
begin
  Result := (FPhase in [tpCountdown, tpGreen]) and (T >= GreenDueMs);
  if (Lane = FUserLane) and FRedLit then
    Result := False;
end;

{ ---- pedals ---- }

function TfrmMain.EffTrans: TTransMode;
begin
  if FMultiTouch then
    Result := FTransMode
  else
    Result := trAuto;
end;

function TfrmMain.EffThrottle: TThrottleMode;
begin
  if FMultiTouch then
    Result := FThrottleMode
  else
    Result := thAuto;
end;

function TfrmMain.PedalUsed(P: TPedal): Boolean;
begin
  case P of
    pdClutch:   Result := EffTrans = trManual;
    pdThrottle: Result := EffThrottle = thManual;
  else
    Result := True;
  end;
end;

function TfrmMain.CarHeld(const S: TPedals): Boolean;
begin
  // the car is held while the brake is on or, with a manual gearbox,
  // while the clutch is in
  Result := (pdBrake in S) or ((EffTrans = trManual) and (pdClutch in S));
end;

function TfrmMain.CarReady(const S: TPedals): Boolean;
begin
  // ready to start the tree: on the brake with an automatic; clutch in with
  // a manual (the brake may already be off, ready for the throttle)
  if EffTrans = trManual then
    Result := pdClutch in S
  else
    Result := pdBrake in S;
end;

function TfrmMain.ThrottleOpen: Boolean;
begin
  Result := (EffThrottle = thAuto) or (pdThrottle in FPressed);
end;

procedure TfrmMain.CreatePads;
var
  P: TPedal;
begin
  for P := Low(TPedal) to High(TPedal) do
  begin
    FPads[P] := TRectangle.Create(Self);
    FPads[P].Parent := layPads;
    FPads[P].XRadius := 16;
    FPads[P].YRadius := 16;
    FPads[P].Fill.Kind := TBrushKind.Solid;
    FPads[P].Fill.Color := clrPadIdle;
    FPads[P].Stroke.Kind := TBrushKind.Solid;
    FPads[P].Stroke.Color := PedalColors[P];
    FPads[P].Stroke.Thickness := 2;
    FPads[P].Tag := Ord(P);
    FPads[P].OnMouseDown := PadMouseDown;
    FPads[P].OnMouseUp := PadMouseUp;
    FPads[P].OnMouseLeave := PadMouseLeave;

    if P = pdThrottle then
    begin
      // rev bar: grows up from the bottom of the pad with the rpm
      FRevFill := TRectangle.Create(Self);
      FRevFill.Parent := FPads[P];
      FRevFill.XRadius := 16;
      FRevFill.YRadius := 16;
      FRevFill.Fill.Kind := TBrushKind.Solid;
      FRevFill.Fill.Color := TAlphaColor($55FFFFFF);
      FRevFill.Stroke.Kind := TBrushKind.None;
      FRevFill.HitTest := False;
      FRevFill.Height := 0;
    end;

    FPadLabels[P] := TLabel.Create(Self);
    FPadLabels[P].Parent := FPads[P];
    FPadLabels[P].Align := TAlignLayout.Client;
    FPadLabels[P].Text := PedalNames[P];
    StyleLabel(FPadLabels[P], 18, clrText, True, TTextAlign.Center);
    FPadLabels[P].WordWrap := True;
  end;
  layPadsResize(layPads);
  UpdatePads;
end;

procedure TfrmMain.layPadsResize(Sender: TObject);
var
  P: TPedal;
  Count, I: Integer;
  W, Gap: Single;
begin
  if FPads[pdBrake] = nil then
    Exit;
  Count := 0;
  for P := Low(TPedal) to High(TPedal) do
    if PedalUsed(P) then
      Inc(Count);
  Gap := 8;
  W := (layPads.Width - Gap * (Count - 1)) / Count;
  I := 0;
  for P := Low(TPedal) to High(TPedal) do
  begin
    FPads[P].Visible := PedalUsed(P);
    if FPads[P].Visible then
    begin
      FPads[P].SetBounds(I * (W + Gap), 0, W, layPads.Height);
      Inc(I);
    end;
  end;
  UpdateRevs(0);
end;

procedure TfrmMain.UpdatePads;
var
  P: TPedal;
begin
  for P := Low(TPedal) to High(TPedal) do
    if FPads[P] <> nil then
    begin
      if P in FPressed then
        FPads[P].Fill.Color := DimColor(PedalColors[P], 0.75)
      else
        FPads[P].Fill.Color := clrPadIdle;
    end;
end;

function TfrmMain.PedalsAt(const Touches: TTouches): TPedals;
var
  I: Integer;
  P: TPedal;
begin
  Result := [];
  for I := 0 to High(Touches) do
    for P := Low(TPedal) to High(TPedal) do
      if FPads[P].Visible and FPads[P].AbsoluteRect.Contains(Touches[I].Location) then
        Include(Result, P);
end;

procedure TfrmMain.FormTouch(Sender: TObject; const Touches: TTouches;
  const Action: TTouchAction);
var
  T, Stamp: Double;
  Under: TPedals;
begin
  T := NowMs; // timestamp first
  if not FTouchSeen then
  begin
    // real multi-touch is arriving, stop using the emulated mouse events
    FTouchSeen := True;
    FMousePedals := [];
  end;
  Under := PedalsAt(Touches);

  case Action of
    TTouchAction.Down, TTouchAction.Move:
      begin
        // Touches holds every finger that is down, so this is the full set.
        // If a lift was waiting to be resolved, it happened at its own time.
        Stamp := T;
        if FPendingUp then
          Stamp := FPendingUpMs;
        FPendingUp := False;
        FTouchPedals := Under;
        PedalsChanged(Stamp);
      end;
    TTouchAction.Up, TTouchAction.Cancel:
      begin
        if Length(Touches) <= 1 then
        begin
          // the finger in Touches is the one that lifted
          FPendingUp := False;
          if Length(Touches) = 0 then
            FTouchPedals := []
          else
            FTouchPedals := FTouchPedals - Under;
          PedalsChanged(T);
        end
        else
        begin
          // Several fingers listed and one of them lifted. Which one shows up
          // in the next event, which lists only the fingers still down; the
          // release is then dated to now.
          if not FPendingUp then
          begin
            FPendingUpMs := T;
            FPendingUnder := [];
          end;
          FPendingUnder := FPendingUnder + Under;
          FPendingUp := True;
        end;
      end;
  end;
end;

procedure TfrmMain.PadMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
  T: Double;
begin
  T := NowMs;
  if FTouchSeen then
    Exit;
  Include(FMousePedals, TPedal(TComponent(Sender).Tag));
  PedalsChanged(T);
end;

procedure TfrmMain.PadMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
  T: Double;
begin
  T := NowMs;
  if FTouchSeen then
    Exit;
  Exclude(FMousePedals, TPedal(TComponent(Sender).Tag));
  PedalsChanged(T);
end;

procedure TfrmMain.PadMouseLeave(Sender: TObject);
begin
  PadMouseUp(Sender, TMouseButton.mbLeft, [], 0, 0);
end;

procedure TfrmMain.FormKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: WideChar; Shift: TShiftState);
var
  T: Double;
begin
  T := NowMs;
  // Windows: Space is the brake, Enter starts a run
  if (KeyChar = ' ') or (Key = vkSpace) then
  begin
    if not (pdBrake in FKeyPedals) then
    begin
      Include(FKeyPedals, pdBrake);
      PedalsChanged(T);
    end;
    KeyChar := #0;
    Key := 0;
  end
  else if Key = vkReturn then
  begin
    StartRun;
    Key := 0;
  end;
end;

procedure TfrmMain.FormKeyUp(Sender: TObject; var Key: Word;
  var KeyChar: WideChar; Shift: TShiftState);
begin
  // Android Back button closes the top panel instead of quitting the app
  if Key = vkHardwareBack then
  begin
    if FSlipPanel.Visible then
      SlipDoneClick(nil)
    else if FCarPanel.Visible then
      CarDoneClick(nil)
    else if FSettingsPanel.Visible then
      SettingsDoneClick(nil)
    else
      Exit; // nothing open: Android goes back as usual
    Key := 0;
    Exit;
  end;
  if (KeyChar = ' ') or (Key = vkSpace) then
  begin
    Exclude(FKeyPedals, pdBrake);
    PedalsChanged(NowMs);
  end;
end;

procedure TfrmMain.PedalsChanged(T: Double);
var
  Old, New: TPedals;
  P: TPedal;
begin
  Old := FPressed;
  New := FTouchPedals + FMousePedals + FKeyPedals;
  for P := Low(TPedal) to High(TPedal) do
    if not PedalUsed(P) then
      Exclude(New, P);
  if New = Old then
    Exit;
  FPressed := New;
  UpdatePads;

  // Letting the car go once the tree is running is the launch: the brake
  // with an automatic, the clutch with a manual
  if FRunning and not FUserLaunched
    and (FPhase in [tpWaiting, tpCountdown, tpGreen]) then
  begin
    if EffTrans = trAuto then
    begin
      if CarHeld(Old) and not CarHeld(New) then
        Launch(T);
    end
    else if (pdClutch in Old) and not (pdClutch in New) then
    begin
      if pdBrake in New then
        Stall('dropped the clutch on the brake')
      else if not ThrottleOpen then
        Stall('dropped the clutch with no throttle')
      else
        Launch(T);
    end;
  end;

  if FRunning then
    UpdateHint;
end;

{ ---- settings screen ---- }

procedure TfrmMain.CreateSettingsPanel;
const
  RowH = 46;
var
  Box: TLayout;
  Title: TLabel;
  Done: TTapButton;
  S: TSetting;
begin
  FSettingsPanel := TRectangle.Create(Self);
  FSettingsPanel.Parent := Self;
  FSettingsPanel.Align := TAlignLayout.Contents;
  FSettingsPanel.Fill.Kind := TBrushKind.Solid;
  FSettingsPanel.Fill.Color := TAlphaColor($F0121212);
  FSettingsPanel.Stroke.Kind := TBrushKind.None;
  FSettingsPanel.HitTest := True; // swallow taps behind the panel
  FSettingsPanel.Visible := False;

  Box := TLayout.Create(Self);
  Box.Parent := FSettingsPanel;
  Box.Align := TAlignLayout.Center;
  Box.Width := 300;
  Box.Height := RowH * (Ord(High(TSetting)) + 3) + 16;

  Title := TLabel.Create(Self);
  Title.Parent := Box;
  Title.Align := TAlignLayout.Top;
  Title.Height := RowH;
  Title.Text := 'Settings';
  StyleLabel(Title, 24, clrText, True, TTextAlign.Center);

  for S := Low(TSetting) to High(TSetting) do
  begin
    FSettingButtons[S] := MakeButton(Box, '', clrBtnOption, SettingButtonClick);
    FSettingButtons[S].Align := TAlignLayout.Top;
    FSettingButtons[S].Position.Y := RowH * (Ord(S) + 1); // keeps the order
    FSettingButtons[S].Height := RowH - 8;
    FSettingButtons[S].Margins.Bottom := 8;
    FSettingButtons[S].Tag := Ord(S);
  end;

  Done := MakeButton(Box, 'Done', clrBtnSettings, SettingsDoneClick);
  Done.Align := TAlignLayout.Top;
  Done.Position.Y := RowH * (Ord(High(TSetting)) + 2);
  Done.Height := RowH - 8;
  Done.Margins.Top := 8;

  UpdateSettingsTexts;
end;

procedure TfrmMain.UpdateSettingsTexts;
const
  NeedsTouch = ' (needs multi-touch)';
var
  Summary: string;
begin
  FSettingButtons[stTree].Text := 'Tree: ' + TreeNames[FTreeMode];
  FSettingButtons[stLane].Text := 'Lane: ' + LaneNames[FUserLane];
  FSettingButtons[stStaging].Text := 'Staging: ' + StageNames[FStageMode];
  FSettingButtons[stTrans].Text := 'Transmission: ' + TransNames[EffTrans];
  FSettingButtons[stThrottle].Text := 'Throttle: ' + ThrottleNames[EffThrottle];
  if not FMultiTouch then
  begin
    FSettingButtons[stTrans].Text := FSettingButtons[stTrans].Text + NeedsTouch;
    FSettingButtons[stThrottle].Text := FSettingButtons[stThrottle].Text + NeedsTouch;
  end;
  FSettingButtons[stTrans].Enabled := FMultiTouch;
  FSettingButtons[stThrottle].Enabled := FMultiTouch;

  FSettingButtons[stCar].Text := 'Car: ' + CarTitle + '  >';
  FSettingButtons[stLength].Text := 'Race: ' + RaceLengthNames[FRaceLength];
  FSettingButtons[stSurface].Text := 'Track: ' + SurfaceNames[FSurface];
  if FImperial then
    FSettingButtons[stUnits].Text := 'Units: hp, lb, mph'
  else
    FSettingButtons[stUnits].Text := 'Units: kW, kg, km/h';

  Summary := Format('%s tree, %s lane, %s staging', [TreeNames[FTreeMode],
    LowerCase(LaneNames[FUserLane]), LowerCase(StageNames[FStageMode])]);
  if FMultiTouch then
    Summary := Summary + Format(', %s trans, %s throttle',
      [LowerCase(TransNames[EffTrans]), LowerCase(ThrottleNames[EffThrottle])])
  else
    Summary := Summary + ', brake only';
  Summary := Summary + sLineBreak + Format('%s, %s, %s', [CarTitle,
    RaceLengthNames[FRaceLength], LowerCase(SurfaceNames[FSurface])]);
  lblSummary.Text := Summary;
end;

procedure TfrmMain.SettingButtonClick(Sender: TObject);
begin
  case TSetting(TComponent(Sender).Tag) of
    stTree:
      if FTreeMode = tmPro then FTreeMode := tmSportsman else FTreeMode := tmPro;
    stLane:
      FUserLane := 1 - FUserLane;
    stStaging:
      if FStageMode = smAuto then FStageMode := smManual else FStageMode := smAuto;
    stTrans:
      if FTransMode = trAuto then FTransMode := trManual else FTransMode := trAuto;
    stThrottle:
      if FThrottleMode = thAuto then FThrottleMode := thManual else FThrottleMode := thAuto;
    stCar:
      begin
        UpdateCarTexts;
        FCarPanel.Visible := True;
        FCarPanel.BringToFront;
        Exit;
      end;
    stLength:
      FRaceLength := TRaceLength((Ord(FRaceLength) + 1) mod (Ord(High(TRaceLength)) + 1));
    stSurface:
      FSurface := TSurface((Ord(FSurface) + 1) mod (Ord(High(TSurface)) + 1));
    stUnits:
      FImperial := not FImperial;
  end;
  SaveSettings;
  UpdateSettingsTexts;
end;

{ ---- car screen ---- }

const
  KwToHp = 1.341022;
  KgToLb = 2.204623;
  MsToKmh = 3.6;
  MsToMph = 2.236936;
  InchesPerM = 39.3701;

function TfrmMain.CarTitle: string;
begin
  Result := FCar.Name;
  if not SpecsEqual(FCar, Presets[FCarPreset]) then
    Result := Result + ' (modified)';
end;

function TfrmMain.PowerText(KW: Double): string;
begin
  if FImperial then
    Result := Format('%d hp', [Round(KW * KwToHp)])
  else
    Result := Format('%d kW', [Round(KW)]);
end;

function TfrmMain.WeightText(Kg: Double): string;
begin
  if FImperial then
    Result := Format('%d lb', [Round(Kg * KgToLb)])
  else
    Result := Format('%d kg', [Round(Kg)]);
end;

function TfrmMain.SpeedText(Ms: Double): string;
begin
  if FImperial then
    Result := Format('%.1f mph', [Ms * MsToMph], TFormatSettings.Invariant)
  else
    Result := Format('%.1f km/h', [Ms * MsToKmh], TFormatSettings.Invariant);
end;

procedure TfrmMain.CreateCarPanel;
const
  RowH = 46;
  Rows = 11;
var
  Box: TLayout;
  Title: TLabel;
  Row: TLayout;
  Back: TRectangle;
  B: TTapButton;
  F: TCarField;
  C: TCarCycle;
  Y: Single;

  function NewRow(H: Single): TLayout;
  begin
    Result := TLayout.Create(Self);
    Result.Parent := Box;
    Result.Align := TAlignLayout.Top;
    Result.Position.Y := Y; // keeps the order
    Result.Height := H - 6;
    Result.Margins.Bottom := 6;
    Y := Y + H;
  end;

  procedure Stepper(AF: TCarField);
  begin
    Row := NewRow(RowH);
    B := MakeButton(Row, '-', clrBtnOption, nil);
    B.Align := TAlignLayout.Left;
    B.Width := 52;
    B.Tag := Ord(AF) * 2;
    B.OnMouseDown := CarStepDown;
    B.OnMouseUp := CarStepUp;
    B.OnMouseLeave := CarStepLeave;
    B := MakeButton(Row, '+', clrBtnOption, nil);
    B.Align := TAlignLayout.Right;
    B.Width := 52;
    B.Tag := Ord(AF) * 2 + 1;
    B.OnMouseDown := CarStepDown;
    B.OnMouseUp := CarStepUp;
    B.OnMouseLeave := CarStepLeave;
    Back := TRectangle.Create(Self);
    Back.Parent := Row;
    Back.Align := TAlignLayout.Client;
    Back.Margins.Left := 6;
    Back.Margins.Right := 6;
    Back.XRadius := 10;
    Back.YRadius := 10;
    Back.Fill.Color := clrPanel;
    Back.Stroke.Kind := TBrushKind.None;
    Back.HitTest := False;
    FCarValues[AF] := TLabel.Create(Self);
    FCarValues[AF].Parent := Back;
    FCarValues[AF].Align := TAlignLayout.Client;
    StyleLabel(FCarValues[AF], 15, clrText, True, TTextAlign.Center);
    FCarValues[AF].WordWrap := True;
  end;

begin
  FCarPanel := TRectangle.Create(Self);
  FCarPanel.Parent := Self;
  FCarPanel.Align := TAlignLayout.Contents;
  FCarPanel.Fill.Kind := TBrushKind.Solid;
  FCarPanel.Fill.Color := clrBackground;
  FCarPanel.Stroke.Kind := TBrushKind.None;
  FCarPanel.HitTest := True; // swallow taps behind the panel
  FCarPanel.Visible := False;

  Box := TLayout.Create(Self);
  Box.Parent := FCarPanel;
  Box.Align := TAlignLayout.Center;
  Box.Width := 320;
  Box.Height := RowH * Rows + 16;
  Y := 0;

  Title := TLabel.Create(Self);
  Title.Parent := Box;
  Title.Align := TAlignLayout.Top;
  Title.Height := RowH;
  Title.Position.Y := Y;
  Title.Text := 'Car';
  StyleLabel(Title, 24, clrText, True, TTextAlign.Center);
  Y := Y + RowH;

  Stepper(cfPreset);
  Stepper(cfPower);
  Stepper(cfWeight);

  // drive, engine and tyres: tap to change
  Row := NewRow(RowH);
  for C := Low(TCarCycle) to High(TCarCycle) do
  begin
    FCarCycles[C] := MakeButton(Row, '', clrBtnOption, CarCycleClick);
    FCarCycles[C].Align := TAlignLayout.Left;
    FCarCycles[C].Width := (Box.Width - 12) / 3;
    FCarCycles[C].Tag := Ord(C);
    if C <> Low(TCarCycle) then
      FCarCycles[C].Margins.Left := 6;
  end;

  for F := cfGears to High(TCarField) do
    Stepper(F);

  Row := NewRow(RowH);
  FCarEstimate := TLabel.Create(Self);
  FCarEstimate.Parent := Row;
  FCarEstimate.Align := TAlignLayout.Client;
  StyleLabel(FCarEstimate, 13, clrSubtle, False, TTextAlign.Center);
  FCarEstimate.WordWrap := True;

  Row := NewRow(RowH);
  B := MakeButton(Row, 'Done', clrBtnSettings, CarDoneClick);
  B.Align := TAlignLayout.Client;
end;

procedure TfrmMain.UpdateCarTexts;
var
  ET, Trap: Double;
  Gearbox: string;
begin
  FCarValues[cfPreset].Text := CarTitle;
  FCarValues[cfPower].Text := 'Power ' + PowerText(FCar.PowerKW);
  FCarValues[cfWeight].Text := 'Weight ' + WeightText(FCar.WeightKg);
  if FCar.Gears = 1 then
    FCarValues[cfGears].Text := '1 gear'
  else
    FCarValues[cfGears].Text := Format('%d gears', [FCar.Gears]);
  FCarValues[cfFinal].Text := Format('Final drive %.2f', [FCar.FinalDrive],
    TFormatSettings.Invariant);
  FCarValues[cfShift].Text := Format('Shift at %d rpm', [Round(FCar.ShiftRpm)]);
  if EffTrans = trManual then
    FCarValues[cfLaunch].Text := Format('Launch at %d rpm', [Round(FCar.LaunchRpm)])
  else
    FCarValues[cfLaunch].Text := Format('Stall speed %d rpm', [Round(FCar.StallRpm)]);

  FCarCycles[ccDrive].Text := DriveNames[FCar.Drive];
  if FCar.Turbo then
    FCarCycles[ccEngine].Text := 'Turbo'
  else
    FCarCycles[ccEngine].Text := 'No turbo';
  FCarCycles[ccTyres].Text := TyreNames[FCar.Tyres];

  // a good full-throttle run, so you can see what a change does
  EstimateRun(FCar, EffTrans = trManual, FSurface, FRaceLength, ET, Trap);
  Gearbox := LowerCase(TransNames[EffTrans]);
  if ET > 0 then
    FCarEstimate.Text := Format('Best run: %s in %s s at %s',
      [RaceLengthNames[FRaceLength], FormatET(ET), SpeedText(Trap)]) +
      sLineBreak + Format('(%s, %s gearbox)', [LowerCase(SurfaceNames[FSurface]), Gearbox])
  else
    FCarEstimate.Text := 'Too slow to reach the finish line';
end;

procedure TfrmMain.ChangeCarField(F: TCarField; Dir: Integer);
var
  V, St: Double;
begin
  case F of
    cfPreset:
      begin
        FCarPreset := (FCarPreset + Dir + PresetCount) mod PresetCount;
        FCar := Presets[FCarPreset];
      end;
    cfPower:
      begin
        // steps in the units shown, bigger for big numbers
        if FImperial then V := FCar.PowerKW * KwToHp else V := FCar.PowerKW;
        if V < 250 then St := 5 else if V < 1300 then St := 10 else St := 50;
        V := Round(V / St) * St + Dir * St;
        if FImperial then V := V / KwToHp;
        FCar.PowerKW := EnsureRange(V, 20.0, 5000.0);
      end;
    cfWeight:
      begin
        if FImperial then
        begin
          V := FCar.WeightKg * KgToLb;
          if V < 1300 then St := 10 else St := 50;
          FCar.WeightKg := EnsureRange((Round(V / St) * St + Dir * St) / KgToLb, 100.0, 4000.0);
        end
        else
        begin
          V := FCar.WeightKg;
          if V < 600 then St := 5 else St := 25;
          FCar.WeightKg := EnsureRange(Round(V / St) * St + Dir * St, 100.0, 4000.0);
        end;
      end;
    cfGears:
      FCar.Gears := EnsureRange(FCar.Gears + Dir, 1, MaxGears);
    cfFinal:
      FCar.FinalDrive := EnsureRange((Round(FCar.FinalDrive * 20) + Dir) / 20, 1.5, 8.0);
    cfShift:
      FCar.ShiftRpm := EnsureRange(Round(FCar.ShiftRpm / 100) * 100.0 + Dir * 100.0,
        1500.0, FCar.RevLimit);
    cfLaunch:
      if EffTrans = trManual then
        FCar.LaunchRpm := EnsureRange(Round(FCar.LaunchRpm / 100) * 100.0 + Dir * 100.0,
          1000.0, FCar.RevLimit - 100)
      else
        FCar.StallRpm := EnsureRange(Round(FCar.StallRpm / 100) * 100.0 + Dir * 100.0,
          1000.0, FCar.RevLimit - 500);
  end;
  SaveSettings;
  UpdateCarTexts;
end;

procedure TfrmMain.CarStepDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
  Dir: Integer;
begin
  // change once now, then keep going while the button is held
  FRepeatTag := TComponent(Sender).Tag;
  if Odd(FRepeatTag) then Dir := 1 else Dir := -1;
  ChangeCarField(TCarField(FRepeatTag div 2), Dir);
  FRepeatTimer.Interval := 450;
  FRepeatTimer.Enabled := True;
end;

procedure TfrmMain.CarStepUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  FRepeatTimer.Enabled := False;
end;

procedure TfrmMain.CarStepLeave(Sender: TObject);
begin
  FRepeatTimer.Enabled := False;
end;

procedure TfrmMain.RepeatTimerTick(Sender: TObject);
var
  Dir: Integer;
begin
  FRepeatTimer.Interval := 70;
  if Odd(FRepeatTag) then Dir := 1 else Dir := -1;
  ChangeCarField(TCarField(FRepeatTag div 2), Dir);
end;

procedure TfrmMain.CarCycleClick(Sender: TObject);
begin
  case TCarCycle(TComponent(Sender).Tag) of
    ccDrive:
      FCar.Drive := TDrive((Ord(FCar.Drive) + 1) mod (Ord(High(TDrive)) + 1));
    ccEngine:
      FCar.Turbo := not FCar.Turbo;
    ccTyres:
      FCar.Tyres := TTyres((Ord(FCar.Tyres) + 1) mod (Ord(High(TTyres)) + 1));
  end;
  SaveSettings;
  UpdateCarTexts;
end;

procedure TfrmMain.CarDoneClick(Sender: TObject);
begin
  FRepeatTimer.Enabled := False;
  FCarPanel.Visible := False;
  UpdateSettingsTexts;
end;

{ ---- time slip ---- }

procedure TfrmMain.CreateSlipPanel;
begin
  FSlipPanel := TRectangle.Create(Self);
  FSlipPanel.Parent := Self;
  FSlipPanel.Align := TAlignLayout.Contents;
  FSlipPanel.Fill.Kind := TBrushKind.Solid;
  FSlipPanel.Fill.Color := TAlphaColor($C0000000);
  FSlipPanel.Stroke.Kind := TBrushKind.None;
  FSlipPanel.HitTest := True;
  FSlipPanel.Visible := False;

  FSlipBox := TRectangle.Create(Self);
  FSlipBox.Parent := FSlipPanel;
  FSlipBox.Align := TAlignLayout.Center;
  FSlipBox.Width := 320;
  FSlipBox.Height := 300;
  FSlipBox.XRadius := 12;
  FSlipBox.YRadius := 12;
  FSlipBox.Fill.Color := clrPanel;
  FSlipBox.Stroke.Color := clrSubtle;
  FSlipBox.Padding.Rect := RectF(12, 8, 12, 12);
end;

procedure TfrmMain.ShowSlip(const R: TRunResult; const Verdict: string;
  VerdictColor: TAlphaColor);
const
  RowH = 24;
var
  Y: Single;
  S, Last: TSplit;
  Opp: Integer;
  OK: TTapButton;
  L: TLabel;

  function AddLabel(AParent: TFmxObject; const Text: string; AAlign: TAlignLayout;
    W: Single; Color: TAlphaColor; Bold: Boolean; HAlign: TTextAlign): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := AParent;
    Result.Align := AAlign;
    if W > 0 then
      Result.Width := W;
    Result.Text := Text;
    StyleLabel(Result, 14, Color, Bold, HAlign);
  end;

  procedure AddRow(const Caption, You, Other: string; Bold: Boolean);
  var
    Row: TLayout;
  begin
    Row := TLayout.Create(Self);
    Row.Parent := FSlipBox;
    Row.Align := TAlignLayout.Top;
    Row.Position.Y := Y;
    Row.Height := RowH;
    Y := Y + RowH;
    AddLabel(Row, Caption, TAlignLayout.Left, 96, clrSubtle, Bold, TTextAlign.Leading);
    AddLabel(Row, Other, TAlignLayout.Right, 92, clrOpponent, Bold, TTextAlign.Trailing);
    AddLabel(Row, You, TAlignLayout.Client, 0, clrYou, Bold, TTextAlign.Trailing);
  end;

  function SplitText(Lane: Integer; Sp: TSplit): string;
  begin
    if FRuns[Lane].SplitTime[Sp] > 0 then
      Result := FormatET(FRuns[Lane].SplitTime[Sp])
    else
      Result := '-';
  end;

  function SplitSpeed(Lane: Integer; Sp: TSplit): string;
  begin
    if FRuns[Lane].SplitTime[Sp] > 0 then
      Result := SpeedText(FRuns[Lane].SplitSpeed[Sp])
    else
      Result := '-';
  end;

begin
  Opp := OppLane;
  FSlipBox.DeleteChildren;
  Y := 0;

  L := AddLabel(FSlipBox, 'TIME SLIP', TAlignLayout.Top, 0, clrText, True,
    TTextAlign.Center);
  L.Height := 34;
  Y := 34;
  AddRow(SurfaceNames[FSurface], 'YOU', 'OTHER', True);
  AddRow('Reaction', FormatSecs(R.ReactionMs), FormatSecs(R.OppReactionMs), False);
  Last := RaceSplit[FRaceLength];
  for S := Low(TSplit) to Last do
  begin
    AddRow(SplitNames[S], SplitText(FUserLane, S), SplitText(Opp, S), S = Last);
    if (S = spEighth) or (S = Last) then
      AddRow('  speed', SplitSpeed(FUserLane, S), SplitSpeed(Opp, S), False);
  end;

  L := AddLabel(FSlipBox, Verdict, TAlignLayout.Top, 0, VerdictColor, True,
    TTextAlign.Center);
  L.Position.Y := Y;
  L.Height := 44;
  L.TextSettings.Font.Size := 18;
  L.WordWrap := True;
  Y := Y + 44;

  OK := MakeButton(FSlipBox, 'OK', clrBtnSettings, SlipDoneClick);
  OK.Align := TAlignLayout.Top;
  OK.Position.Y := Y;
  OK.Height := 44;
  Y := Y + 44;

  FSlipBox.Height := Y + FSlipBox.Padding.Top + FSlipBox.Padding.Bottom;
  FSlipPanel.Visible := True;
  FSlipPanel.BringToFront;
end;

procedure TfrmMain.SlipDoneClick(Sender: TObject);
begin
  FSlipPanel.Visible := False;
end;

procedure TfrmMain.btnSettingsClick(Sender: TObject);
begin
  if FRunning then
    Exit;
  UpdateSettingsTexts;
  FSettingsPanel.Visible := True;
  FSettingsPanel.BringToFront;
end;

procedure TfrmMain.SettingsDoneClick(Sender: TObject);
begin
  FSettingsPanel.Visible := False;
  // pedal set may have changed
  FTouchPedals := [];
  FMousePedals := [];
  FPressed := [];
  layPadsResize(layPads);
  UpdatePads;
  ResetTree;
end;

{ ---- look ---- }

procedure TfrmMain.StyleLabel(L: TLabel; Size: Single; Color: TAlphaColor;
  Bold: Boolean; Align: TTextAlign);
begin
  L.StyledSettings := L.StyledSettings - [TStyledSetting.Size,
    TStyledSetting.FontColor, TStyledSetting.Style];
  L.TextSettings.Font.Size := Size;
  L.TextSettings.FontColor := Color;
  if Bold then
    L.TextSettings.Font.Style := [TFontStyle.fsBold]
  else
    L.TextSettings.Font.Style := [];
  L.TextSettings.HorzAlign := Align;
  L.HitTest := False;
end;

procedure TfrmMain.ApplyLook;
begin
  Fill.Kind := TBrushKind.Solid;
  Fill.Color := clrBackground;
{$IFDEF IOS}
  // Keep clear of the notch and the home indicator
  Padding.Top := 44;
  Padding.Bottom := 20;
{$ENDIF}

  StyleLabel(lblReaction, 48, clrText, True, TTextAlign.Center);
  StyleLabel(lblVerdict, 20, clrSubtle, True, TTextAlign.Center);
  StyleLabel(lblStats, 14, clrSubtle, False, TTextAlign.Center);
  StyleLabel(lblSummary, 12, clrSubtle, False, TTextAlign.Leading);
  lblSummary.WordWrap := True;
  StyleLabel(lblHistoryTitle, 14, clrSubtle, True, TTextAlign.Center);
  StyleLabel(lblHistory, 14, clrText, False, TTextAlign.Leading);
  lblHistory.TextSettings.VertAlign := TTextAlign.Leading;
  lblHistory.WordWrap := True;
  StyleLabel(lblHint, 14, clrSubtle, True, TTextAlign.Center);

  rectHistory.Fill.Kind := TBrushKind.Solid;
  rectHistory.Fill.Color := clrPanel;
  rectHistory.Stroke.Kind := TBrushKind.None;
end;

function TfrmMain.MakeButton(AParent: TFmxObject; const AText: string;
  AColor: TAlphaColor; AOnClick: TNotifyEvent): TTapButton;
begin
  Result := TTapButton.Create(Self);
  Result.Parent := AParent;
  Result.Text := AText;
  Result.Color := AColor;
  Result.OnClick := AOnClick;
end;

procedure TfrmMain.CreateButtons;
begin
  btnSettings := MakeButton(layOptions, 'Settings', clrBtnSettings,
    btnSettingsClick);
  btnSettings.Align := TAlignLayout.Left;
  btnSettings.Width := 100;

  btnStart := MakeButton(layButtons, 'Start', clrBtnStart, btnStartClick);
  btnStop := MakeButton(layButtons, 'Stop', clrBtnStop, btnStopClick);
  btnReset := MakeButton(layButtons, 'Reset', clrBtnReset, btnResetClick);
  btnClear := MakeButton(layButtons, 'Clear', clrBtnClear, btnClearClick);
  layButtonsResize(layButtons);
end;

procedure TfrmMain.layButtonsResize(Sender: TObject);
const
  Edge = 4;
  Gap = 8;
var
  W: Single;
  I: Integer;
  B: TTapButton;
begin
  // can fire while the form is still loading, before the buttons exist
  if btnClear = nil then
    Exit;
  // the layout already has a 4 px margin each side, so the outer buttons
  // line up with the 8 px margin of everything above
  W := (layButtons.Width - 2 * Edge - 3 * Gap) / 4;
  for I := 0 to 3 do
  begin
    case I of
      0: B := btnStart;
      1: B := btnStop;
      2: B := btnReset;
    else
      B := btnClear;
    end;
    B.SetBounds(Edge + I * (W + Gap), 0, W, layButtons.Height);
  end;
end;

procedure TfrmMain.SetVerdict(const Text: string; Color: TAlphaColor);
begin
  lblVerdict.Text := Text;
  lblVerdict.TextSettings.FontColor := Color;
end;

{ ---- running the tree ---- }

procedure TfrmMain.ResetTree;
var
  Lane: Integer;
begin
  tmrTree.Enabled := False;
  FPhase := tpIdle;
  FRunning := False;
  FRedLit := False;
  FUserLaunched := False;
  FRaceDone := False;
  FWinLane := -1;
  FResultIdx := -1;
  FRuns[0].Abort;
  FRuns[1].Abort;
  if FSlipPanel <> nil then
    FSlipPanel.Visible := False;
  FBogged := False;
  FRpm := IdleRpm;
  FEngineOn := True;
  FStallSinceMs := 0;
  UpdateRevs(0);
  for Lane := 0 to 1 do
  begin
    FCars[Lane] := Default(TCar);
    FCars[Lane].Pos := CarStartIn;
  end;
  lblReaction.Text := '-.---';
  lblReaction.TextSettings.FontColor := clrText;
  SetVerdict('Press START to stage', clrSubtle);
  btnSettings.Enabled := True;
  UpdateSettingsTexts;
  UpdateHint;
  pbTree.Repaint;
end;

procedure TfrmMain.StartRun;
begin
  if FSettingsPanel.Visible then
    Exit;
  ResetTree;
  FRunning := True;
  FPhase := tpStaging;
  btnSettings.Enabled := False;
  // the other car starts rolling a moment later
  FCars[OppLane].RollAtMs := NowMs + 300;
  FLastTickMs := NowMs;
  SetVerdict('Staging...', clrSubtle);
  UpdateHint;
  tmrTree.Enabled := True;
  pbTree.Repaint;
end;

procedure TfrmMain.StopRun(const Msg: string);
begin
  tmrTree.Enabled := False;
  FPhase := tpIdle;
  FRunning := False;
  btnSettings.Enabled := True;
  SetVerdict(Msg, clrSubtle);
  UpdateHint;
  pbTree.Repaint;
end;

procedure TfrmMain.MoveCars(T, Dt: Double);
const
  AutoRollIn: Double = 40.0;   // fast roll-in speed, in/s
  CreepIn: Double = 4.0;       // creeping speed near the beams, in/s
  MinSpeed: Double = 2.0;
var
  Lane: Integer;
  Auto: Boolean;
  Gap, Step: Double;
begin
  for Lane := 0 to 1 do
  begin
    if FCars[Lane].Launched then
    begin
      // the car model, up to now; the other lane's driver keeps it pinned
      FRuns[Lane].Advance((T - FCars[Lane].RunStartMs) / 1000,
        (Lane <> FUserLane) or ThrottleOpen);
      FCars[Lane].Pos := FCars[Lane].LaunchPos + FRuns[Lane].Distance * InchesPerM;
      Continue;
    end;

    if FPhase <> tpStaging then
      Continue;

    Auto := (Lane = OppLane) or (FStageMode = smAuto);
    if Auto then
    begin
      // the opponent waits a moment before it rolls in
      if (Lane = OppLane) and (T < FCars[Lane].RollAtMs) then
        Continue;
      Gap := AutoStageIn - FCars[Lane].Pos;
      if Gap > 0.05 then
      begin
        // fast roll-in, slowing to a creep near the beams
        Step := EnsureRange(Gap * 1.5, MinSpeed, AutoRollIn) * Dt;
        FCars[Lane].Pos := Min(AutoStageIn, FCars[Lane].Pos + Step);
      end
      else
        FCars[Lane].Pos := AutoStageIn;
    end
    else if not CarHeld(FPressed) then
    begin
      // manual staging: off the brake the car idles forward
      if FCars[Lane].Pos < -12 then
        FCars[Lane].Pos := FCars[Lane].Pos + AutoRollIn * Dt
      else
        FCars[Lane].Pos := FCars[Lane].Pos + CreepIn * Dt;
    end;
  end;
end;

procedure TfrmMain.tmrTreeTimer(Sender: TObject);
var
  T, Dt: Double;
  Opp: Integer;
begin
  T := NowMs;
  Dt := Min((T - FLastTickMs) / 1000, 0.1);
  FLastTickMs := T;
  Opp := OppLane;

  // A lift that no later touch event has explained: assume every finger
  // listed with it came up (all fingers lifted together).
  if FPendingUp and (T - FPendingUpMs > 250) then
  begin
    FPendingUp := False;
    FTouchPedals := FTouchPedals - FPendingUnder;
    PedalsChanged(FPendingUpMs);
  end;

  // Manual gearbox: on the brake with the clutch out the engine stalls.
  // A short grace lets the fingers land one after the other.
  if (EffTrans = trManual) and not FUserLaunched
    and (pdBrake in FPressed) and not (pdClutch in FPressed) then
  begin
    if FStallSinceMs = 0 then
      FStallSinceMs := T
    else if T - FStallSinceMs > StallGraceMs then
    begin
      Stall('clutch out on the brake');
      Exit;
    end;
  end
  else
    FStallSinceMs := 0;

  MoveCars(T, Dt);

  case FPhase of
    tpStaging:
      begin
        if FCars[FUserLane].Pos >= TooFarIn then
        begin
          FRedLit := True;
          StopRun('TOO FAR FORWARD - press Reset');
          lblVerdict.TextSettings.FontColor := clrRed;
          Exit;
        end;
        if StageLit(FUserLane) and not PreStageLit(FUserLane) then
          SetVerdict('Deep staged', clrAmber)
        else if StageLit(FUserLane) then
          SetVerdict('Staged', clrSubtle)
        else if PreStageLit(FUserLane) then
          SetVerdict('Pre-staged', clrSubtle);
        // the tree starts once both lanes are staged and you are holding
        // the car ready to go
        if StageLit(FUserLane) and CarReady(FPressed)
          and ((FStageMode = smManual) or (FCars[FUserLane].Pos >= AutoStageIn))
          and StageLit(Opp) and (FCars[Opp].Pos >= AutoStageIn) then
        begin
          FPhase := tpWaiting;
          FCountdownMs := T + AutoStartMinMs + Random(AutoStartRandMs);
          FCars[Opp].LaunchAtMs := GreenDueMs + 40 + Random(200);
        end;
        UpdateHint;
      end;
    tpWaiting:
      if T >= FCountdownMs then
        FPhase := tpCountdown;
    tpCountdown:
      if T >= GreenDueMs then
        FPhase := tpGreen;
  end;

  // the other lane leaves on its own green, timed from when it was due to
  // go rather than from this tick
  if (FPhase = tpGreen) and not FCars[Opp].Launched
    and (T >= FCars[Opp].LaunchAtMs) then
  begin
    FCars[Opp].Launched := True;
    FCars[Opp].LaunchPos := FCars[Opp].Pos;
    FCars[Opp].RunStartMs := FCars[Opp].LaunchAtMs;
    FRuns[Opp].Start(FCar, EffTrans = trManual, FSurface, FRaceLength,
      FCar.LaunchRpm);
  end;

  // the race is over once both cars have finished (or given up)
  if FUserLaunched and FCars[Opp].Launched and not FRaceDone
    and (FRuns[FUserLane].State <> rsRunning)
    and (FRuns[Opp].State <> rsRunning) then
  begin
    FinishRace;
    Exit;
  end;

  pbTree.Repaint;
end;

procedure TfrmMain.Stall(const Why: string);
begin
  FRpm := 0;
  FEngineOn := False;
  UpdateRevs(0);
  StopRun('STALLED - ' + Why);
  lblReaction.Text := 'STALL';
  lblReaction.TextSettings.FontColor := clrRed;
  lblVerdict.TextSettings.FontColor := clrRed;
  lblHint.Text := 'Press START to try again';
end;

procedure TfrmMain.RevTimerTick(Sender: TObject);
var
  T: Double;
begin
  T := NowMs;
  UpdateRevs(Min((T - FRevLastMs) / 1000, 0.1));
  FRevLastMs := T;
end;

procedure TfrmMain.UpdateRevs(Dt: Double);
var
  Target: Double;
  H: Single;
begin
  if (FRevFill = nil) or (FPads[pdThrottle] = nil) then
    Exit;
  // the engine runs unless it has stalled; it revs whenever the throttle
  // is held and drops back to idle when it is let go, run or no run
  if FEngineOn then
  begin
    if FUserLaunched and (FRuns[FUserLane].State = rsRunning) then
      // on the run the car model says what the engine is doing
      FRpm := FRuns[FUserLane].EngineRpm
    else
    begin
      if not (pdThrottle in FPressed) then
        Target := IdleRpm
      else if FRunning and not FUserLaunched then
      begin
        // staged: a manual holds its launch revs (two-step), an automatic
        // on the brake only revs to its stall speed
        if EffTrans = trManual then
          Target := FCar.LaunchRpm
        else
          Target := FCar.StallRpm;
      end
      else
        Target := FCar.RevLimit;
      if FRpm < Target then
        FRpm := Min(Target, FRpm + RevUpRate * Dt)
      else
        FRpm := Max(Target, FRpm - RevDownRate * Dt);
    end;
  end;
  H := FPads[pdThrottle].Height * EnsureRange(FRpm / (FCar.RevLimit + 1000), 0.0, 1.0);
  FRevFill.SetBounds(0, FPads[pdThrottle].Height - H,
    FPads[pdThrottle].Width, H);
  if FRpm >= FCar.RevLimit - 200 then
    FRevFill.Fill.Color := TAlphaColor($66FF5252)  // on the limiter
  else
    FRevFill.Fill.Color := TAlphaColor($55FFFFFF);
  if FRpm <= 0 then
    FPadLabels[pdThrottle].Text := PedalNames[pdThrottle] + sLineBreak + 'engine off'
  else
    FPadLabels[pdThrottle].Text := PedalNames[pdThrottle] + sLineBreak +
      Format('%d rpm', [Round(FRpm / 100) * 100]);
end;

procedure TfrmMain.Launch(ReleaseMs: Double);
var
  R: TRunResult;
  LaunchRpm: Double;
begin
  if not FRunning or FUserLaunched then
    Exit;

  FUserLaunched := True;
  FCars[FUserLane].Launched := True;
  FCars[FUserLane].LaunchPos := FCars[FUserLane].Pos;
  FCars[FUserLane].RunStartMs := ReleaseMs;
  FBogged := not ThrottleOpen;
  // a manual launches on the revs you are holding (idle if none)
  if EffThrottle = thManual then
    LaunchRpm := FRpm
  else
    LaunchRpm := FCar.LaunchRpm;
  FRuns[FUserLane].Start(FCar, EffTrans = trManual, FSurface, FRaceLength,
    LaunchRpm);

  R := Default(TRunResult);
  R.Mode := FTreeMode;
  R.BeforeTree := FPhase = tpWaiting;
  R.ReactionMs := ReleaseMs - GreenDueMs;
  R.Foul := R.ReactionMs < 0;
  R.Bogged := FBogged;

  // A red light lights your red bulb; the tree carries on for the other lane
  if R.Foul then
    FRedLit := True;

  FResults.Add(R);
  FResultIdx := FResults.Count - 1;
  ShowResult(R);
  UpdateStats;
  UpdateHint;
  pbTree.Repaint;
end;

procedure TfrmMain.FinishRace;
var
  R: TRunResult;
  Opp: Integer;
  UserDone, OppDone: Boolean;
  UserAt, OppAt, Margin: Double;
  Verdict: string;
  Color: TAlphaColor;
begin
  FRaceDone := True;
  tmrTree.Enabled := False;
  FRunning := False;
  btnSettings.Enabled := True;
  if FResultIdx < 0 then
    Exit;

  Opp := OppLane;
  UserDone := FRuns[FUserLane].State = rsFinished;
  OppDone := FRuns[Opp].State = rsFinished;
  R := FResults[FResultIdx];
  R.Finished := UserDone;
  R.ET := FRuns[FUserLane].ET;
  R.TrapSpeed := FRuns[FUserLane].TrapSpeed;
  R.OppReactionMs := FCars[Opp].LaunchAtMs - GreenDueMs;
  R.OppET := FRuns[Opp].ET;

  // First to the finish line wins: both greens came on together, so that
  // is reaction time + elapsed time. A red light loses.
  UserAt := FCars[FUserLane].RunStartMs + FRuns[FUserLane].FinishTime * 1000;
  OppAt := FCars[Opp].RunStartMs + FRuns[Opp].FinishTime * 1000;
  Margin := Abs(UserAt - OppAt);
  if R.Foul then
    R.Outcome := ocLoss
  else if not UserDone then
  begin
    if OppDone then R.Outcome := ocLoss else R.Outcome := ocNone;
  end
  else if not OppDone then
    R.Outcome := ocWin
  else if Margin < 0.05 then
    R.Outcome := ocTie
  else if UserAt < OppAt then
    R.Outcome := ocWin
  else
    R.Outcome := ocLoss;
  FResults[FResultIdx] := R;

  case R.Outcome of
    ocWin:
      begin
        FWinLane := FUserLane;
        if OppDone then
          Verdict := Format('YOU WIN by %s s', [FormatSecs(Margin)])
        else
          Verdict := 'YOU WIN';
        Color := clrGreen;
      end;
    ocLoss:
      begin
        FWinLane := Opp;
        if R.Foul then
          Verdict := 'RED LIGHT - you lose'
        else if not UserDone then
          Verdict := 'Did not finish - you lose'
        else
          Verdict := Format('Beaten by %s s', [FormatSecs(Margin)]);
        Color := clrRed;
        if not R.Foul and UserDone then
          Color := clrAmber;
      end;
    ocTie:
      begin
        FWinLane := 2;
        Verdict := 'DEAD HEAT!';
        Color := clrAmber;
      end;
  else
    begin
      FWinLane := -1;
      Verdict := 'Neither car finished';
      Color := clrSubtle;
    end;
  end;

  SetVerdict(Verdict, Color);
  UpdateStats;
  UpdateHint;
  pbTree.Repaint;
  ShowSlip(R, Verdict, Color);
end;

procedure TfrmMain.ShowResult(const R: TRunResult);
var
  Verdict: string;
  Color: TAlphaColor;
begin
  lblReaction.Text := FormatSecs(R.ReactionMs);
  if R.Foul then
  begin
    if R.BeforeTree then
      Verdict := 'RED LIGHT - went before the tree'
    else
      Verdict := 'RED LIGHT';
    Color := clrRed;
  end
  else
  begin
    Color := clrGreen;
    if R.ReactionMs < 10 then
      Verdict := 'PERFECT LIGHT!'
    else if R.ReactionMs < 50 then
      Verdict := 'Great light'
    else if R.ReactionMs < 100 then
      Verdict := 'Good light'
    else if R.ReactionMs < 200 then
    begin
      Verdict := 'A bit late';
      Color := clrAmber;
    end
    else
    begin
      Verdict := 'Asleep on the tree';
      Color := clrAmber;
    end;
  end;
  if R.Bogged then
    Verdict := Verdict + ' - bogged, no throttle';
  lblReaction.TextSettings.FontColor := Color;
  SetVerdict(Verdict, Color);
end;

procedure TfrmMain.UpdateHint;
var
  Need: string;
begin
  if EffTrans = trManual then
    Need := 'hold the CLUTCH in'
  else
    Need := 'hold BRAKE';

  if not FRunning then
  begin
    if FUserLaunched then
      lblHint.Text := 'START for another run'
    else
      lblHint.Text := 'Press START';
  end
  else if FUserLaunched then
  begin
    if (EffThrottle = thManual) and not ThrottleOpen then
      lblHint.Text := 'Hold THROTTLE!'
    else
      lblHint.Text := '';
  end
  else if (EffTrans = trManual) and (pdBrake in FPressed)
    and not (pdClutch in FPressed) then
    lblHint.Text := 'CLUTCH in or you will stall!'
  else if FPhase = tpStaging then
  begin
    if (FStageMode = smManual) and not StageLit(FUserLane) then
      lblHint.Text := 'Ease off the brake to creep in'
    else if not CarReady(FPressed) then
      lblHint.Text := 'Staged: ' + Need
    else
      lblHint.Text := 'Waiting for the other lane';
  end
  else if EffTrans = trManual then
  begin
    if (pdBrake in FPressed) and (EffThrottle = thManual) then
      lblHint.Text := 'Brake off, foot on the THROTTLE'
    else if pdBrake in FPressed then
      lblHint.Text := 'Brake off, drop the CLUTCH on green'
    else if (EffThrottle = thManual) and not ThrottleOpen then
      lblHint.Text := 'Hold THROTTLE, drop the CLUTCH on green'
    else
      lblHint.Text := 'Drop the CLUTCH to launch';
  end
  else if (EffThrottle = thManual) and not ThrottleOpen then
    lblHint.Text := 'Hold THROTTLE, release BRAKE on green'
  else
    lblHint.Text := 'Release BRAKE to launch';
end;

procedure TfrmMain.UpdateStats;
var
  I, Good, Fouls: Integer;
  Sum, Best: Double;
  R: TRunResult;
  Lines: TStringBuilder;
begin
  Good := 0;
  Fouls := 0;
  Sum := 0;
  Best := MaxDouble;
  for R in FResults do
    if R.Foul then
      Inc(Fouls)
    else
    begin
      Inc(Good);
      Sum := Sum + R.ReactionMs;
      Best := Min(Best, R.ReactionMs);
    end;

  if Good > 0 then
    lblStats.Text := Format('Runs %d   Best %s   Avg %s   Red %d',
      [FResults.Count, FormatSecs(Best), FormatSecs(Sum / Good), Fouls])
  else
    lblStats.Text := Format('Runs %d   Best -.---   Avg -.---   Red %d',
      [FResults.Count, Fouls]);

  Lines := TStringBuilder.Create;
  try
    I := FResults.Count - 1;
    while (I >= 0) and (I >= FResults.Count - HistoryLines) do
    begin
      R := FResults[I];
      Lines.Append(Format('#%d  %s', [I + 1, FormatSecs(R.ReactionMs)]));
      if R.Mode = tmSportsman then
        Lines.Append(' S');
      if R.Foul then
        Lines.Append(' R');
      if R.Bogged then
        Lines.Append(' B');
      Lines.Append(sLineBreak);
      if R.Finished or (R.Outcome <> ocNone) then
      begin
        if R.Finished then
          Lines.Append('   ' + Format('%.2f', [R.ET], TFormatSettings.Invariant))
        else
          Lines.Append('   DNF');
        case R.Outcome of
          ocWin: Lines.Append(' W');
          ocLoss: Lines.Append(' L');
          ocTie: Lines.Append(' T');
        end;
        Lines.Append(sLineBreak);
      end;
      Dec(I);
    end;
    lblHistory.Text := Lines.ToString;
  finally
    Lines.Free;
  end;
end;

procedure TfrmMain.btnStartClick(Sender: TObject);
begin
  StartRun;
end;

procedure TfrmMain.btnStopClick(Sender: TObject);
begin
  if FRunning then
    StopRun('Stopped');
end;

procedure TfrmMain.btnResetClick(Sender: TObject);
begin
  ResetTree;
end;

procedure TfrmMain.btnClearClick(Sender: TObject);
begin
  FResults.Clear;
  ResetTree;
  UpdateStats;
end;

procedure TfrmMain.pbTreePaint(Sender: TObject; Canvas: TCanvas);
const
  Rows = 7;        // pre-stage, stage, amber x3, green, red
  LabelH = 22;
  TrackFrac = 0.30; // share of the height used for the staging view
  ViewBackIn = -36; // track window, inches relative to the pre-stage beam
  ViewFwdIn = 22;
var
  W, H, TreeH, RowH, R, SmallR, TrackTop, TrackBottom, Scale, LaneW: Single;
  LaneX: array[0..1] of Single;
  Lane, I: Integer;
  T: Double;
  State: TCanvasSaveState;

  function RowY(Row: Integer): Single;
  begin
    Result := LabelH + 6 + RowH * (Row + 0.5);
  end;

  function InchY(Inches: Double): Single;
  begin
    Result := TrackBottom - (Inches - ViewBackIn) * Scale;
  end;

  procedure Bulb(CX, CY, Radius: Single; Color: TAlphaColor; Lit: Boolean);
  begin
    Canvas.Fill.Kind := TBrushKind.Solid;
    if Lit then
    begin
      // soft glow, then the lens, then a highlight
      Canvas.Fill.Color := Color;
      Canvas.FillEllipse(RectF(CX - Radius * 1.6, CY - Radius * 1.6,
        CX + Radius * 1.6, CY + Radius * 1.6), 0.12);
      Canvas.FillEllipse(RectF(CX - Radius * 1.25, CY - Radius * 1.25,
        CX + Radius * 1.25, CY + Radius * 1.25), 0.25);
      Canvas.FillEllipse(RectF(CX - Radius, CY - Radius,
        CX + Radius, CY + Radius), 1);
      Canvas.Fill.Color := TAlphaColors.White;
      Canvas.FillEllipse(RectF(CX - Radius * 0.55, CY - Radius * 0.6,
        CX - Radius * 0.05, CY - Radius * 0.15), 0.55);
    end
    else
    begin
      Canvas.Fill.Color := DimColor(Color, 0.16);
      Canvas.FillEllipse(RectF(CX - Radius, CY - Radius,
        CX + Radius, CY + Radius), 1);
    end;
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := clrRim;
    Canvas.Stroke.Thickness := Max(2.0, Radius * 0.12);
    Canvas.DrawEllipse(RectF(CX - Radius, CY - Radius,
      CX + Radius, CY + Radius), 1);
  end;

  procedure LabelText(const ARect: TRectF; const S: string; Color: TAlphaColor;
    Size: Single);
  begin
    Canvas.Font.Size := Size;
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := Color;
    Canvas.FillText(ARect, S, False, 1, [], TTextAlign.Center, TTextAlign.Center);
  end;

  procedure DrawCar(CX: Single; Pos: Double; Body: TAlphaColor);
  var
    FrontY, HalfW, TyreW, TyreL: Single;
  begin
    // top-down view, car pointing up the track; Pos is the front tyre edge
    FrontY := InchY(Pos);
    HalfW := LaneW * 0.30;
    TyreW := HalfW * 0.35;
    TyreL := 26 * Scale;
    Canvas.Fill.Kind := TBrushKind.Solid;
    // nose ahead of the front tyres, body running back off the view
    Canvas.Fill.Color := Body;
    Canvas.FillRect(RectF(CX - HalfW * 0.45, FrontY - 14 * Scale,
      CX + HalfW * 0.45, FrontY + 200 * Scale), HalfW * 0.3, HalfW * 0.3,
      AllCorners, 1);
    Canvas.FillRect(RectF(CX - HalfW * 0.75, FrontY + TyreL * 0.5,
      CX + HalfW * 0.75, FrontY + 200 * Scale), 4, 4, AllCorners, 1);
    // front tyres
    Canvas.Fill.Color := TAlphaColor($FF0A0A0A);
    Canvas.FillRect(RectF(CX - HalfW, FrontY, CX - HalfW + TyreW, FrontY + TyreL),
      2, 2, AllCorners, 1);
    Canvas.FillRect(RectF(CX + HalfW - TyreW, FrontY, CX + HalfW, FrontY + TyreL),
      2, 2, AllCorners, 1);
  end;

  procedure Beam(CX: Single; Inches: Double; Lit: Boolean; const Name: string;
    ShowName: Boolean);
  var
    Y: Single;
  begin
    Y := InchY(Inches);
    Canvas.Stroke.Kind := TBrushKind.Solid;
    if Lit then
      Canvas.Stroke.Color := clrStage
    else
      Canvas.Stroke.Color := TAlphaColor($FF8A8A8A);
    Canvas.Stroke.Thickness := 2;
    Canvas.DrawLine(PointF(CX - LaneW * 0.48, Y), PointF(CX + LaneW * 0.48, Y), 1);
    if ShowName then
      LabelText(RectF(0, Y - 8, CX - LaneW * 0.48, Y + 8), Name, clrSubtle, 10);
  end;

  procedure DrawTrack;
  const
    TopGap = 16;    // lane readouts above the finish line
    BottomGap = 6;
  var
    FinishM, MScale, StartY, Y, CarH, D: Double;
    Sp: TSplit;
    Ln: Integer;
    Txt: string;

    function MetreY(M: Double): Single;
    begin
      Result := StartY - EnsureRange(M, 0.0, FinishM) * MScale;
    end;

  begin
    FinishM := SplitM[RaceSplit[FRaceLength]];
    StartY := TrackBottom - BottomGap;
    MScale := (StartY - TrackTop - TopGap) / FinishM;
    CarH := LaneW * 0.25;
    if CarH < 6 then
      CarH := 6
    else if CarH > 14 then
      CarH := 14;
    for Ln := 0 to 1 do
    begin
      Canvas.Fill.Kind := TBrushKind.Solid;
      Canvas.Fill.Color := clrTrack;
      Canvas.FillRect(RectF(LaneX[Ln] - LaneW * 0.5, TrackTop + TopGap,
        LaneX[Ln] + LaneW * 0.5, TrackBottom), 0, 0, AllCorners, 1);
      // timing marks, then the start and finish lines
      Canvas.Stroke.Kind := TBrushKind.Solid;
      Canvas.Stroke.Thickness := 1;
      Canvas.Stroke.Color := TAlphaColor($FF6A6A6A);
      for Sp := Low(TSplit) to Pred(RaceSplit[FRaceLength]) do
      begin
        Y := MetreY(SplitM[Sp]);
        Canvas.DrawLine(PointF(LaneX[Ln] - LaneW * 0.5, Y),
          PointF(LaneX[Ln] + LaneW * 0.5, Y), 1);
      end;
      Canvas.Stroke.Color := TAlphaColors.White;
      Canvas.Stroke.Thickness := 3;
      Canvas.DrawLine(PointF(LaneX[Ln] - LaneW * 0.5, MetreY(FinishM)),
        PointF(LaneX[Ln] + LaneW * 0.5, MetreY(FinishM)), 1);
      Canvas.Stroke.Thickness := 2;
      Canvas.DrawLine(PointF(LaneX[Ln] - LaneW * 0.5, StartY),
        PointF(LaneX[Ln] + LaneW * 0.5, StartY), 1);

      // the car: its nose at the distance it has covered
      D := 0;
      if FCars[Ln].Launched then
        D := FRuns[Ln].DistFromLine;
      Y := MetreY(D);
      Canvas.Fill.Kind := TBrushKind.Solid;
      if Ln = FUserLane then
        Canvas.Fill.Color := clrYou
      else
        Canvas.Fill.Color := clrOpponent;
      Canvas.FillRect(RectF(LaneX[Ln] - LaneW * 0.2, Y, LaneX[Ln] + LaneW * 0.2,
        Y + CarH * 1.6), 3, 3, AllCorners, 1);

      // above the lane: speed on the way, the elapsed time at the end
      if FRuns[Ln].State = rsFinished then
        Txt := FormatET(FRuns[Ln].ET)
      else if FCars[Ln].Launched then
        Txt := SpeedText(FRuns[Ln].Speed)
      else
        Txt := '';
      LabelText(RectF(LaneX[Ln] - LaneW * 0.5, TrackTop, LaneX[Ln] + LaneW * 0.5,
        TrackTop + TopGap), Txt, clrText, 11);
    end;
    LabelText(RectF(0, TrackTop + TopGap - 2, LaneX[0] - LaneW * 0.5,
      TrackTop + TopGap + 12), RaceLengthNames[FRaceLength], clrSubtle, 9);
  end;

begin
  W := pbTree.Width;
  H := pbTree.Height;
  if (W < 40) or (H < 80) then
    Exit;
  T := NowMs;

  TreeH := H * (1 - TrackFrac);
  RowH := (TreeH - LabelH - 12) / Rows;
  LaneX[0] := W * 0.31;
  LaneX[1] := W * 0.69;
  LaneW := W * 0.36;
  R := Min(W * 0.13, RowH * 0.42);
  SmallR := R * 0.42;

  // ----- tree -----
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := clrHousing;
  Canvas.FillRect(RectF(W * 0.5 - 6, LabelH, W * 0.5 + 6, TreeH), 0, 0,
    AllCorners, 1);

  for Lane := 0 to 1 do
  begin
    // lane label: YOU in blue over your lane, the win light once decided
    if (FWinLane = Lane) or (FWinLane = 2) then
    begin
      Canvas.Fill.Kind := TBrushKind.Solid;
      Canvas.Fill.Color := clrStage;
      Canvas.FillRect(RectF(LaneX[Lane] - R * 1.6, 1, LaneX[Lane] + R * 1.6,
        LabelH - 1), 6, 6, AllCorners, 0.9);
      if FWinLane = 2 then
        LabelText(RectF(LaneX[Lane] - R * 2, 0, LaneX[Lane] + R * 2, LabelH),
          'TIE', clrBackground, 14)
      else if Lane = FUserLane then
        LabelText(RectF(LaneX[Lane] - R * 2, 0, LaneX[Lane] + R * 2, LabelH),
          'YOU WIN', clrBackground, 14)
      else
        LabelText(RectF(LaneX[Lane] - R * 2, 0, LaneX[Lane] + R * 2, LabelH),
          'WIN', clrBackground, 14);
    end
    else if Lane = FUserLane then
      LabelText(RectF(LaneX[Lane] - R * 2, 0, LaneX[Lane] + R * 2, LabelH),
        'YOU', clrYou, 15)
    else
      LabelText(RectF(LaneX[Lane] - R * 2, 0, LaneX[Lane] + R * 2, LabelH),
        'OTHER LANE', clrSubtle, 11);

    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := clrHousing;
    Canvas.FillRect(RectF(LaneX[Lane] - R * 1.6, LabelH + 2, LaneX[Lane] + R * 1.6,
      TreeH - 2), R * 0.6, R * 0.6, AllCorners, 1);
    if Lane = FUserLane then
    begin
      Canvas.Stroke.Kind := TBrushKind.Solid;
      Canvas.Stroke.Color := clrYou;
      Canvas.Stroke.Thickness := 2;
      Canvas.DrawRect(RectF(LaneX[Lane] - R * 1.6, LabelH + 2,
        LaneX[Lane] + R * 1.6, TreeH - 2), R * 0.6, R * 0.6, AllCorners, 1);
    end;

    // pre-stage and stage are pairs of small bulbs
    Bulb(LaneX[Lane] - SmallR * 1.3, RowY(0), SmallR, clrStage, PreStageLit(Lane));
    Bulb(LaneX[Lane] + SmallR * 1.3, RowY(0), SmallR, clrStage, PreStageLit(Lane));
    Bulb(LaneX[Lane] - SmallR * 1.3, RowY(1), SmallR, clrStage, StageLit(Lane));
    Bulb(LaneX[Lane] + SmallR * 1.3, RowY(1), SmallR, clrStage, StageLit(Lane));

    for I := 0 to 2 do
      Bulb(LaneX[Lane], RowY(2 + I), R, clrAmber, AmberLit(I, T));

    Bulb(LaneX[Lane], RowY(5), R, clrGreen, GreenLit(Lane, T));
    Bulb(LaneX[Lane], RowY(6), R, clrRed, (Lane = FUserLane) and FRedLit);
  end;

  // ----- staging view, then the whole track once you have gone -----
  TrackTop := TreeH + 8;
  TrackBottom := H;
  Scale := (TrackBottom - TrackTop) / (ViewFwdIn - ViewBackIn);
  if FUserLaunched then
  begin
    DrawTrack;
    Exit;
  end;

  State := Canvas.SaveState;
  try
    Canvas.IntersectClipRect(RectF(0, TrackTop, W, TrackBottom));
    for Lane := 0 to 1 do
    begin
      Canvas.Fill.Kind := TBrushKind.Solid;
      Canvas.Fill.Color := clrTrack;
      Canvas.FillRect(RectF(LaneX[Lane] - LaneW * 0.5, TrackTop,
        LaneX[Lane] + LaneW * 0.5, TrackBottom), 0, 0, AllCorners, 1);
      // "too far" zone past the stage beam
      Canvas.Fill.Color := clrRed;
      Canvas.FillRect(RectF(LaneX[Lane] - LaneW * 0.5, InchY(ViewFwdIn),
        LaneX[Lane] + LaneW * 0.5, InchY(TooFarIn)), 0, 0, AllCorners, 0.18);

      Beam(LaneX[Lane], 0, PreStageLit(Lane), 'PRE', Lane = 0);
      Beam(LaneX[Lane], StageBeamIn, StageLit(Lane), 'STAGE', Lane = 0);

      if Lane = FUserLane then
        DrawCar(LaneX[Lane], FCars[Lane].Pos, clrYou)
      else
        DrawCar(LaneX[Lane], FCars[Lane].Pos, clrOpponent);
    end;
  finally
    Canvas.RestoreState(State);
  end;
end;

end.
