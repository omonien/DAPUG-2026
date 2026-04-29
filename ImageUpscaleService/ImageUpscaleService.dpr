program ImageUpscaleService;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  IUS.Server in 'src\IUS.Server.pas',
  IUS.Config in 'src\IUS.Config.pas',
  IUS.JobQueue in 'src\IUS.JobQueue.pas',
  IUS.Storage in 'src\IUS.Storage.pas',
  IUS.Routes in 'src\IUS.Routes.pas',
  IUS.Validation in 'src\IUS.Validation.pas',
  IUS.Prompt in 'src\IUS.Prompt.pas',
  IUS.Upscaler.Intf in 'src\IUS.Upscaler.Intf.pas',
  IUS.Upscaler.Fake in 'src\IUS.Upscaler.Fake.pas',
  IUS.Upscaler.Native in 'src\IUS.Upscaler.Native.pas',
  IUS.Upscaler.DelphiGemini in 'src\IUS.Upscaler.DelphiGemini.pas',
  IUS.Describer.Intf in 'src\IUS.Describer.Intf.pas';

begin
  try
    RunServer;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      Writeln('See config.ini.example for the expected configuration shape.');
      ExitCode := 1;
    end;
  end;
end.
