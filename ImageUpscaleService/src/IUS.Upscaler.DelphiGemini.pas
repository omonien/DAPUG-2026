{ -----------------------------------------------------------------------------
  /// <summary>
  ///   IUpscaler implementation using the MaxiDonkey/DelphiGemini library.
  /// </summary>
  /// <remarks>
  ///   Pedagogical contrast to IUS.Upscaler.Native: the same Nano Banana Pro
  ///   call expressed via the community wrapper. Same model, same prompt,
  ///   same output. The wrapper handles the JSON shape, base64 encoding, and
  ///   response parsing; we just hand it bytes + mime + size.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit IUS.Upscaler.DelphiGemini;

interface

uses
  System.SysUtils,
  IUS.Upscaler.Intf;

type
  TDelphiGeminiUpscaler = class(TInterfacedObject, IUpscaler)
  strict private
    FApiKey: string;
    FModel: string;
    FPrompt: string;
  public
    constructor Create(const AApiKey, AModel, APrompt: string);
    function Upscale(const ASource: TBytes;
                     const ASourceMime: string;
                     const AResolution: TUpscaleResolution): TBytes;
  end;

implementation

uses
  System.NetEncoding,
  Gemini,
  Gemini.Chat,
  Gemini.Chat.Request,
  Gemini.Chat.Request.GenerationConfig,
  Gemini.Chat.Response,
  Gemini.Helpers;

constructor TDelphiGeminiUpscaler.Create(const AApiKey, AModel, APrompt: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FModel := AModel;
  FPrompt := APrompt;
end;

function TDelphiGeminiUpscaler.Upscale(const ASource: TBytes;
                                       const ASourceMime: string;
                                       const AResolution: TUpscaleResolution): TBytes;
var
  LClient: IGemini;
  LChat: TChat;
  LCandidate: TChatCandidate;
  LPart: TChatPart;
  LBase64: string;
  LResolutionStr: string;
begin
  LClient := TGeminiFactory.CreateInstance(FApiKey);
  LBase64 := TNetEncoding.Base64.EncodeBytesToString(ASource);
  LResolutionStr := ResolutionToApiString(AResolution);

  try
    LChat := LClient.Chat.Create(FModel,
      procedure(Params: TChatParams)
      begin
        Params
          .Contents(
            Generation.Contents
              .AddParts(
                Generation.Parts
                  .AddInlineData(LBase64, ASourceMime)
                  .AddText(FPrompt)
              )
          )
          .GenerationConfig(
            TGenerationConfig.Create
              .ImageConfig(
                TImageConfig.Create
                  .ImageSize(LResolutionStr)
              )
          );
      end);
  except
    on E: Exception do
      raise EUpscalerNetworkError.Create('DelphiGemini call failed: ' + E.Message);
  end;

  try
    if (LChat = nil) or (Length(LChat.Candidates) = 0) then
      raise EUpscalerEmptyResultError.Create('DelphiGemini returned no candidates');

    for LCandidate in LChat.Candidates do
      if LCandidate.Content <> nil then
        for LPart in LCandidate.Content.Parts do
          if Assigned(LPart.InlineData) then
          begin
            Result := TNetEncoding.Base64.DecodeStringToBytes(LPart.InlineData.Data);
            Exit;
          end;

    raise EUpscalerEmptyResultError.Create('DelphiGemini response had no inlineData image part');
  finally
    LChat.Free;
  end;
end;

end.
