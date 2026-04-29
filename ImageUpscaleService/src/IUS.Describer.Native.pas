{ -----------------------------------------------------------------------------
  /// <summary>
  ///   IDescriber implementation using TNetHTTPClient + System.JSON to call
  ///   Gemini Flash's generateContent endpoint with structured-output.
  /// </summary>
  /// <remarks>
  ///   Pedagogical: built side-by-side with TNativeUpscaler so the workshop
  ///   can compare. Same wire shape, different generationConfig - this one
  ///   asks for application/json with a fixed responseSchema (title + caption)
  ///   so parsing is a one-liner instead of regex over prose.
  /// </remarks>
  /// <copyright>Copyright (c) 2026 Olaf Monien. MIT License.</copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Describer.Native;

interface

uses
  System.SysUtils, System.Classes, System.NetEncoding, System.JSON,
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient,
  IUS.Describer.Intf;

type
  TNativeDescriber = class(TInterfacedObject, IDescriber)
  strict private
    FApiKey: string;
    FModel: string;
  public
    constructor Create(const AApiKey, AModel: string);
    /// <summary>Builds the JSON request body. Public so unit tests can inspect
    ///   the wire format without going through the HTTP layer.</summary>
    function BuildRequestBody(const AImage: TBytes; const AImageMime: string): string;
    /// <summary>Parses a Gemini structured-output response into a TDescription.
    ///   Public for unit-test purposes.</summary>
    function ExtractDescription(const AResponseBody: string): TDescription;
    function Describe(const AImage: TBytes; const AImageMime: string): TDescription;
    /// <summary>Maps an HTTP status code to an EDescriber* exception.
    ///   Class method so tests can drive it directly.</summary>
    class procedure MapStatusCode(const AStatusCode: Integer; const ABody: string); static;
  end;

implementation

uses
  IUS.DescribePrompt;

constructor TNativeDescriber.Create(const AApiKey, AModel: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FModel  := AModel;
end;

function TNativeDescriber.BuildRequestBody(const AImage: TBytes;
                                           const AImageMime: string): string;
var
  LRoot, LContent, LTextPart, LImagePart, LInlineData, LGenCfg, LSchema,
  LProps, LTitleProp, LCaptionProp: TJSONObject;
  LContentsArr, LPartsArr, LRequired: TJSONArray;
begin
  LRoot := TJSONObject.Create;
  try
    LContentsArr := TJSONArray.Create;
    LContent     := TJSONObject.Create;
    LPartsArr    := TJSONArray.Create;

    LTextPart := TJSONObject.Create;
    LTextPart.AddPair('text', cDescribePrompt);
    LPartsArr.AddElement(LTextPart);

    LInlineData := TJSONObject.Create;
    LInlineData.AddPair('mimeType', AImageMime);
    // Base64String (not Base64) is the unbroken-line variant. The Gemini API
    // rejects RFC 2045-style 76-char line wrapping with "Base64 decoding failed".
    LInlineData.AddPair('data',
      TNetEncoding.Base64String.EncodeBytesToString(AImage));
    LImagePart := TJSONObject.Create;
    LImagePart.AddPair('inlineData', LInlineData);
    LPartsArr.AddElement(LImagePart);

    LContent.AddPair('parts', LPartsArr);
    LContentsArr.AddElement(LContent);
    LRoot.AddPair('contents', LContentsArr);

    // Structured output: ask for JSON conforming to a fixed schema.
    LTitleProp   := TJSONObject.Create;
    LTitleProp.AddPair('type', 'string');
    LCaptionProp := TJSONObject.Create;
    LCaptionProp.AddPair('type', 'string');

    LProps := TJSONObject.Create;
    LProps.AddPair('title', LTitleProp);
    LProps.AddPair('caption', LCaptionProp);

    LRequired := TJSONArray.Create;
    LRequired.Add('title');
    LRequired.Add('caption');

    LSchema := TJSONObject.Create;
    LSchema.AddPair('type', 'object');
    LSchema.AddPair('properties', LProps);
    LSchema.AddPair('required', LRequired);

    LGenCfg := TJSONObject.Create;
    LGenCfg.AddPair('responseMimeType', 'application/json');
    LGenCfg.AddPair('responseSchema', LSchema);
    LRoot.AddPair('generationConfig', LGenCfg);

    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TNativeDescriber.ExtractDescription(const AResponseBody: string): TDescription;
var
  LRoot, LCandidate, LContent, LPart, LInner: TJSONObject;
  LCandidates, LParts: TJSONArray;
  LText: string;
  I: Integer;
begin
  LRoot := TJSONObject.ParseJSONValue(AResponseBody) as TJSONObject;
  if LRoot = nil then
    raise EDescriberEmptyResultError.Create('Response is not valid JSON');
  try
    LCandidates := LRoot.GetValue<TJSONArray>('candidates');
    if (LCandidates = nil) or (LCandidates.Count = 0) then
      raise EDescriberEmptyResultError.Create('No candidates in response');
    LCandidate := LCandidates.Items[0] as TJSONObject;
    // A safety-blocked candidate has no 'content' field at all (it carries
    // finishReason + safetyRatings instead). Treat that as an empty result
    // so the worker's silent soft-fail catches it rather than dereferencing
    // nil and propagating an AV.
    if not LCandidate.TryGetValue<TJSONObject>('content', LContent) or
       (LContent = nil) then
      raise EDescriberEmptyResultError.Create('No content in candidate');
    if not LContent.TryGetValue<TJSONArray>('parts', LParts) or
       (LParts = nil) then
      raise EDescriberEmptyResultError.Create('No parts in content');
    LText := '';
    for I := 0 to LParts.Count - 1 do
    begin
      LPart := LParts.Items[I] as TJSONObject;
      if LPart.TryGetValue<string>('text', LText) and (LText <> '') then
        Break;
    end;
    if LText = '' then
      raise EDescriberEmptyResultError.Create('No text part in response');

    // The text part itself is the JSON object enforced by responseSchema.
    // Free is nil-safe in Delphi, so the try/finally covers both the
    // successful-parse path and the failed-parse path uniformly.
    LInner := TJSONObject.ParseJSONValue(LText) as TJSONObject;
    try
      if LInner = nil then
        raise EDescriberEmptyResultError.Create('Inner text is not JSON');
      if not LInner.TryGetValue<string>('title', Result.Title) or
         (Trim(Result.Title) = '') then
        raise EDescriberEmptyResultError.Create('Missing title field');
      if not LInner.TryGetValue<string>('caption', Result.Caption) or
         (Trim(Result.Caption) = '') then
        raise EDescriberEmptyResultError.Create('Missing caption field');
    finally
      LInner.Free;
    end;
  finally
    LRoot.Free;
  end;
end;

class procedure TNativeDescriber.MapStatusCode(const AStatusCode: Integer;
                                               const ABody: string);
begin
  case AStatusCode of
    200: ; // ok
    429: raise EDescriberQuotaError.Create('429 quota');
    400, 403, 404:
      raise EDescriberRejectedError.CreateFmt('%d %s', [AStatusCode, ABody]);
    500..599:
      raise EDescriberServerError.CreateFmt('%d %s', [AStatusCode, ABody]);
  else
    raise EDescriberRejectedError.CreateFmt('%d %s', [AStatusCode, ABody]);
  end;
end;

function TNativeDescriber.Describe(const AImage: TBytes;
                                   const AImageMime: string): TDescription;
var
  LClient: TNetHTTPClient;
  LRequest: TNetHTTPRequest;
  LResponse: IHTTPResponse;
  LBody: TStringStream;
  LUrl: string;
begin
  LClient := TNetHTTPClient.Create(nil);
  LRequest := TNetHTTPRequest.Create(nil);
  LBody := TStringStream.Create(BuildRequestBody(AImage, AImageMime), TEncoding.UTF8);
  try
    LClient.ConnectionTimeout := 30000;
    LClient.ResponseTimeout   := 30000;
    LRequest.Client := LClient;
    LRequest.CustomHeaders['x-goog-api-key'] := FApiKey;
    LRequest.CustomHeaders['Content-Type']   := 'application/json';
    LUrl := Format(
      'https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent',
      [FModel]);

    try
      LResponse := LRequest.Post(LUrl, LBody);
    except
      on E: ENetHTTPClientException do
        raise EDescriberNetworkError.Create('Network error: ' + E.Message);
    end;

    MapStatusCode(LResponse.StatusCode, LResponse.ContentAsString);
    Result := ExtractDescription(LResponse.ContentAsString);
  finally
    LBody.Free;
    LRequest.Free;
    LClient.Free;
  end;
end;

end.
