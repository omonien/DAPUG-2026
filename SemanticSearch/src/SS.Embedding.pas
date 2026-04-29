{ -----------------------------------------------------------------------------
  /// <summary>
  ///   SS.Embedding
  ///   Calls an OpenAI-compatible /embeddings endpoint and returns
  ///   floating-point vectors.
  /// </summary>
  /// <remarks>
  ///   Uses TNetHTTPClient + TNetHTTPRequest + System.JSON. Works with
  ///   OpenAI, Azure, Ollama, LM Studio, or any server that exposes
  ///   the /embeddings endpoint.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit SS.Embedding;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient;

type
  TEmbeddingVector = TArray<Double>;

  TEmbeddingResult = record
    Vector: TEmbeddingVector;
    TokenCount: Integer;
  end;

  TEmbeddingClient = class
  strict private
    FApiKey: string;
    FModel: string;
    FBaseUrl: string;
    function BuildRequestBody(const AText: string): string;
    function ParseResponse(const AResponseBody: string): TEmbeddingResult;
  public
    constructor Create(const AApiKey, AModel, ABaseUrl: string);
    function GetEmbedding(const AText: string): TEmbeddingResult;
    function GetEmbeddings(const ATexts: TArray<string>): TArray<TEmbeddingResult>;
    class function CosineSimilarity(const A, B: TEmbeddingVector): Double; static;
  end;

implementation

uses
  System.Math;

constructor TEmbeddingClient.Create(const AApiKey, AModel, ABaseUrl: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FModel := AModel;
  FBaseUrl := ABaseUrl.TrimRight(['/']);
end;

function TEmbeddingClient.BuildRequestBody(const AText: string): string;
var
  LRoot: TJSONObject;
  LInputArr: TJSONArray;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('model', FModel);
    LInputArr := TJSONArray.Create;
    LInputArr.Add(AText);
    LRoot.AddPair('input', LInputArr);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TEmbeddingClient.ParseResponse(const AResponseBody: string): TEmbeddingResult;
var
  LRoot, LDataItem, LUsage: TJSONObject;
  LData: TJSONArray;
  LEmbArr: TJSONArray;
  I: Integer;
begin
  LRoot := TJSONObject.ParseJSONValue(AResponseBody) as TJSONObject;
  if LRoot = nil then
    raise Exception.Create('Embedding response is not valid JSON');
  try
    LData := LRoot.GetValue<TJSONArray>('data');
    if (LData = nil) or (LData.Count = 0) then
      raise Exception.Create('No embedding data in response');
    LDataItem := LData.Items[0] as TJSONObject;
    LEmbArr := LDataItem.GetValue<TJSONArray>('embedding');
    SetLength(Result.Vector, LEmbArr.Count);
    for I := 0 to LEmbArr.Count - 1 do
      Result.Vector[I] := LEmbArr.Items[I].AsType<Double>;
    Result.TokenCount := 0;
    LUsage := LRoot.GetValue<TJSONObject>('usage');
    if LUsage <> nil then
      Result.TokenCount := LUsage.GetValue<Integer>('total_tokens', 0);
  finally
    LRoot.Free;
  end;
end;

function TEmbeddingClient.GetEmbedding(const AText: string): TEmbeddingResult;
var
  LClient: TNetHTTPClient;
  LRequest: TNetHTTPRequest;
  LResponse: IHTTPResponse;
  LBody: TStringStream;
  LUrl: string;
begin
  LClient := TNetHTTPClient.Create(nil);
  LRequest := TNetHTTPRequest.Create(nil);
  LBody := TStringStream.Create(BuildRequestBody(AText), TEncoding.UTF8);
  try
    LClient.ConnectionTimeout := 30000;
    LClient.ResponseTimeout := 60000;
    LRequest.Client := LClient;
    LRequest.CustomHeaders['Authorization'] := 'Bearer ' + FApiKey;
    LRequest.CustomHeaders['Content-Type'] := 'application/json';
    LUrl := FBaseUrl + '/embeddings';
    try
      LResponse := LRequest.Post(LUrl, LBody);
    except
      on E: ENetHTTPClientException do
        raise Exception.Create('Embedding network error: ' + E.Message);
    end;
    if LResponse.StatusCode <> 200 then
      raise Exception.CreateFmt('Embedding API error %d: %s',
        [LResponse.StatusCode, Copy(LResponse.ContentAsString(TEncoding.UTF8), 1, 500)]);
    Result := ParseResponse(LResponse.ContentAsString(TEncoding.UTF8));
  finally
    LBody.Free;
    LRequest.Free;
    LClient.Free;
  end;
end;

function TEmbeddingClient.GetEmbeddings(const ATexts: TArray<string>): TArray<TEmbeddingResult>;
var
  I: Integer;
begin
  SetLength(Result, Length(ATexts));
  for I := 0 to High(ATexts) do
    Result[I] := GetEmbedding(ATexts[I]);
end;

class function TEmbeddingClient.CosineSimilarity(const A, B: TEmbeddingVector): Double;
var
  I: Integer;
  LDot, LNormA, LNormB: Double;
begin
  if Length(A) <> Length(B) then
    raise Exception.CreateFmt('Vector dimension mismatch: %d vs %d', [Length(A), Length(B)]);
  LDot := 0;
  LNormA := 0;
  LNormB := 0;
  for I := 0 to High(A) do
  begin
    LDot := LDot + A[I] * B[I];
    LNormA := LNormA + A[I] * A[I];
    LNormB := LNormB + B[I] * B[I];
  end;
  if (LNormA = 0) or (LNormB = 0) then
    Exit(0);
  Result := LDot / (Sqrt(LNormA) * Sqrt(LNormB));
end;

end.
