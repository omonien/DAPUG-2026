program DX.DateChanger;

uses
  System.StartUpCopy,
  FMX.Forms,
  FormMain in 'src\FormMain.pas' {MainForm},
  DX.DateChanger.Parser   in 'src\DX.DateChanger.Parser.pas',
  DX.DateChanger.FileTime in 'src\DX.DateChanger.FileTime.pas',
  DX.DateChanger.Service  in 'src\DX.DateChanger.Service.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
