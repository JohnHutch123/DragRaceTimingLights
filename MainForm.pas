unit MainForm;

{ Drag racing tree reaction time trainer.

  A run:
    START  -> both cars roll up to the beams. The pre-stage bulb lights when
              the front tyre breaks the pre-stage beam, the stage bulb when it
              breaks the stage beam (7 in further on).
           -> once both lanes are staged, a random wait (0.8 to 3.0 s)
           -> countdown:
                Pro tree:       all three ambers together, green 0.400 s later
                Sportsman tree: ambers one after another 0.500 s apart,
                                green 0.500 s after the last amber
  Reaction time = launch tap time - time the green is due.
  0.000 is a perfect light; anything below zero is a red light.

  Staging can be automatic, or manual: hold the launch pad to creep forward
  and let go once staged. Rolling right through the stage beam is
  "too far forward" and ends the run. }

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
  TTreePhase = (tpIdle, tpStaging, tpWaiting, tpCountdown, tpGreen);

  TRunResult = record
    ReactionMs: Double;
    Foul: Boolean;
    BeforeTree: Boolean;   // left before the countdown had even started
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
    btnTreeMode: TButton;
    btnLane: TButton;
    btnStaging: TButton;
    layMiddle: TLayout;
    pbTree: TPaintBox;
    rectHistory: TRectangle;
    lblHistoryTitle: TLabel;
    lblHistory: TLabel;
    rectLaunch: TRectangle;
    lblLaunch: TLabel;
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
    procedure pbTreePaint(Sender: TObject; Canvas: TCanvas);
    procedure tmrTreeTimer(Sender: TObject);
    procedure rectLaunchMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure rectLaunchMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure rectLaunchMouseLeave(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnResetClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnTreeModeClick(Sender: TObject);
    procedure btnLaneClick(Sender: TObject);
    procedure btnStagingClick(Sender: TObject);
    procedure layButtonsResize(Sender: TObject);
    procedure layOptionsResize(Sender: TObject);
  private
    FWatch: TStopwatch;
    FLastTickMs: Double;
    FTreeMode: TTreeMode;
    FStageMode: TStageMode;
    FUserLane: Integer;          // 0 = left, 1 = right
    FPhase: TTreePhase;
    FRunning: Boolean;
    FCreeping: Boolean;          // manual staging: launch pad held
    FCountdownMs: Double;        // when the first amber lights
    FCars: array[0..1] of TCar;  // indexed by lane
    FRedLit: Boolean;            // red bulb in the user's lane
    FUserLaunched: Boolean;
    FResults: TList<TRunResult>;
    function NowMs: Double;
    function GreenDueMs: Double;
    function OppLane: Integer;
    function PreStageLit(Lane: Integer): Boolean;
    function StageLit(Lane: Integer): Boolean;
    function AmberLit(Index: Integer; T: Double): Boolean;
    function GreenLit(Lane: Integer; T: Double): Boolean;
    procedure StyleLabel(L: TLabel; Size: Single; Color: TAlphaColor;
      Bold: Boolean; Align: TTextAlign);
    procedure ApplyLook;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure UpdateOptionButtons;
    procedure ResetTree;
    procedure StartRun;
    procedure StopRun(const Msg: string);
    procedure MoveCars(T, Dt: Double);
    procedure Launch(TapMs: Double);
    procedure ShowResult(const R: TRunResult);
    procedure SetVerdict(const Text: string; Color: TAlphaColor);
    procedure UpdateLaunchText;
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

  LaneNames: array[0..1] of string = ('Left', 'Right');
  TreeNames: array[TTreeMode] of string = ('Pro', 'Sportsman');
  StageNames: array[TStageMode] of string = ('Auto', 'Manual');

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
begin
  Result := TPath.Combine(TPath.GetDocumentsPath, 'DragTree.ini');
end;

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Randomize;
  FResults := TList<TRunResult>.Create;
  FWatch := TStopwatch.StartNew;
  LoadSettings;
  ApplyLook;
  UpdateOptionButtons;
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
begin
  FTreeMode := tmPro;
  FStageMode := smAuto;
  FUserLane := 0;
  try
    Ini := TMemIniFile.Create(SettingsFile);
    try
      FTreeMode := TTreeMode(EnsureRange(Ini.ReadInteger('Options', 'Tree', 0),
        Ord(Low(TTreeMode)), Ord(High(TTreeMode))));
      FStageMode := TStageMode(EnsureRange(Ini.ReadInteger('Options', 'Staging', 0),
        Ord(Low(TStageMode)), Ord(High(TStageMode))));
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
begin
  try
    Ini := TMemIniFile.Create(SettingsFile);
    try
      Ini.WriteInteger('Options', 'Tree', Ord(FTreeMode));
      Ini.WriteInteger('Options', 'Staging', Ord(FStageMode));
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
  StyleLabel(lblHistoryTitle, 14, clrSubtle, True, TTextAlign.Center);
  StyleLabel(lblHistory, 14, clrText, False, TTextAlign.Leading);
  lblHistory.TextSettings.VertAlign := TTextAlign.Leading;
  lblHistory.WordWrap := True;
  StyleLabel(lblLaunch, 22, clrText, True, TTextAlign.Center);
  lblLaunch.WordWrap := True;

  rectHistory.Fill.Kind := TBrushKind.Solid;
  rectHistory.Fill.Color := clrPanel;
  rectHistory.Stroke.Kind := TBrushKind.None;

  rectLaunch.Fill.Kind := TBrushKind.Solid;
  rectLaunch.Fill.Color := TAlphaColor($FF2C2C2C);
  rectLaunch.Stroke.Kind := TBrushKind.Solid;
  rectLaunch.Stroke.Color := TAlphaColor($FF4A4A4A);
  rectLaunch.Stroke.Thickness := 2;

  // Buttons must not take focus, otherwise the space bar "clicks" them
  btnStart.CanFocus := False;
  btnStop.CanFocus := False;
  btnReset.CanFocus := False;
  btnClear.CanFocus := False;
  btnTreeMode.CanFocus := False;
  btnLane.CanFocus := False;
  btnStaging.CanFocus := False;
end;

procedure TfrmMain.UpdateOptionButtons;
begin
  btnTreeMode.Text := 'Tree: ' + TreeNames[FTreeMode];
  btnLane.Text := 'Lane: ' + LaneNames[FUserLane];
  btnStaging.Text := 'Stage: ' + StageNames[FStageMode];
  btnTreeMode.Enabled := not FRunning;
  btnLane.Enabled := not FRunning;
  btnStaging.Enabled := not FRunning;
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

procedure TfrmMain.layOptionsResize(Sender: TObject);
var
  W: Single;
begin
  W := layOptions.Width / 3 - btnTreeMode.Margins.Left - btnTreeMode.Margins.Right;
  btnTreeMode.Width := W;
  btnLane.Width := W;
  btnStaging.Width := W;
end;

procedure TfrmMain.SetVerdict(const Text: string; Color: TAlphaColor);
begin
  lblVerdict.Text := Text;
  lblVerdict.TextSettings.FontColor := Color;
end;

procedure TfrmMain.ResetTree;
var
  Lane: Integer;
begin
  tmrTree.Enabled := False;
  FPhase := tpIdle;
  FRunning := False;
  FCreeping := False;
  FRedLit := False;
  FUserLaunched := False;
  for Lane := 0 to 1 do
  begin
    FCars[Lane] := Default(TCar);
    FCars[Lane].Pos := CarStartIn;
  end;
  lblReaction.Text := '-.---';
  lblReaction.TextSettings.FontColor := clrText;
  SetVerdict('Press START to stage', clrSubtle);
  UpdateLaunchText;
  UpdateOptionButtons;
  pbTree.Repaint;
end;

procedure TfrmMain.StartRun;
begin
  ResetTree;
  FRunning := True;
  FPhase := tpStaging;
  // the other car starts rolling a moment later
  FCars[OppLane].RollAtMs := NowMs + 300;
  FLastTickMs := NowMs;
  if FStageMode = smManual then
    SetVerdict('Hold the pad to creep in', clrSubtle)
  else
    SetVerdict('Staging...', clrSubtle);
  UpdateLaunchText;
  UpdateOptionButtons;
  tmrTree.Enabled := True;
  pbTree.Repaint;
end;

procedure TfrmMain.StopRun(const Msg: string);
begin
  tmrTree.Enabled := False;
  FPhase := tpIdle;
  FRunning := False;
  FCreeping := False;
  SetVerdict(Msg, clrSubtle);
  UpdateLaunchText;
  UpdateOptionButtons;
  pbTree.Repaint;
end;

procedure TfrmMain.MoveCars(T, Dt: Double);
const
  LaunchAccel: Double = 900.0; // in/s^2, a bit over 2 g
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
      if FCars[Lane].Pos < OffScreenIn then
      begin
        FCars[Lane].Speed := FCars[Lane].Speed + LaunchAccel * Dt;
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
    else if FCreeping then
    begin
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

  MoveCars(T, Dt);

  case FPhase of
    tpStaging:
      begin
        if not FUserLaunched and (FCars[FUserLane].Pos >= TooFarIn) then
        begin
          FRedLit := True;
          StopRun('TOO FAR FORWARD - press Reset');
          lblVerdict.TextSettings.FontColor := clrRed;
          Exit;
        end;
        if not FUserLaunched then
        begin
          if StageLit(FUserLane) and not PreStageLit(FUserLane) then
            SetVerdict('Deep staged', clrAmber)
          else if StageLit(FUserLane) then
            SetVerdict('Staged', clrSubtle)
          else if PreStageLit(FUserLane) then
            SetVerdict('Pre-staged', clrSubtle);
        end;
        // the tree starts once both lanes are staged and settled
        if StageLit(FUserLane) and not FCreeping
          and ((FStageMode = smManual) or (FCars[FUserLane].Pos >= AutoStageIn))
          and StageLit(Opp) and (FCars[Opp].Pos >= AutoStageIn) then
        begin
          FPhase := tpWaiting;
          FCountdownMs := T + AutoStartMinMs + Random(AutoStartRandMs);
          FCars[Opp].LaunchAtMs := GreenDueMs + 120 + Random(180);
          UpdateLaunchText;
        end;
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

  // finished once your car is away and, if the tree ran, the other car too.
  // Leaving during staging means the tree never starts.
  if FUserLaunched and (FCars[FUserLane].Pos >= OffScreenIn)
    and ((FPhase = tpStaging)
      or ((FPhase = tpGreen) and (FCars[Opp].Pos >= OffScreenIn))) then
  begin
    tmrTree.Enabled := False;
    FRunning := False;
    UpdateLaunchText;
    UpdateOptionButtons;
  end;

  pbTree.Repaint;
end;

procedure TfrmMain.rectLaunchMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var
  T: Double;
begin
  T := NowMs; // timestamp first
  if (FStageMode = smManual) and (FPhase = tpStaging) and not FUserLaunched then
  begin
    FCreeping := True;
    rectLaunch.Fill.Color := TAlphaColor($FF3A3A3A);
  end
  else
    Launch(T);
end;

procedure TfrmMain.rectLaunchMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  FCreeping := False;
  rectLaunch.Fill.Color := TAlphaColor($FF2C2C2C);
end;

procedure TfrmMain.rectLaunchMouseLeave(Sender: TObject);
begin
  FCreeping := False;
  rectLaunch.Fill.Color := TAlphaColor($FF2C2C2C);
end;

procedure TfrmMain.FormKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: WideChar; Shift: TShiftState);
begin
  // Desktop testing: Space launches (or creeps in manual staging),
  // Enter starts a run
  if KeyChar = ' ' then
  begin
    rectLaunchMouseDown(Self, TMouseButton.mbLeft, [], 0, 0);
    KeyChar := #0;
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
    rectLaunchMouseUp(Self, TMouseButton.mbLeft, [], 0, 0);
end;

procedure TfrmMain.Launch(TapMs: Double);
var
  R: TRunResult;
begin
  if not FRunning or FUserLaunched then
    Exit;

  FUserLaunched := True;
  FCars[FUserLane].Launched := True;
  R.Mode := FTreeMode;
  R.BeforeTree := FPhase in [tpStaging, tpWaiting];
  if FPhase = tpStaging then
    R.ReactionMs := NaN
  else
    R.ReactionMs := TapMs - GreenDueMs;
  R.Foul := R.BeforeTree or (R.ReactionMs < 0);

  // A red light lights your red bulb; the tree carries on for the other lane
  if R.Foul then
    FRedLit := True;

  FResults.Add(R);
  ShowResult(R);
  UpdateStats;
  UpdateLaunchText;
  pbTree.Repaint;
end;

procedure TfrmMain.ShowResult(const R: TRunResult);
var
  Verdict: string;
  Color: TAlphaColor;
begin
  if IsNan(R.ReactionMs) then
    lblReaction.Text := '-.---'
  else
    lblReaction.Text := FormatSecs(R.ReactionMs);
  if R.Foul then
  begin
    if R.BeforeTree and IsNan(R.ReactionMs) then
      Verdict := 'RED LIGHT - left before staging'
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
  lblReaction.TextSettings.FontColor := Color;
  SetVerdict(Verdict, Color);
end;

procedure TfrmMain.UpdateLaunchText;
begin
  if not FRunning then
  begin
    if FUserLaunched then
      lblLaunch.Text := 'START for another run'
    else
      lblLaunch.Text := 'Press START';
  end
  else if FUserLaunched then
    lblLaunch.Text := ''
  else if (FStageMode = smManual) and (FPhase = tpStaging) then
    lblLaunch.Text := 'HOLD TO CREEP FORWARD' + sLineBreak + 'let go when staged'
  else
    lblLaunch.Text := 'TAP TO LAUNCH';
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
      if IsNan(R.ReactionMs) then
        Lines.Append(Format('#%d  early', [I + 1]))
      else
        Lines.Append(Format('#%d  %s', [I + 1, FormatSecs(R.ReactionMs)]));
      if R.Mode = tmSportsman then
        Lines.Append(' S');
      if R.Foul then
        Lines.Append(' R');
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

procedure TfrmMain.btnTreeModeClick(Sender: TObject);
begin
  if FRunning then
    Exit;
  if FTreeMode = tmPro then
    FTreeMode := tmSportsman
  else
    FTreeMode := tmPro;
  SaveSettings;
  ResetTree;
end;

procedure TfrmMain.btnLaneClick(Sender: TObject);
begin
  if FRunning then
    Exit;
  FUserLane := 1 - FUserLane;
  SaveSettings;
  ResetTree;
end;

procedure TfrmMain.btnStagingClick(Sender: TObject);
begin
  if FRunning then
    Exit;
  if FStageMode = smAuto then
    FStageMode := smManual
  else
    FStageMode := smAuto;
  SaveSettings;
  ResetTree;
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
   // Canvas.StrokeThickness := Max(2, Radius * 0.12);
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
    Canvas.StrokeThickness := 2;
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
      Canvas.StrokeThickness := 2;
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
