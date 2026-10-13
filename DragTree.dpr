program DragTree;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Types,
  MainForm in 'MainForm.pas' {frmMain};

{$R *.res}

begin
  Application.Initialize;
  Application.FormFactor.Orientations := [TScreenOrientation.Portrait];
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
