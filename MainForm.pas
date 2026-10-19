unit MainForm;

{ Drag racing tree reaction time trainer.

  A run:
    START  -> both cars roll up to the beams. The pre-stage bulb lights when
              the front tyre breaks the pre-stage beam, the stage bulb when it
              breaks the stage beam (7 in further on).
           -> once both lanes are staged and you are holding the car on the
              brake (and clutch, with a manual gearbox), a random wait
              (0.8 to 3.0 s)
           -> countdown:
                Pro tree:       all three ambers together, green 0.400 s later
                Sportsman tree: ambers one after another 0.500 s apart,
                                green 0.500 s after the last amber
  You launch by letting the car go: release the brake (automatic gearbox) or
  release both brake and clutch (manual gearbox).
  Reaction time = release time - time the green is due.
  0.000 is a perfect light; anything below zero is a red light.

  Pedals are on-screen pads used with several fingers at once:
    BRAKE    always. Hold to stop, ease off to creep (manual staging).
    CLUTCH   with a manual gearbox. Must be held in to stage.
    THROTTLE with manual throttle. Hold for full throttle; launching without
             it bogs the car.
  Without multi-touch (a mouse on Windows) only the brake is used. On Windows
  the space bar is also the brake.

  Rolling right through the stage beam is "too far forward" and ends the run. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Diagnostics, System.Generics.Collections, System.IOUtils,
  System.IniFiles,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Objects, FMX.StdCtrls,
  FMX.Layouts, FMX.Controls.Presentation;

const
  ProAmberMs: Double = 400.0;   // Pro tree: ambers to green
  SportAmberMs: Double = 500.0; // Sportsman tree: gap between each amber and green
  AutoStartMinMs = 800;     // random wait after both lanes are staged
  AutoStartRandMs = 2200;
  HistoryLines = 20;

  // Staging geometry in inches, measured from the pre-stage beam to the
  // leading edge of the front tyre. Positive is forward.
  StageBeamIn: Double = 7.0;    // stage beam is 7 in past the pre-stage beam
  PreStageOffIn: Double = 11.0; // deep staging: pre-stage bulb goes out
  TooFarIn: Double = 16.0;      // tyre has rolled right through the stage beam
  AutoStageIn: Double = 8.5;    // where auto staging stops (shallow stage)
  CarStartIn: Double = -40.0;
  OffScreenIn: Double = 240.0;

type
  TTreeMode = (tmPro, tmSportsman);
  TStageMode = (smAuto, smManual);
  TTransMode = (trAuto, trManual);
  TThrottleMode = (thAuto, thManual);
  TTreePhase = (tpIdle, tpStaging, tpWaiting, tpCountdown, tpGreen);
  TPedal = (pdClutch, pdBrake, pdThrottle);
  TPedals = set of TPedal;
  TSetting = (stTree, stLane, stStaging, stTrans, stThrottle);

  TRunResult = record
    ReactionMs: Double;
    Foul: Boolean;
    BeforeTree: Boolean;   // left before the countdown had even started
    Bogged: Boolean;       // launched with the throttle closed
    Mode: TTreeMode;
  end;

  TCar = record
    Pos: Double;           // inches, see the geometry constants above
    Speed: Double;         // inches per second
    Launched: Boolean;
    RollAtMs: Double;      // opponent only: when it starts rolling in
    LaunchAtMs: Double;    // opponent only: when it will leave
  end;

  TfrmMain = class(TForm)
    layTop: TLayout;
    lblReaction: TLabel;
    lblVerdict: TLabel;
    lblStats: TLabel;
    layOptions: TLayout;
    btnSettings: TButton;
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
    btnStart: TButton;
    btnStop: TButton;
    btnReset: TButton;
    btnClear: TButton;
    tmrTree: TTimer;
    procedure FormCreate(Sender: TObject);
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

    // settings screen
    FSettingsPanel: TRectangle;
    FSettingButtons: array[TSetting] of TButton;

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
    procedure CreatePads;
    procedure CreateSettingsPanel;
    procedure SettingButtonClick(Sender: TObject);
    procedure SettingsDoneClick(Sender: TObject);
    procedure UpdateSettingsTexts;
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
    procedure ShowResult(const R: TRunResult);
    procedure SetVerdict(const Text: string; Color: TAlphaColor);
    procedure UpdateHint;
    procedure UpdateStats;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

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

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Randomize;
  FResults := TList<TRunResult>.Create;
  FWatch := TStopwatch.StartNew;
  FMultiTouch := HasMultiTouch;
  LoadSettings;
  ApplyLook;
  CreatePads;
  CreateSettingsPanel;
  ResetTree;
  UpdateStats;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FResults.Free;
end;

procedure TfrmMain.LoadSettings;
var
  Ini: TMemIniFile;
  FileName: string;
begin
  FTreeMode := tmPro;
  FStageMode := smAuto;
  FTransMode := trAuto;
  FThrottleMode := thAuto;
  FUserLane := 0;
  FileName := SettingsFile;
  if (FileName = '') or not System.IOUtils.TFile.Exists(FileName) then
    Exit;
  try
    Ini := TMemIniFile.Create(FileName);
    try
      FTreeMode := TTreeMode(EnsureRange(Ini.ReadInteger('Options', 'Tree', 0),
        Ord(Low(TTreeMode)), Ord(High(TTreeMode))));
      FStageMode := TStageMode(EnsureRange(Ini.ReadInteger('Options', 'Staging', 0),
        Ord(Low(TStageMode)), Ord(High(TStageMode))));
      FTransMode := TTransMode(EnsureRange(Ini.ReadInteger('Options', 'Trans', 0),
        Ord(Low(TTransMode)), Ord(High(TTransMode))));
      FThrottleMode := TThrottleMode(EnsureRange(Ini.ReadInteger('Options', 'Throttle', 0),
        Ord(Low(TThrottleMode)), Ord(High(TThrottleMode))));
      FUserLane := EnsureRange(Ini.ReadInteger('Options', 'Lane', 0), 0, 1);
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
  // ready to start the tree: on the brake, and clutch in with a manual box
  Result := (pdBrake in S) and ((EffTrans = trAuto) or (pdClutch in S));
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

    FPadLabels[P] := TLabel.Create(Self);
    FPadLabels[P].Parent := FPads[P];
    FPadLabels[P].Align := TAlignLayout.Client;
    FPadLabels[P].Text := PedalNames[P];
    StyleLabel(FPadLabels[P], 18, clrText, True, TTextAlign.Center);
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

  // Letting the car go once the tree is running is the launch
  if FRunning and not FUserLaunched
    and (FPhase in [tpWaiting, tpCountdown, tpGreen])
    and CarHeld(Old) and not CarHeld(New) then
    Launch(T);

  UpdateHint;
end;

{ ---- settings screen ---- }

procedure TfrmMain.CreateSettingsPanel;
const
  RowH = 52;
var
  Box: TLayout;
  Title: TLabel;
  Done: TButton;
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
    FSettingButtons[S] := TButton.Create(Self);
    FSettingButtons[S].Parent := Box;
    FSettingButtons[S].Align := TAlignLayout.Top;
    FSettingButtons[S].Position.Y := RowH * (Ord(S) + 1); // keeps the order
    FSettingButtons[S].Height := RowH - 8;
    FSettingButtons[S].Margins.Bottom := 8;
    FSettingButtons[S].Tag := Ord(S);
    FSettingButtons[S].CanFocus := False;
    FSettingButtons[S].OnClick := SettingButtonClick;
  end;

  Done := TButton.Create(Self);
  Done.Parent := Box;
  Done.Align := TAlignLayout.Top;
  Done.Position.Y := RowH * (Ord(High(TSetting)) + 2);
  Done.Height := RowH - 8;
  Done.Margins.Top := 8;
  Done.Text := 'Done';
  Done.CanFocus := False;
  Done.OnClick := SettingsDoneClick;

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

  Summary := Format('%s tree, %s lane, %s staging', [TreeNames[FTreeMode],
    LowerCase(LaneNames[FUserLane]), LowerCase(StageNames[FStageMode])]);
  if FMultiTouch then
    Summary := Summary + Format(', %s trans, %s throttle',
      [LowerCase(TransNames[EffTrans]), LowerCase(ThrottleNames[EffThrottle])])
  else
    Summary := Summary + ', brake only';
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
  end;
  SaveSettings;
  UpdateSettingsTexts;
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

  // Buttons must not take focus, otherwise the space bar "clicks" them
  btnStart.CanFocus := False;
  btnStop.CanFocus := False;
  btnReset.CanFocus := False;
  btnClear.CanFocus := False;
  btnSettings.CanFocus := False;
end;

procedure TfrmMain.layButtonsResize(Sender: TObject);
var
  W: Single;
begin
  W := layButtons.Width / 4 - btnStart.Margins.Left - btnStart.Margins.Right;
  btnStart.Width := W;
  btnStop.Width := W;
  btnReset.Width := W;
  btnClear.Width := W;
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
  FBogged := False;
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
  LaunchAccel: Double = 900.0; // in/s^2, a bit over 2 g
  BogAccel: Double = 60.0;     // throttle closed: barely moving
  AutoRollIn: Double = 40.0;   // fast roll-in speed, in/s
  CreepIn: Double = 4.0;       // creeping speed near the beams, in/s
  MinSpeed: Double = 2.0;
var
  Lane: Integer;
  Auto: Boolean;
  Gap, Step, Accel: Double;
begin
  for Lane := 0 to 1 do
  begin
    if FCars[Lane].Launched then
    begin
      if FCars[Lane].Pos < OffScreenIn then
      begin
        Accel := LaunchAccel;
        if (Lane = FUserLane) and not ThrottleOpen then
          Accel := BogAccel;
        FCars[Lane].Speed := FCars[Lane].Speed + Accel * Dt;
        FCars[Lane].Pos := FCars[Lane].Pos + FCars[Lane].Speed * Dt;
      end;
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
          FCars[Opp].LaunchAtMs := GreenDueMs + 120 + Random(180);
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

  // the other lane leaves on its own green
  if (FPhase = tpGreen) and not FCars[Opp].Launched
    and (T >= FCars[Opp].LaunchAtMs) then
    FCars[Opp].Launched := True;

  // finished once both cars are away
  if FUserLaunched and (FPhase = tpGreen)
    and (FCars[FUserLane].Pos >= OffScreenIn)
    and (FCars[Opp].Pos >= OffScreenIn) then
  begin
    tmrTree.Enabled := False;
    FRunning := False;
    btnSettings.Enabled := True;
    UpdateHint;
  end;

  pbTree.Repaint;
end;

procedure TfrmMain.Launch(ReleaseMs: Double);
var
  R: TRunResult;
begin
  if not FRunning or FUserLaunched then
    Exit;

  FUserLaunched := True;
  FCars[FUserLane].Launched := True;
  FBogged := not ThrottleOpen;
  R.Mode := FTreeMode;
  R.BeforeTree := FPhase = tpWaiting;
  R.ReactionMs := ReleaseMs - GreenDueMs;
  R.Foul := R.ReactionMs < 0;
  R.Bogged := FBogged;

  // A red light lights your red bulb; the tree carries on for the other lane
  if R.Foul then
    FRedLit := True;

  FResults.Add(R);
  ShowResult(R);
  UpdateStats;
  UpdateHint;
  pbTree.Repaint;
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
    Need := 'hold BRAKE + CLUTCH'
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
    lblHint.Text := 'Release BRAKE and CLUTCH to launch'
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
    // lane label: YOU in blue over your lane
    if Lane = FUserLane then
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

  // ----- staging view -----
  TrackTop := TreeH + 8;
  TrackBottom := H;
  Scale := (TrackBottom - TrackTop) / (ViewFwdIn - ViewBackIn);

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
