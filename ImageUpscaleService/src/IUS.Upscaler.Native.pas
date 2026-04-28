{ -----------------------------------------------------------------------------
  /// <summary>
  ///   IUpscaler implementation using TNetHTTPClient + System.JSON to call
  ///   Nano Banana Pro's generateContent endpoint directly.
  /// </summary>
  /// <remarks>
  ///   Pedagogical: this unit shows the bare wire format. Builds the JSON
  ///   request, sends as POST with the API key in x-goog-api-key, parses the
  ///   inlineData PNG out of the response, returns its bytes. HTTP status
  ///   codes are mapped to specific EUpscaler* exception subclasses.
  /// </remarks>
  /// <copyright>Copyright (c) 2026 Olaf Monien. MIT License.</copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Upscaler.Native;

interface

uses
  System.SysUtils, System.Classes, System.NetEncoding, System.JSON,
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient,
  IUS.Upscaler.Intf;

type
  TNativeUpscaler = class(TInterfacedObject, IUpscaler)
  strict private
    FApiKey: string;
    FModel: string;
    FPrompt: string;
    function BuildRequestBody(const ASource: TBytes;
                              const ASourceMime: string;
                              const AResolution: TUpscaleResolution): string;
    function ExtractInlineImage(const AResponseBody: string): TBytes;
  public
    constructor Create(const AApiKey, AModel, APrompt: string);
    function Upscale(const ASource: TBytes;
                     const ASourceMime: string;
                     const AResolution: TUpscaleResolution): TBytes;
  end;

implementation

uses
  IUS.Prompt;

constructor TNativeUpscaler.Create(const AApiKey, AModel, APrompt: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FModel := AModel;
  FPrompt := APrompt;
end;

function TNativeUpscaler.BuildRequestBody(const ASource: TBytes;
                                          const ASourceMime: string;
                                          const AResolution: TUpscaleResolution): string;
var
  LRoot, LContents, LContent, LParts, LTextPart, LImagePart, LInlineData,
  LGenCfg, LImageCfg: TJSONObject;
  LContentsArr, LPartsArr: TJSONArray;
begin
  LRoot := TJSONObject.Create;
  try
    LContentsArr := TJSONArray.Create;
    LContent := TJSONObject.Create;
    LPartsArr := TJSONArray.Create;

    LTextPart := TJSONObject.Create;
    LTextPart.AddPair('text', FPrompt);
    LPartsArr.AddElement(LTextPart);

    LInlineData := TJSONObject.Create;
    LInlineData.AddPair('mimeType', ASourceMime);
    LInlineData.AddPair('data', TNetEncoding.Base64.EncodeBytesToString(ASource));
    LImagePart := TJSONObject.Create;
    LImagePart.AddPair('inlineData', LInlineData);
    LPartsArr.AddElement(LImagePart);

    LContent.AddPair('parts', LPartsArr);
    LContentsArr.AddElement(LContent);
    LRoot.AddPair('contents', LContentsArr);

    LImageCfg := TJSONObject.Create;
    LImageCfg.AddPair('imageSize', ResolutionToApiString(AResolution));
    LGenCfg := TJSONObject.Create;
    LGenCfg.AddPair('imageConfig', LImageCfg);
    LRoot.AddPair('generationConfig', LGenCfg);

    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TNativeUpscaler.ExtractInlineImage(const AResponseBody: string): TBytes;
var
  LRoot, LCandidate, LContent, LPart, LInlineData: TJSONObject;
  LCandidates, LParts: TJSONArray;
  I: Integer;
  LData: string;
begin
  LRoot := TJSONObject.ParseJSONValue(AResponseBody) as TJSONObject;
  if LRoot = nil then
    raise EUpscalerEmptyResultError.Create('Response is not valid JSON');
  try
    LCandidates := LRoot.GetValue<TJSONArray>('candidates');
    if (LCandidates = nil) or (LCandidates.Count = 0) then
      raise EUpscalerEmptyResultError.Create('No candidates in response');
    LCandidate := LCandidates.Items[0] as TJSONObject;
    LContent := LCandidate.GetValue<TJSONObject>('content');
    LParts := LContent.GetValue<TJSONArray>('parts');
    for I := 0 to LParts.Count - 1 do
    begin
      LPart := LParts.Items[I] as TJSONObject;
      LInlineData := LPart.GetValue<TJSONObject>('inlineData');
      if LInlineData <> nil then
      begin
        LData := LInlineData.GetValue<string>('data');
        Result := TNetEncoding.Base64.DecodeStringToBytes(LData);
        Exit;
      end;
    end;
    raise EUpscalerEmptyResultError.Create('No inlineData part in response');
  finally
    LRoot.Free;
  end;
end;

function TNativeUpscaler.Upscale(const ASource: TBytes;
                                 const ASourceMime: string;
                                 const AResolution: TUpscaleResolution): TBytes;
var
  LClient: TNetHTTPClient;
  LRequest: TNetHTTPRequest;
  LResponse: IHTTPResponse;
  LBody: TStringStream;
  LUrl: string;
begin
  LClient := TNetHTTPClient.Create(nil);
  LRequest := TNetHTTPRequest.Create(nil);
  LBody := TStringStream.Create(BuildRequestBody(ASource, ASourceMime, AResolution), TEncoding.UTF8);
  try
    LClient.ConnectionTimeout := 60000;
    LClient.ResponseTimeout := 60000;
    LRequest.Client := LClient;
    LRequest.CustomHeaders['x-goog-api-key'] := FApiKey;
    LRequest.CustomHeaders['Content-Type'] := 'application/json';
    LUrl := Format(
      'https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent',
      [FModel]);

    try
      LResponse := LRequest.Post(LUrl, LBody);
    except
      on E: ENetHTTPClientException do
        raise EUpscalerNetworkError.Create('Network error: ' + E.Message);
    end;

    case LResponse.StatusCode of
      200: ; // fall through to parse
      429: raise EUpscalerQuotaError.Create('429 quota');
      400, 403, 404: raise EUpscalerRejectedError.CreateFmt('%d %s', [LResponse.StatusCode, LResponse.ContentAsString]);
      500..599: raise EUpscalerServerError.CreateFmt('%d %s', [LResponse.StatusCode, LResponse.StatusText]);
    else
      raise EUpscalerRejectedError.CreateFmt('%d %s', [LResponse.StatusCode, LResponse.StatusText]);
    end;

    Result := ExtractInlineImage(LResponse.ContentAsString);
  finally
    LBody.Free;
    LRequest.Free;
    LClient.Free;
  end;
end;

end.
