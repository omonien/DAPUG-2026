{ -----------------------------------------------------------------------------
  /// <summary>Loads + validates config.ini into a TConfig record.</summary>
  /// <remarks>
  ///   Fail-fast: any missing/invalid required field raises EConfigError
  ///   with a message that names the failing key.
  /// </remarks>
  /// <copyright>Copyright (c) 2026 Olaf Monien. MIT License.</copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Config;

interface

uses
  System.SysUtils, System.IniFiles;

type
  EConfigError = class(Exception);

  TConfig = record
    Port: Integer;
    ApiKey: string;
    Model: string;
    Provider: string; // 'native' | 'delphigemini'
    UploadDir: string;
    ResultDir: string;
    RetentionMinutes: Integer;
    DescribeModel: string;
  end;

function LoadConfig(const APath: string): TConfig;

implementation

function LoadConfig(const APath: string): TConfig;
var
  LIni: TMemIniFile;
begin
  // Use TMemIniFile (Delphi-native parser) rather than TIniFile (Win32
  // GetPrivateProfileString), which mishandles relative paths and requires
  // strict CRLF line endings on Windows.
  LIni := TMemIniFile.Create(APath, TEncoding.UTF8);
  try
    Result.Port := LIni.ReadInteger('Server', 'Port', 8080);

    Result.ApiKey := Trim(LIni.ReadString('Gemini', 'ApiKey', ''));
    if Result.ApiKey = '' then
      raise EConfigError.Create('[Gemini] ApiKey is empty. Get one at https://aistudio.google.com/app/apikey');
    if not Result.ApiKey.StartsWith('AIza') then
      raise EConfigError.Create('[Gemini] ApiKey does not look like a Gemini key (should start with AIza...)');

    Result.Model := LIni.ReadString('Gemini', 'Model', 'gemini-3-pro-image-preview');

    Result.Provider := LowerCase(LIni.ReadString('Upscaler', 'Provider', 'native'));
    if (Result.Provider <> 'native') and (Result.Provider <> 'delphigemini') then
      raise EConfigError.CreateFmt('[Upscaler] Provider=%s is invalid. Use native or delphigemini.',
        [Result.Provider]);

    Result.UploadDir := LIni.ReadString('Storage', 'UploadDir', './var/uploads');
    Result.ResultDir := LIni.ReadString('Storage', 'ResultDir', './var/results');
    Result.RetentionMinutes := LIni.ReadInteger('Storage', 'RetentionMinutes', 30);
    Result.DescribeModel := LIni.ReadString('Describer', 'Model',
      'gemini-3.1-flash-lite-preview');
  finally
    LIni.Free;
  end;
end;

end.
