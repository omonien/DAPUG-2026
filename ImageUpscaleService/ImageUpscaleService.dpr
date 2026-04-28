program ImageUpscaleService;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse;

begin
  try
    Writeln('ImageUpscaleService starting (no routes yet).');
    THorse.Listen(8080,
      procedure
      begin
        Writeln('Listening on http://localhost:8080');
      end);
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
